import gleam/list
import gleam/option.{None, Some}
import gleeunit
import greenwood.{Bare, NodeElement, TokenElement, Trivia}

pub fn main() {
  gleeunit.main()
}

pub type Kind {
  Root
  Parent
  Child
  Leaf
  CommentTrivia
}

fn leaf(text: String) -> greenwood.Element(Kind) {
  TokenElement(greenwood.token(Leaf, text))
}

fn comment(text: String) -> greenwood.Token(Kind) {
  greenwood.token(CommentTrivia, text)
}

fn simple_tree() -> greenwood.Node(Kind) {
  greenwood.node(Root, [
    NodeElement(greenwood.node(Parent, [leaf("a"), leaf("b")])),
    NodeElement(greenwood.node(Parent, [leaf("c")])),
  ])
}

pub fn node_creates_with_empty_trivia_test() {
  let n = greenwood.node(Root, [])
  assert Root == n.kind
  assert [] == n.children
  assert Bare == n.trivia
}

pub fn node_with_trivia_test() {
  let t = Trivia(leading: [comment("# hi")], trailing: [])
  let n = greenwood.node_with_trivia(Root, [leaf("x")], t)
  let assert Trivia(leading: [tok], trailing: []) = n.trivia
  assert "# hi" == tok.text
}

pub fn token_creates_correctly_test() {
  let tok = greenwood.token(Leaf, "hello")
  assert Leaf == tok.kind
  assert "hello" == tok.text
}

pub fn fold_children_counts_elements_test() {
  let tree = simple_tree()
  let count = list.fold(tree.children, 0, fn(acc, _el) { acc + 1 })
  assert 2 == count
}

pub fn fold_deep_counts_all_elements_test() {
  let tree = simple_tree()
  let count =
    greenwood.fold(over: tree, from: 0, with: fn(acc, _el) { acc + 1 })
  // 2 parent nodes + 3 leaf tokens = 5
  assert 5 == count
}

pub fn fold_with_depth_tracks_depth_test() {
  let tree = simple_tree()
  let depths =
    greenwood.fold_with_depth(over: tree, from: [], with: fn(acc, _el, depth) {
      [depth, ..acc]
    })
  // 2 Parent nodes at depth 0, 3 leaf tokens at depth 1
  let assert 5 = list.length(depths)
  let at_zero = list.filter(depths, fn(d) { d == 0 }) |> list.length
  let at_one = list.filter(depths, fn(d) { d == 1 }) |> list.length
  let assert 2 = at_zero
  let assert 3 = at_one
}

pub fn fold_with_depth_no_deeper_than_expected_test() {
  let tree = simple_tree()
  let max_depth =
    greenwood.fold_with_depth(over: tree, from: 0, with: fn(acc, _el, depth) {
      case depth > acc {
        True -> depth
        False -> acc
      }
    })
  let assert 1 = max_depth
}

pub fn each_visits_all_elements_test() {
  let tree = simple_tree()
  greenwood.each(over: tree, with: fn(_el) { Nil })
}

pub fn each_with_depth_visits_all_test() {
  let tree = simple_tree()
  greenwood.each_with_depth(over: tree, with: fn(_el, _depth) { Nil })
}

pub fn find_child_returns_first_match_test() {
  let tree = simple_tree()
  let assert Some(_) =
    greenwood.find_child(in: tree, where: fn(el) {
      case el {
        NodeElement(n) -> n.children == [leaf("c")]
        _ -> False
      }
    })
}

pub fn find_child_returns_none_when_no_match_test() {
  let assert None =
    greenwood.find_child(in: simple_tree(), where: fn(_) { False })
}

pub fn filter_children_returns_matching_test() {
  let tree = greenwood.node(Root, [leaf("a"), leaf("b"), leaf("c")])
  let results =
    greenwood.filter_children(in: tree, where: fn(el) {
      case el {
        TokenElement(t) -> t.text != "b"
        _ -> False
      }
    })
  let assert [TokenElement(t1), TokenElement(t2)] = results
  assert "a" == t1.text
  assert "c" == t2.text
}

pub fn find_descendant_finds_deep_token_test() {
  let tree = simple_tree()
  let assert Some(TokenElement(t)) =
    greenwood.find_descendant(in: tree, where: fn(el) {
      case el {
        TokenElement(t) -> t.text == "c"
        _ -> False
      }
    })
  assert "c" == t.text
}

