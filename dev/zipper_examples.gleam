//// Examples demonstrating greenwood/zipper cursor operations.
////
//// This file shows the new zipper API for navigating and editing Greenwood
//// syntax trees using a Huet zipper (cursor).
////
//// Run with: gleam run -m zipper_examples

import gleam/io
import gleam/option.{Some}
import gleam/string
import greenwood.{type Element, type Node, NodeElement as N, TokenElement as T}
import greenwood/zipper

// A minimal "document" kind system
type DocKind {
  Document
  Section
  Heading
  Paragraph
  Text
  Whitespace
}

fn text(s: String) -> Element(DocKind) {
  T(greenwood.token(Text, s))
}

fn ws() -> Element(DocKind) {
  T(greenwood.token(Whitespace, " "))
}

fn paragraph(words: List(String)) -> Node(DocKind) {
  let children =
    words
    |> intersperse_with(fn(w) { text(w) }, fn() { ws() })
  greenwood.node(Paragraph, children)
}

fn section(title: String, paragraphs: List(Node(DocKind))) -> Node(DocKind) {
  let heading = greenwood.node(Heading, [text(title)])
  let children = [N(heading), ..paragraphs |> list_map_n]
  greenwood.node(Section, children)
}

fn example_doc() -> Node(DocKind) {
  greenwood.node(Document, [
    N(
      section("Introduction", [
        paragraph(["Hello", "world"]),
        paragraph(["This", "is", "greenwood"]),
      ]),
    ),
    N(
      section("Navigation", [
        paragraph(["Zippers", "provide", "cursors"]),
      ]),
    ),
    N(
      section("Editing", [
        paragraph(["Insert", "delete", "replace"]),
      ]),
    ),
  ])
}

pub fn main() {
  io.println("=== Greenwood Zipper Examples ===\n")

  navigation_examples()
  io.println("")
  editing_examples()
  io.println("")
  search_examples()
}

fn navigation_examples() {
  io.println("--- Navigation ---")
  let doc = example_doc()
  let z = zipper.zip(doc)

  // down: enter first child
  let assert Some(z1) = zipper.down(z)
  io.println("down → " <> describe(z1.focus))

  // down_last: enter last child
  let assert Some(z_last) = zipper.down_last(z)
  io.println("down_last → " <> describe(z_last.focus))

  // right: move to next sibling
  let assert Some(z2) = zipper.right(z1)
  io.println("right → " <> describe(z2.focus))

  // left: move back
  let assert Some(z3) = zipper.left(z2)
  io.println("left → " <> describe(z3.focus))

  // nth_child: jump directly to nth child
  let assert Some(z4) = zipper.nth_child(z, n: 2)
  io.println("nth_child(2) → " <> describe(z4.focus))

  // up_until: ascend to Document
  let assert Some(z_deep) =
    zipper.down(z1)
    |> option.then(fn(z) {
      zipper.right_where(z, predicate: fn(n) { n.kind == Paragraph })
    })
  io.println("deep focus → " <> describe(z_deep.focus))
  let assert Some(z_up) =
    zipper.up_until(z_deep, predicate: fn(n) { n.kind == Document })
  io.println("up_until(Document) → " <> describe(z_up.focus))

  // right_until with stop: find "Editing" section, stop if we hit something
  let assert Some(z_edit) =
    zipper.right_until(
      z1,
      target: fn(n) { has_heading(n, "Editing") },
      stop: fn(_) { False },
    )
  io.println("right_until(Editing) → " <> describe(z_edit.focus))

  // right_n_until: skip 2 sections matching predicate
  let assert Some(z_nav) =
    zipper.right_n_until(
      z1,
      n: 2,
      target: fn(n) { n.kind == Section },
      stop: fn(_) { False },
    )
  io.println("right_n_until(2 sections) → " <> describe(z_nav.focus))
}

