native:
    cargo build --release --manifest-path native/hegel_nif/Cargo.toml
    # erlang:load_nif/2 looks for a .so file on every Unix, including macOS.
    # Copy then rename, so a VM that has the old .so mapped keeps its file.
    if [ -f native/hegel_nif/target/release/libhegel_nif.dylib ]; then cp native/hegel_nif/target/release/libhegel_nif.dylib native/hegel_nif/target/release/libhegel_nif.so.tmp && mv native/hegel_nif/target/release/libhegel_nif.so.tmp native/hegel_nif/target/release/libhegel_nif.so; fi

compile: native
    rebar3 compile

test: compile
    rebar3 eunit
    cd packages/hegel_ex && mix test
    cd packages/hegel_gleam && gleam test
    cd examples/erlang && rebar3 eunit
    cd examples/elixir && mix test
    cd examples/gleam && gleam test

format:
    cargo fmt --manifest-path native/hegel_nif/Cargo.toml
    rebar3 fmt
    cd packages/hegel_ex && mix format
    cd packages/hegel_gleam && gleam format
    cd examples/elixir && mix format
    cd examples/gleam && gleam format