pub fn find_descendant_returns_none_test() {
  let assert None =
    greenwood.find_descendant(in: simple_tree(), where: fn(el) {
      case el {
        TokenElement(t) -> t.text == "z"
        _ -> False
      }
    })
}

pub fn map_children_transforms_all_test() {
  let tree = greenwood.node(Root, [leaf("a"), leaf("b")])
  let mapped =
    greenwood.map_children(in: tree, with: fn(el) {
      case el {
        TokenElement(t) -> TokenElement(greenwood.token(t.kind, t.text <> "!"))
        other -> other
      }
    })
  let assert [TokenElement(t1), TokenElement(t2)] = mapped.children
  assert "a!" == t1.text
  assert "b!" == t2.text
}

pub fn map_deep_transforms_nested_test() {
  let tree = simple_tree()
  let mapped =
    greenwood.map_tree_up(in: tree, with: fn(el) {
      case el {
        TokenElement(t) -> TokenElement(greenwood.token(t.kind, t.text <> "x"))
        other -> other
      }
    })
  let assert [NodeElement(first), ..] = mapped.children
  let assert [TokenElement(t1), TokenElement(t2)] = first.children
  assert "ax" == t1.text
  assert "bx" == t2.text
}

pub fn map_tree_down_transforms_before_recursing_test() {
  // map_tree_down applies f to parent first, then recurses into result.
  // If f replaces a NodeElement with a TokenElement, recursion stops.
  let inner = greenwood.node(Child, [leaf("a"), leaf("b")])
  let tree = greenwood.node(Root, [NodeElement(inner), leaf("c")])
  let mapped =
    greenwood.map_tree_down(in: tree, with: fn(el) {
      case el {
        // Replace the entire inner node with a single token
        NodeElement(n) if n.kind == Child -> leaf("replaced")
        TokenElement(t) -> TokenElement(greenwood.token(t.kind, t.text <> "!"))
        other -> other
      }
    })
  // Inner node was replaced before its children were visited,
  // so "a" and "b" are gone. "c" gets the "!" suffix.
  let assert [TokenElement(t1), TokenElement(t2)] = mapped.children
  assert "replaced" == t1.text
  assert "c!" == t2.text
}

pub fn replace_child_at_index_test() {
  let tree = greenwood.node(Root, [leaf("a"), leaf("b"), leaf("c")])
  let updated = greenwood.replace_child(in: tree, at: 1, with: leaf("B"))
  let assert [TokenElement(t1), TokenElement(t2), TokenElement(t3)] =
    updated.children
  assert "a" == t1.text
  assert "B" == t2.text
  assert "c" == t3.text
}

pub fn replace_first_matching_test() {
  let tree = greenwood.node(Root, [leaf("a"), leaf("b"), leaf("c")])
  let updated =
    greenwood.replace_first(
      in: tree,
      where: fn(el) {
        case el {
          TokenElement(t) -> t.text == "b"
          _ -> False
        }
      },
      with: fn(_) { leaf("B") },
    )
  let assert [TokenElement(t1), TokenElement(t2), TokenElement(t3)] =
    updated.children
  assert "a" == t1.text
  assert "B" == t2.text
  assert "c" == t3.text
}

pub fn insert_before_test() {
  let tree = greenwood.node(Root, [leaf("a"), leaf("c")])
  let updated =
    greenwood.insert_before(
      in: tree,
      where: fn(el) {
        case el {
          TokenElement(t) -> t.text == "c"
          _ -> False
        }
      },
      insert: leaf("b"),
    )
  let assert [TokenElement(t1), TokenElement(t2), TokenElement(t3)] =
    updated.children
  assert "a" == t1.text
  assert "b" == t2.text
  assert "c" == t3.text
}

pub fn insert_after_test() {
  let tree = greenwood.node(Root, [leaf("a"), leaf("c")])
  let updated =
    greenwood.insert_after(
      in: tree,
      where: fn(el) {
        case el {
          TokenElement(t) -> t.text == "a"
          _ -> False
        }
      },
      insert: leaf("b"),
    )
  let assert [TokenElement(t1), TokenElement(t2), TokenElement(t3)] =
    updated.children
  assert "a" == t1.text
  assert "b" == t2.text
  assert "c" == t3.text
}

