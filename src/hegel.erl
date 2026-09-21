-module(hegel).
-export([check/1, check/2, run/1, run/2, reproduce/2, reproduce/3,
         draw/2, draw/3, draw_silent/2, current_test_case/0,
         assume/1, reject/0, note/1, note/2, event/1, event/2,
         target/1, target/2, on_cleanup/1]).

-define(TC_KEY, '$hegel_test_case').
-define(CLEANUP_KEY, '$hegel_cleanups').

check(Property) -> check(Property, #{}).
check(Property, Options) ->
    case run(Property, Options) of
        #{status := passed} -> ok;
        #{status := failed, failures := [Failure]} -> report_failure(Failure), raise_failure(Failure);
        #{status := failed, failures := Failures} ->
            lists:foreach(fun report_failure/1, Failures), error({hegel_multiple_failures, Failures});
        #{status := error, error := Reason} -> error({hegel_run_error, Reason})
    end.

run(Property) -> run(Property, #{}).
run(Property, Options0) when is_function(Property, 1), is_map(Options0) ->
    Options = defaults(Options0),
    {ok, Run} = hegel_native:run_start(
        atom_to_binary(maps:get(profile, Options)), maps:get(test_cases, Options),
        seed_value(maps:get(seed, Options)), maps:get(derandomize, Options),
        maps:get(report_multiple_failures, Options), maps:get(show_statistics, Options),
        maps:get(print_blob, Options), database_value(maps:get(database, Options))),
    Discovery = drive(Run, Property, []),
    finish(Run, Property, Options, Discovery).

reproduce(Property, Blob) -> reproduce(Property, Blob, #{}).
reproduce(Property, Blob, Options0) ->
    Options = defaults(Options0),
    {ok, TC} = replay_case(Blob, Options),
    Result = execute(Property, TC),
    _ = complete_result(TC, Result),
    case Result of
        {failed, Failure} -> raise_failure(Failure#{blob => Blob});
        _ -> error({hegel_stale_reproduction, Blob})
    end.

draw(TC, Generator) -> draw(TC, "value", Generator).
draw(TC, Name, Generator) ->
    Value = hegel_gen:run(Generator, TC),
    note(TC, [to_text(Name), " = ", hegel_gen:format(Generator, Value)]),
    Value.
draw_silent(TC, Generator) -> hegel_gen:run(Generator, TC).

current_test_case() ->
    case get(?TC_KEY) of undefined -> error(hegel_not_in_property); TC -> TC end.
assume(true) -> ok;
assume(false) -> throw(hegel_reject).
reject() -> throw(hegel_reject).
note(Text) -> note(current_test_case(), Text).
note(TC, Text) -> unwrap_unit(hegel_native:note(TC, iolist_to_binary(Text))).
event(Name) -> unwrap_unit(hegel_native:event(current_test_case(), iolist_to_binary(to_text(Name)))).
event(Name, Value) when is_number(Value) ->
    unwrap_unit(hegel_native:event_value(current_test_case(), iolist_to_binary(to_text(Name)), erlang:float(Value)));
event(Name, Value) -> event([to_text(Name), "=", io_lib:format("~tp", [Value])]).
target(Value) -> target("target", Value).
target(Name, Value) when is_number(Value) ->
    unwrap_unit(hegel_native:target(current_test_case(), iolist_to_binary(to_text(Name)), erlang:float(Value))).
on_cleanup(Fun) when is_function(Fun, 0) ->
    put(?CLEANUP_KEY, [Fun | case get(?CLEANUP_KEY) of undefined -> []; X -> X end]), ok.

defaults(Options) -> maps:merge(#{profile => default, test_cases => 100, seed => undefined,
    derandomize => false, database => default, report_multiple_failures => false,
    show_statistics => false, print_blob => true, verbosity => normal}, Options).

drive(Run, Property, Stash) ->
    case hegel_native:run_next(Run) of
        done -> Stash;
        {ok, TC} ->
            Result = execute(Property, TC), _ = complete_result(TC, Result),
            drive(Run, Property, case Result of {failed, F} -> [F | Stash]; _ -> Stash end);
        {error, Reason} -> error({hegel_native, Reason})
    end.

finish(Run, Property, Options, Discovery) ->
    case hegel_native:run_result(Run) of
        {passed, _} -> #{status => passed, failures => []};
        {error, Reason} -> #{status => error, error => Reason, failures => []};
        {failed_nondeterministic, _} ->
            #{status => failed, failures => lists:reverse(Discovery), nondeterministic => true};
        {failed, NativeFailures} ->
            #{status => failed,
              failures => [replay_failure(Property, Options, F) || F <- NativeFailures]}
    end.

replay_failure(Property, Options, #{origin := Origin, blob := Blob}) ->
    {ok, TC} = replay_case(Blob, Options),
    {ok, Printer} = hegel_native:open_printer(TC),
    Result = execute(Property, TC),
    Output = case hegel_native:printer_output(Printer) of
        {ok, Text} -> Text;
        {error, PrinterError} -> iolist_to_binary(io_lib:format("Unable to render draws: ~ts", [PrinterError]))
    end,
    _ = complete_result(TC, Result),
    case Result of
        {failed, Failure} -> Failure#{origin => Origin, blob => Blob, output => Output};
        _ -> #{class => error, reason => {hegel_flaky, Origin}, stacktrace => [],
               origin => Origin, blob => Blob}
    end.

replay_case(Blob, Options) ->
    hegel_native:case_from_blob(atom_to_binary(maps:get(profile, Options)), Blob,
        maps:get(test_cases, Options), seed_value(maps:get(seed, Options)),
        maps:get(derandomize, Options), maps:get(show_statistics, Options),
        maps:get(print_blob, Options), database_value(maps:get(database, Options))).

execute(Property, TC) ->
    put(?TC_KEY, TC), put(?CLEANUP_KEY, []),
    try Property(TC) of _ -> valid
    catch
        throw:hegel_reject -> invalid;
        throw:hegel_overrun -> overrun;
        Class:Reason:Stack ->
            {failed, #{class => Class, reason => Reason, stacktrace => Stack,
                       origin => failure_origin(Stack)}}
    after
        run_cleanups(get(?CLEANUP_KEY)), erase(?CLEANUP_KEY), erase(?TC_KEY)
    end.

complete_result(TC, valid) -> hegel_native:complete(TC, valid, <<>>);
complete_result(TC, invalid) -> hegel_native:complete(TC, invalid, <<>>);
complete_result(TC, overrun) -> hegel_native:complete(TC, overrun, <<>>);
complete_result(TC, {failed, #{origin := Origin}}) ->
    hegel_native:complete(TC, interesting, unicode:characters_to_binary(Origin)).

failure_origin([{Module, Function, Args, Info} | _]) ->
    File = proplists:get_value(file, Info, "unknown"), Line = proplists:get_value(line, Info, 0),
    io_lib:format("~s:~B ~p:~p/~p", [File, Line, Module, Function, arity(Args)]);
failure_origin([]) -> "unknown".
arity(Args) when is_list(Args) -> length(Args);
arity(N) -> N.
raise_failure(#{class := Class, reason := Reason, stacktrace := Stack}) ->
    erlang:raise(Class, Reason, Stack).
report_failure(#{output := <<>>}) -> ok;
report_failure(#{output := Output}) -> io:put_chars(standard_error, ["Property test failed:\n", Output, "\n"]);
report_failure(_) -> ok.
run_cleanups(undefined) -> ok;
run_cleanups(Funs) -> lists:foreach(fun(F) -> try F() catch _:_ -> ok end end, Funs).
unwrap_unit(ok) -> ok;
unwrap_unit(stop) -> throw(hegel_overrun);
unwrap_unit({error, Reason}) -> error({hegel_native, Reason}).
to_text(Value) when is_binary(Value); is_list(Value) -> Value;
to_text(Value) when is_atom(Value) -> atom_to_binary(Value);
to_text(Value) -> io_lib:format("~tp", [Value]).
database_value(default) -> <<"$default">>;
database_value(disabled) -> <<>>;
database_value(Path) -> iolist_to_binary(Path).
seed_value(undefined) -> nil;
seed_value(Seed) -> Seed.
