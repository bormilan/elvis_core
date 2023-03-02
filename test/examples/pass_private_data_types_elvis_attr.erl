-module(pass_private_data_types_elvis_attr).
-elvis([{elvis_style, private_data_types, #{apply_to => [record, tuple]}}]).

-record(my_rec, {a :: integer(), b :: integer(), c :: integer()}).

-type my_rec() :: #my_rec{}.
-type my_tuple() :: {bitstring(), bitstring()}.
-type my_map() :: map().

-export([hello/0]).

-spec hello() -> ok.
hello() ->
    my_fun(#my_rec{a = 1, b = 2, c = 3}, {<<"hello">>, <<"world">>}, #{a => 1}).

-spec my_fun(my_rec(), my_tuple(), my_map()) -> ok.
my_fun(_Rec, _Tup, _Map) -> ok.
