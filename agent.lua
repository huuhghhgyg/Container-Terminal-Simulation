function Agent()
    local agent = {
        speed = {1, 1, 1},
        model = nil,
        pos = {0, 0, 0}, -- Agent位置，只有init更新，相当于每个任务的Origin
        taskstart = 0,
        tasks = {},
        tasksequence = {},
        state = 'idle'
    }

    agent.type = 'agent'
    agent.id = agent.model ~= nil and agent.model.id or nil
    agent.timeerror = 10e-8 -- 可以忽略不记的时间误差范围

    -- 原生函数
    function agent:delete()
        agent.model:delete()
    end
    
    -- 任务相关函数
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
            agent.taskstart = nil
            print('[' .. agent.type .. agent.id .. '] stopped at', coroutine.qtime())
            return
        end

        -- 任务推进
        agent.taskstart = coroutine.qtime()
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

        local dt = coroutine.qtime() - agent.taskstart -- 计算仿真时间差

        -- 检查任务初始化
        if params == nil then
            params = {}
        end
        if not params.init then
            agent.taskstart = coroutine.qtime()
            if agent.tasks[taskname].init ~= nil then
                agent.tasks[taskname].init(params)
            end
        end

        -- 执行刷新。如果任务结束，删除任务
        if agent.tasks[taskname].execute ~= nil then
            agent.tasks[taskname].execute(dt, params)
        end

        -- 检测时间推进
        if params.dt ~= nil and dt > params.dt and dt - params.dt > agent.timeerror then -- 如果误差时间大于允许计算误差
            print(agent.type .. agent.id .. '任务' .. taskname .. '时间推进异常 at ' .. coroutine.qtime())
            print('任务预计params.dt=', params.dt, '实际输入dt=', dt, '时间差异=', dt - params.dt)
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
            coroutine.queue(params.dt, agent.execute, agent) -- 结束时间唤醒execute
        end,
        execute = function(dt, params)
            -- 计算坐标
            local position = {table.unpack(agent.pos)}
            for i = 1, 3 do
                position[i] = dt <= params.est[i] and agent.pos[i] + agent.speed[i] * dt * params.vecE[i] or params[i]
            end
            
            -- 设置位置
            agent.model:setpos(table.unpack(position))

            if dt == params.dt then
                agent.pos = position -- 更新位置
                agent:deltask() -- 删除任务
            end
        end
    }

    return agent
end