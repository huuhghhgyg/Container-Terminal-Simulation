# Agent 模板

## 任务

Agent 自刷新总流程

```mermaid
graph
addtask(添加任务 addtask)
execute(执行任务...)
deltask(删除任务 deltask)
invoke(协程唤醒 agent.execute)
running(设为运行状态 running)
idle(设为空闲状态 idle)

addtask-->running-->invoke
invoke-->execute -->deltask
deltask-->|有任务|invoke
deltask-->|无任务|idle
```

### 添加任务

```mermaid
graph
addtask(添加任务 addtask)
not_idle(检查状态)
invoke(协程立即唤醒 agent.execute)
running(state == 'running')
execute(执行任务...)

addtask-->not_idle-->|state=='idle'|running-->|coroutine.queue|invoke-->execute
not_idle-->|state!='idle'|execute
```

### 删除任务

```mermaid
graph
deltask(删除任务)
invoke(协程立即唤醒 agent.execute)
execute_next(执行下一个任务...)
idle(agent.state=='idle')
has_task(判断是否还有任务)

deltask-->has_task-->|没有其他任务|idle
has_task-->|还有任务|invoke-->execute_next
```

### 任务执行

`agent:execute()`执行任务

```mermaid
graph
invoke(协程唤醒agent.execute)
get_task(获取任务)
init(任务初始化检查)
execute(执行task.execute)
verify_dt(推进时间验证)
exit(退出)

subgraph agent.init
  init_params(初始化参数)
  nail(预定结束时刻唤醒)
end

invoke-->|有任务|get_task-->init-->|已初始化|execute-->verify_dt-->exit
invoke-->|无任务|exit
init-->|未初始化|init_params-->nail-->execute
```

### 任务相关变量

- `parms.init`: 是否完成任务初始化。决定是否执行`task.init`函数。
- `params.dt`：执行任务所需时间。init 后应该使用`coroutine.queue`在`params.dt`后唤醒 agent.execute，完成任务并删除。

### 任务推进

任务相关变量

- 任务推进相关
  - agent.tasks: 任务列表
  - agent.tasksequence: 任务队列
  - agent.taskstart: 任务开始时间

tasks 表结构

- tasks
  - 任务名
    - `init()`: 限制最大步进时间的函数。如果没有则不限制，直接使用 CPU 运行时间得到的 dt。
    - `execute()`: 执行任务的函数。
  - ...

# 属性

agent.state: 状态，有`idle`和`running`两种状态。用于检测 agent 是否正在执行任务。

# 交互

Agent 之间通过任务相互等待进行交互。

属性
`agent.operator`：操作者，显示当前 agent 被谁占用。如果没有被占用则为 nil。
