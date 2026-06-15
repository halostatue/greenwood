import gleam/option.{None, Some}
import greenwood
import greenwood/zipper

pub type Kind {
  Root
  Parent
  Child
  Leaf
}

fn leaf(text: String) -> greenwood.Element(Kind) {
  greenwood.TokenElement(greenwood.token(Leaf, text))
}

fn simple_tree() -> greenwood.Node(Kind) {
  greenwood.node(Root, [
    greenwood.NodeElement(greenwood.node(Parent, [leaf("a"), leaf("b")])),
    greenwood.NodeElement(greenwood.node(Parent, [leaf("c")])),
  ])
}

fn sibling_tree() -> greenwood.Node(Kind) {
  greenwood.node(Root, [
    greenwood.NodeElement(greenwood.node(Child, [leaf("a")])),
    greenwood.NodeElement(greenwood.node(Child, [leaf("b")])),
    greenwood.NodeElement(greenwood.node(Child, [leaf("c")])),
  ])
}

fn mixed_sibling_tree() -> greenwood.Node(Kind) {
  greenwood.node(Root, [
    greenwood.NodeElement(greenwood.node(Parent, [leaf("a")])),
    greenwood.NodeElement(greenwood.node(Child, [leaf("b")])),
    greenwood.NodeElement(greenwood.node(Parent, [leaf("c")])),
    greenwood.NodeElement(greenwood.node(Child, [leaf("d")])),
    greenwood.NodeElement(greenwood.node(Parent, [leaf("e")])),
  ])
}

fn deep_tree() -> greenwood.Node(Kind) {
  greenwood.node(Root, [
    greenwood.NodeElement(
      greenwood.node(Parent, [
        greenwood.NodeElement(greenwood.node(Child, [leaf("x")])),
      ]),
    ),
  ])
}

fn focus_child_with(
  tree: greenwood.Node(Kind),
  text: String,
) -> greenwood.Zipper(Kind) {
  let assert Some(z) =
    zipper.zip(tree)
    |> zipper.down_where(predicate: fn(n) { n.children == [leaf(text)] })
  z
}

// ---------------------------------------------------------------------------
// zip / unzip
// ---------------------------------------------------------------------------

pub fn zip_and_unzip_is_identity_test() {
  let tree = simple_tree()
  assert tree == tree |> zipper.zip |> zipper.unzip
}

// ---------------------------------------------------------------------------
// down / down_where
// ---------------------------------------------------------------------------

pub fn down_focuses_first_child_node_test() {
  let assert Some(z) = zipper.zip(simple_tree()) |> zipper.down
  assert Parent == z.focus.kind
}

pub fn down_where_finds_matching_child_test() {
  let tree = simple_tree()
  let assert Some(z) =
    zipper.zip(tree)
    |> zipper.down_where(predicate: fn(n) { n.children == [leaf("c")] })
  let assert [greenwood.TokenElement(t)] = z.focus.children
  assert "c" == t.text
}

pub fn down_returns_none_on_leaf_only_children_test() {
  let tree = greenwood.node(Root, [leaf("x")])
  assert None == zipper.zip(tree) |> zipper.down
}

// ---------------------------------------------------------------------------
// down_last / down_last_where
// ---------------------------------------------------------------------------

pub fn down_last_focuses_last_child_node_test() {
  let tree = sibling_tree()
  let assert Some(z) = zipper.zip(tree) |> zipper.down_last
  assert z.focus.children == [leaf("c")]
}

pub fn down_last_where_finds_last_matching_test() {
  let tree = mixed_sibling_tree()
  let assert Some(z) =
    zipper.zip(tree)
    |> zipper.down_last_where(predicate: fn(n) { n.kind == Parent })
  assert z.focus.children == [leaf("e")]
}

pub fn down_last_where_returns_none_when_no_match_test() {
  let tree = sibling_tree()
  assert None
    == zipper.zip(tree)
    |> zipper.down_last_where(predicate: fn(n) { n.kind == Parent })
}

pub fn down_last_round_trips_test() {
  let tree = sibling_tree()
  let assert Some(z) = zipper.zip(tree) |> zipper.down_last
  assert tree == zipper.unzip(z)
}

// ---------------------------------------------------------------------------
// up / up_n / up_until
// ---------------------------------------------------------------------------

pub fn up_restores_parent_test() {
  let tree = simple_tree()
  let assert Some(child_z) = zipper.zip(tree) |> zipper.down
  let assert Some(parent_z) = zipper.up(child_z)
  assert parent_z.focus == tree
}

