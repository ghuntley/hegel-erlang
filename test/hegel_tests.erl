-module(hegel_tests).
-include_lib("eunit/include/eunit.hrl").

passing_property_test() ->
    ?assertEqual(#{status => passed, failures => []},
        hegel:run(fun(TC) ->
            X = hegel:draw(TC, "x", hegel_gen:integer(-10, 10)),
            ?assert(is_integer(X))
        end, #{test_cases => 10, database => disabled})).

failure_is_structured_test() ->
    Result = hegel:run(fun(TC) ->
        X = hegel:draw(TC, "x", hegel_gen:integer(0, 100)),
        ?assert(X < 0)
    end, #{test_cases => 10, database => disabled, seed => 7}),
    ?assertMatch(#{status := failed, failures := [#{class := error, blob := _}]}, Result).

check_preserves_exception_test() ->
    ?assertException(error, original_failure,
        hegel:check(fun(TC) ->
            _ = hegel:draw(TC, "x", hegel_gen:integer(0, 10)),
            erlang:error(original_failure)
        end, #{test_cases => 5, database => disabled, seed => 9})).
