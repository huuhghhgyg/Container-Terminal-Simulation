-- 测试agent的setvalue和fn任务
-- setvalue：运行时设置agent的属性值
-- fn：运行时执行一个函数
-- 总流程部分
scene.setenv({
    grid = 'plane'
})

require('agent')

print()

function showStatus(agent)
    print('by showStatus f:',agent.type..agent.id,'status=',agent.status, 'at', coroutine.qtime())
end

local agent = Agent()
agent.model = scene.addobj('box')
agent.id = agent.model.id
print('agent status:', agent.status)
agent:addtask('setvalue', {key='status', value = 1})
agent:addtask('fn', {f=showStatus, args={agent}})
agent:addtask('move2', {0, 0, 10})
agent:addtask('setvalue', {key='status', value = 2})
agent:addtask('fn', {f=showStatus, args={agent}})
agent:addtask('move2', {10, 0, 10})
agent:addtask('setvalue', {key='status', value = 3})
agent:addtask('fn', {f=showStatus, args={agent}})
agent:addtask('delay', {5})
agent:addtask('move2', {10, 10, 10})
agent:addtask('setvalue', {key='status', value = 4})
agent:addtask('fn', {f=showStatus, args={agent}})
agent:addtask('move2', {0, 0, 0})

-- 独立刷新的绘图协程
require('watchdog')
local simv = 5
local ActionObjs = {agent}

local watchdog = WatchDog(simv, ActionObjs)
watchdog.refresh()
