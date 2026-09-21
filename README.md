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
import hegel_gleam
import hegel_gleam/gen

hegel_gleam.check(fn(test_case) {
  let n = hegel_gleam.draw(test_case, "n", gen.int())
  assert n == n
})
```

## Development

Enter the devenv shell, then run `just test`. `just native` statically links
`hegeltest-c` into the Rustler NIF. Production packages load a bundled binary;
`HEGEL_NIF_PATH` is available for packagers and local debugging.