pub fn up_from_root_returns_none_test() {
  assert None == zipper.zip(simple_tree()) |> zipper.up
}

pub fn up_n_moves_n_parents_test() {
  let tree = deep_tree()
  let assert Some(z) =
    zipper.zip(tree)
    |> zipper.down
    |> option.then(zipper.down)
  let assert Some(z2) = zipper.up_n(z, by: 2)
  assert z2.focus == tree
}

pub fn up_n_zero_is_identity_test() {
  let tree = deep_tree()
  let assert Some(z) = zipper.zip(tree) |> zipper.down
  let assert Some(z2) = zipper.up_n(z, by: 0)
  assert z2.focus == z.focus
}

pub fn up_n_overshoot_returns_none_test() {
  let tree = deep_tree()
  let assert Some(z) = zipper.zip(tree) |> zipper.down
  assert None == zipper.up_n(z, by: 5)
}

pub fn up_until_finds_ancestor_test() {
  let tree = deep_tree()
  let assert Some(z) =
    zipper.zip(tree)
    |> zipper.down
    |> option.then(zipper.down)
  let assert Some(z2) = zipper.up_until(z, predicate: fn(n) { n.kind == Root })
  assert z2.focus == tree
}

pub fn up_until_returns_none_when_no_match_test() {
  let tree = deep_tree()
  let assert Some(z) =
    zipper.zip(tree)
    |> zipper.down
    |> option.then(zipper.down)
  assert None == zipper.up_until(z, predicate: fn(n) { n.kind == Leaf })
}

// ---------------------------------------------------------------------------
// nth_child
// ---------------------------------------------------------------------------

pub fn nth_child_first_test() {
  let tree = sibling_tree()
  let assert Some(z) = zipper.zip(tree) |> zipper.nth_child(n: 1)
  assert z.focus.children == [leaf("a")]
}

pub fn nth_child_third_test() {
  let tree = sibling_tree()
  let assert Some(z) = zipper.zip(tree) |> zipper.nth_child(n: 3)
  assert z.focus.children == [leaf("c")]
}

pub fn nth_child_overshoot_returns_none_test() {
  let tree = sibling_tree()
  assert None == zipper.zip(tree) |> zipper.nth_child(n: 10)
}

pub fn nth_child_zero_returns_none_test() {
  let tree = sibling_tree()
  assert None == zipper.zip(tree) |> zipper.nth_child(n: 0)
}

pub fn nth_child_negative_returns_none_test() {
  let tree = sibling_tree()
  assert None == zipper.zip(tree) |> zipper.nth_child(n: -1)
}

// ---------------------------------------------------------------------------
// left / right / left_where / right_where
// ---------------------------------------------------------------------------

pub fn right_moves_to_next_sibling_test() {
  let z = focus_child_with(sibling_tree(), "a")
  let assert Some(z2) = zipper.right(z)
  assert z2.focus.children == [leaf("b")]
}

pub fn right_returns_none_at_last_test() {
  let z = focus_child_with(sibling_tree(), "c")
  assert None == zipper.right(z)
}

pub fn left_moves_to_prev_sibling_test() {
  let z = focus_child_with(sibling_tree(), "c")
  let assert Some(z2) = zipper.left(z)
  assert z2.focus.children == [leaf("b")]
}

pub fn left_returns_none_at_first_test() {
  let z = focus_child_with(sibling_tree(), "a")
  assert None == zipper.left(z)
}

pub fn right_then_left_is_identity_test() {
  let tree = sibling_tree()
  let z = focus_child_with(tree, "a")
  let assert Some(z2) = zipper.right(z)
  let assert Some(z3) = zipper.left(z2)
  assert z3.focus == z.focus
  assert zipper.unzip(z3) == tree
}

pub fn right_where_skips_non_matching_test() {
  let tree = sibling_tree()
  let z = focus_child_with(tree, "a")
  let assert Some(z2) =
    zipper.right_where(z, predicate: fn(n) { n.children == [leaf("c")] })
  assert z2.focus.children == [leaf("c")]
  assert zipper.unzip(z2) == tree
}

pub fn left_where_skips_non_matching_test() {
  let tree = sibling_tree()
  let z = focus_child_with(tree, "c")
  let assert Some(z2) =
    zipper.left_where(z, predicate: fn(n) { n.children == [leaf("a")] })
  assert z2.focus.children == [leaf("a")]
  assert zipper.unzip(z2) == tree
}

