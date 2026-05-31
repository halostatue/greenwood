//// An example parser of arithmetic S-expressions using greenwood. Partially
//// based on [`s_expressions.rs`][sexp-rs] from Rowan.
////
//// The arithmetic S-expressions look like this:
////
//// ```
//// (+ (* 15 2) 62)
//// ```
////
//// [sexp-rs]: https://github.com/rust-analyzer/rowan/blob/master/examples/s_expressions.rs

import gleam/bool
import gleam/io
import gleam/list
import gleam/string
import greenwood.{type Element, Node, NodeElement as N, Token, TokenElement as T}

/// Sexpr token and node kind identifiers presented as a flat list.
///
/// Greenwood Elements (`Node`s or `Token`s) take a single `kind` parameter,
/// allowing `Node`s to be created with `kind`s that are intended as `Token`s.
/// It is up to the parser implementer to ensure that these kinds aren't mixed,
/// or if they are, the distinction between `Node(Number)` and `Token(Number)`
/// is sensible.
type SexprKind {
  // Token(kind) values: Literal arithmetic source text
  /// `(`
  LeftParen
  /// `)`
  RightParen
  /// `+`, `15`
  Word
  /// Whitespace is explicit
  Whitespace
  /// Errors are explicit
  Error

  // Node(kind) values: the trees
  /// `(+ 2 3)` -- a list of words
  Expression
  ///  `+`, `15`, wrapping a Word token
  Atom
  /// Top level node, a list of s-expressions
  Root
}

type SexprElement =
  Element(SexprKind)

pub fn main() -> Nil {
  let assert "=  " = dump("   ")
  let assert "= (+ (* 15 2) 62)" = dump("(+   (*   15   2)   62)")
  let assert "=  92" = dump(" 92")
  let assert "= (+ 62 30)" = dump("(+ 62 30)")
  let assert "= (/ 92 0)" = dump("(/ 92 0)")
  let assert "= nan" = dump("nan")

  Nil
}

fn dump(source: String) -> String {
  let result = parse(source) |> to_string()
  io.println("[" <> source <> "] ⇒ [" <> result <> "]")
  result
}

fn to_string(sexpr: SexprElement) -> String {
  case sexpr {
    N(Node(kind: Root, children:, ..)) -> {
      "= " <> { list.map(children, to_string) |> string.concat }
    }
    N(Node(kind: Expression, children:, ..))
    | N(Node(kind: Atom, children:, ..)) ->
      list.map(children, to_string) |> string.concat

    T(Token(kind: Error, text:)) -> "** Error: " <> text <> " **"
    T(Token(kind: LeftParen, ..)) -> "("
    T(Token(kind: RightParen, ..)) -> ")"
    T(Token(kind: Word, text:)) -> text
    T(Token(kind: Whitespace, ..)) -> " "

    N(_) -> ""
    T(_) -> ""
  }
}

fn parse(source: String) -> SexprElement {
  greenwood.node_element(kind: Root, children: do_parse(source, []))
}

fn do_parse(source, acc) -> List(SexprElement) {
  let #(source, acc) = skip_ws(source, acc)

  case source {
    "" -> list.reverse(acc)
    ")" <> rest ->
      do_parse(rest, [T(Token(kind: Error, text: "unmatched `)`")), ..acc])
    "(" <> rest -> {
      let #(source, expr) =
        parse_expression(rest, [
          T(Token(kind: LeftParen, text: "")),
        ])

      do_parse(source, [expr, ..acc])
    }
    _ -> {
      let #(source, atom) = parse_atom(source, [])
      do_parse(source, [atom, ..acc])
    }
  }
}

fn parse_expression(
  source: String,
  acc: List(SexprElement),
) -> #(String, SexprElement) {
  let #(source, acc) = skip_ws(source, acc)

  case source {
    "" -> {
      #(
        "",
        greenwood.node_element(
          kind: Expression,
          children: list.reverse([
            T(Token(kind: Error, text: "expected `)`")),
            ..acc
          ]),
        ),
      )
    }

    ")" <> rest -> {
      #(
        rest,
        greenwood.node_element(
          kind: Expression,
          children: list.reverse([T(Token(kind: RightParen, text: "")), ..acc]),
        ),
      )
    }

    "(" <> rest -> {
      let #(source, expr) =
        parse_expression(rest, [
          T(Token(kind: LeftParen, text: "")),
        ])

      parse_expression(source, [expr, ..acc])
    }

    _ -> {
      let #(source, atom) = parse_atom(source, [])
      parse_expression(source, [atom, ..acc])
    }
  }
}

fn parse_atom(source: String, acc: List(String)) -> #(String, SexprElement) {
  case source {
    "" | " " <> _ | "\t" <> _ | "(" <> _ | ")" <> _ -> {
      let word = T(Token(kind: Word, text: reverse_concat(acc)))
      #(source, greenwood.node_element(kind: Atom, children: [word]))
    }
    _ -> {
      let #(first, rest) = split_at(source, 1)
      parse_atom(rest, [first, ..acc])
    }
  }
}

fn skip_ws(source, acc) -> #(String, List(SexprElement)) {
  let #(source, acc) = case do_skip_ws(source, []) {
    #(rest, "") -> #(rest, acc)
    #(rest, text) -> #(rest, [T(Token(kind: Whitespace, text:)), ..acc])
  }

  #(source, acc)
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
