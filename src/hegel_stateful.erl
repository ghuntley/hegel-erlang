-module(hegel_stateful).
-export([run/3, run/4]).

%% A rule is a map containing generate, run, and optionally precondition/name:
%% #{generate => Generator | fun((State) -> Generator),
%%   run => fun((TestCase, State, Command) -> NewState)}.
run(TC, InitialState, Rules) -> run(TC, InitialState, Rules, #{}).
run(TC, InitialState, Rules, Options) when is_list(Rules), is_map(Options) ->
    Min = maps:get(min_steps, Options, 1), Max = maps:get(max_steps, Options, 20),
    Steps = hegel:draw_silent(TC, hegel_gen:integer(Min, Max)),
    run_steps(TC, InitialState, Rules, Steps).

run_steps(_TC, State, _Rules, 0) -> State;
run_steps(TC, State, Rules, Left) ->
    Available = [R || R <- Rules, applicable(R, State)],
    hegel:assume(Available =/= []),
    Rule = hegel:draw_silent(TC, hegel_gen:one_of([hegel_gen:constant(R) || R <- Available])),
    Generator = case maps:get(generate, Rule) of F when is_function(F, 1) -> F(State); G -> G end,
    Command = hegel:draw(TC, maps:get(name, Rule, command), Generator),
    Run = maps:get(run, Rule),
    Next = Run(TC, State, Command),
    run_steps(TC, Next, Rules, Left - 1).

applicable(Rule, State) ->
    case maps:get(precondition, Rule, fun(_) -> true end) of F -> F(State) end.
