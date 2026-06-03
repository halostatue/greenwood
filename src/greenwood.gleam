//// Greenwood: a generic trivia-preserving concrete syntax tree
////
//// Greenwood provides an immutable concrete syntax tree parameterized by node
//// and token `kind`, with associated trivia and structural transformation
//// primitives. Greenwood syntax trees are format-agnostic and parsers supply
//// their own `kind` types.
////
//// ### Function Groups
////
//// There are six types of functions in the Greenwood interface:
////
//// - `builder`: build a Greenwood tree
//// - `query`: interrogate a Greenwood tree
//// - `transformer`: transform a Greenwood tree
//// - `traversal`: traverse a Greenwood tree
//// - `trivia`: manage trivia on Greenwood tree node(s)
//// - `cursor`: navigate and edit a Greenwood tree with a movable cursor
////
//// Each function and type in the Greenwood interface is marked with the
//// appropriate interface group or groups.
////
//// ### Trivia
////
//// In syntax tree terminology, "trivia" refers to source text that has no
//// semantic meaning to the language but matters to humans: whitespace,
//// comments, blank lines, and sometimes preprocessor directives. A pure AST
//// discards trivia entirely, but a CST must track it.
////
//// Greenwood implements a hybrid concrete syntax tree supporting
//// [Roslyn][dn]-style Trivia annotations (attached trivia) or
//// [Rowan][rust]-style green tree child tokens (inline trivia), depending on
//// the choices made by the parser.
////
//// - Attached trivia (Roslyn-style) is where each node carries leading and
////   trailing trivia tokens. A comment above a function "belongs to" that
////   function node. This makes it easy to move a node and have its comments
////   follow. Greenwood supports this with `Trivia(leading, trailing)`.
////
//// - Inline trivia (Rowan-style) tokens are siblings in the children list,
////   with no special attachment. The tree is uniform but the parser (or
////   a later pass) must decide ownership when moving nodes. Greenwood supports
////   this with `Bare` trivia markers.
////
//// ### Concrete and Abstract Syntax Trees
////
//// A concrete syntax tree is a tree representation of the actual tokens for
//// a language, whereas abstract syntax trees are simplified forms discarding
//// anything not necessary for resolution of the language into meaning.
////
//// As an example, consider what the abstract syntax tree for the following
//// Gleam code might look like:
////
//// ```gleam
//// /// Tail-recursive Fibonacci sequence implementation
//// pub fn fib(n: Int) -> Int {
////   case n {
////     0 | 1 -> n
////     _ -> fib(n - 1) + fib(n - 2)
////   }
//// }
//// ```
////
//// This would produce an executable abstract syntax tree like:
////
//// ```gleam
//// Function(
////  name: "fib", publicity: Public,
////  parameters: [Parameter(name: "n", type: Int)],
////  return_type: Int,
////  body: Case(
////    subjects: [Variable("n")],
////    clauses: [
////      Clause(patterns: [Int(0), Int(1)], body: Variable("n")),
////      Clause(patterns: [Discard], body: BinOp(
////        Add,
////        Call("fib", [BinOp(Sub, Variable("n"), Int(1))]),
////        Call("fib", [BinOp(Sub, Variable("n"), Int(2))]),
////      )),
////    ],
////  ),
//// )
//// ```
////
//// This could be transformed, but when rendered back to Gleam, the result
//// would _drop_ the leading documentation comment. Comparatively, the concrete
//// syntax tree is about the form of the text and _keeps_ the leading
//// documentation comment. Every single run of contiguous whitespace is
//// accounted for. Everything is assigned a meaning for preservation.
////
//// ```gleam
//// Function(
////   trivia: Trivia(leading: [
////     DocComment("/// Tail-recursive Fibonacci sequence implementation"),
////     Newline("\n")
////   ]),
////   children: [
////     Token(Pub, "pub"),
////     Token(Whitespace, " "),
////     Token(Fn, "fn"),
////     Token(Whitespace, " "),
////     Token(Name, "fib"),
////     Token(LeftParen, "("),
////     Token(Name, "n"),
////     Token(Colon, ":"),
////     Token(Whitespace, " "),
////     Token(UpperName, "Int"),
////     Token(RightParen, ")"),
////     Token(Whitespace, " "),
////     Token(Arrow, "->"),
////     Token(Whitespace, " "),
////     Token(UpperName, "Int"),
////     Token(Whitespace, " "),
////     Token(LeftBrace, "{"),
////     Token(Newline, "\n"),
////     Token(Whitespace, "  "),
////     Node(Case, [
////       Token(Case, "case"),
////       Token(Whitespace, " "),
////       Token(Name, "n"),
////       Token(Whitespace, " "),
////       Token(LeftBrace, "{"),
////       Token(Newline, "\n"),
////       ...every token including whitespace, pipes, arrows...
////     ]),
////     Token(Newline, "\n"),
////     Token(RightBrace, "}"),
////     Token(Newline, "\n"),
////   ],
//// )
//// ```
////
//// The differences are vast: the abstract syntax tree tells you what the code
//// means, but the concrete syntax tree tells you what the source looks like.
//// The source can be reconstructed byte-for-byte from the concrete syntax
//// tree.
////
//// This makes a concrete syntax tree useful for editors, language server
//// implementations, and for edit-safe transformations.
////
//// [dn]: https://github.com/dotnet/roslyn/blob/main/docs/wiki/Roslyn-Overview.md#syntax-trivia
//// [rust]: https://github.com/rust-analyzer/rowan

