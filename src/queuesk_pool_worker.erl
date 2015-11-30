-module(queuesk_pool_worker).

-export([start_link/1,
	 init/2]).

-export([submit_task/2]).

-include("queuesk.hrl").

-record(state, {worker_ref, parent_pid, queue_rec}).

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
    proc_lib:init_ack({ok, Parent}),    
    WorkerRef = Queue#qsk_queue_registery.queue_id,
    register(WorkerRef, self()),
    loop(#state{worker_ref = WorkerRef, 
		parent_pid = Parent,
		queue_rec = Queue}).


%%--------------------------------------------------------------------
%% loop
%%--------------------------------------------------------------------
loop(State) ->
    receive
	{high_priority, Task} ->
	    ok = run_task(Task, State),
	    loop(State)
    after 0 ->
	    receive
		{med_priority, Task} ->
		    ok = run_task(Task, State),
		    loop(State)
	    after 0 ->
		    receive
			{low_priority, Task} ->
			    ok = run_task(Task, State),
			    loop(State)
		    end
	    end
    end.

%%--------------------------------------------------------------------
%% submit_task
%%--------------------------------------------------------------------
submit_task(WorkerPid, #qsk_queue_record{priority = PriorityNum} = Task) ->
    
    %% @TODO: implement a shaper not to be got overflow

    PriorityAtom = 
	case PriorityNum of
	    1 -> high_priority;
	    2 -> med_priority;
	    _ -> low_priority
	end,
    WorkerPid ! {PriorityAtom, Task},
    ok.
    
%%===================================================================
%% Internal Functions
%%===================================================================

%%--------------------------------------------------------------------
%% run_task
%%--------------------------------------------------------------------
run_task(Task, State) ->
    QueueRec = State#state.queue_rec,
    QueueID = QueueRec#qsk_queue_registery.queue_id,
    TaskKey = Task#qsk_queue_record.priority,
    TaskFunc = Task#qsk_queue_record.task,
    
    case apply(TaskFunc, []) of
	ok ->
	    queuesk:task_remove(QueueID, TaskKey),
	    ok;
	Else ->
	    %% @TODO: log it somewhere and notify someone
	    ok
    end.
