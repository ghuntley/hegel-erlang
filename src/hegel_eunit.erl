-module(hegel_eunit).
-export([property/1, property/2]).
property(Fun) -> property(Fun, #{}).
property(Fun, Options) -> fun() -> hegel:check(Fun, Options) end.