pub fn remove_children_test() {
  let tree = greenwood.node(Root, [leaf("a"), leaf("b"), leaf("c")])
  let updated =
    greenwood.remove_children(in: tree, where: fn(el) {
      case el {
        TokenElement(t) -> t.text == "b"
        _ -> False
      }
    })
  let assert [TokenElement(t1), TokenElement(t2)] = updated.children
  assert "a" == t1.text
  assert "c" == t2.text
}

pub fn append_child_test() {
  let tree = greenwood.node(Root, [leaf("a")])
  let updated = greenwood.append_child(in: tree, child: leaf("b"))
  let assert [TokenElement(t1), TokenElement(t2)] = updated.children
  assert "a" == t1.text
  assert "b" == t2.text
}

pub fn prepend_child_test() {
  let tree = greenwood.node(Root, [leaf("b")])
  let updated = greenwood.prepend_child(in: tree, child: leaf("a"))
  let assert [TokenElement(t1), TokenElement(t2)] = updated.children
  assert "a" == t1.text
  assert "b" == t2.text
}

pub fn set_leading_trivia_test() {
  let n = greenwood.node(Root, [])
  let updated = greenwood.set_leading_trivia(on: n, trivia: [comment("# x")])
  let assert Trivia(leading: [tok], trailing: []) = updated.trivia
  assert "# x" == tok.text
}

pub fn set_trailing_trivia_test() {
  let n = greenwood.node(Root, [])
  let updated = greenwood.set_trailing_trivia(on: n, trivia: [comment("# y")])
  let assert Trivia(leading: [], trailing: [tok]) = updated.trivia
  assert "# y" == tok.text
}

pub fn all_trivia_combines_leading_and_trailing_test() {
  let t = Trivia(leading: [comment("# a")], trailing: [comment("# b")])
  let n = greenwood.node_with_trivia(Root, [], t)
  let assert [t1, t2] = greenwood.all_trivia(from: n)
  assert "# a" == t1.text
  assert "# b" == t2.text
}

pub fn leading_trivia_test() {
  let t = Trivia(leading: [comment("# a")], trailing: [comment("# b")])
  let n = greenwood.node_with_trivia(Root, [], t)
  let assert [t1] = greenwood.leading_trivia(from: n)
  assert "# a" == t1.text
}

pub fn trailing_trivia_test() {
  let t = Trivia(leading: [comment("# a")], trailing: [comment("# b")])
  let n = greenwood.node_with_trivia(Root, [], t)
  let assert [t1] = greenwood.trailing_trivia(from: n)
  assert "# b" == t1.text
}

pub fn zip_and_unzip_is_identity_test() {
  let tree = simple_tree()
  let result = tree |> greenwood.zip |> greenwood.unzip
  assert result == tree
}

pub fn down_focuses_first_child_node_test() {
  let tree = simple_tree()
  let assert Some(z) = greenwood.zip(tree) |> greenwood.down
  assert Parent == z.focus.kind
}

pub fn down_where_finds_matching_child_test() {
  let tree = simple_tree()
  let assert Some(z) =
    greenwood.zip(tree)
    |> greenwood.down_where(fn(n) { n.children == [leaf("c")] })
  let assert [TokenElement(t)] = z.focus.children
  assert "c" == t.text
}

pub fn up_restores_parent_test() {
  let tree = simple_tree()
  let assert Some(child_z) = greenwood.zip(tree) |> greenwood.down
  let assert Some(parent_z) = greenwood.up(child_z)
  let assert True = parent_z.focus == tree
}

pub fn up_from_root_returns_none_test() {
  assert None == greenwood.zip(simple_tree()) |> greenwood.up
}

pub fn set_focus_replaces_node_test() {
  let tree = simple_tree()
  let assert Some(z) = greenwood.zip(tree) |> greenwood.down
  let new_child = greenwood.node(Child, [leaf("replaced")])
  let updated = greenwood.set_focus(z, new_child)
  assert updated.focus == new_child
}

pub fn map_focus_transforms_focused_node_test() {
  let tree = simple_tree()
  let assert Some(z) = greenwood.zip(tree) |> greenwood.down
  let updated =
    greenwood.map_focus(z, fn(n) {
      greenwood.append_child(in: n, child: leaf("new"))
    })
  let assert [TokenElement(t1), TokenElement(t2), TokenElement(t3)] =
    updated.focus.children
  assert "a" == t1.text
  assert "b" == t2.text
  assert "new" == t3.text
}

