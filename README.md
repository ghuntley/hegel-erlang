# Hegel for the BEAM

An Erlang-first binding to [Hegel](https://hegel.dev), with idiomatic Elixir
and Gleam facades. All three languages share the same native engine, generator
semantics, shrinking, replay blobs, and failure model.

## Erlang

```erlang
-include_lib("hegel/include/hegel.hrl").

reverse_property_test() ->
    hegel:check(fun(_TC) ->
        ?DRAW(Xs, hegel_gen:list(hegel_gen:integer())),
        Xs = lists:reverse(lists:reverse(Xs))
    end).
```

`hegel:check/1,2` re-raises the original, shrunk exception. `hegel:run/1,2`
returns a structured result for tools and custom test adapters. A test case is
an explicit value, so helper functions and concurrent workers do not rely on
hidden global state.

## Elixir

```elixir
use Hegel

property "reverse is involutive" do
  xs = draw(Hegel.Gen.list(Hegel.Gen.integer()))
  assert xs |> Enum.reverse() |> Enum.reverse() == xs
end
```

The property macro tags tests with `:hegel`, captures useful draw names, and
preserves ExUnit assertion exceptions and stacktraces.

Stateful testing is exposed as `Hegel.StateMachine`; concurrent tests against
shared processes or ETS state use `Hegel.ConcurrentStateMachine`. `Hegel.Task`
clones the native test-case handle so worker processes have independent,
deterministic choice streams.

## Gleam

```gleam
import hegel/gen
import hegel/property

property.check(fn(test_case) {
  let n = property.draw(test_case, "n", gen.int())
  assert n == n
})
```

The facade uses the `hegel/property` and `hegel/gen` namespace. A root Gleam
module named `hegel` would compile to the same BEAM module as the Erlang API,
so the nested namespace keeps both packages interoperable.

## Examples

Complete, runnable applications are available for each BEAM language:

- [Erlang](examples/erlang/README.md)
- [Elixir](examples/elixir/README.md)
- [Gleam](examples/gleam/README.md)

Each project includes a passing framework-integrated property and a separate
failure demo that shows shrinking and native assertion reporting.

## Development

Enter the devenv shell, then run `just test`. `just native` statically links
`hegeltest-c` into the Rustler NIF for development. Compiled NIFs are release
artifacts rather than source-controlled files; packaged releases place them
under `priv/native/<platform>`. `HEGEL_NIF_PATH` remains available for
packagers and local debugging.
