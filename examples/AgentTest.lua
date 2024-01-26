-- 其他引用
-- 1.下载函数库到虚拟磁盘
print('正在下载依赖库到虚拟磁盘...')
os.upload('https://www.zhhuu.top/ModelResource/libs/tablestr.lua')
print('下载完成')
-- 2.引用库
require('tablestr')

function Agent()
    local agent = {
        speed = {1, 1, 1},
        model = scene.addobj('box'),
        pos = {0, 0, 0}, -- Agent位置，只有init更新，相当于每个任务的Origin
        lastupdate = 0,
        tasks = {},
        tasksequence = {},
        state = 'idle'
    }

    agent.type = 'agent'
    agent.id = agent.model.id

    function agent:addtask(name, params)
        table.insert(agent.tasksequence, {name, params})
        -- 如果是空闲状态，立刻执行
        if agent.state == 'idle' then
            agent.state = 'running'
            print('[' .. agent.type .. agent.id .. '] started at', coroutine.qtime())
            coroutine.queue(0, agent.execute, agent)
        end
    end

    function agent:deltask()
        print('删除任务', agent.tasksequence[1][1], 'at', coroutine.qtime())
        table.remove(agent.tasksequence, 1)

        -- 如果任务队列为空，进入空闲状态
        if #agent.tasksequence == 0 then
            agent.state = 'idle'
            agent.lastupdate = nil
            print('[' .. agent.type .. agent.id .. '] stopped at', coroutine.qtime())
            return
        end

        -- 任务推进
        agent.lastupdate = coroutine.qtime()
        coroutine.queue(0, agent.execute, agent)
    end

    -- 更新任务和事件
    function agent:execute()
        -- 判断任务队列长度
        if #agent.tasksequence == 0 then
            return
        end

        local taskname, params = table.unpack(agent.tasksequence[1])
        if agent.tasks[taskname] == nil then
            print(debug.traceback('错误，没有找到任务'))
            os.exit()
        end

        local dt = coroutine.qtime() - agent.lastupdate -- 计算仿真时间差

        -- 检查任务初始化
        if params == nil then
            params = {}
        end
        if not params.init then
            agent.lastupdate = coroutine.qtime()
            if agent.tasks[taskname].init ~= nil then
                agent.tasks[taskname].init(params)
            end
        end

        -- 执行刷新。如果任务结束，删除任务
        if agent.tasks[taskname].execute ~= nil then
            agent.tasks[taskname].execute(dt, params)
        end

        -- 检测时间推进
        if dt > params.dt then
            print(agent.type .. agent.id .. '任务' .. taskname .. '时间推进异常 at ' .. coroutine.qtime())
            print('任务预计params.dt=', params.dt, '实际输入dt=', dt)
            print(debug.traceback())
            os.exit()
        end
    end

    -- params = {x, y, z, ...}
    agent.tasks.move2 = {
        init = function(params)
            print('init move2 at', coroutine.qtime())
            local px, py, pz = agent.model:getpos()
            agent.pos = {px, py, pz}
            params.est, params.delta, params.vecE = {}, {}, {}

            -- 计算坐标
            for i = 1, 3 do
                params.delta[i] = params[i] - agent.pos[i]
                params.vecE[i] = params.delta[i] == 0 and 0 or params.delta[i] / math.abs(params.delta[i])
                params.est[i] = params.delta[i] == 0 and 0 or math.abs(params.delta[i]) / agent.speed[i]
            end
            params.dt = math.max(table.unpack(params.est)) -- 任务所需时间

            params.init = true -- 标记完成初始化
            coroutine.queue(params.dt, agent.execute, agent) -- 确定结束时间
        end,
        execute = function(dt, params)
            -- 计算坐标
            local position = {table.unpack(agent.pos)}
            for i = 1, 3 do
                position[i] = dt <= params.est[i] and agent.pos[i] + agent.speed[i] * dt * params.vecE[i] or params[i]
            end

            if dt == params.dt then
                agent.pos = position -- 更新位置
                agent:deltask() -- 删除任务
            end

            -- 设置位置
            agent.model:setpos(table.unpack(position))
        end
    }

    return agent
end

-- 总流程部分
scene.setenv({
    grid = 'plane'
})

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