pub fn edit_via_zipper_round_trips_test() {
  let tree = simple_tree()
  let assert Some(z) = tree |> greenwood.zip |> greenwood.down
  let result =
    z
    |> greenwood.map_focus(fn(n) {
      greenwood.append_child(in: n, child: leaf("d"))
    })
    |> greenwood.unzip

  let assert [NodeElement(first), ..] = result.children
  let assert [TokenElement(t1), TokenElement(t2), TokenElement(t3)] =
    first.children
  assert "a" == t1.text
  assert "b" == t2.text
  assert "d" == t3.text
}

// Regression: navigating into a non-first child then back up must restore the
// original sibling order. (Earlier `split_at_node` reversed `left` twice.)
pub fn up_from_non_first_child_restores_order_test() {
  let tree = simple_tree()
  let assert Some(z) =
    greenwood.zip(tree)
    |> greenwood.down_where(fn(n) { n.children == [leaf("c")] })
  let assert Some(parent_z) = greenwood.up(z)
  assert parent_z.focus == tree
}

fn sibling_tree() -> greenwood.Node(Kind) {
  greenwood.node(Root, [
    NodeElement(greenwood.node(Child, [leaf("a")])),
    NodeElement(greenwood.node(Child, [leaf("b")])),
    NodeElement(greenwood.node(Child, [leaf("c")])),
  ])
}

fn focus_child_with(
  tree: greenwood.Node(Kind),
  text: String,
) -> greenwood.Zipper(Kind) {
  let assert Some(z) =
    greenwood.zip(tree)
    |> greenwood.down_where(fn(n) { n.children == [leaf(text)] })
  z
}

pub fn right_moves_to_next_sibling_test() {
  let tree = sibling_tree()
  let z = focus_child_with(tree, "a")
  let assert Some(z2) = greenwood.right(z)
  assert z2.focus.children == [leaf("b")]
}

pub fn right_returns_none_at_last_sibling_test() {
  let tree = sibling_tree()
  let z = focus_child_with(tree, "c")
  assert None == greenwood.right(z)
}

pub fn right_returns_none_at_root_test() {
  assert None == greenwood.right(greenwood.zip(sibling_tree()))
}

pub fn left_moves_to_previous_sibling_test() {
  let tree = sibling_tree()
  let z = focus_child_with(tree, "c")
  let assert Some(z2) = greenwood.left(z)
  assert z2.focus.children == [leaf("b")]
}

pub fn left_returns_none_at_first_sibling_test() {
  let tree = sibling_tree()
  let z = focus_child_with(tree, "a")
  assert None == greenwood.left(z)
}

pub fn left_returns_none_at_root_test() {
  assert None == greenwood.left(greenwood.zip(sibling_tree()))
}

pub fn right_then_left_is_identity_test() {
  let tree = sibling_tree()
  let z = focus_child_with(tree, "a")
  let assert Some(z2) = greenwood.right(z)
  let assert Some(z3) = greenwood.left(z2)
  assert z3.focus == z.focus
  assert greenwood.unzip(z3) == tree
}

pub fn right_where_skips_non_matching_test() {
  let tree = sibling_tree()
  let z = focus_child_with(tree, "a")
  let assert Some(z2) =
    greenwood.right_where(z, fn(n) { n.children == [leaf("c")] })
  assert z2.focus.children == [leaf("c")]
  // And it round-trips correctly.
  assert greenwood.unzip(z2) == tree
}

pub fn left_where_skips_non_matching_test() {
  let tree = sibling_tree()
  let z = focus_child_with(tree, "c")
  let assert Some(z2) =
    greenwood.left_where(z, fn(n) { n.children == [leaf("a")] })
  assert z2.focus.children == [leaf("a")]
  assert greenwood.unzip(z2) == tree
}

