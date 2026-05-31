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

@docs-open: docs
    open build/dev/docs/greenwood/index.html
