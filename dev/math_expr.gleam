//// An example parser of linear arithmetic expressions using greenwood.
//// Partially based on [`math.rs`][math-rs] from Rowan.
////
//// Given the input `1 + 2 * 3 + 4` this builds the syntax tree:
////
//// - `Node(Root)`
////   - `Node(Operation)`
////     - `Node(Operation)`
////       - `"1" Token(Number)`
////       - `"+" Token(Add)`
////       - `Node(Operation)`
////         - `"2" Token(Number)`
////         - `"*" Token(Mul)`
////         - `"3" Token(Number)`
////     - `"+" Token(Add)`
////     - `"4" Token(Number)`
////
//// This example also shows the use of leading and trailing trivia for
//// restoring whitespace. In most parser implementations, whitespace will be
//// collected as its own token as part of a node's children, and not trivia on
//// the node. Whitespace is often important for higher-level tokenization.
//// Trivia will more frequently be used for non-critical syntax elements like
//// comments.
////
//// The use of Trivia tokens is completely optional for nodes and highlights
//// the adaptability of greenwood to both Roslyn-style parsing (where trivia is
//// collected on nodes) and Rowan-style parsing (where trivia on nodes is not
//// used and triva tokens are just child tokens. When parsing Roslyn-style,
//// trivia values that are at the end of the source (after the most last
//// meaningful node) *usually* require a special "EOF" node for the placement
//// of that trivia.
////
//// [math-rs]: https://github.com/rust-analyzer/rowan/blob/master/examples/math.rs

import gleam/bool
import gleam/io
import gleam/list
import gleam/string
import greenwood.{type Element, Node, Token, TokenElement as T, Trivia}

/// Math token and node kind identifiers presented as a flat list.
///
/// Greenwood Elements (`Node`s or `Token`s) take a single `kind` parameter,
/// allowing `Node`s to be created with `kind`s that are intended as `Token`s.
/// It is up to the parser implementer to ensure that these kinds aren't mixed,
/// or if they are, the distinction between `Node(Number)` and `Token(Number)`
/// is sensible.
type MathKind {
  // Token(kind) values: Literal arithmetic source text
  Add
  Sub
  Mul
  Div
  Number

  // Token(kind) value exclusively used in trivia
  Whitespace

  // Node(kind) values: the trees
  Error
  Operation
  Root
}

type MathElement =
  Element(MathKind)

pub fn main() -> Nil {
  let source = "1 + 2 * 3 + 4"
  let parsed = parse(source)

  io.println("parsing: [" <> source <> "]")
  io.println("rebuilt: [" <> parsed |> to_string() <> "]")
  io.println("notds: ")

  pretty_print(parsed, 0)
  Nil
}

fn pretty_print(element: MathElement, indent: Int) -> Nil {
  let pad = string.repeat("  ", indent)
  case element {
    T(Token(kind:, text:)) ->
      io.println(
        pad
        <> "- "
        <> string.inspect(text)
        <> " Token("
        <> kind_name(kind)
        <> ")",
      )
    greenwood.NodeElement(Node(kind:, children:, trivia:)) -> {
      io.println(pad <> "- Node(" <> kind_name(kind) <> ")")
      case trivia {
        Trivia(leading:, trailing:) -> {
          case leading {
            [] -> Nil
            _ ->
              io.println(
                pad
                <> "    leading: "
                <> string.inspect(list.map(leading, fn(t) { t.text })),
              )
          }
          case trailing {
            [] -> Nil
            _ ->
              io.println(
                pad
                <> "    trailing: "
                <> string.inspect(list.map(trailing, fn(t) { t.text })),
              )
          }
        }
        _ -> Nil
      }
      list.each(children, pretty_print(_, indent + 1))
    }
  }
}

fn kind_name(kind: MathKind) -> String {
  case kind {
    Whitespace -> "Whitespace"
    Add -> "Add"
    Sub -> "Sub"
    Mul -> "Mul"
    Div -> "Div"
    Number -> "Number"
    Error -> "Error"
    Operation -> "Operation"
    Root -> "Root"
  }
}

fn to_string(element: MathElement) -> String {
  case element {
    T(Token(text:, ..)) -> text
    greenwood.NodeElement(Node(children:, trivia:, ..)) -> {
      let #(leading, trailing) = case trivia {
        Trivia(leading:, trailing:) -> #(
          list.map(leading, fn(t) { t.text }) |> string.concat,
          list.map(trailing, fn(t) { t.text }) |> string.concat,
        )
        _ -> #("", "")
      }
      // For Operation nodes: children are [left, op, right]
      // leading trivia goes before op, trailing after op
      case children {
        [left, op, right] ->
          to_string(left)
          <> leading
          <> to_string(op)
          <> trailing
          <> to_string(right)
        _ -> list.map(children, to_string) |> string.concat
      }
    }
  }
}