import gleam/bool
import gleam/list
import gleam/option.{type Option, None, Some}

/// A leaf node carrying literal source text for the `kind`.
///
/// `builder`
pub type Token(kind) {
  Token(kind: kind, text: String)
}

pub type Trivia(kind) {
  /// Trivia attached to an element: comments, whitespace, blank lines that
  /// should travel with the element during transforms. This is the Roslyn
  /// approach.
  ///
  /// `builder`, `trivia`
  Trivia(leading: List(Token(kind)), trailing: List(Token(kind)))

  /// No trivia association. Use this when trivia tokens (whitespace, comments)
  /// are stored directly in the node's `children` list rather than in separate
  /// leading/trailing fields. This is the Rowan approach: the tree is uniform
  /// and trivia is just another child element.
  ///
  /// This is also appropriate for nodes where trivia attachment is meaningless
  /// (e.g., a synthetic node created during a transform that has no source
  /// origin).
  ///
  /// `builder`, `trivia`
  Bare
}

/// An interior syntax tree node with typed children and associated trivia.
///
/// `builder`
pub type Node(kind) {
  Node(kind: kind, children: List(Element(kind)), trivia: Trivia(kind))
}

/// A child of a node: either an interior node or a leaf token.
///
/// `builder`
pub type Element(kind) {
  /// The constructor for a Node element.
  ///
  /// In parsers or syntax manipulation modules where there's substantial
  /// pattern matching, it may be beneficial to import this aliased to a much
  /// shorter name.
  ///
  /// ```gleam
  /// import greenwood.{NodeElement as N}
  /// ```
  ///
  /// `builder`
  NodeElement(Node(kind))
  /// The constructor for a Token element.
  ///
  /// In parsers or syntax manipulation modules where there's substantial
  /// pattern matching, it may be beneficial to import this aliased to a much
  /// shorter name.
  ///
  /// ```gleam
  /// import greenwood.{TokenElement as T}
  /// ```
  ///
  ///
  /// `builder`
  TokenElement(Token(kind))
}

/// A zipper provides a focused view into a tree (a cursor), allowing navigation
/// and local edits while preserving the ability to reconstruct the whole tree.
///
/// The term zipper comes from an [article by Gérard Huet][zipper] in 1997.
///
/// Gérard Huet. "The Zipper." Journal of Functional Programming, 7(5):549–554,
/// September 1997.
///
/// `cursor`
///
/// [zipper]: https://people.mpi-sws.org/~skilpat/plerg/papers/huet-zipper-2up.pdf
pub type Zipper(kind) {
  Zipper(focus: Node(kind), crumbs: List(Crumb(kind)))
}

