# Hegel Erlang example

This rebar3 application demonstrates `hegel:check/2`, composable generators,
the `?DRAW` macro, EUnit integration, shrinking, and native Erlang failures.

From the repository root, build the native engine once:

```shell
just native
```

Then build and run the passing property:

```shell
cd examples/erlang
rebar3 escriptize
_build/default/bin/hegel_erlang_example
rebar3 eunit
```

Run the intentional failure demo:

```shell
_build/default/bin/hegel_erlang_example failure
```

The demo asks Hegel to prove that every integer from `0` through `100` is
below `10`. It fails, shrinks the input, prints the minimal counterexample,
and exits with the original Erlang `badmatch` exception.
