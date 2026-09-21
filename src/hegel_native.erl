-module(hegel_native).
-on_load(init/0).
-export([init/0, version/0, run_start/8, run_next/1, run_result/1,
         case_from_blob/8, complete/3, clone_case/1,
         boolean/2, integer/3, float/3, bytes/3, note/2, open_printer/1, printer_output/1,
         event/2, event_value/3, target/3]).

init() -> load_first(candidate_paths()).

candidate_paths() ->
    Override = case os:getenv("HEGEL_NIF_PATH") of false -> []; P -> [P] end,
    Priv = case code:priv_dir(hegel) of
        {error, _} -> [];
        Dir -> [filename:join(Dir, "hegel_nif"), filename:join([Dir, "native", platform(), "hegel_nif"])]
    end,
    Beam = code:which(?MODULE),
    {ok, Cwd} = file:get_cwd(),
    Override ++ Priv ++ native_paths(Cwd) ++ native_paths(filename:dirname(Beam)).

native_paths(Path) -> native_paths(filename:absname(Path), 8, []).
native_paths(_Path, 0, Acc) -> Acc;
native_paths(Path, Left, Acc) ->
    Parent = filename:dirname(Path),
    Here = [filename:join([Path, "native", "hegel_nif", "target", "release", "libhegel_nif"]),
            filename:join([Path, "native", "hegel_nif", "target", "debug", "libhegel_nif"])],
    case Parent =:= Path of true -> Here ++ Acc; false -> native_paths(Parent, Left - 1, Here ++ Acc) end.

platform() ->
    Arch = case erlang:system_info(system_architecture) of
        Value when is_list(Value) ->
            case lists:prefix("aarch64", Value) of true -> "arm64"; false -> "amd64" end
    end,
    case os:type() of
        {unix, darwin} -> "macos-" ++ Arch;
        {unix, _} -> "linux-" ++ Arch ++ "-gnu";
        {win32, _} -> "windows-" ++ Arch ++ "-msvc"
    end.

load_first([]) -> {error, {load_failed, "set HEGEL_NIF_PATH or run `just native`"}};
load_first([Path | Rest]) ->
    case erlang:load_nif(Path, 0) of ok -> ok; {error, _} -> load_first(Rest) end.

nif_error() -> erlang:nif_error({nif_not_loaded, ?MODULE}).
version() -> nif_error().
run_start(_, _, _, _, _, _, _, _) -> nif_error().
run_next(_) -> nif_error().
run_result(_) -> nif_error().
case_from_blob(_, _, _, _, _, _, _, _) -> nif_error().
complete(_, _, _) -> nif_error().
clone_case(_) -> nif_error().
boolean(_, _) -> nif_error().
integer(_, _, _) -> nif_error().
float(_, _, _) -> nif_error().
bytes(_, _, _) -> nif_error().
note(_, _) -> nif_error().
open_printer(_) -> nif_error().
printer_output(_) -> nif_error().
event(_, _) -> nif_error().
event_value(_, _, _) -> nif_error().
target(_, _, _) -> nif_error().