/// A breadcrumb: the context needed to reconstruct a parent from a focused child.
///
/// `cursor`
pub type Crumb(kind) {
  Crumb(
    kind: kind,
    trivia: Trivia(kind),
    left: List(Element(kind)),
    right: List(Element(kind)),
  )
}

/// Create a node without Trivia.
///
/// This is the same as `Node(kind:, children:, trivia: Bare)`.
///
/// `builder`
pub fn node(
  kind kind: kind,
  children children: List(Element(kind)),
) -> Node(kind) {
  Node(kind:, children:, trivia: Bare)
}

/// Create a node with Trivia.
///
/// This is the same as `Node(kind:, children:, trivia:)`.
///
/// `builder`
pub fn node_with_trivia(
  kind kind: kind,
  children children: List(Element(kind)),
  trivia trivia: Trivia(kind),
) -> Node(kind) {
  Node(kind:, children:, trivia:)
}

/// Create a node element without Trivia. This is the same as
/// `NodeElement(Node(kind:, children:, trivia: Bare))`.
///
/// `builder`
pub fn node_element(
  kind kind: kind,
  children children: List(Element(kind)),
) -> Element(kind) {
  NodeElement(Node(kind:, children:, trivia: Bare))
}

/// Create a node element with Trivia. This is the same as
/// `NodeElement(Node(kind:, children:, trivia:))`.
///
/// `builder`
pub fn node_element_with_trivia(
  kind kind: kind,
  children children: List(Element(kind)),
  trivia trivia: Trivia(kind),
) -> Element(kind) {
  NodeElement(Node(kind:, children:, trivia:))
}

/// Create a token. This is the same as `Token(kind:, text:)`.
///
/// `builder`
pub fn token(kind kind: kind, text text: String) -> Token(kind) {
  Token(kind:, text:)
}

/// Create a token element. This is the same as `Token(kind:, text:)`.
///
/// `builder`
pub fn token_element(kind kind: kind, text text: String) -> Element(kind) {
  TokenElement(Token(kind:, text:))
}

/// Recursively fold over all elements depth-first.
///
/// If you only need to fold over a node's immediate children, consider using
/// `node.children |> list.fold(...)` directly.
///
/// `traversal`
pub fn fold(
  over node: Node(kind),
  from acc: a,
  with f: fn(a, Element(kind)) -> a,
) -> a {
  do_fold(node.children, acc, f)
}

/// Recursively fold over all elements depth-first, with depth. Depth `0` is the
/// immediate children of the provided `node` (e.g., `node.children`).
///
/// `traversal`
pub fn fold_with_depth(
  over node: Node(kind),
  from acc: a,
  with f: fn(a, Element(kind), Int) -> a,
) -> a {
  do_fold_with_depth(node.children, acc, f, 0)
}

/// Recursively traverse all elements for side effects, with depth.
///
/// `traversal`
pub fn each_with_depth(
  over node: Node(kind),
  with f: fn(Element(kind), Int) -> Nil,
) -> Nil {
  do_each_with_depth(node.children, f, 0)
}

/// Recursively traverse all elements for side effects.
///
/// `traversal`
pub fn each(over node: Node(kind), with f: fn(Element(kind)) -> Nil) -> Nil {
  do_each(node.children, f)
}

/// Map over immediate children of a node.
///
/// `transformer`
pub fn map_children(
  in node: Node(kind),
  with f: fn(Element(kind)) -> Element(kind),
) -> Node(kind) {
  Node(..node, children: list.map(node.children, f))
}

/// Recursively map all elements leaf nodes first. Child nodes are processed
/// before sibling nodes.
///
/// ```
///       A        ← processed last
///      / \
///     B   C      ← processed second
///    / \
///   D   E        ← processed first
/// ```
///
/// `transformer`
pub fn map_tree_up(
  in node: Node(kind),
  with f: fn(Element(kind)) -> Element(kind),
) -> Node(kind) {
  let children =
    list.map(node.children, fn(el) {
      case el {
        NodeElement(child) -> f(NodeElement(map_tree_up(in: child, with: f)))
        TokenElement(_) -> f(el)
      }
    })
  Node(..node, children:)
}

