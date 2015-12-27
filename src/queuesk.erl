-module(queuesk).

-export([start/0, 
	 stop/0]).

-export([queue_add/2,
	 queue_remove/1,
	 queue_list/0,
	 queue_get/1,
	 queue_make_id/1,
	 queue_get_id/1]).

-export([task_push/3,
	 task_pop/1,
	 task_peek/1,
	 task_remove/2]).

-include("queuesk.hrl").

%%===================================================================
%% Queue API
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
%% queue_add
%%--------------------------------------------------------------------
queue_add(QueueName, Opts) 
  when is_atom(QueueName),
       is_list(Opts) ->
    
    %% @TODO: don't let use reserved names like 'registery', 'record' and 'failed_record'

    {ok, DefaultType} = queuesk_utils:get_config(default_queue_type),
    {ok, DefaultPersist} = queuesk_utils:get_config(default_queue_persist),
    {ok, DefaultSchedulers} = queuesk_utils:get_config(default_queue_schedulers),

    QueueID = queue_make_id(QueueName),
		
    NewOpts = [{queue_id, QueueID},
	       {type, proplists:get_value(type, Opts, DefaultType)},
	       {persist, proplists:get_value(persist, Opts, DefaultPersist)},
	       {schedulers, proplists:get_value(schedulers, Opts, DefaultSchedulers)}],

    do_queue_add(QueueName, NewOpts).

do_queue_add(QueueName, Opts) ->
    
    %% @TODO: make following action transactional and idempotent

    QueueID = proplists:get_value(queue_id, Opts),
    Type = proplists:get_value(type, Opts),
    Persist = proplists:get_value(persist, Opts),
    Schedulers = proplists:get_value(schedulers, Opts),
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
					       qsk_queue_schema)}]),

    case Result of
	{atomic, ok} ->
	    Queue = #qsk_queue_registery{
		       queue_id = QueueID,
		       queue_name = QueueName,
		       type = Type,
		       persist = Persist,
		       schedulers = Schedulers},

	    ok = mnesia:dirty_write(Queue),
	    {ok, _QueueSchedulerPID} = queuesk_pool_sup:add_scheduler(Queue),
	    
	    {ok, QueueID};
	Else ->
	    Else
    end.

%%--------------------------------------------------------------------
%% queue_remove
%%--------------------------------------------------------------------
queue_remove(QueueName) ->
    {ok, QueueID} = queue_get_id(QueueName),
    {atomic, ok} = mnesia:delete_table(QueueID),
    ok = mnesia:dirty_delete({qsk_queue_registery, QueueName}),
    ok.
    
%%--------------------------------------------------------------------
%% queue_get
%%--------------------------------------------------------------------
queue_get(QueueName) ->
    case mnesia:dirty_read({qsk_queue_registery, QueueName}) of
	[QueueRec] ->
	    {ok, QueueRec};
	[] ->
	    not_exist
    end.

%%--------------------------------------------------------------------
%% queue_get_id
%%--------------------------------------------------------------------
queue_get_id(QueueName) ->
    case queue_get(QueueName) of
	{ok, #qsk_queue_registery{queue_id = QueueID}} ->
	    {ok, QueueID};
	_ ->
	    not_exist
    end.

%%--------------------------------------------------------------------
%% queue_make_id
%%--------------------------------------------------------------------
queue_make_id(QueueName) ->
    {ok, QueueIDPrefix} = queuesk_utils:get_config(queue_id_prefix),    
    list_to_atom(
      atom_to_list(QueueIDPrefix)
      ++ "_"
      ++ atom_to_list(QueueName)).

%%--------------------------------------------------------------------
%% queue_list
%%--------------------------------------------------------------------
queue_list() ->
    mnesia:dirty_select(qsk_queue_registery, [{'_',[],['$_']}]).

%%===================================================================
%% Task API
%%===================================================================

%%--------------------------------------------------------------------
%% task_push
%%--------------------------------------------------------------------
task_push(QueueID, TaskFunc, Opts) ->

    %% @NOTE:
    %% TaskFunc must return ok if it's task was done
    %% correctly. Otherwise the scheduler will retry it.

    %% @TODO: add api for pushing MFAs (local or external),
    %% in addition to FUN terms for efficiency

    {ok, DefaultTaskPriority} = queuesk_utils:get_config(default_task_priority),
    {ok, DefaultTaskRetry} = queuesk_utils:get_config(default_task_retry),
    {ok, DefaultTaskTimeout} = queuesk_utils:get_config(default_task_timeout),

    TaskPriority = proplists:get_value(priority, Opts, DefaultTaskPriority),
    TaskRetry = proplists:get_value(retry, Opts, DefaultTaskRetry),
    TaskTimeout = proplists:get_value(timeout, Opts, DefaultTaskTimeout),

    TaskRec = #qsk_queue_record{priority = {TaskPriority, ?NOW_TIMESTAMP},
				retry = TaskRetry,
				timeout = TaskTimeout,
				task = TaskFunc,
				queue_id = QueueID},

    ok = mnesia:dirty_write(?SPECIFIC_QUEUE_REC(TaskRec)),
    ok = queuesk_pool_scheduler:submit_task(QueueID, TaskRec),
    ok.

%%--------------------------------------------------------------------
%% task_pop
%%--------------------------------------------------------------------
task_pop(QueueID) ->
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
%% task_peek
%%--------------------------------------------------------------------
task_peek(QueueID) ->
    Key = mnesia:dirty_first(QueueID),
    case mnesia:dirty_read(QueueID, Key) of
	[Rec] ->
	    Rec;
	[] ->
	    empy
    end.

%%--------------------------------------------------------------------
%% task_remove
%%--------------------------------------------------------------------
task_remove(QueueID, Key) ->
    mnesia:dirty_delete({QueueID, Key}).
