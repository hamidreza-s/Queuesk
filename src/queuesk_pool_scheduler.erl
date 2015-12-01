-module(queuesk_pool_scheduler).

-export([start_link/1,
	 init/2]).

-export([submit_task/2]).

-include("queuesk.hrl").

-record(state, {scheduler_ref, parent_pid, queue_rec}).

%%===================================================================
%% API
%%===================================================================

%%--------------------------------------------------------------------
%% start_link
%%--------------------------------------------------------------------
start_link(Queue) ->
    proc_lib:start_link(?MODULE, init, [self(), Queue]).

%%--------------------------------------------------------------------
%% init
%%--------------------------------------------------------------------
init(Parent, Queue) ->
    SchedulerRef = Queue#qsk_queue_registery.queue_id,
    register(SchedulerRef, self()),
    proc_lib:init_ack({ok, Parent}),    
    loop(#state{scheduler_ref = SchedulerRef, 
		parent_pid = Parent,
		queue_rec = Queue}).


%%--------------------------------------------------------------------
%% loop
%%--------------------------------------------------------------------
loop(State) ->
    receive
	{task, high_priority, Task} ->
	    ok = run_task(Task, State),
	    loop(State)
    after 0 ->
	    receive
		{task, med_priority, Task} ->
		    ok = run_task(Task, State),
		    loop(State)
	    after 0 ->
		    receive
			{task, low_priority, Task} ->
			    ok = run_task(Task, State),
			    loop(State)
		    end
	    end
    end.

%%--------------------------------------------------------------------
%% submit_task
%%--------------------------------------------------------------------
submit_task(SchedulerPid, #qsk_queue_record{priority = PriorityNum} = Task) ->
    
    %% @TODO: implement a shaper not to be got overflow

    PriorityAtom = 
	case PriorityNum of
	    1 -> high_priority;
	    2 -> med_priority;
	    _ -> low_priority
	end,
    SchedulerPid ! {task, PriorityAtom, Task},
    ok.
    
%%===================================================================
%% Internal Functions
%%===================================================================

%%--------------------------------------------------------------------
%% done_task
%%--------------------------------------------------------------------
done_task(QueueID, #qsk_queue_record{priority = TaskKey}) ->
    ok = queuesk:task_remove(QueueID, TaskKey).

%%--------------------------------------------------------------------
%% failed_task
%%--------------------------------------------------------------------
failed_task(QueueID, Task, Reason) ->
    ok = mnesia:dirty_write(#qsk_queue_failed_record{
			       queue_id = QueueID,
			       qsk_queue_record = Task,
			       time = now(),
			       reason = Reason}).

%%--------------------------------------------------------------------
%% run_task
%%--------------------------------------------------------------------
run_task(Task, State) ->

    ?DEBUG("queuesk_pool_scheduler:run_task:begin", []),

    QueueRec = State#state.queue_rec,
    QueueID = QueueRec#qsk_queue_registery.queue_id,
    TaskTimeout = Task#qsk_queue_record.timeout,
    TaskRetry = Task#qsk_queue_record.retry,

    {WorkerPID, WorkerRef} = spawn_monitor(fun() -> do_run_task(Task, State) end),
    
    receive
	{'DOWN', WorkerRef, process, WorkerPID, done} ->
	    ?DEBUG("queuesk_pool_scheduler:run_task:receive:done", []),
	    done_task(QueueID, Task),
	    ok;
	{'DOWN', WorkerRef, process, WorkerPID, Reason} ->
	    ?DEBUG("queuesk_pool_scheduler:run_task:receive:{~p}", [Reason]),
	    NewTaskRetry = TaskRetry - 1,
	    case NewTaskRetry > 0 of
		true ->
		    NewTask = Task#qsk_queue_record{retry = NewTaskRetry},
		    ?DEBUG("queuesk_pool_scheduler:run_task:receive:{~p}:retry", 
			   [Reason]),
		    submit_task(QueueID, NewTask),
		    ok;
		false ->
		    failed_task(QueueID, Task, {error, Reason}),
		    ?DEBUG("queuesk_pool_scheduler:run_task:receive:{~p}:dont_retry", 
			   [Reason]),
		    ok
	    end
    after TaskTimeout ->
	    ?DEBUG("queuesk_pool_scheduler:run_task:timeout", []),
	    erlang:demonitor(WorkerRef, [flush]),
	    exit(WorkerPID, kill),
	    NewTaskRetry = TaskRetry - 1,
	    case NewTaskRetry > 0 of
		true ->
		    NewTask = Task#qsk_queue_record{retry = NewTaskRetry},
		    ?DEBUG("queuesk_pool_scheduler:run_task:timeout:retry", []),
		    submit_task(QueueID, NewTask),
		    ok;
		false ->
		    failed_task(QueueID, Task, timeout),
		    ?DEBUG("queuesk_pool_scheduler:run_task:timeout:dont_retry", []),
		    ok
	    end

    end.

%%--------------------------------------------------------------------
%% do_run_task (quarantine)
%%--------------------------------------------------------------------
do_run_task(Task, _State) ->
    ?DEBUG("queuesk_pool_scheduler:do_run_task:begin", []),
    TaskFunc = Task#qsk_queue_record.task,
    case apply(TaskFunc, []) of
    	ok ->
    	    ?DEBUG("queuesk_pool_scheduler:do_run_task:exit:ok", []),
    	    exit(done);
    	Reason ->
    	    ?DEBUG("queuesk_pool_scheduler:do_run_task:exit:{~p}", [Reason]),
    	    exit(Reason)
    end.