/// Recursively map all elements root node first. Child nodes are processed
/// before sibling nodes.
///
/// Unlike `map_tree_up`, this runs the mapping function over the root node
/// first and recurses into the _result_ of the mapping function. It is
/// therefore possible to affect the next iteration with the mapping function.
///
/// ```
///       A        ← processed first
///      / \
///     B′  C′     ← processed second
///    / \
///   D″  E″       ← processed last
/// ```
///
/// `transformer`
pub fn map_tree_down(
  in node: Node(kind),
  with f: fn(Element(kind)) -> Element(kind),
) -> Node(kind) {
  let children =
    list.map(node.children, fn(el) {
      let mapped = f(el)
      case mapped {
        NodeElement(child) -> NodeElement(map_tree_down(in: child, with: f))
        TokenElement(_) -> mapped
      }
    })
  Node(..node, children:)
}

/// Find the first immediate child element matching a predicate.
///
/// `query`
pub fn find_child(
  in node: Node(kind),
  where predicate: fn(Element(kind)) -> Bool,
) -> Option(Element(kind)) {
  list.find(node.children, predicate) |> option.from_result
}

/// Find all immediate child elements matching a predicate.
///
/// `query`
pub fn filter_children(
  in node: Node(kind),
  where predicate: fn(Element(kind)) -> Bool,
) -> List(Element(kind)) {
  list.filter(node.children, predicate)
}

/// Find the first descendant matching a predicate. Searches from root to leaves
/// returning the shallowest match.
///
/// `query`
pub fn find_descendant(
  in node: Node(kind),
  where predicate: fn(Element(kind)) -> Bool,
) -> Option(Element(kind)) {
  do_find_descendant(node.children, predicate)
}

/// Replace a child at a given index.
///
/// `transformer`
pub fn replace_child(
  in node: Node(kind),
  at index: Int,
  with element: Element(kind),
) -> Node(kind) {
  let children =
    list.index_map(node.children, fn(el, i) {
      use <- bool.guard(i == index, return: element)
      el
    })
  Node(..node, children:)
}

/// Replace the first child matching a predicate.
///
/// `transformer`
pub fn replace_first(
  in node: Node(kind),
  where predicate: fn(Element(kind)) -> Bool,
  with replacement: fn(Element(kind)) -> Element(kind),
) -> Node(kind) {
  let children = do_replace_first(node.children, predicate, replacement, [])
  Node(..node, children:)
}

/// Insert an element before the first child matching a predicate.
///
/// `transformer`
pub fn insert_before(
  in node: Node(kind),
  where predicate: fn(Element(kind)) -> Bool,
  insert element: Element(kind),
) -> Node(kind) {
  let children = do_insert_before(node.children, predicate, element, [])
  Node(..node, children:)
}

/// Insert an element after the first child matching a predicate.
///
/// `transformer`
pub fn insert_after(
  in node: Node(kind),
  where predicate: fn(Element(kind)) -> Bool,
  insert element: Element(kind),
) -> Node(kind) {
  let children = do_insert_after(node.children, predicate, element, [])
  Node(..node, children:)
}

/// Remove all children matching a predicate.
///
/// `transformer`
pub fn remove_children(
  in node: Node(kind),
  where predicate: fn(Element(kind)) -> Bool,
) -> Node(kind) {
  Node(..node, children: list.filter(node.children, fn(el) { !predicate(el) }))
}

/// Append a child to the end of a node's children.
///
/// `transformer`
pub fn append_child(
  in node: Node(kind),
  child element: Element(kind),
) -> Node(kind) {
  Node(..node, children: list.append(node.children, [element]))
}

/// Prepend a child to the beginning of a node's children.
///
/// `transformer`
pub fn prepend_child(
  in node: Node(kind),
  child element: Element(kind),
) -> Node(kind) {
  Node(..node, children: [element, ..node.children])
}

/// Attach leading trivia to a node.
///
/// `trivia`
pub fn set_leading_trivia(
  on node: Node(kind),
  trivia tokens: List(Token(kind)),
) -> Node(kind) {
  let new_trivia = case node.trivia {
    Trivia(leading: _, trailing: t) -> Trivia(leading: tokens, trailing: t)
    Bare -> Trivia(leading: tokens, trailing: [])
  }
  Node(..node, trivia: new_trivia)
}

