-module(queuesk_manager).
-behaviour(gen_server).

-export([start_link/0]).

-export([init/1,
	 handle_call/3,
	 handle_cast/2,
	 handle_info/2,
	 terminate/2,
	 code_change/3]).

-include("queuesk.hrl").

%%===================================================================
%% API Functions 
%%===================================================================

%%--------------------------------------------------------------------
%% start_link
%%--------------------------------------------------------------------
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%%====================================================================
%% Generic Server Callback
%%====================================================================

%%--------------------------------------------------------------------
%% init
%%--------------------------------------------------------------------
init([]) ->
    

    ok = init_workers_pool(),
    ok = init_queue_info(),

    {ok, undefined}.

%%--------------------------------------------------------------------
%% handle_call
%%--------------------------------------------------------------------
handle_call(_Msg, _From, State) ->
    {reply, ok, State}.

%%--------------------------------------------------------------------
%% handle_cast
%%--------------------------------------------------------------------
handle_cast(_Msg, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% handle_info
%%--------------------------------------------------------------------
handle_info(_Msg, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% terminate
%%--------------------------------------------------------------------
terminate(_Reason, _State) ->
    ok.
%%--------------------------------------------------------------------
%% code_change
%%--------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%====================================================================
%% Internal Functions
%%====================================================================

%%--------------------------------------------------------------------
%% init_workers_pool
%%--------------------------------------------------------------------
init_workers_pool() ->
    {ok, WorkerPool} = queuesk_utils:get_config(pool_workers_number),
    [queuesk_pool_sup:add_worker() || _ <- lists:seq(1, WorkerPool)],
    
    ok.

%%--------------------------------------------------------------------
%% init_queue_info
%%--------------------------------------------------------------------
init_queue_info() ->
    Queues = queuesk:list_queues(),
    [begin
	 ID = Queue#qsk_queue_registery.queue_id,
	 Parallel = Queue#qsk_queue_registery.parallel,
	 Empty = case mnesia:table_info(ID, size) of
		     0 ->
			 true;
		     _ ->
			 false
		 end,

	 ets:insert(qsk_queue_info,
		    #qsk_queue_info{queue_id = ID,
				    parallel = Parallel,
				    empty = Empty})
     end || Queue <- Queues],

    ok.
