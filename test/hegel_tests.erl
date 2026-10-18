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

%% A deliberately unstable property fails discovery and passes the engine's
%% replay. This exercises the real native Flaky error rather than mocking it.
flaky_run_preserves_discovery_test() ->
    Property = flaky_property(),
    Result = hegel:run(Property, #{test_cases => 10, database => disabled, seed => 7}),
    ?assertMatch(#{status := error, error := _,
                  failures := [#{class := error, reason := original_flaky_failure,
                                 stacktrace := [_ | _]} | _]}, Result),
    #{failures := Failures} = Result,
    ?assert(lists:all(fun(F) -> not maps:is_key(blob, F) andalso
                               not maps:is_key(output, F) end, Failures)).

flaky_check_preserves_native_and_beam_error_test() ->
    Property = flaky_property(),
    try hegel:check(Property, #{test_cases => 10, database => disabled, seed => 7}) of
        _ -> ?assert(false)
    catch
        error:{hegel_run_error, _NativeReason, [First | _]}:Stack ->
            ?assertMatch(#{class := error, reason := original_flaky_failure}, First),
            ?assertEqual(maps:get(stacktrace, First), Stack)
    end.

-spec flaky_property() -> fun((term()) -> ok).
flaky_property() ->
    Counter = atomics:new(1, []),
    fun(TC) ->
        _ = hegel:draw(TC, "value", hegel_gen:integer(0, 1000000)),
        case atomics:add_get(Counter, 1, 1) of
            1 -> erlang:error(original_flaky_failure);
            _ -> ok
        end
    end.

oversized_binary_is_an_error_not_an_abort_test() ->
    Size = 1 bsl 64 - 1,
    ?assertMatch(#{status := passed},
        hegel:run(fun(TC) ->
            ?assertError({hegel_native, _}, hegel:draw(TC, "b", hegel_gen:binary(Size, Size)))
        end, #{test_cases => 1, database => disabled})).
