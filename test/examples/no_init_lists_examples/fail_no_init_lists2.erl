-module(fail_no_init_lists2).

-behaviour(gen_server).

-export([start_link/1, init/1, handle_cast/2, handle_call/3]).

start_link(AParam) ->
  gen_server:start_link(?MODULE, AParam, []).

init(_A = [1, 2, 3]) ->
  ok.

handle_cast(_, _) -> ok.

handle_call(_, _, _) -> ok.