/// Attach trailing trivia to a node.
///
/// `trivia`
pub fn set_trailing_trivia(
  on node: Node(kind),
  trivia tokens: List(Token(kind)),
) -> Node(kind) {
  let new_trivia = case node.trivia {
    Trivia(leading: l, trailing: _) -> Trivia(leading: l, trailing: tokens)
    Bare -> Trivia(leading: [], trailing: tokens)
  }
  Node(..node, trivia: new_trivia)
}

/// Get all trivia tokens (leading then trailing) from a node.
///
/// `trivia`
pub fn all_trivia(from node: Node(kind)) -> List(Token(kind)) {
  case node.trivia {
    Trivia(leading:, trailing:) -> list.append(leading, trailing)
    Bare -> []
  }
}

/// Get leading trivia tokens from a node.
///
/// `trivia`
pub fn leading_trivia(from node: Node(kind)) -> List(Token(kind)) {
  case node.trivia {
    Trivia(leading:, ..) -> leading
    Bare -> []
  }
}

/// Get trailing trivia tokens from a node.
///
/// `trivia`
pub fn trailing_trivia(from node: Node(kind)) -> List(Token(kind)) {
  case node.trivia {
    Trivia(trailing:, ..) -> trailing
    Bare -> []
  }
}

/// Create a zipper focused on the root node.
///
/// `cursor`
pub fn zip(root: Node(kind)) -> Zipper(kind) {
  Zipper(focus: root, crumbs: [])
}

/// Move focus to the first child that is a Node.
///
/// `cursor`
pub fn down(zipper: Zipper(kind)) -> Option(Zipper(kind)) {
  down_where(zipper:, predicate: fn(_) { True })
}

/// Move focus to the first child Node matching a predicate.
///
/// `cursor`
pub fn down_where(
  zipper zipper: Zipper(kind),
  predicate predicate: fn(Node(kind)) -> Bool,
) -> Option(Zipper(kind)) {
  do_down(zipper.focus, predicate, zipper.crumbs, [])
}

/// Move focus to the nearest sibling Node to the left of the focus.
///
/// Returns `None` if the focus is the root or has no Node sibling to the left.
///
/// `cursor`
pub fn left(zipper: Zipper(kind)) -> Option(Zipper(kind)) {
  left_where(zipper:, predicate: fn(_) { True })
}

/// Move focus to the nearest sibling Node to the left matching a predicate.
///
/// Token siblings (whitespace, comments stored inline) are skipped and remain
/// in place between the old and new focus.
///
/// `cursor`
pub fn left_where(
  zipper zipper: Zipper(kind),
  predicate predicate: fn(Node(kind)) -> Bool,
) -> Option(Zipper(kind)) {
  case zipper.crumbs {
    [] -> None
    [crumb, ..rest] ->
      case
        scan_left(crumb.left, predicate, [
          NodeElement(zipper.focus),
          ..crumb.right
        ])
      {
        Some(#(new_left, new_focus, new_right)) -> {
          let new_crumb =
            Crumb(
              kind: crumb.kind,
              trivia: crumb.trivia,
              left: new_left,
              right: new_right,
            )
          Some(Zipper(focus: new_focus, crumbs: [new_crumb, ..rest]))
        }
        None -> None
      }
  }
}

/// Move focus to the nearest sibling Node to the right of the focus.
///
/// Returns `None` if the focus is the root or has no Node sibling to the right.
///
/// `cursor`
pub fn right(zipper: Zipper(kind)) -> Option(Zipper(kind)) {
  right_where(zipper:, predicate: fn(_) { True })
}

