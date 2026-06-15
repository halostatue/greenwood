//// Zipper (cursor) operations for Greenwood syntax trees.
////
//// This module provides all navigation, mutation, and query operations for
//// the `Zipper` type. The zipper implements a Huet zipper providing a focused
//// view into the tree with O(1) local moves and edits.

import gleam/bool
import gleam/list
import gleam/option.{type Option, None, Some}
import greenwood.{
  type Crumb, type Element, type Node, type Zipper, Crumb, NodeElement, Zipper,
}

/// Create a zipper focused on the root node.
///
/// `cursor`
pub fn zip(root: Node(kind)) -> Zipper(kind) {
  Zipper(focus: root, crumbs: [])
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

/// Move focus to the first child that is a Node.
///
/// `cursor`
pub fn down(zipper: Zipper(kind)) -> Option(Zipper(kind)) {
  down_where(zipper:, predicate: always)
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

/// Move focus to the last child that is a Node.
///
/// `cursor`
pub fn down_last(zipper: Zipper(kind)) -> Option(Zipper(kind)) {
  down_last_where(zipper:, predicate: always)
}

/// Move focus to the last child Node matching a predicate.
///
/// `cursor`
pub fn down_last_where(
  zipper zipper: Zipper(kind),
  predicate predicate: fn(Node(kind)) -> Bool,
) -> Option(Zipper(kind)) {
  do_down_last(zipper.focus, predicate, zipper.crumbs)
}

/// Move focus back up to the parent.
///
/// `cursor`
pub fn up(zipper: Zipper(kind)) -> Option(Zipper(kind)) {
  case zipper.crumbs {
    [] -> None
    [crumb, ..rest] -> {
      let children =
        list.append(list.reverse(crumb.left), [
          NodeElement(zipper.focus),
          ..crumb.right
        ])
      let parent =
        greenwood.Node(kind: crumb.kind, children:, trivia: crumb.trivia)
      Some(Zipper(focus: parent, crumbs: rest))
    }
  }
}

/// Move focus up `n` parents. Returns `None` if `n` is negative or would move
/// above the root.
///
/// `up_n(z, by: 0)` returns `Some(z)`.
///
/// `cursor`
pub fn up_n(zipper zipper: Zipper(kind), by n: Int) -> Option(Zipper(kind)) {
  repeat_move(zipper, n, up)
}

/// Ascend until the focused node's parent matches a predicate.
/// Returns the zipper focused on the first ancestor matching `predicate`,
/// or `None` if the root is reached without a match.
///
/// `cursor`
pub fn up_until(
  zipper zipper: Zipper(kind),
  predicate predicate: fn(Node(kind)) -> Bool,
) -> Option(Zipper(kind)) {
  case up(zipper) {
    None -> None
    Some(z) -> {
      use <- bool.guard(predicate(z.focus), return: Some(z))
      up_until(zipper: z, predicate:)
    }
  }
}

/// Descend to the nth child Node (1-indexed). Returns `None` if fewer than `n`
/// Node children exist.
///
/// `cursor`
pub fn nth_child(
  zipper zipper: Zipper(kind),
  n n: Int,
) -> Option(Zipper(kind)) {
  use <- bool.guard(n < 1, return: None)
  case down(zipper) {
    None -> None
    Some(z) if n == 1 -> Some(z)
    Some(z) -> right_n(zipper: z, by: n - 1)
  }
}

/// Move focus to the nearest sibling Node to the left.
///
/// `cursor`
pub fn left(zipper: Zipper(kind)) -> Option(Zipper(kind)) {
  left_where(zipper:, predicate: always)
}

/// Move focus to the nearest sibling Node to the left matching a predicate.
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

/// Move focus to the nearest sibling Node to the right.
///
/// `cursor`
pub fn right(zipper: Zipper(kind)) -> Option(Zipper(kind)) {
  right_where(zipper:, predicate: always)
}

/// Move focus to the nearest sibling Node to the right matching a predicate.
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

/// Move focus `n` sibling Nodes to the left. Negative `n` flips direction.
///
/// `cursor`
pub fn left_n(zipper zipper: Zipper(kind), by n: Int) -> Option(Zipper(kind)) {
  use <- bool.guard(n < 0, return: repeat_move(zipper, -n, right))
  repeat_move(zipper, n, left)
}

/// Move focus `n` sibling Nodes to the left matching a predicate.
/// Negative `n` flips direction.
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
        Some(z) -> left_n_where(zipper: z, by: n - 1, predicate:)
        None -> None
      }
  }
}