pub fn right_skips_token_siblings_and_preserves_them_test() {
  // Inline tokens between Node siblings must be skipped on navigation and
  // remain in their original positions when the tree is reconstructed.
  let tree =
    greenwood.node(Root, [
      NodeElement(greenwood.node(Child, [leaf("a")])),
      leaf(" "),
      NodeElement(greenwood.node(Child, [leaf("b")])),
    ])
  let z = focus_child_with(tree, "a")
  let assert Some(z2) = greenwood.right(z)
  assert z2.focus.children == [leaf("b")]
  assert greenwood.unzip(z2) == tree
}

pub fn left_skips_token_siblings_and_preserves_them_test() {
  let tree =
    greenwood.node(Root, [
      NodeElement(greenwood.node(Child, [leaf("a")])),
      leaf(" "),
      NodeElement(greenwood.node(Child, [leaf("b")])),
    ])
  let z = focus_child_with(tree, "b")
  let assert Some(z2) = greenwood.left(z)
  assert z2.focus.children == [leaf("a")]
  assert greenwood.unzip(z2) == tree
}

pub fn right_n_moves_n_siblings_test() {
  let tree = sibling_tree()
  let z = focus_child_with(tree, "a")
  let assert Some(z2) = greenwood.right_n(z, 2)
  assert z2.focus.children == [leaf("c")]
}

pub fn right_n_zero_is_identity_test() {
  let z = focus_child_with(sibling_tree(), "b")
  let assert Some(z2) = greenwood.right_n(z, 0)
  assert z2.focus == z.focus
}

pub fn right_n_overshoot_returns_none_test() {
  let z = focus_child_with(sibling_tree(), "a")
  assert None == greenwood.right_n(z, 5)
}

pub fn right_n_negative_equals_left_n_test() {
  let z = focus_child_with(sibling_tree(), "c")
  let assert Some(via_right_neg) = greenwood.right_n(z, -2)
  let assert Some(via_left_pos) = greenwood.left_n(z, 2)
  assert via_right_neg.focus == via_left_pos.focus
}

pub fn left_n_moves_n_siblings_test() {
  let z = focus_child_with(sibling_tree(), "c")
  let assert Some(z2) = greenwood.left_n(z, 2)
  assert z2.focus.children == [leaf("a")]
}

pub fn left_n_overshoot_returns_none_test() {
  let z = focus_child_with(sibling_tree(), "c")
  assert None == greenwood.left_n(z, 5)
}

pub fn left_n_negative_equals_right_n_test() {
  let z = focus_child_with(sibling_tree(), "a")
  let assert Some(via_left_neg) = greenwood.left_n(z, -2)
  let assert Some(via_right_pos) = greenwood.right_n(z, 2)
  assert via_left_neg.focus == via_right_pos.focus
}

fn mixed_sibling_tree() -> greenwood.Node(Kind) {
  greenwood.node(Root, [
    NodeElement(greenwood.node(Parent, [leaf("a")])),
    NodeElement(greenwood.node(Child, [leaf("b")])),
    NodeElement(greenwood.node(Parent, [leaf("c")])),
    NodeElement(greenwood.node(Child, [leaf("d")])),
    NodeElement(greenwood.node(Parent, [leaf("e")])),
  ])
}

pub fn right_n_where_moves_to_nth_match_test() {
  let tree = mixed_sibling_tree()
  let assert Some(z) =
    greenwood.zip(tree)
    |> greenwood.down_where(fn(n) { n.children == [leaf("a")] })
  let assert Some(z2) =
    greenwood.right_n_where(z, 2, fn(n) { n.kind == Parent })
  assert z2.focus.children == [leaf("e")]
}

pub fn right_n_where_zero_is_identity_test() {
  let tree = mixed_sibling_tree()
  let assert Some(z) =
    greenwood.zip(tree)
    |> greenwood.down_where(fn(n) { n.children == [leaf("b")] })
  let assert Some(z2) =
    greenwood.right_n_where(z, 0, fn(n) { n.kind == Parent })
  assert z2.focus == z.focus
}

pub fn right_n_where_overshoot_returns_none_test() {
  let tree = mixed_sibling_tree()
  let assert Some(z) =
    greenwood.zip(tree)
    |> greenwood.down_where(fn(n) { n.children == [leaf("a")] })
  assert None == greenwood.right_n_where(z, 5, fn(n) { n.kind == Parent })
}