pub fn right_skips_token_siblings_test() {
  let tree =
    greenwood.node(Root, [
      greenwood.NodeElement(greenwood.node(Child, [leaf("a")])),
      leaf(" "),
      greenwood.NodeElement(greenwood.node(Child, [leaf("b")])),
    ])
  let z = focus_child_with(tree, "a")
  let assert Some(z2) = zipper.right(z)
  assert z2.focus.children == [leaf("b")]
  assert zipper.unzip(z2) == tree
}

// ---------------------------------------------------------------------------
// left_n / right_n / left_n_where / right_n_where
// ---------------------------------------------------------------------------

pub fn right_n_moves_n_siblings_test() {
  let z = focus_child_with(sibling_tree(), "a")
  let assert Some(z2) = zipper.right_n(z, by: 2)
  assert z2.focus.children == [leaf("c")]
}

pub fn right_n_zero_is_identity_test() {
  let z = focus_child_with(sibling_tree(), "b")
  let assert Some(z2) = zipper.right_n(z, by: 0)
  assert z2.focus == z.focus
}

pub fn right_n_overshoot_returns_none_test() {
  let z = focus_child_with(sibling_tree(), "a")
  assert None == zipper.right_n(z, by: 5)
}

pub fn right_n_negative_equals_left_n_test() {
  let z = focus_child_with(sibling_tree(), "c")
  let assert Some(via_right_neg) = zipper.right_n(z, by: -2)
  let assert Some(via_left_pos) = zipper.left_n(z, by: 2)
  assert via_right_neg.focus == via_left_pos.focus
}

pub fn left_n_moves_n_siblings_test() {
  let z = focus_child_with(sibling_tree(), "c")
  let assert Some(z2) = zipper.left_n(z, by: 2)
  assert z2.focus.children == [leaf("a")]
}

pub fn right_n_where_moves_to_nth_match_test() {
  let tree = mixed_sibling_tree()
  let assert Some(z) =
    zipper.zip(tree)
    |> zipper.down_where(predicate: fn(n) { n.children == [leaf("a")] })
  let assert Some(z2) =
    zipper.right_n_where(z, by: 2, predicate: fn(n) { n.kind == Parent })
  assert z2.focus.children == [leaf("e")]
}

pub fn left_n_where_moves_to_nth_match_test() {
  let tree = mixed_sibling_tree()
  let assert Some(z) =
    zipper.zip(tree)
    |> zipper.down_where(predicate: fn(n) { n.children == [leaf("e")] })
  let assert Some(z2) =
    zipper.left_n_where(z, by: 2, predicate: fn(n) { n.kind == Parent })
  assert z2.focus.children == [leaf("a")]
}

// ---------------------------------------------------------------------------
// right_until / left_until / right_n_until / left_n_until
// ---------------------------------------------------------------------------

pub fn right_until_finds_target_test() {
  let tree = mixed_sibling_tree()
  let z = focus_child_with(tree, "a")
  let assert Some(z2) =
    zipper.right_until(
      z,
      target: fn(n) { n.children == [leaf("c")] },
      stop: fn(n) { n.children == [leaf("e")] },
    )
  assert z2.focus.children == [leaf("c")]
}

pub fn right_until_stops_on_stop_test() {
  let tree = mixed_sibling_tree()
  let z = focus_child_with(tree, "a")
  assert None
    == zipper.right_until(
      z,
      target: fn(n) { n.children == [leaf("e")] },
      stop: fn(n) { n.children == [leaf("c")] },
    )
}

pub fn right_until_returns_none_on_exhaustion_test() {
  let tree = sibling_tree()
  let z = focus_child_with(tree, "a")
  assert None
    == zipper.right_until(
      z,
      target: fn(n) { n.children == [leaf("z")] },
      stop: fn(_) { False },
    )
}

pub fn left_until_finds_target_test() {
  let tree = mixed_sibling_tree()
  let z = focus_child_with(tree, "e")
  let assert Some(z2) =
    zipper.left_until(
      z,
      target: fn(n) { n.children == [leaf("c")] },
      stop: fn(n) { n.children == [leaf("a")] },
    )
  assert z2.focus.children == [leaf("c")]
}

pub fn left_until_stops_on_stop_test() {
  let tree = mixed_sibling_tree()
  let z = focus_child_with(tree, "e")
  assert None
    == zipper.left_until(
      z,
      target: fn(n) { n.children == [leaf("a")] },
      stop: fn(n) { n.children == [leaf("c")] },
    )
}

