-module(hegel_printer_tests).
-include_lib("eunit/include/eunit.hrl").

%% Clones open deferred printer slots; the failure printer must resolve them.
concurrent_failure_renders_worker_draws_test() ->
    Rules = [#{name => "add", generate => hegel_gen:integer(0, 10),
               run => fun(_TC, N) when N > 5 -> error(too_big); (_TC, _N) -> ok end}],
    #{status := failed, failures := [#{reason := too_big, output := Output}]} =
        hegel:run(fun(TC) -> hegel_concurrent_stateful:run(TC, Rules) end,
                  #{test_cases => 50, database => disabled, seed => 1}),
    ?assertEqual(nomatch, string:find(Output, "Unable to render draws")),
    ?assertNotEqual(nomatch, string:find(Output, "add = ")).

failure_without_clones_renders_draws_test() ->
    #{status := failed, failures := [#{output := Output}]} =
        hegel:run(fun(TC) -> ?assert(hegel:draw(TC, "x", hegel_gen:integer(0, 100)) < 0) end,
                  #{test_cases => 10, database => disabled, seed => 7}),
    ?assertNotEqual(nomatch, string:find(Output, "x = ")).
