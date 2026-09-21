-module(hegel_gleam_ffi).
-export([check/1, reproduce/2, draw/3, reject/0, note/1, event/2, target/2]).

check(Property) -> hegel:check(Property).
reproduce(Property, Blob) -> hegel:reproduce(Property, Blob).
draw(TC, Name, Generator) -> hegel:draw(TC, Name, Generator).
reject() -> hegel:reject().
note(Value) -> hegel:note(io_lib:format("~tp", [Value])).
event(Name, Value) -> hegel:event(Name, Value).
target(Name, Value) -> hegel:target(Name, Value).