fn editing_examples() {
  io.println("--- Editing ---")
  let doc = example_doc()
  let z = zipper.zip(doc)

  // insert_right: add a new section after Introduction
  let assert Some(z1) = zipper.down(z)
  let new_section = section("Overview", [paragraph(["Added", "via", "zipper"])])
  let assert Some(z2) = zipper.insert_right(z1, element: N(new_section))
  let edited = zipper.unzip(z2)
  io.println(
    "insert_right: now "
    <> count_sections(edited) |> string.inspect
    <> " sections",
  )

  // insert_left: add before current focus
  let assert Some(z3) =
    zipper.insert_left(z1, element: N(section("Preface", [])))
  let edited2 = zipper.unzip(z3)
  io.println(
    "insert_left: now "
    <> count_sections(edited2) |> string.inspect
    <> " sections",
  )

  // insert_down: add a child to a section, focus moves into it
  let new_para = paragraph(["Inserted", "child"])
  let z4 = zipper.insert_down(z1, child: new_para)
  io.println("insert_down: focus now on → " <> describe(z4.focus))
  let assert Some(z5) = zipper.up(z4)
  io.println(
    "  parent children: " <> z5.focus.children |> list_length |> string.inspect,
  )

  // delete: remove a section
  let assert Some(z6) =
    zipper.zip(doc)
    |> zipper.down
    |> option.then(zipper.right)
  io.println("before delete: focus on → " <> describe(z6.focus))
  let assert Some(z7) = zipper.delete(z6)
  io.println("after delete: focus on → " <> describe(z7.focus))
  let edited3 = zipper.unzip(z7)
  io.println(
    "  remaining sections: " <> count_sections(edited3) |> string.inspect,
  )

  // set_focus: replace a node entirely
  let assert Some(z8) = zipper.zip(doc) |> zipper.down
  let replacement = section("Replaced!", [paragraph(["All", "new"])])
  let z9 = zipper.set_focus(z8, node: replacement)
  let assert Some(heading_z) = zipper.down(z9)
  io.println("set_focus heading → " <> describe(heading_z.focus))
}

fn search_examples() {
  io.println("--- Search ---")
  let doc = example_doc()

  // find_descendant: depth-first search for a specific paragraph
  let assert Some(z) =
    zipper.zip(doc)
    |> zipper.find_descendant(where: fn(n) { n.kind == Paragraph })
  io.println("find_descendant(Paragraph) → " <> describe(z.focus))

  // find_descendant from a deeper starting point
  let assert Some(z2) =
    zipper.zip(doc)
    |> zipper.down
    |> option.then(zipper.right)
    |> option.then(
      zipper.find_descendant(_, where: fn(n) { n.kind == Paragraph }),
    )
  io.println("find in Navigation section → " <> describe(z2.focus))
}

// --- Helpers ---

fn describe(node: Node(DocKind)) -> String {
  case node.kind {
    Document -> "Document"
    Section -> "Section(" <> first_heading_text(node) <> ")"
    Heading -> "Heading(" <> collect_text(node) <> ")"
    Paragraph -> "Paragraph(" <> collect_text(node) <> ")"
    Text -> "Text"
    Whitespace -> "Whitespace"
  }
}

fn first_heading_text(node: Node(DocKind)) -> String {
  case node.children {
    [N(heading), ..] if heading.kind == Heading -> collect_text(heading)
    _ -> "?"
  }
}

fn collect_text(node: Node(DocKind)) -> String {
  greenwood.fold(over: node, from: "", with: fn(acc, el) {
    case el {
      T(tok) -> acc <> tok.text
      _ -> acc
    }
  })
}

fn has_heading(node: Node(DocKind), title: String) -> Bool {
  node.kind == Section && first_heading_text(node) == title
}

fn count_sections(node: Node(DocKind)) -> Int {
  node.children
  |> list_count(fn(el) {
    case el {
      N(n) -> n.kind == Section
      _ -> False
    }
  })
}

fn intersperse_with(
  items: List(a),
  wrap: fn(a) -> b,
  separator: fn() -> b,
) -> List(b) {
  case items {
    [] -> []
    [x] -> [wrap(x)]
    [x, ..rest] -> [
      wrap(x),
      separator(),
      ..intersperse_with(rest, wrap, separator)
    ]
  }
}

fn list_map_n(nodes: List(Node(DocKind))) -> List(Element(DocKind)) {
  case nodes {
    [] -> []
    [n, ..rest] -> [N(n), ..list_map_n(rest)]
  }
}

fn list_length(items: List(a)) -> Int {
  case items {
    [] -> 0
    [_, ..rest] -> 1 + list_length(rest)
  }
}

fn list_count(items: List(a), pred: fn(a) -> Bool) -> Int {
  case items {
    [] -> 0
    [x, ..rest] ->
      case pred(x) {
        True -> 1 + list_count(rest, pred)
        False -> list_count(rest, pred)
      }
  }
}
