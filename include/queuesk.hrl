%%===================================================================
%% Records
%%===================================================================

%%--------------------------------------------------------------------
%% qsk_queue_registery
%%--------------------------------------------------------------------
-record(qsk_queue_registery, {queue_name, queue_id, type, persist, schedulers}).

%%--------------------------------------------------------------------
%% qsk_queue_schema
%%--------------------------------------------------------------------
-record(qsk_queue_schema, {priority, task, retry, timeout}).

%%--------------------------------------------------------------------
%% qsk_queue_record
%%--------------------------------------------------------------------
-record(qsk_queue_record, {priority, task, retry, timeout, queue_id}).

%%--------------------------------------------------------------------
%% qsk_queue_failed_record
%%--------------------------------------------------------------------
-record(qsk_queue_failed_record, {queue_id, qsk_queue_record, reason, time}).

%%===================================================================
%% Macros
%%===================================================================

%%--------------------------------------------------------------------
%% specific queue record
%%--------------------------------------------------------------------
-define(SPECIFIC_QUEUE_REC(Rec), {Rec#qsk_queue_record.queue_id,
				  Rec#qsk_queue_record.priority,
				  Rec#qsk_queue_record.task,
				  Rec#qsk_queue_record.retry,
				  Rec#qsk_queue_record.timeout}).

%%--------------------------------------------------------------------
%% generic queue record
%%--------------------------------------------------------------------
-define(GENERIC_QUEUE_REC(Rec), 
	begin 
	    {QueueID, Priority, Task, Retry, Timeout} = Rec,
	    #qsk_queue_record{priority = Priority,
			      task = Task, 
			      retry = Retry, 
			      timeout = Timeout,
			      queue_id = QueueID}
	end).

%%--------------------------------------------------------------------
%% supervisor child
%%--------------------------------------------------------------------
-define(SUPERVISOR_CHILD(I, Type), {I, {I, start_link, []}, permanent, 
				    5000, Type, [I]}).

%%--------------------------------------------------------------------
%% now timestamp
%%--------------------------------------------------------------------
-define(NOW_TIMESTAMP, now()).

%%--------------------------------------------------------------------
%% debug
%%--------------------------------------------------------------------
-define(DEBUG(String, Args), begin
				 case queuesk_utils:get_config(mode) of
				     {ok, development} ->
					 error_logger:info_msg(String ++ "~n", Args);
				     _ ->
					 dont
				 end
			     end).
