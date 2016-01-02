Queuesk
======

Queuesk (pronounce it like kiosk /ˈkiːɑːsk/) is a lightweight priority task queue which can be used inside your Erlang application as a dependency. The order of executing tasks is based on their priority levels. Also you can set timeout and a number for retrying the tasks which would fail or crash when executing. Each queue's tasks can be durable or not durable after restart.

Quick Start
----

**Installation**

On a machine with an installed Erlang/OTP R15 or newer, just clone this repo and go through following steps:

```bash
$ git clone https://github.com/bisphone/Queuesk.git
$ cd Queuesk
$ make
```

Also for using it as a dependency in your project using `rebar`, add the following code snippet to your `rebar.config` file:

```erlang
{deps, [
        %% ...
        {queuesk, ".*", {git, "git://github.com/bisphone/queuesk.git", {branch, "master"}}}
       ]}.
```

**Usage**

Let's imagine we need a task queue for newly registered users in our website for doing some tasks after their registration. First we must create the queue, and because the tasks are not trivial to us, we make the queue persistent.

```erlang
{ok, QueueID} = queuesk:queue_add(new_users, [{persist, true}]).
```

In this scenario each user must receive a welcome email and also her friends must be notified about her registration. Because sending welcome email has more priority, we set its priority higher.

```erlang
ok = queuesk:task_push(QueueID,
                       fun() -> send_welcome_email() end, 
                       [{priority, 1}, {retry, 3}, {timeout, 3000}]),
ok = queuesk:task_push(QueueID,
                       fun() -> send_notification() end, 
                       [{priority, 2}, {retry, 2}, {timeout, 3000}])
```

The retry and timeout parameters help to tailor each task to the needs and restrictions of our usecases.

Configuration
----

There are some default configuration which you can change based on your needs as follows:

```erlang
{mode, development},
{queue_id_prefix, qsk_queue},
{default_queue_type, priority},
{default_queue_persist, false},
{default_queue_schedulers, 1},
{default_task_priority, 1},
{default_task_retry, 1},
{default_task_timeout, 3000}
```

These config parameters resides in `src/queuesk.app.src` file.

API
----

The main APIs are exported via `queuesk` module as follows:

**Types**

```erlang
-type queue_opts() :: {persist, true | false}.
-type task_id() :: {integer(), erlang:timestamp()}.
-type task_opts() :: {priority, integer()} | {retry, integer()} | {timeout, integer()}.
-type task_func() :: (fun() -> nok | ok).
```

**Queue API**

```erlang
-spec queue_add(QueueName :: atom(), Opts :: [queue_opts()]) -> ok.
-spec queue_remove(QueueName :: atom()) -> ok.
-spec queue_get(QueueName :: atom()) -> {ok, QueueRecord :: #qsk_queue_registery{}} | not_exist.
-spec queue_get_id(QueueName :: atom()) -> {ok, QueueID :: atom()} | not_exit.
-spec queue_list() -> [#qsk_queue_registery{}].
```

**Task API**

```erlang
-spec task_push(QueueID :: atom(), Func :: task_func(), Opts :: [task_opts()]) -> ok.
-spec task_pop(QueueID :: atom()) -> #qsk_queue_record{} | empty.
-spec task_peek(QueueID :: atom()) -> #qsk_queue_record{} | empty.
-spec task_remove(QueueID :: atom(), Key :: task_id()) -> ok.
```

Contribution
-----

Comments, contributions and patches are greatly appreciated.

License
-----
The MIT License (MIT).
