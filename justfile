native:
    cargo build --release --manifest-path native/hegel_nif/Cargo.toml

compile: native
    rebar3 compile

test: compile
    rebar3 eunit
    cd packages/hegel_ex && mix test
    cd packages/hegel_gleam && gleam test

format:
    cargo fmt --manifest-path native/hegel_nif/Cargo.toml
    rebar3 fmt
    cd packages/hegel_ex && mix format
    cd packages/hegel_gleam && gleam format
