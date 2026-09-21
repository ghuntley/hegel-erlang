# Hegel Gleam example

This Gleam application demonstrates the `hegel/property` and `hegel/gen`
modules, generator composition, gleeunit integration, shrinking, and native
Gleam assertion failures.

From the repository root, build the native engine once:

```shell
just native
```

Then run the passing property and test suite:

```shell
cd examples/gleam
gleam run
gleam test
```

Run the intentional failure demo:

```shell
gleam run -m failure_demo
```

The demo asks Hegel to prove that every integer from `0` through `100` is
below `10`. It fails, shrinks the input, prints the minimal counterexample,
and exits with the original Gleam assertion failure.