fn parse(source: String) -> MathElement {
  let #(_source, expr) = parse_add(source)
  greenwood.node_element(kind: Root, children: [expr])
}

/// Low precedence: + and -
fn parse_add(source: String) -> #(String, MathElement) {
  let #(source, left) = parse_mul(source)
  do_parse_add(source, left)
}

fn do_parse_add(source: String, left: MathElement) -> #(String, MathElement) {
  let #(source, ws_before) = collect_ws(source)
  case source {
    "+" <> rest | "-" <> rest -> {
      let op = case source {
        "+" <> _ -> T(Token(kind: Add, text: "+"))
        _ -> T(Token(kind: Sub, text: "-"))
      }
      let #(rest, ws_after) = collect_ws(rest)
      let #(source, right) = parse_mul(rest)
      let node =
        greenwood.node_element_with_trivia(
          kind: Operation,
          children: [left, op, right],
          trivia: make_trivia(ws_before, ws_after),
        )
      do_parse_add(source, node)
    }
    _ -> #(prepend_ws(source, ws_before), left)
  }
}

/// High precedence: * and /
fn parse_mul(source: String) -> #(String, MathElement) {
  let #(source, left) = parse_value(source)
  do_parse_mul(source, left)
}

fn do_parse_mul(source: String, left: MathElement) -> #(String, MathElement) {
  let #(source, ws_before) = collect_ws(source)
  case source {
    "*" <> rest | "/" <> rest -> {
      let op = case source {
        "*" <> _ -> T(Token(kind: Mul, text: "*"))
        _ -> T(Token(kind: Div, text: "/"))
      }
      let #(rest, ws_after) = collect_ws(rest)
      let #(source, right) = parse_value(rest)
      let node =
        greenwood.node_element_with_trivia(
          kind: Operation,
          children: [left, op, right],
          trivia: make_trivia(ws_before, ws_after),
        )
      do_parse_mul(source, node)
    }
    _ -> #(prepend_ws(source, ws_before), left)
  }
}

/// Atom level: numbers or errors
fn parse_value(source: String) -> #(String, MathElement) {
  case source {
    "0" as d <> rest
    | "1" as d <> rest
    | "2" as d <> rest
    | "3" as d <> rest
    | "4" as d <> rest
    | "5" as d <> rest
    | "6" as d <> rest
    | "7" as d <> rest
    | "8" as d <> rest
    | "9" as d <> rest -> {
      let #(source, num) = parse_number(rest, [d])
      #(source, num)
    }
    _ -> {
      let #(first, rest) = split_at(source, 1)
      case first {
        "" -> #("", error_element("unexpected end of input"))
        _ -> #(rest, error_element(first))
      }
    }
  }
}

fn error_element(text: String) -> MathElement {
  greenwood.node_element(kind: Error, children: [T(Token(kind: Error, text:))])
}

fn parse_number(source: String, acc: List(String)) -> #(String, MathElement) {
  case source {
    "0" as d <> rest
    | "1" as d <> rest
    | "2" as d <> rest
    | "3" as d <> rest
    | "4" as d <> rest
    | "5" as d <> rest
    | "6" as d <> rest
    | "7" as d <> rest
    | "8" as d <> rest
    | "9" as d <> rest -> parse_number(rest, [d, ..acc])
    _ -> #(source, T(Token(kind: Number, text: reverse_concat(acc))))
  }
}

fn make_trivia(
  leading: String,
  trailing: String,
) -> greenwood.Trivia(MathKind) {
  let l = case leading {
    "" -> []
    _ -> [Token(kind: Whitespace, text: leading)]
  }
  let t = case trailing {
    "" -> []
    _ -> [Token(kind: Whitespace, text: trailing)]
  }
  case l, t {
    [], [] -> greenwood.Bare
    _, _ -> Trivia(leading: l, trailing: t)
  }
}

/// Collect whitespace, returning the consumed text.
fn collect_ws(source: String) -> #(String, String) {
  do_skip_ws(source, [])
}

/// Put unconsumed whitespace back onto the source string.
fn prepend_ws(source: String, ws: String) -> String {
  ws <> source
}

fn do_skip_ws(source: String, ws_acc: List(String)) -> #(String, String) {
  case source {
    " " as ws <> rest | "\t" as ws <> rest -> do_skip_ws(rest, [ws, ..ws_acc])
    _ -> #(source, list.reverse(ws_acc) |> string.concat)
  }
}

fn split_at(string s: String, at index: Int) -> #(String, String) {
  let len = string.length(s)

  use <- bool.guard(len < index, return: #(s, ""))
  use <- bool.guard(index >= 0, return: #(
    string.slice(s, 0, index),
    string.slice(s, index, len),
  ))

  #(string.slice(s, 0, len + index), string.slice(s, len + index, len))
}

fn reverse_concat(acc: List(String)) -> String {
  list.reverse(acc) |> string.concat
}