/// Move focus `n` sibling Nodes to the right. Negative `n` flips direction.
///
/// `cursor`
pub fn right_n(zipper zipper: Zipper(kind), by n: Int) -> Option(Zipper(kind)) {
  use <- bool.guard(n < 0, return: repeat_move(zipper, -n, left))
  repeat_move(zipper, n, right)
}

/// Move focus `n` sibling Nodes to the right matching a predicate.
/// Negative `n` flips direction.
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
        Some(z) -> right_n_where(zipper: z, by: n - 1, predicate:)
        None -> None
      }
  }
}

/// Scan right siblings for `target`, aborting early if `stop` matches first.
/// Returns `None` if siblings are exhausted or `stop` fires.
///
/// `cursor`
pub fn right_until(
  zipper zipper: Zipper(kind),
  target target: fn(Node(kind)) -> Bool,
  stop stop: fn(Node(kind)) -> Bool,
) -> Option(Zipper(kind)) {
  case right(zipper) {
    None -> None
    Some(next) -> {
      use <- bool.guard(stop(next.focus), return: None)
      use <- bool.guard(target(next.focus), return: Some(next))
      right_until(zipper: next, target:, stop:)
    }
  }
}

/// Scan left siblings for `target`, aborting early if `stop` matches first.
///
/// `cursor`
pub fn left_until(
  zipper zipper: Zipper(kind),
  target target: fn(Node(kind)) -> Bool,
  stop stop: fn(Node(kind)) -> Bool,
) -> Option(Zipper(kind)) {
  case left(zipper) {
    None -> None
    Some(next) -> {
      use <- bool.guard(stop(next.focus), return: None)
      use <- bool.guard(target(next.focus), return: Some(next))
      left_until(zipper: next, target:, stop:)
    }
  }
}

/// Scan `n` target-matching right siblings, stopping early if `stop` fires.
/// `right_n_until(zipper:, n: 0, ..)` returns `Some(zipper)`.
///
/// `cursor`
pub fn right_n_until(
  zipper zipper: Zipper(kind),
  n n: Int,
  target target: fn(Node(kind)) -> Bool,
  stop stop: fn(Node(kind)) -> Bool,
) -> Option(Zipper(kind)) {
  case n {
    0 -> Some(zipper)
    _ ->
      case right_until(zipper:, target:, stop:) {
        None -> None
        Some(next) -> right_n_until(zipper: next, n: n - 1, target:, stop:)
      }
  }
}

/// Scan `n` target-matching left siblings, stopping early if `stop` fires.
/// `left_n_until(zipper:, n: 0, ..)` returns `Some(zipper)`.
///
/// `cursor`
pub fn left_n_until(
  zipper zipper: Zipper(kind),
  n n: Int,
  target target: fn(Node(kind)) -> Bool,
  stop stop: fn(Node(kind)) -> Bool,
) -> Option(Zipper(kind)) {
  case n {
    0 -> Some(zipper)
    _ ->
      case left_until(zipper:, target:, stop:) {
        None -> None
        Some(next) -> left_n_until(zipper: next, n: n - 1, target:, stop:)
      }
  }
}

/// Depth-first search below the focus for a descendant matching a predicate.
/// Returns a zipper focused on the match, or `None`.
///
/// `cursor`
pub fn find_descendant(
  zipper zipper: Zipper(kind),
  where predicate: fn(Node(kind)) -> Bool,
) -> Option(Zipper(kind)) {
  do_find_descendant(zipper, predicate)
}

/// Replace the focused node.
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
  zipper zipper: Zipper(kind),
  with f: fn(Node(kind)) -> Node(kind),
) -> Zipper(kind) {
  Zipper(..zipper, focus: f(zipper.focus))
}

/// Insert an element to the left of the focus. Focus does not move.
/// Returns `None` if the focus is the root (no parent to hold the sibling).
///
/// `cursor`
pub fn insert_left(
  zipper zipper: Zipper(kind),
  element element: Element(kind),
) -> Option(Zipper(kind)) {
  case zipper.crumbs {
    [] -> None
    [crumb, ..rest] -> {
      let new_crumb = Crumb(..crumb, left: [element, ..crumb.left])
      Some(Zipper(focus: zipper.focus, crumbs: [new_crumb, ..rest]))
    }
  }
}

/// Insert an element to the right of the focus. Focus does not move.
/// Returns `None` if the focus is the root.
///
/// `cursor`
pub fn insert_right(
  zipper zipper: Zipper(kind),
  element element: Element(kind),
) -> Option(Zipper(kind)) {
  case zipper.crumbs {
    [] -> None
    [crumb, ..rest] -> {
      let new_crumb = Crumb(..crumb, right: [element, ..crumb.right])
      Some(Zipper(focus: zipper.focus, crumbs: [new_crumb, ..rest]))
    }
  }
}

