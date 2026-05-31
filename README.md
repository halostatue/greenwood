# greenwood

[![Hex.pm](https://img.shields.io/hexpm/v/greenwood?style=for-the-badge "Hex Version")](https://hex.pm/package/greenwood)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg?style=for-the-badge "Hex Docs")](https://greenwood.hexdocs.pm/)
[![Apache 2.0](https://img.shields.io/hexpm/l/greenwood?style=for-the-badge&label=licence "Apache 2.0")](https://github.com/halostatue/greenwood/blob/main/LICENCE.md)
![JavaScript Compatible](https://img.shields.io/badge/target-javascript-f3e155?style=for-the-badge "JavaScript Compatible")
![Erlang Compatible](https://img.shields.io/badge/target-erlang-f3e155?style=for-the-badge "Erlang Compatible")

- code :: <https://github.com/halostatue/greenwood>
- issues :: <https://github.com/halostatue/greenwood/issues>

A generic trivia-preserving concrete syntax tree (CST) library for Gleam.

## Overview

Greenwood provides an immutable concrete syntax tree parameterized by node and
token `kind`, with associated trivia and structural transformation primitives.
Greenwood syntax trees are format-agnostic and parsers supply their own `kind`
types.

## Installation

```sh
gleam add greenwood@1
```

Further documentation can be found at <https://greenwood.hexdocs.pm>.

## A Deeper Dive

### Function Groups

There are six types of functions in the Greenwood interface:

- `builder`: construct Greenwood trees
- `query`: interrogate a tree
- `transformer`: transform a tree
- `traversal`: traverse a tree
- `trivia`: manage trivia on nodes
- `cursor`: navigate and edit with a movable cursor

Each function and type is marked with its interface group in the documentation.

### Trivia

In syntax tree terminology, "trivia" refers to source text that has no semantic
meaning to the language but matters to humans: whitespace, comments, blank
lines, and sometimes preprocessor directives. A pure AST discards trivia
entirely, but a CST must track it.

Greenwood implements a hybrid concrete syntax tree supporting [Roslyn][dn]-style
Trivia annotations (attached trivia) or [Rowan][rust]-style green tree child
tokens (inline trivia), depending on the choices made by the parser.

- Attached trivia (Roslyn-style) is where each node carries leading and trailing
  trivia tokens. A comment above a function "belongs to" that function node.
  This makes it easy to move a node and have its comments follow. Greenwood
  supports this with `Trivia(leading, trailing)`.

- Inline trivia (Rowan-style) tokens are siblings in the children list, with no
  special attachment. The tree is uniform but the parser (or a later pass) must
  decide ownership when moving nodes. Greenwood supports this with `Bare` trivia
  markers.

[dn]: https://github.com/dotnet/roslyn/blob/main/docs/wiki/Roslyn-Overview.md#syntax-trivia
[rust]: https://github.com/rust-analyzer/rowan

### Cursor (Zipper)

The cursor API implements a Huet [zipper][zipper] (Gérard Huet, "The Zipper",
_Journal of Functional Programming_ 7(5):549–554, 1997). It provides a focused
view into the tree — you can navigate down into children, edit the focused node,
and reconstruct the full tree by moving back up. This avoids rebuilding the
entire tree from the root for localized edits.

[zipper]: https://people.mpi-sws.org/~skilpat/plerg/papers/huet-zipper-2up.pdf

### Core Types

- `Node(kind, children, trivia)` — interior tree node
- `Token(kind, text)` — leaf carrying literal source text
- `Element` — either a `NodeElement(Node)` or `TokenElement(Token)`
- `Trivia` — `Trivia(leading, trailing)` or `Bare`
- `Zipper` — cursor with focus node and breadcrumbs
- `Crumb` — context for reconstructing a parent from a focused child

## Libraries Using Greenwood

COMING SOON

## Roadmap

Future capabilities may include tree diffing (compare two trees and produce a
minimal edit script).

## Semantic Versioning

`greenwood` follows [Semantic Versioning 2.0][semver].

[docs]: https://greenwood.hexdocs.pm/
[hexpm]: https://hex.pm/packages/greenwood
[licence]: https://github.com/halostatue/greenwood/blob/main/LICENCE.md
[semver]: https://semver.org/
