-module(queuesk_SUITE).

-include_lib("common_test/include/ct.hrl").
-include_lib("eunit/include/eunit.hrl").

-include("queuesk.hrl").

-compile(export_all).

-define(SELF, ct_running_process).

%%====================================================================
%% CT Callbacks
%%====================================================================

%%--------------------------------------------------------------------
%% suite | groups | all
%%--------------------------------------------------------------------
suite() -> [{timetrap, {seconds, 60*60}}].

groups() -> [].

all() ->
    [test_queue_api,
     test_task_api].

%%--------------------------------------------------------------------
%% init_per_suite | end_per_suite
%%--------------------------------------------------------------------
init_per_suite(Config) ->
    application:start(queuesk),
    Config.

end_per_suite(_Config) ->
    application:stop(queuesk),
    ok.

%%--------------------------------------------------------------------
%% init_per_group | end_per_group
%%--------------------------------------------------------------------
init_per_group(_group, Config) ->
    Config.

end_per_group(_group, Config) ->
    Config.

%%--------------------------------------------------------------------
%% init_per_testcase | end_per_testcase
%%--------------------------------------------------------------------
init_per_testcase(_TestCase, Config) ->
    register(?SELF, self()),
    Config.

end_per_testcase(_TestCase, Config) ->
    unregister(?SELF),
    Config.

%%====================================================================
%% Test Cases
%%====================================================================

%%--------------------------------------------------------------------
%% test_queue_api
%%--------------------------------------------------------------------
test_queue_api(_Config) ->

    %%----------------------------------------------------------------
    %% add and get queue
    %%----------------------------------------------------------------

    ?assertEqual({ok, qsk_queue_test1},
		 queuesk:queue_add(test1, [])),
    
    ?assertEqual({ok, #qsk_queue_registery{queue_name = test1, 
					   queue_id = qsk_queue_test1, 
					   type = priority,
					   persist = false,
					   schedulers = 1}},
		 queuesk:queue_get(test1)),

    ?assertEqual({ok, qsk_queue_test2},
		 queuesk:queue_add(test2, [{persist, false}])),

    ?assertEqual({ok, #qsk_queue_registery{queue_name = test2,
					   queue_id = qsk_queue_test2, 
					   type = priority,
					   persist = false,
					   schedulers = 1}},
		 queuesk:queue_get(test2)),

    ?assertEqual({ok, qsk_queue_test3},
		 queuesk:queue_add(test3, [{persist, true}])),

    ?assertEqual({ok, #qsk_queue_registery{queue_name = test3, 
					   queue_id = qsk_queue_test3, 
					   type = priority,
					   persist = true,
					   schedulers = 1}},
		 queuesk:queue_get(test3)),

    %%----------------------------------------------------------------
    %% get queue id
    %%----------------------------------------------------------------

    ?assertEqual({ok, qsk_queue_test1}, queuesk:queue_get_id(test1)),

    %%----------------------------------------------------------------
    %% list queues
    %%----------------------------------------------------------------

    ?assertEqual([#qsk_queue_registery{queue_name = test1, 
				       queue_id = qsk_queue_test1, 
				       type = priority,
				       persist = false,
				       schedulers = 1},
		  #qsk_queue_registery{queue_name = test2, 
				       queue_id = qsk_queue_test2, 
				       type = priority,
				       persist = false,
				       schedulers = 1},
		  #qsk_queue_registery{queue_name = test3, 
				       queue_id = qsk_queue_test3, 
				       type = priority,
				       persist = true,
				       schedulers = 1}],
		 queuesk:queue_list()),

    %%----------------------------------------------------------------
    %% remove queue
    %%----------------------------------------------------------------

    ?assertEqual(ok, queuesk:queue_remove(test1)),

    ?assertEqual(not_exist, queuesk:queue_get(test1)),

    ?assertEqual([#qsk_queue_registery{queue_name = test2, 
				       queue_id = qsk_queue_test2, 
				       type = priority,
				       persist = false,
				       schedulers = 1},
		  #qsk_queue_registery{queue_name = test3, 
				       queue_id = qsk_queue_test3, 
				       type = priority,
				       persist = true,
				       schedulers = 1}],
		 queuesk:queue_list()),

    ok.

%%--------------------------------------------------------------------
%% test_task_api
%%--------------------------------------------------------------------
test_task_api(_Config) ->

    %%----------------------------------------------------------------
    %% push task
    %%----------------------------------------------------------------

    ?assertEqual({ok, qsk_queue_test4},
    		 queuesk:queue_add(test4, [])),
    
    Self = self(),
    TasksNumber = 2,

    lists:foreach(fun(_) ->
    			  ?assertEqual(ok, 
    				       queuesk:task_push(qsk_queue_test4,
    							 fun() -> Self ! task, ok end,
    							 [{priority, 1}, {retry, 3}, 
    							  {timeout, 3000}]))
    		  end,
    		  lists:seq(1, TasksNumber)),

    ?assertEqual(ok, count_done_tasks(TasksNumber)),

    ok.

%%====================================================================
%% Controlling functions
%%====================================================================

%%--------------------------------------------------------------------
%% count done tasks
%%--------------------------------------------------------------------
count_done_tasks(Number)
  when Number > 0 ->
    receive
	task ->
	    count_done_tasks(Number - 1)
    end;
count_done_tasks(_) ->
    ok.

%%--------------------------------------------------------------------
%% pause
%%--------------------------------------------------------------------
pause() ->
    receive
	stop ->
	    ok
    end.

%%--------------------------------------------------------------------
%% next
%%--------------------------------------------------------------------
next() ->
    catch ?SELF ! stop,
    ok.