/// Insert a child as the first child of the focus and move focus to it.
/// Returns `None` if the focus has no children list (impossible for Node, but
/// kept as Option for API consistency).
///
/// `cursor`
pub fn insert_down(
  zipper zipper: Zipper(kind),
  child child: Node(kind),
) -> Zipper(kind) {
  let crumb =
    Crumb(
      kind: zipper.focus.kind,
      trivia: zipper.focus.trivia,
      left: [],
      right: zipper.focus.children,
    )
  Zipper(focus: child, crumbs: [crumb, ..zipper.crumbs])
}

/// Delete the focused node. Focus shifts to:
/// 1. Right sibling (if exists)
/// 2. Left sibling (if exists)
/// 3. Parent with focus removed from children
///
/// Returns `None` if the focus is the root.
///
/// `cursor`
pub fn delete(zipper: Zipper(kind)) -> Option(Zipper(kind)) {
  case zipper.crumbs {
    [] -> None
    [crumb, ..rest] ->
      case scan_right(crumb.right, always, crumb.left) {
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
        None ->
          case scan_left(crumb.left, always, crumb.right) {
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
            None -> {
              // No Node siblings at all — move up. The deleted node is gone;
              // remaining elements in left/right (tokens only) become children.
              let children = list.append(list.reverse(crumb.left), crumb.right)
              let parent =
                greenwood.Node(
                  kind: crumb.kind,
                  children:,
                  trivia: crumb.trivia,
                )
              Some(Zipper(focus: parent, crumbs: rest))
            }
          }
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
    Some(#(new_left, child, new_right)) -> {
      let crumb =
        Crumb(
          kind: parent.kind,
          trivia: parent.trivia,
          left: new_left,
          right: new_right,
        )
      Some(Zipper(focus: child, crumbs: [crumb, ..crumbs]))
    }
    None -> None
  }
}

fn do_down_last(
  parent: Node(kind),
  predicate: fn(Node(kind)) -> Bool,
  crumbs: List(Crumb(kind)),
) -> Option(Zipper(kind)) {
  case split_at_last_node(parent.children, predicate) {
    Some(#(left, child, right)) -> {
      let crumb = Crumb(kind: parent.kind, trivia: parent.trivia, left:, right:)
      Some(Zipper(focus: child, crumbs: [crumb, ..crumbs]))
    }
    None -> None
  }
}

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

fn split_at_last_node(
  elements: List(Element(kind)),
  predicate: fn(Node(kind)) -> Bool,
) -> Option(#(List(Element(kind)), Node(kind), List(Element(kind)))) {
  do_split_at_last_node(elements, predicate, [], None)
}

fn do_split_at_last_node(
  elements: List(Element(kind)),
  predicate: fn(Node(kind)) -> Bool,
  left: List(Element(kind)),
  best: Option(#(List(Element(kind)), Node(kind), List(Element(kind)))),
) -> Option(#(List(Element(kind)), Node(kind), List(Element(kind)))) {
  case elements {
    [] -> best
    [NodeElement(n), ..rest] ->
      case predicate(n) {
        True ->
          do_split_at_last_node(
            rest,
            predicate,
            [NodeElement(n), ..left],
            Some(#(left, n, rest)),
          )
        False ->
          do_split_at_last_node(rest, predicate, [NodeElement(n), ..left], best)
      }
    [other, ..rest] ->
      do_split_at_last_node(rest, predicate, [other, ..left], best)
  }
}

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

fn do_find_descendant(
  zipper: Zipper(kind),
  predicate: fn(Node(kind)) -> Bool,
) -> Option(Zipper(kind)) {
  // Try descending into children first
  case down(zipper) {
    None -> None
    Some(child_z) -> search_siblings_and_below(child_z, predicate)
  }
}

fn search_siblings_and_below(
  zipper: Zipper(kind),
  predicate: fn(Node(kind)) -> Bool,
) -> Option(Zipper(kind)) {
  use <- bool.guard(predicate(zipper.focus), return: Some(zipper))

  // Try descending
  case do_find_descendant(zipper, predicate) {
    Some(_) as found -> found
    None ->
      // Try next sibling
      case right(zipper) {
        None -> None
        Some(next) -> search_siblings_and_below(next, predicate)
      }
  }
}

fn always(_: Node(kind)) -> Bool {
  True
}