/// Move focus to the nearest sibling Node to the right matching a predicate.
///
/// Token siblings (whitespace, comments stored inline) are skipped and remain
/// in place between the old and new focus.
///
/// `cursor`
pub fn right_where(
  zipper zipper: Zipper(kind),
  predicate predicate: fn(Node(kind)) -> Bool,
) -> Option(Zipper(kind)) {
  case zipper.crumbs {
    [] -> None
    [crumb, ..rest] ->
      case
        scan_right(crumb.right, predicate, [
          NodeElement(zipper.focus),
          ..crumb.left
        ])
      {
        Some(#(new_left, new_focus, new_right)) -> {
          let new_crumb =
            Crumb(
              kind: crumb.kind,
              trivia: crumb.trivia,
              left: new_left,
              right: new_right,
            )
          Some(Zipper(focus: new_focus, crumbs: [new_crumb, ..rest]))
        }
        None -> None
      }
  }
}

/// Move focus back up to the parent.
///
/// `cursor`
pub fn up(zipper: Zipper(kind)) -> Option(Zipper(kind)) {
  case zipper.crumbs {
    [] -> None
    [crumb, ..rest] -> {
      // `crumb.left` is stored nearest-first; reverse to restore source order.
      let children =
        list.append(list.reverse(crumb.left), [
          NodeElement(zipper.focus),
          ..crumb.right
        ])
      let parent = Node(kind: crumb.kind, children:, trivia: crumb.trivia)
      Some(Zipper(focus: parent, crumbs: rest))
    }
  }
}

/// Move focus up `n` parents. Strict: returns `None` if `n` is negative or if
/// the cursor would move above the root.
///
/// `up_n(z, by: 0)` returns `Some(z)`.
///
/// `cursor`
pub fn up_n(zipper zipper: Zipper(kind), by n: Int) -> Option(Zipper(kind)) {
  repeat_move(zipper, n, up)
}

/// Move focus `n` sibling Nodes to the left. Strict: returns `None` if the
/// move cannot be completed in full.
///
/// `left_n(z, by: 0)` returns `Some(z)`. Negative `n` flips direction:
/// `left_n(z, by: -n)` is equivalent to `right_n(z, by: n)`.
///
/// `cursor`
pub fn left_n(zipper zipper: Zipper(kind), by n: Int) -> Option(Zipper(kind)) {
  use <- bool.guard(n < 0, return: repeat_move(zipper, -n, right))

  repeat_move(zipper, n, left)
}

/// Move focus `n` sibling Nodes to the left where those nodes match
/// a predicate. Strict: returns `None` if the move cannot be completed in full.
///
/// Token siblings (whitespace, comments stored inline) are skipped and remain
/// in place between the old and new focus.
///
/// `left_n_where(zipper:, by: 0, predicate:)` returns `Some(zipper)`. Negative
/// `n` flips direction: `left_n_where(zipper:, by: -n, predicate:)` is
/// equivalent to `right_n_where(zipper:, by: n, predicate:)`
///
/// `cursor`
pub fn left_n_where(
  zipper zipper: Zipper(kind),
  by n: Int,
  predicate predicate: fn(Node(kind)) -> Bool,
) -> Option(Zipper(kind)) {
  case n {
    0 -> Some(zipper)
    _ if n < 0 -> right_n_where(zipper:, by: -n, predicate:)
    _ ->
      case left_where(zipper:, predicate:) {
        Some(zipper) -> left_n_where(zipper:, by: n - 1, predicate:)
        None -> None
      }
  }
}

/// Move focus `n` sibling Nodes to the right. Strict: returns `None` if the
/// move cannot be completed in full.
///
/// `right_n(z, by: 0)` returns `Some(z)`. Negative `n` flips direction:
/// `right_n(z, by: -n)` is equivalent to `left_n(z, by: n)`.
///
/// `cursor`
pub fn right_n(zipper zipper: Zipper(kind), by n: Int) -> Option(Zipper(kind)) {
  use <- bool.guard(n < 0, return: repeat_move(zipper, -n, left))

  repeat_move(zipper, n, right)
}

