-module(hegel_process).
-export([spawn/2, await/1]).
spawn(TC, Fun) when is_function(Fun, 1) ->
    {ok, Clone} = hegel_native:clone_case(TC), Parent = self(),
    erlang:spawn_monitor(fun() -> Parent ! {hegel_process, self(), execute(Fun, Clone)} end).
await({Pid, Ref}) -> receive
    {hegel_process, Pid, Result} -> erlang:demonitor(Ref, [flush]),
        case Result of {ok, V} -> V; {raise, C, R, S} -> erlang:raise(C, R, S) end;
    {'DOWN', Ref, process, Pid, Reason} -> exit(Reason)
end.
execute(Fun, TC) -> try {ok, Fun(TC)} catch C:R:S -> {raise, C, R, S} end.
