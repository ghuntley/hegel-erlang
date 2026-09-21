# Hegel Elixir example

This Mix application demonstrates the `Hegel.property` and `draw` macros,
generator composition, ExUnit integration, shrinking, and native Elixir
failures.

From the repository root, build the native engine once:

```shell
just native
```

Then run the passing property and test suite:

```shell
cd examples/elixir
mix run -e 'HegelElixirExample.reverse_property()'
mix test
```

Run the intentional failure demo:

```shell
mix run -e 'HegelElixirExample.failure_demo()'
```

The demo asks Hegel to prove that every integer from `0` through `100` is
below `10`. It fails, shrinks the input, prints the minimal counterexample,
and exits with the original Elixir match error.
