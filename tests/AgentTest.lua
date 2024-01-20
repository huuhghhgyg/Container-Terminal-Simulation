-- 总流程部分
scene.setenv({
    grid = 'plane'
})

require('agent')

print()
local agent = Agent()
agent:addtask('move2', {0, 0, 10})
agent:addtask('move2', {10, 0, 10})
agent:addtask('move2', {10, 10, 10})
agent:addtask('move2', {0, 0, 0})

-- 独立刷新的绘图协程
local lastrun = os.clock()
local simv = 5

function refresh()
    -- 检测是否存在任务
    if #agent.tasksequence == 0 then
        print('无任务，停止推进') -- 这里的时间没有意义，不显示
        return
    end

    -- 更新时钟
    local dt = (os.clock() - lastrun) * simv
    lastrun = os.clock()

    -- agent更新
    agent:execute()

    local signal = scene.render()
    if not signal then
        return
    end

    -- print()
    -- print('refresh at time', coroutine.qtime())

    coroutine.queue(dt, refresh)
end
refresh()