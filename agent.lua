function Agent()
    local agent = {
        speed = 1,
        model = nil,
        pos = {0, 0, 0}, -- Agent位置，只有init更新，相当于每个任务的Origin
        taskstart = nil,
        tasks = {},
        tasksequence = {},
        state = 'idle'
    }

    agent.type = 'agent'
    agent.id = agent.model ~= nil and agent.model.id or nil
    agent.timeError = 10e-8 -- 允许的计算时间误差范围
    agent.lastpos = agent.pos -- 初始化任务初始位置

    -- 原生函数
    function agent:setpos(x, y, z)
        agent.model:setpos(x, y, z)
    end

    function agent:delete()
        agent.model:delete()
    end

    -- 任务相关函数
    function agent:addtask(name, params)
        table.insert(agent.tasksequence, {name, params})
        -- 如果是空闲状态，立刻执行
        if agent.state ~= 'running' then
            agent.state = 'running'
            agent.taskstart = coroutine.qtime() -- 记录任务开始时间
            print('[' .. agent.type .. agent.id .. '] started at', coroutine.qtime())
            coroutine.queue(0, agent.execute, agent)
        end
    end

    function agent:deltask()
        -- print('[' .. agent.type .. tostring(agent.id) .. '] 删除任务', agent.tasksequence[1][1], 'at',
        --     coroutine.qtime())
        table.remove(agent.tasksequence, 1)

        -- 如果任务队列为空，进入空闲状态
        if #agent.tasksequence == 0 then
            agent.state = 'idle'
            agent.taskstart = nil
            print('[' .. agent.type .. agent.id .. '] stopped at', coroutine.qtime())
            return
        end

        -- 任务推进
        -- print('[' .. agent.type .. tostring(agent.id) .. '] 任务:', agent.tasksequence[1][1], 'at', coroutine.qtime())
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
        -- 参数验证
        if agent.tasks[taskname] == nil then
            print('[' .. agent.type .. agent.id .. '] 错误，没有找到任务:',taskname)
            print(debug.traceback())
            os.exit()
        end

        if agent.taskstart == nil then
            print(debug.traceback('[' .. agent.type .. agent.id .. '] 错误，任务开始时间为空'))
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
        if params.dt ~= nil and dt - params.dt > agent.timeError then -- 如果误差时间大于允许计算误差
            print(agent.type .. agent.id .. '任务' .. taskname .. '时间推进异常 at ' .. coroutine.qtime())
            print('任务预计params.dt=', params.dt, '实际输入dt=', dt, '时间差异=', dt - params.dt)
            print(debug.traceback())
            os.exit()
        end
    end

    -- 运行时设置agent的value值
    -- params = {key=, value=}
    agent.tasks.setvalue = {
        init = function(params)
            -- 参数检查
            if params.key == nil then
                print(debug.traceback('[' .. agent.type .. agent.id .. '] 错误，setvalue任务没有找到key参数'))
                os.exit()
            end

            if params.value == nil then
                print(debug.traceback('[' .. agent.type .. agent.id .. '] 错误，setvalue任务没有找到value参数'))
                os.exit()
            end

            agent[params.key] = params.value
            -- print('[' .. agent.type .. agent.id .. '] setvalue', params.key, '=', params.value, 'at', coroutine.qtime())

            params.init = true -- 标记完成初始化
            coroutine.queue(0, agent.execute, agent) -- 结束时间唤醒execute
        end,
        execute = function()
            agent:deltask() -- 只执行一次，直接删除
        end
    }

    -- 运行时运行一个传入的函数
    -- params = {f=,args={}}
    agent.tasks.fn = {
        init = function(params)
            -- 参数检查
            if type(params.f) ~= 'function' then
                print('[' .. agent.type .. agent.id .. '] 错误，fn任务的fn参数错误:', params.fn)
                print(debug.traceback())
                os.exit()
            end

            if type(params.args) ~= 'table' then
                print(debug.traceback('[' .. agent.type .. agent.id .. '] 错误，fn任务没有找到args参数'))
                os.exit()
            end
            
            params.init = true
            coroutine.queue(0, agent.execute, agent) -- 结束时间唤醒execute
        end,
        execute = function(dt, params)
            params.f(table.unpack(params.args))
            agent:deltask() -- 只执行一次，直接删除
        end
    }

    -- params = {t} 秒
    agent.tasks.delay = {
        init = function (params)
            -- 参数检查
            if type(params[1]) ~= "number" then
                print('[' .. agent.type .. agent.id .. '] 错误，delay任务的参数不为数字',params[1])
                print(debug.traceback())
                os.exit()
            end

            params.init = true
            params.dt = params[1]
            coroutine.queue(params.dt, agent.execute, agent)
        end,
        execute = function (dt, params)
            if dt == params.dt then
                agent:deltask() -- 删除任务
            end
        end
    }

    -- {'move2', {x, y, z, ...}}
    agent.tasks.move2 = {
        init = function(params)
            -- 参数检查
            if type(params[1]) ~= 'number' or type(params[2]) ~= 'number' or type(params[3]) ~= 'number' then
                print(agent.type .. agent.id, 'move2错误：输入的坐标参数有误:', params[1], params[2], params[3])
                print(debug.traceback())
                os.exit()
            end

            -- 设置任务初始位置
            agent.lastpos = {table.unpack(agent.pos)}

            -- 设置参数
            params.delta = {params[1] - agent.lastpos[1], params[2] - agent.lastpos[2], params[3] - agent.lastpos[3]} -- 位移
            local distance = math.sqrt(params.delta[1] ^ 2 + params.delta[2] ^ 2 + params.delta[3] ^ 2)
            params.est = distance / agent.speed -- 预计到达时间
            params.speed = {} -- agent只有一个总速度，需要计算分方向的速度
            -- 计算速度
            for i = 1, 3 do
                params.speed[i] = params.delta[i] == 0 and 0 or params.delta[i] / distance * agent.speed
            end

            params.dt = params.est -- 这个任务中est就是dt
            params.init = true -- 标记完成初始化
            coroutine.queue(params.dt, agent.execute, agent) -- 结束时间唤醒execute
        end,
        execute = function(dt, params)
            -- 计算坐标
            local position = {table.unpack(agent.lastpos)}
            for i = 1, 3 do
                position[i] = position[i] + params.speed[i] * dt
            end

            -- 设置agent位置
            agent:setpos(table.unpack(position))

            if math.abs(params.dt - dt) < agent.timeError then -- 如果时间误差小于agent.timeerror，任务结束
                agent.pos = position -- 更新位置
                agent:deltask() -- 删除任务
            end
        end
    }

    return agent
end
