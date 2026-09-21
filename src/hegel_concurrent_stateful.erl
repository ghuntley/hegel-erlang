-module(hegel_concurrent_stateful).
-export([run/2, run/3]).

%% Concurrent rules operate on shared external state (a process, ETS table,
%% socket, etc.). Each rule is #{generate => Gen, run => fun(TC, Command)}.
run(TC, Rules) -> run(TC, Rules, #{}).
run(TC, Rules, Options) when is_list(Rules), Rules =/= [], is_map(Options) ->
    Workers = maps:get(workers, Options, 2),
    Min = maps:get(min_steps, Options, 1),
    Max = maps:get(max_steps, Options, 10),
    Tasks = [hegel_process:spawn(TC, fun(Clone) -> worker(Clone, Rules, Min, Max) end)
             || _ <- lists:seq(1, Workers)],
    [hegel_process:await(Task) || Task <- Tasks].

worker(TC, Rules, Min, Max) ->
    Steps = hegel:draw_silent(TC, hegel_gen:integer(Min, Max)),
    lists:foreach(fun(_) ->
        Rule = hegel:draw_silent(TC, hegel_gen:one_of([hegel_gen:constant(R) || R <- Rules])),
        Generator = maps:get(generate, Rule),
        Command = hegel:draw(TC, maps:get(name, Rule, command), Generator),
        Run = maps:get(run, Rule),
        Run(TC, Command)
    end, lists:seq(1, Steps)).
