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
%--------------------------------------------------------------------
init([]) ->
    
    ok = init_schedulers_pool(),
    ok = run_remaining_tasks(),

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
%% init_schedulers_pool
%%--------------------------------------------------------------------
init_schedulers_pool() ->

    Queues = queuesk:queue_list(),
    [begin
	 queuesk_pool_sup:add_scheduler(Queue)
     end || Queue <- Queues],
    
    ok.

%%--------------------------------------------------------------------
%% run_remaining_tasks
%%--------------------------------------------------------------------
run_remaining_tasks() ->
    
    Queues = queuesk:queue_list(),
    [begin

	 QueueID = Queue#qsk_queue_registery.queue_id,
	 Acc = 0,
	 mnesia:activity(
	   transaction,
	   fun() -> 
		   mnesia:foldl(
		     fun(TaskRec, _) -> 
			     queuesk_pool_scheduler:submit_task(
			       QueueID, ?GENERIC_QUEUE_REC(TaskRec))
		     end, 
		     Acc, 
		     QueueID) 
	   end)
	     
     end || Queue <- Queues],
  
    ok.
