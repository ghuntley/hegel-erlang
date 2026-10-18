-module(hegel_run_tests).
-include_lib("eunit/include/eunit.hrl").

run_start_error_is_a_run_error_test() ->
    Options = #{profile => no_such_profile, test_cases => 1, database => disabled},
    ?assertMatch(#{status := error, error := _, failures := []},
                 hegel:run(fun(_TC) -> ok end, Options)),
    ?assertError({hegel_run_error, _}, hegel:check(fun(_TC) -> ok end, Options)).