pub fn right_n_until_counts_targets_test() {
  let tree = mixed_sibling_tree()
  let z = focus_child_with(tree, "a")
  // Find 2 Parent siblings to the right
  let assert Some(z2) =
    zipper.right_n_until(
      z,
      n: 2,
      target: fn(n) { n.kind == Parent },
      stop: fn(_) { False },
    )
  assert z2.focus.children == [leaf("e")]
}

pub fn right_n_until_zero_is_identity_test() {
  let z = focus_child_with(sibling_tree(), "a")
  let assert Some(z2) =
    zipper.right_n_until(z, n: 0, target: fn(_) { True }, stop: fn(_) { False })
  assert z2.focus == z.focus
}

pub fn left_n_until_counts_targets_test() {
  let tree = mixed_sibling_tree()
  let z = focus_child_with(tree, "e")
  let assert Some(z2) =
    zipper.left_n_until(
      z,
      n: 2,
      target: fn(n) { n.kind == Parent },
      stop: fn(_) { False },
    )
  assert z2.focus.children == [leaf("a")]
}

// ---------------------------------------------------------------------------
// find_descendant
// ---------------------------------------------------------------------------

pub fn find_descendant_finds_nested_node_test() {
  let tree = deep_tree()
  let assert Some(z) =
    zipper.zip(tree)
    |> zipper.find_descendant(where: fn(n) { n.kind == Child })
  assert z.focus.kind == Child
  assert z.focus.children == [leaf("x")]
}

pub fn find_descendant_returns_none_when_no_match_test() {
  let tree = simple_tree()
  assert None
    == zipper.zip(tree)
    |> zipper.find_descendant(where: fn(n) { n.kind == Leaf })
}

pub fn find_descendant_finds_immediate_child_test() {
  let tree = sibling_tree()
  let assert Some(z) =
    zipper.zip(tree)
    |> zipper.find_descendant(where: fn(n) { n.children == [leaf("b")] })
  assert z.focus.children == [leaf("b")]
  // Should round-trip
  assert zipper.unzip(z) == tree
}

// ---------------------------------------------------------------------------
// set_focus / map_focus
// ---------------------------------------------------------------------------

pub fn set_focus_replaces_node_test() {
  let tree = simple_tree()
  let assert Some(z) = zipper.zip(tree) |> zipper.down
  let new_node = greenwood.node(Child, [leaf("replaced")])
  let updated = zipper.set_focus(z, node: new_node)
  assert updated.focus == new_node
}

pub fn map_focus_transforms_focused_node_test() {
  let tree = simple_tree()
  let assert Some(z) = zipper.zip(tree) |> zipper.down
  let updated =
    zipper.map_focus(z, with: fn(n) {
      greenwood.append_child(in: n, child: leaf("new"))
    })
  let assert [_, _, greenwood.TokenElement(t)] = updated.focus.children
  assert "new" == t.text
}

// ---------------------------------------------------------------------------
// insert_left / insert_right
// ---------------------------------------------------------------------------

pub fn insert_left_adds_sibling_test() {
  let tree = sibling_tree()
  let z = focus_child_with(tree, "b")
  let new_el = greenwood.NodeElement(greenwood.node(Child, [leaf("x")]))
  let assert Some(z2) = zipper.insert_left(z, element: new_el)
  // Focus stays on "b"
  assert z2.focus.children == [leaf("b")]
  // After unzip, "x" appears before "b"
  let result = zipper.unzip(z2)
  let assert [
    greenwood.NodeElement(n1),
    greenwood.NodeElement(n2),
    greenwood.NodeElement(n3),
    greenwood.NodeElement(n4),
  ] = result.children
  assert n1.children == [leaf("a")]
  assert n2.children == [leaf("x")]
  assert n3.children == [leaf("b")]
  assert n4.children == [leaf("c")]
}

pub fn insert_right_adds_sibling_test() {
  let tree = sibling_tree()
  let z = focus_child_with(tree, "b")
  let new_el = greenwood.NodeElement(greenwood.node(Child, [leaf("x")]))
  let assert Some(z2) = zipper.insert_right(z, element: new_el)
  // Focus stays on "b"
  assert z2.focus.children == [leaf("b")]
  // After unzip, "x" appears after "b"
  let result = zipper.unzip(z2)
  let assert [
    greenwood.NodeElement(n1),
    greenwood.NodeElement(n2),
    greenwood.NodeElement(n3),
    greenwood.NodeElement(n4),
  ] = result.children
  assert n1.children == [leaf("a")]
  assert n2.children == [leaf("b")]
  assert n3.children == [leaf("x")]
  assert n4.children == [leaf("c")]
}

