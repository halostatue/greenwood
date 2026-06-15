_default:
    just --list

@test:
    gleam test --target erlang
    gleam test --target javascript

@build:
    gleam build

@lint:
    gleam run -m glinter

@format:
    gleam format

@format-check:
    gleam format --check src test

@docs:
    gleam docs build

golden-test runtime="erlang":
    #!/usr/bin/env bash

    set -euo pipefail

    target=erlang
    runtime=()

    case "{{ runtime }}" in
      erlang) : ;;
      bun)
        target=javascript
        runtime=(--runtime bun)
        ;;
      deno)
        target=javascript
        runtime=(--runtime deno)
        ;;
      node)
        target=javascript
        runtime=(--runtime node)
        ;;
    esac

    for mod in math_expr s_expressions zipper_examples; do
      gleam run -m "$mod" \
        --target "${target}" \
        "${runtime[@]}" >"test/golden/$mod.actual"
      diff -u "test/golden/$mod.expected" "test/golden/$mod.actual" && echo "Pass"
    done

golden:
    #!/usr/bin/env bash

    set -euo pipefail

    for mod in math_expr s_expressions zipper_examples; do
      gleam run -m "$mod" >"test/golden/$mod.expected"
    done

@docs-open: docs
    open build/dev/docs/greenwood/index.html
