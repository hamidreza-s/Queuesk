-module(queuesk_app).
-behaviour(application).

-export([start/2, 
	 stop/1]).

-include("queuesk.hrl").

%%===================================================================
%% Application callbacks
%%===================================================================

%%--------------------------------------------------------------------
%% start
%%--------------------------------------------------------------------
start(_StartType, _StartArgs) ->
    
    ok = init_database(),

    queuesk_sup:start_link().

%%--------------------------------------------------------------------
%% stop
%%--------------------------------------------------------------------
stop(_State) ->
    ok.

%%===================================================================
%% Internals
%%===================================================================

%%--------------------------------------------------------------------
%% init_database
%%--------------------------------------------------------------------
init_database() ->
    case mnesia:create_schema([node()]) of
	ok ->
	    ok;
	{error, {_, {already_exists, _}}} ->
	    ok
    end,

    mnesia:start(),
    
    mnesia:create_table(qsk_queue_registery, 
			[{type, ordered_set},
			 {disc_copies, [node()]},
			 {attributes, record_info(fields, qsk_queue_registery)}]),

    ets:new(qsk_queue_info, [set, public, named_table,
			     {keypos, 2},
			     {write_concurrency, false},
			     {read_concurrency, true}]),

    ok.
