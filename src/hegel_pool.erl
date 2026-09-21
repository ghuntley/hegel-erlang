-module(hegel_pool).
-export([new/0, put/2, member/2, delete/2, values/1, draw/2]).

new() -> ets:new(?MODULE, [set, public]).
put(Pool, Value) -> ets:insert(Pool, {Value}), ok.
member(Pool, Value) -> ets:member(Pool, Value).
delete(Pool, Value) -> ets:delete(Pool, Value), ok.
values(Pool) -> [Value || {Value} <- ets:tab2list(Pool)].
draw(TC, Pool) ->
    Items = values(Pool), hegel:assume(Items =/= []),
    hegel:draw_silent(TC, hegel_gen:one_of([hegel_gen:constant(V) || V <- Items])).