pub fn insert_left_at_root_returns_none_test() {
  let z = zipper.zip(simple_tree())
  assert None == zipper.insert_left(z, element: leaf("x"))
}

pub fn insert_right_at_root_returns_none_test() {
  let z = zipper.zip(simple_tree())
  assert None == zipper.insert_right(z, element: leaf("x"))
}

// ---------------------------------------------------------------------------
// insert_down
// ---------------------------------------------------------------------------

pub fn insert_down_adds_first_child_and_focuses_it_test() {
  let tree = sibling_tree()
  let z = focus_child_with(tree, "b")
  let new_child = greenwood.node(Child, [leaf("inner")])
  let z2 = zipper.insert_down(z, child: new_child)
  // Focus moved to new child
  assert z2.focus == new_child
  // Going up shows the new child is first, old children are right siblings
  let assert Some(parent_z) = zipper.up(z2)
  let assert [greenwood.NodeElement(first), leaf_b] = parent_z.focus.children
  assert first == new_child
  assert leaf_b == leaf("b")
}

pub fn insert_down_into_empty_node_test() {
  let tree =
    greenwood.node(Root, [greenwood.NodeElement(greenwood.node(Child, []))])
  let assert Some(z) = zipper.zip(tree) |> zipper.down
  let new_child = greenwood.node(Child, [leaf("new")])
  let z2 = zipper.insert_down(z, child: new_child)
  assert z2.focus == new_child
  let result = zipper.unzip(z2)
  let assert [greenwood.NodeElement(outer)] = result.children
  let assert [greenwood.NodeElement(inner)] = outer.children
  assert inner == new_child
}

// ---------------------------------------------------------------------------
// delete
// ---------------------------------------------------------------------------

pub fn delete_shifts_to_right_sibling_test() {
  let tree = sibling_tree()
  let z = focus_child_with(tree, "b")
  let assert Some(z2) = zipper.delete(z)
  // Focus shifted to "c" (right sibling)
  assert z2.focus.children == [leaf("c")]
  let result = zipper.unzip(z2)
  let assert [greenwood.NodeElement(n1), greenwood.NodeElement(n2)] =
    result.children
  assert n1.children == [leaf("a")]
  assert n2.children == [leaf("c")]
}

pub fn delete_shifts_to_left_when_no_right_test() {
  let tree = sibling_tree()
  let z = focus_child_with(tree, "c")
  let assert Some(z2) = zipper.delete(z)
  // Focus shifted to "b" (left sibling, since no right)
  assert z2.focus.children == [leaf("b")]
}

pub fn delete_shifts_to_parent_when_no_siblings_test() {
  let tree =
    greenwood.node(Root, [
      greenwood.NodeElement(greenwood.node(Child, [leaf("only")])),
    ])
  let assert Some(z) = zipper.zip(tree) |> zipper.down
  let assert Some(z2) = zipper.delete(z)
  // Focus shifted to parent (now empty of Node children)
  assert z2.focus.kind == Root
  assert z2.focus.children == []
}

pub fn delete_at_root_returns_none_test() {
  let z = zipper.zip(simple_tree())
  assert None == zipper.delete(z)
}

pub fn delete_preserves_token_siblings_test() {
  let tree =
    greenwood.node(Root, [
      greenwood.NodeElement(greenwood.node(Child, [leaf("a")])),
      leaf(" "),
      greenwood.NodeElement(greenwood.node(Child, [leaf("b")])),
      leaf(" "),
      greenwood.NodeElement(greenwood.node(Child, [leaf("c")])),
    ])
  let z = focus_child_with(tree, "b")
  let assert Some(z2) = zipper.delete(z)
  // Should shift to "c" (next Node sibling to the right)
  assert z2.focus.children == [leaf("c")]
  // Token siblings should be preserved in the result
  let result = zipper.unzip(z2)
  let assert [
    greenwood.NodeElement(n1),
    greenwood.TokenElement(_),
    greenwood.TokenElement(_),
    greenwood.NodeElement(n2),
  ] = result.children
  assert n1.children == [leaf("a")]
  assert n2.children == [leaf("c")]
}
