# `greenwood` Changelog

## 1.2.0 / 2026-06-16

- `cursor`: Soft-deprecated cursor functions in `greenwood`. They will be
  hard-deprecated on the next minor version and removed in v2.

- `cursor`: Implemented cursor functions in `greenwood/zipper`. This implements
  a number of zipper/cursor-based functions discovered to be useful in
  implementation and maintains the existing functions.

  - Existing functions: `down`, `down_where`, `left`, `left_n`, `left_n_where`,
    `left_where`, `map_focus`, `right`, `right_n`, `right_n_where`,`set_focus`,
    `right_where`, `unzip`, `up`, `up_n`, `zip`

  - New functions: `delete`, `down_last`, `down_last_where`, `find_descendant`,
    `insert_down`, `insert_left`, `insert_right`, `left_n_until`, `left_until`,
    `nth_child`, `right_n_until`, `right_until`, `up_until`

- `cursor`: Added some zipper examples in `dev/zipper_examples.gleam`.

- `builder`: In advance of introducing a new `Token` variant (`ImplicitToken`)
  in Greenwood v2, new constructor functions have been added that formalize
  implicit tokens as textless (`Token(kind:, text: "")`).

## 1.1.0 / 2026-06-08

- `traversal`: Added `traverse` for rich syntax tree traversal.
- `cursor`: Added `left_n_where` and `right_n_where` predicate functions.

## 1.0.0 / 2026-05-31

- Initial release.
