-module(hegel_pool_tests).
-include_lib("eunit/include/eunit.hrl").

pool_is_deleted_with_its_test_case_test() ->
    #{status := passed} = hegel:run(fun(TC) ->
        Pool = hegel_pool:new(),
        hegel_pool:put(Pool, hegel:draw(TC, "x", hegel_gen:integer(0, 9))),
        case hegel:draw(TC, "delete", hegel_gen:boolean()) of
            true -> ets:delete(Pool);
            false -> ok
        end
    end, #{test_cases => 50, database => disabled}),
    ?assertEqual([], [T || T <- ets:all(), ets:info(T, name) =:= hegel_pool]).

pool_outside_property_is_kept_test() ->
    Pool = hegel_pool:new(),
    #{status := passed} = hegel:run(fun(_TC) -> ok end, #{test_cases => 1, database => disabled}),
    ?assertEqual(ok, hegel_pool:put(Pool, value)),
    true = ets:delete(Pool).
