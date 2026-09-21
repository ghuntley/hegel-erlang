-module(hegel_erlang_example_tests).
-include_lib("eunit/include/eunit.hrl").

reverse_property_test() ->
    ?assertEqual(ok, hegel_erlang_example:reverse_property()).