/// Move focus `n` sibling Nodes to the right where those nodes match
/// a predicate. Strict: returns `None` if the move cannot be completed in full.
///
/// Token siblings (whitespace, comments stored inline) are skipped and remain
/// in place between the old and new focus.
///
/// `right_n_where(zipper:, by: 0, predicate:)` returns `Some(zipper)`. Negative
/// `n` flips direction: `right_n_where(zipper:, by: -n, predicate:)` is
/// equivalent to `left_n_where(zipper:, by: n, predicate:)`
///
/// `cursor`
pub fn right_n_where(
  zipper zipper: Zipper(kind),
  by n: Int,
  predicate predicate: fn(Node(kind)) -> Bool,
) -> Option(Zipper(kind)) {
  case n {
    0 -> Some(zipper)
    _ if n < 0 -> left_n_where(zipper:, by: -n, predicate:)
    _ ->
      case right_where(zipper:, predicate:) {
        Some(zipper) -> right_n_where(zipper:, by: n - 1, predicate:)
        None -> None
      }
  }
}

/// Replace the focused node and return the updated zipper.
///
/// `cursor`
pub fn set_focus(
  zipper zipper: Zipper(kind),
  node node: Node(kind),
) -> Zipper(kind) {
  Zipper(..zipper, focus: node)
}

/// Apply a transform to the focused node.
///
/// `cursor`
pub fn map_focus(
  zipper: Zipper(kind),
  with f: fn(Node(kind)) -> Node(kind),
) -> Zipper(kind) {
  Zipper(..zipper, focus: f(zipper.focus))
}

/// Reconstruct the full tree from a zipper by moving up to the root.
///
/// `cursor`
pub fn unzip(zipper: Zipper(kind)) -> Node(kind) {
  case up(zipper) {
    Some(parent_zipper) -> unzip(parent_zipper)
    None -> zipper.focus
  }
}

fn do_find_descendant(
  elements: List(Element(kind)),
  predicate: fn(Element(kind)) -> Bool,
) -> Option(Element(kind)) {
  case elements {
    [] -> None
    [el, ..rest] -> {
      use <- bool.guard(predicate(el), return: Some(el))

      case el {
        NodeElement(child) ->
          do_find_descendant(child.children, predicate)
          |> option.lazy_or(fn() { do_find_descendant(rest, predicate) })
        TokenElement(_) -> do_find_descendant(rest, predicate)
      }
    }
  }
}

fn do_replace_first(
  elements: List(Element(kind)),
  predicate: fn(Element(kind)) -> Bool,
  replacement: fn(Element(kind)) -> Element(kind),
  acc: List(Element(kind)),
) -> List(Element(kind)) {
  case elements {
    [] -> list.reverse(acc)
    [el, ..rest] -> {
      use <- bool.guard(
        predicate(el),
        return: list.append(list.reverse(acc), [replacement(el), ..rest]),
      )
      do_replace_first(rest, predicate, replacement, [el, ..acc])
    }
  }
}

fn do_insert_before(
  elements: List(Element(kind)),
  predicate: fn(Element(kind)) -> Bool,
  element: Element(kind),
  acc: List(Element(kind)),
) -> List(Element(kind)) {
  case elements {
    [] -> list.reverse(acc)
    [el, ..rest] -> {
      use <- bool.guard(
        predicate(el),
        return: list.append(list.reverse(acc), [element, el, ..rest]),
      )
      do_insert_before(rest, predicate, element, [el, ..acc])
    }
  }
}

fn do_insert_after(
  elements: List(Element(kind)),
  predicate: fn(Element(kind)) -> Bool,
  element: Element(kind),
  acc: List(Element(kind)),
) -> List(Element(kind)) {
  case elements {
    [] -> list.reverse(acc)
    [el, ..rest] -> {
      use <- bool.guard(
        predicate(el),
        return: list.append(list.reverse(acc), [el, element, ..rest]),
      )
      do_insert_after(rest, predicate, element, [el, ..acc])
    }
  }
}

fn do_down(
  parent: Node(kind),
  predicate: fn(Node(kind)) -> Bool,
  crumbs: List(Crumb(kind)),
  left: List(Element(kind)),
) -> Option(Zipper(kind)) {
  case split_at_node(parent.children, predicate, left) {
    Some(#(left, child, right)) -> {
      let crumb = Crumb(kind: parent.kind, trivia: parent.trivia, left:, right:)
      Some(Zipper(focus: child, crumbs: [crumb, ..crumbs]))
    }
    None -> None
  }
}

