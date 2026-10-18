-module(hegel_pool).
-export([new/0, put/2, member/2, delete/2, values/1, draw/2]).

%% A pool created inside a property is deleted when its test case ends.
new() ->
    Pool = ets:new(?MODULE, [set, public]),
    case in_property() of
        true -> hegel:on_cleanup(fun() -> delete_table(Pool) end);
        false -> ok
    end,
    Pool.
put(Pool, Value) -> ets:insert(Pool, {Value}), ok.
member(Pool, Value) -> ets:member(Pool, Value).
delete(Pool, Value) -> ets:delete(Pool, Value), ok.
values(Pool) -> [Value || {Value} <- ets:tab2list(Pool)].
draw(TC, Pool) ->
    Items = values(Pool), hegel:assume(Items =/= []),
    hegel:draw_silent(TC, hegel_gen:one_of([hegel_gen:constant(V) || V <- Items])).

in_property() ->
    try hegel:current_test_case() of _ -> true catch error:hegel_not_in_property -> false end.
%% The property may already have deleted the table itself.
delete_table(Pool) ->
    case ets:info(Pool, id) of undefined -> ok; _ -> ets:delete(Pool), ok end.
