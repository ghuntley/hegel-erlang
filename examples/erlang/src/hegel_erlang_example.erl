-module(hegel_erlang_example).
-include_lib("hegel/include/hegel.hrl").
-export([main/1, reverse_property/0, failure_demo/0]).

main(["failure"]) -> failure_demo();
main(_) ->
    ok = reverse_property(),
    io:format("The reverse property passed.~n").

reverse_property() ->
    hegel:check(fun(_TestCase) ->
        ?DRAW(Values, hegel_gen:list(hegel_gen:integer())),
        Values = lists:reverse(lists:reverse(Values))
    end, #{database => disabled, seed => 2026}).

failure_demo() ->
    hegel:check(fun(_TestCase) ->
        ?DRAW(Value, hegel_gen:integer(0, 100)),
        true = Value < 10
    end, #{database => disabled, seed => 2026}).