/// `left` is accumulated nearest-first (reversed from source order) so that
/// `left`/`right` cursor moves are O(1) and `up` can rebuild children with a
/// single `list.reverse`.
fn split_at_node(
  elements: List(Element(kind)),
  predicate: fn(Node(kind)) -> Bool,
  left: List(Element(kind)),
) -> Option(#(List(Element(kind)), Node(kind), List(Element(kind)))) {
  case elements {
    [] -> None
    [NodeElement(n), ..rest] -> {
      use <- bool.guard(predicate(n), return: Some(#(left, n, rest)))
      split_at_node(rest, predicate, [NodeElement(n), ..left])
    }
    [other, ..rest] -> split_at_node(rest, predicate, [other, ..left])
  }
}

/// Walk `elements` (the crumb's nearest-first `left` list) looking for the
/// first matching Node. Elements skipped along the way are prepended to
/// `right` so they end up positioned between the new focus and the prior
/// focus in source order.
fn scan_left(
  elements: List(Element(kind)),
  predicate: fn(Node(kind)) -> Bool,
  right: List(Element(kind)),
) -> Option(#(List(Element(kind)), Node(kind), List(Element(kind)))) {
  case elements {
    [] -> None
    [NodeElement(n), ..rest] -> {
      use <- bool.guard(predicate(n), return: Some(#(rest, n, right)))
      scan_left(rest, predicate, [NodeElement(n), ..right])
    }
    [other, ..rest] -> scan_left(rest, predicate, [other, ..right])
  }
}

/// Walk `elements` (the crumb's source-order `right` list) looking for the
/// first matching Node. Elements skipped along the way are prepended to
/// `left` (which is maintained nearest-first) so they end up positioned
/// between the prior focus and the new focus in source order.
fn scan_right(
  elements: List(Element(kind)),
  predicate: fn(Node(kind)) -> Bool,
  left: List(Element(kind)),
) -> Option(#(List(Element(kind)), Node(kind), List(Element(kind)))) {
  case elements {
    [] -> None
    [NodeElement(n), ..rest] -> {
      use <- bool.guard(predicate(n), return: Some(#(left, n, rest)))
      scan_right(rest, predicate, [NodeElement(n), ..left])
    }
    [other, ..rest] -> scan_right(rest, predicate, [other, ..left])
  }
}

fn repeat_move(
  zipper: Zipper(kind),
  n: Int,
  move: fn(Zipper(kind)) -> Option(Zipper(kind)),
) -> Option(Zipper(kind)) {
  case n {
    _ if n < 0 -> None
    0 -> Some(zipper)
    _ ->
      case move(zipper) {
        Some(z) -> repeat_move(z, n - 1, move)
        None -> None
      }
  }
}

fn do_fold(
  children: List(Element(kind)),
  acc: a,
  f: fn(a, Element(kind)) -> a,
) -> a {
  list.fold(children, acc, fn(acc, el) {
    let acc = f(acc, el)
    case el {
      NodeElement(child) -> do_fold(child.children, acc, f)
      TokenElement(_) -> acc
    }
  })
}

fn do_fold_with_depth(
  children: List(Element(kind)),
  acc: a,
  f: fn(a, Element(kind), Int) -> a,
  depth: Int,
) -> a {
  list.fold(children, acc, fn(acc, el) {
    let acc = f(acc, el, depth)
    case el {
      NodeElement(child) ->
        do_fold_with_depth(child.children, acc, f, depth + 1)
      TokenElement(_) -> acc
    }
  })
}

fn do_each_with_depth(
  children: List(Element(kind)),
  f: fn(Element(kind), Int) -> Nil,
  depth: Int,
) -> Nil {
  list.each(children, fn(el) {
    f(el, depth)
    case el {
      NodeElement(child) -> do_each_with_depth(child.children, f, depth + 1)
      TokenElement(_) -> Nil
    }
  })
}

fn do_each(children: List(Element(kind)), f: fn(Element(kind)) -> Nil) -> Nil {
  list.each(children, fn(el) {
    f(el)
    case el {
      NodeElement(child) -> do_each(child.children, f)
      TokenElement(_) -> Nil
    }
  })
}
