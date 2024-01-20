# Agent模板

## 任务
总流程
```mermaid
graph
addtask(添加任务)
execute(执行任务)
deltask(删除任务)
invoke(协程唤醒 agent.execute)
running(设为运行状态 running)
idle(设为空闲状态 idle)

addtask-->running-->invoke
invoke-->execute
deltask-->idle-->|有任务|invoke
```

### 添加任务
```mermaid
graph
addtask(添加任务)
invoke(协程唤醒 agent.execute)
running(设为运行状态 running)

addtask-->running-->|coroutine.queue|invoke
```

### 删除任务
```mermaid
graph
deltask(删除任务)
invoke(协程唤醒 agent.execute)
idle(设为空闲状态 idle)
has_task(判断是否还有任务)

deltask-->idle-->has_task-->|coroutine.queue|invoke
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

nail(预定结束时刻唤醒)

invoke-->|有任务|get_task-->init-->|已初始化|execute-->verify_dt-->exit
invoke-->|无任务|exit
init-->|未初始化|nail-->execute
```

### 任务推进
任务相关变量
- 任务推进相关
  - agent.tasks: 任务列表
  - agent.tasksequence: 任务队列
  - agent.lasttime: 上次执行时间

```lua
-- 任务推进变量之间的关系
agent.currentTask = agent.taskSequence[agent.currentTaskIndex]
```

tasks表结构
- tasks
  - 任务名
    - `init()`: 限制最大步进时间的函数。如果没有则不限制，直接使用CPU运行时间得到的dt。
    - `execute()`: 执行任务的函数。
  - ...

# 交互
Agent之间通过任务相互等待进行交互。

属性
`agent.occpuier`：占用者，显示当前agent被谁占用。如果没有被占用则为nil。