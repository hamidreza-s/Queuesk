-module(queuesk).

-export([start/0, 
	 stop/0]).

-export([add_queue/2,
	 remove_queue/1,
	 list_queues/0,
	 get_queue/1,
	 make_queue_id/1,
	 get_queue_id/1]).

-export([priority_push_task/3,
	 priority_pop_task/1,
	 priority_peek_task/1,
	 priority_remove_task/2]).

-include("queuesk.hrl").

%%===================================================================
%% API
%%===================================================================

%%--------------------------------------------------------------------
%% start
%%--------------------------------------------------------------------
start() ->
    application:start(?MODULE).

%%--------------------------------------------------------------------
%% stop
%%--------------------------------------------------------------------
stop() ->
    application:stop(?MODULE).

%%--------------------------------------------------------------------
%% add_queue
%%--------------------------------------------------------------------
add_queue(QueueName, Opts) 
  when is_atom(QueueName),
       is_list(Opts) ->
    
    {ok, DefaultType} = queuesk_utils:get_config(default_queue_type),
    {ok, DefaultPersist} = queuesk_utils:get_config(default_queue_persist),
    {ok, DefaultParallel} = queuesk_utils:get_config(default_queue_parallel),

    QueueID = make_queue_id(QueueName),
		
    NewOpts = [{queue_id, QueueID},
	       {type, proplists:get_value(type, Opts, DefaultType)},
	       {persist, proplists:get_value(persist, Opts, DefaultPersist)},
	       {parallel, proplists:get_value(parallel, Opts, DefaultParallel)}],

    do_add_queue(QueueName, NewOpts).

do_add_queue(QueueName, Opts) ->
    case proplists:get_value(type, Opts) of
	priority ->
	    add_priority_queue(QueueName, Opts);
	scheduler ->
	    todo;
	lifo ->
	    todo;
	fifi ->
	    todo
    end.

%%--------------------------------------------------------------------
%% remove_queue
%%--------------------------------------------------------------------
remove_queue(QueueName) ->
    {ok, QueueID} = get_queue_id(QueueName),
    {atomic, ok} = mnesia:delete_table(QueueID),
    ok = mnesia:dirty_delete({qsk_queue_registery, QueueName}),
    ok.
    
%%--------------------------------------------------------------------
%% get_queue
%%--------------------------------------------------------------------
get_queue(QueueName) ->
    case mnesia:dirty_read({qsk_queue_registery, QueueName}) of
	[QueueRec] ->
	    {ok, QueueRec};
	[] ->
	    not_exist
    end.

%%--------------------------------------------------------------------
%% get_queue_id
%%--------------------------------------------------------------------
get_queue_id(QueueName) ->
    case get_queue(QueueName) of
	{ok, #qsk_queue_registery{queue_id = QueueID}} ->
	    {ok, QueueID};
	_ ->
	    not_exist
    end.

%%--------------------------------------------------------------------
%% make_queue_id
%%--------------------------------------------------------------------
make_queue_id(QueueName) ->
    {ok, QueueIDPrefix} = queuesk_utils:get_config(queue_id_prefix),    
    list_to_atom(
      atom_to_list(QueueIDPrefix)
      ++ "_"
      ++ atom_to_list(QueueName)).

%%--------------------------------------------------------------------
%% list_queues
%%--------------------------------------------------------------------
list_queues() ->
    mnesia:dirty_select(qsk_queue_registery, [{'_',[],['$_']}]).

%%===================================================================
%% Priority Queue API
%%===================================================================

%%--------------------------------------------------------------------
%% add_priority_queue
%%--------------------------------------------------------------------
add_priority_queue(QueueName, Opts) ->
    
    QueueID = proplists:get_value(queue_id, Opts),
    Type = proplists:get_value(type, Opts),
    Persist = proplists:get_value(persist, Opts),
    Parallel = proplists:get_value(parallel, Opts),
    Storage = case proplists:get_value(persist, Opts) of
		  true ->
		      disc_copies;
		  false ->
		      ram_copies
	      end,
    
    Result = mnesia:create_table(QueueID, 
				 [{type, ordered_set},
				  {Storage, [node()]},
				  {attributes, 
				   record_info(fields, 
					       qsk_queue_priority_schema)}]),

    true = ets:insert(qsk_queue_info, #qsk_queue_info{
					 queue_id = QueueID,
					 parallel = Parallel,
					 empty = true}),
    
    case Result of
	{atomic, ok} ->
	    ok = mnesia:dirty_write(
		   #qsk_queue_registery{
		      queue_id = QueueID,
		      queue_name = QueueName,
		      type = Type,
		      persist = Persist,
		      parallel = Parallel}),
	    {ok, QueueID};
	Else ->
	    Else
    end.

%%--------------------------------------------------------------------
%% priority_push_task
%%--------------------------------------------------------------------
priority_push_task(QueueID, Priority, Task) ->
    Rec = #qsk_queue_priority_record{priority = {Priority, ?NOW_TIMESTAMP},
				     task = Task,
				     queue_id = QueueID},
    mnesia:dirty_write(?PRIORITY_REC(Rec)).

%%--------------------------------------------------------------------
%% priority_pop_task
%%--------------------------------------------------------------------
priority_pop_task(QueueID) ->
    Key = mnesia:dirty_first(QueueID),
    mnesia:activity(
      transaction,
      fun() ->
	      case mnesia:read(QueueID, Key) of
		  [Rec] ->
		      ok = mnesia:delete({QueueID, Key}),
		      Rec;
		  [] ->
		      empty
	      end
      end).

%%--------------------------------------------------------------------
%% priority_peek_task
%%--------------------------------------------------------------------
priority_peek_task(QueueID) ->
    Key = mnesia:dirty_first(QueueID),
    mnesia:dirty_read(QueueID, Key).

%%--------------------------------------------------------------------
%% priority_remove_task
%%--------------------------------------------------------------------
priority_remove_task(QueueID, Key) ->
    mnesia:dirty_delete({QueueID, Key}).
