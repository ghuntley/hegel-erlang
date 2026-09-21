-module(hegel_gen).
-export([boolean/0, boolean/1, integer/0, integer/2, float/0, float/2,
         binary/0, binary/2, utf8/0, utf8/2, constant/1, one_of/1,
         frequency/1, list/1, list/3, tuple/1, map/1, bind/2, map/2,
         filter/2, custom/2, sample/2, run/2, format/2]).
-export_type([t/1]).

-record(gen, {run, format}).
-opaque t(A) :: #gen{run :: fun((term()) -> A), format :: fun((string(), list()) -> iodata())}.

boolean() -> boolean(0.5).
boolean(P) when is_float(P), P >= 0.0, P =< 1.0 ->
    custom(fun(TC) -> unwrap(hegel_native:boolean(TC, P)) end, fun fmt/2).
integer() -> integer(-1000000, 1000000).
integer(Min, Max) when is_integer(Min), is_integer(Max), Min =< Max ->
    custom(fun(TC) -> unwrap(hegel_native:integer(TC, Min, Max)) end, fun fmt/2).
float() -> float(-1.0e6, 1.0e6).
float(Min, Max) when is_number(Min), is_number(Max), Min =< Max ->
    custom(fun(TC) -> unwrap(hegel_native:float(TC, erlang:float(Min), erlang:float(Max))) end, fun fmt/2).
binary() -> binary(0, 64).
binary(Min, Max) when is_integer(Min), is_integer(Max), 0 =< Min, Min =< Max ->
    custom(fun(TC) -> unwrap(hegel_native:bytes(TC, Min, Max)) end, fun fmt/2).
utf8() -> utf8(0, 64).
utf8(Min, Max) -> map(fun(Bin) -> << <<(32 + (B rem 95))/utf8>> || <<B>> <= Bin >> end,
                       binary(Min, Max)).
constant(Value) -> custom(fun(_TC) -> Value end, fun fmt/2).
one_of([]) -> error(badarg);
one_of(Generators) -> bind(integer(1, length(Generators)), fun(I) -> lists:nth(I, Generators) end).
frequency(Weighted) when is_list(Weighted), Weighted =/= [] ->
    Total = lists:sum([Weight || {Weight, _} <- Weighted]),
    bind(integer(1, Total), fun(N) -> choose_weighted(N, Weighted) end).
list(Generator) -> list(Generator, 0, 16).
list(Generator, Min, Max) -> bind(integer(Min, Max), fun(Len) ->
    custom(fun(TC) -> [run(Generator, TC) || _ <- lists:seq(1, Len)] end, fun fmt/2)
end).
tuple(Generators) when is_list(Generators) ->
    custom(fun(TC) -> list_to_tuple([run(G, TC) || G <- Generators]) end, fun fmt/2).
map(Fields) when is_map(Fields) ->
    custom(fun(TC) -> maps:map(fun(_K, G) -> run(G, TC) end, Fields) end, fun fmt/2).
map(Fun, Generator) when is_function(Fun, 1) ->
    custom(fun(TC) -> Fun(run(Generator, TC)) end, fun fmt/2).
bind(Generator, Fun) when is_function(Fun, 1) ->
    custom(fun(TC) -> run(Fun(run(Generator, TC)), TC) end, fun fmt/2).
filter(Predicate, Generator) when is_function(Predicate, 1) ->
    custom(fun(TC) -> filter_loop(Predicate, Generator, TC, 100) end, fun fmt/2).
custom(Run, Formatter) when is_function(Run, 1), is_function(Formatter, 2) ->
    #gen{run = Run, format = Formatter}.
run(#gen{run = Run}, TC) -> Run(TC).
format(#gen{format = Formatter}, Value) -> Formatter("~tp", [Value]).
sample(Generator, Count) when is_integer(Count), Count > 0 ->
    hegel:run(fun(TC) -> hegel:note(TC, io_lib:format("~tp", [run(Generator, TC)])) end,
              #{test_cases => Count, database => disabled}).

filter_loop(_Predicate, _Generator, _TC, 0) -> throw(hegel_reject);
filter_loop(Predicate, Generator, TC, Left) ->
    Value = run(Generator, TC),
    case Predicate(Value) of true -> Value; false -> filter_loop(Predicate, Generator, TC, Left - 1) end.
choose_weighted(N, [{Weight, Generator} | _]) when N =< Weight -> Generator;
choose_weighted(N, [{Weight, _} | Rest]) -> choose_weighted(N - Weight, Rest).
unwrap({ok, Value}) -> Value;
unwrap(stop) -> throw(hegel_overrun);
unwrap({error, Reason}) -> error({hegel_native, Reason}).
fmt(Format, Args) -> io_lib:format(Format, Args).