pub fn right_n_where_negative_equals_left_n_where_test() {
  let tree = mixed_sibling_tree()
  let assert Some(z) =
    greenwood.zip(tree)
    |> greenwood.down_where(fn(n) { n.children == [leaf("e")] })
  let assert Some(via_right_neg) =
    greenwood.right_n_where(z, -2, fn(n) { n.kind == Parent })
  let assert Some(via_left_pos) =
    greenwood.left_n_where(z, 2, fn(n) { n.kind == Parent })
  assert via_right_neg.focus == via_left_pos.focus
}

pub fn left_n_where_moves_to_nth_match_test() {
  let tree = mixed_sibling_tree()
  let assert Some(z) =
    greenwood.zip(tree)
    |> greenwood.down_where(fn(n) { n.children == [leaf("e")] })
  let assert Some(z2) = greenwood.left_n_where(z, 2, fn(n) { n.kind == Parent })
  assert z2.focus.children == [leaf("a")]
}

pub fn left_n_where_zero_is_identity_test() {
  let tree = mixed_sibling_tree()
  let assert Some(z) =
    greenwood.zip(tree)
    |> greenwood.down_where(fn(n) { n.children == [leaf("d")] })
  let assert Some(z2) = greenwood.left_n_where(z, 0, fn(n) { n.kind == Parent })
  assert z2.focus == z.focus
}

pub fn left_n_where_overshoot_returns_none_test() {
  let tree = mixed_sibling_tree()
  let assert Some(z) =
    greenwood.zip(tree)
    |> greenwood.down_where(fn(n) { n.children == [leaf("e")] })
  assert None == greenwood.left_n_where(z, 5, fn(n) { n.kind == Parent })
}

pub fn left_n_where_negative_equals_right_n_where_test() {
  let tree = mixed_sibling_tree()
  let assert Some(z) =
    greenwood.zip(tree)
    |> greenwood.down_where(fn(n) { n.children == [leaf("a")] })
  let assert Some(via_left_neg) =
    greenwood.left_n_where(z, -2, fn(n) { n.kind == Parent })
  let assert Some(via_right_pos) =
    greenwood.right_n_where(z, 2, fn(n) { n.kind == Parent })
  assert via_left_neg.focus == via_right_pos.focus
}

fn deep_tree() -> greenwood.Node(Kind) {
  greenwood.node(Root, [
    NodeElement(
      greenwood.node(Parent, [
        NodeElement(greenwood.node(Child, [leaf("x")])),
      ]),
    ),
  ])
}

pub fn up_n_moves_n_parents_test() {
  let tree = deep_tree()
  let assert Some(z) =
    greenwood.zip(tree) |> greenwood.down |> option.then(greenwood.down)
  let assert Some(z2) = greenwood.up_n(z, 2)
  assert z2.focus == tree
}

pub fn up_n_zero_is_identity_test() {
  let tree = deep_tree()
  let assert Some(z) = greenwood.zip(tree) |> greenwood.down
  let assert Some(z2) = greenwood.up_n(z, 0)
  assert z2.focus == z.focus
}

pub fn up_n_overshoot_returns_none_test() {
  let tree = deep_tree()
  let assert Some(z) = greenwood.zip(tree) |> greenwood.down
  assert None == greenwood.up_n(z, 5)
}

pub fn up_n_negative_returns_none_test() {
  let z = greenwood.zip(deep_tree())
  assert None == greenwood.up_n(z, -1)
}

pub fn node_element_creates_bare_node_element_test() {
  let el = greenwood.node_element(kind: Root, children: [leaf("x")])
  let assert greenwood.NodeElement(n) = el
  assert Root == n.kind
  assert [greenwood.TokenElement(greenwood.Token(Leaf, "x"))] == n.children
  assert Bare == n.trivia
}

pub fn node_element_with_trivia_test() {
  let t = Trivia(leading: [comment("# hi")], trailing: [])
  let el =
    greenwood.node_element_with_trivia(
      kind: Root,
      children: [leaf("y")],
      trivia: t,
    )
  let assert greenwood.NodeElement(n) = el
  assert Root == n.kind
  let assert Trivia(leading: [tok], trailing: []) = n.trivia
  assert "# hi" == tok.text
}

pub fn token_element_creates_token_element_test() {
  let el = greenwood.token_element(kind: Leaf, text: "hello")
  let assert greenwood.TokenElement(tok) = el
  assert Leaf == tok.kind
  assert "hello" == tok.text
}
