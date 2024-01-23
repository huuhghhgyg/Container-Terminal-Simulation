function AGV(config)
    -- 处理参数
    if config == nil then
        config = {}
    end

    local agv = Agent(config)

    -- 属性
    agv.type = 'agv'
    -- agv.tasks
    -- agv.tasksequence
    agv.model = scene.addobj("/res/ct/agv.glb")
    agv.id = agv.model.id

    function agv:init(config)
        agv.speed = config.speed or 10 -- 速度
        agv.roty = config.roty or 0 -- 以y为轴的旋转弧度，默认方向为0
        agv.container = config.container or nil -- 集装箱
        agv.height = config.height or 2.10 -- agv平台高度
        agv.road = config.road or nil -- 相对应road:registerAgv中设置agv的road属性
        agv.state = nil -- 状态，设为正常状态
        agv.targetContainerPos = nil -- 目标集装箱位置{row, col, level}
    end

    -- 绑定对象
    function agv:bindCrane(targetStack, targetContainer)
        agv.stack = targetStack -- 目标stack
        agv.operator = targetStack.operator -- 目标operator
        agv.targetContainerPos = targetContainer -- 目标集装箱{row, col, level}
        agv.arrived = false -- ?是否到达目标
    end

    -- 动作函数(不会更新agv.pos)
    function agv:setpos(x, y, z)
        agv.model:setpos(x, y, z)
        agv.model:setrot(0, agv.roty, 0)

        if agv.container ~= nil then
            agv.container:setpos(x, y + agv.height, z)
            agv.container:setrot(0, agv.roty, 0)
        end
    end

    function agv:setrot(x, y, z)
        agv.roty = y

        agv.model:setrot(x, y, z)
        if agv.container ~= nil then
            agv.container:setrot(x, y, z)
        end
    end

    -- 任务
    -- {'move2', {x, y, z, ...}}
    agv.tasks.move2 = {
        init = function(params)
            params.delta = {params[1] - agv.pos[1], params[2] - agv.pos[2], params[3] - agv.pos[3]} -- 位移
            local distance = math.sqrt(params.delta[1] ^ 2 + params.delta[2] ^ 2 + params.delta[3] ^ 2)
            params.est = distance / agv.speed -- 预计到达时间
            params.speed = {} -- agv只有一个总速度，需要计算分方向的速度
            -- 计算速度
            for i = 1, 3 do
                params.speed[i] = params.delta[i] == 0 and 0 or params.delta[i] / distance * agv.speed
            end

            params.dt = params.est -- 这个任务中est就是dt
            params.init = true -- 标记完成初始化
            coroutine.queue(params.dt, agv.execute, agv) -- 结束时间唤醒execute
        end,
        execute = function(dt, params)
            -- 计算坐标
            local position = {table.unpack(agv.pos)}
            for i = 1, 3 do
                position[i] = position[i] + params.speed[i] * dt
            end

            -- 设置agv位置
            agv:setpos(table.unpack(position))

            if dt >= params.dt then -- 如果时间误差小于agv.timeerror，任务结束
                agv.pos = position -- 更新位置
                agv:deltask() -- 删除任务
            end
        end
    }

    -- {'waitoperator', {operator = operator}}
    agv.tasks.waitoperator = {
        init = function(params)
            -- 判断operator是否为空
            if params.operator == nil then
                print(debug.traceback('[agv' .. agv.id .. '] waitoperator错误，没有输入operator参数'))
                os.exit()
            end

            agv.occupier = params.operator -- 设置当前agv的占用者
            print('agv.operator', agv.operator, 'agv.occupier', agv.occupier)

            params.dt = nil -- 任务所需时间为nil，需要别的任务带动被动运行
            params.init = true -- 标记完成初始化
        end,
        execute = function(dt, params)
            -- print('agv.operator', agv.operator, 'agv.occupier', agv.occupier)
            if agv.operator == nil then
                agv:deltask() -- 删除任务
                coroutine.queue(0, agv.execute, agv) -- 结束时间唤醒execute重新运行一次
            end
        end
    }

    -- {'moveon', {road=, distance=, targetDistance=, stay=}}
    agv.tasks.moveon = {
        init = function(params)
            -- 如果需要注册road
            if agv.road == nil then
                -- 检查参数
                if params.road == nil then
                    print(debug.traceback(agv.type .. agv.id, 'moveon错误：没有输入道路参数'))
                    os.exit()
                end

                -- 注册道路
                params.road:registerAgv(agv, {
                    -- 输入参数，并使用registerAgv的nil检测
                    distance = params.distance,
                    targetDistance = params.targetDistance,
                })
            end

            params.dt = agv.road:timeRemain(agv.roadAgvId) -- 计算最大步进时间
            params.init = true -- 标记完成初始化

            coroutine.queue(params.dt, agv.execute, agv) -- 结束时间唤醒execute
        end,
        execute = function(dt, params)
            -- 获取道路
            local road = agv.road

            -- 步进
            local position = road:setAgvDistance(dt, agv.roadAgvId)

            if dt >= params.dt then
                -- 参数检查
                if position == nil then
                    print(debug.traceback(agv.type .. agv.id,
                        'moveon错误：没有获取到agv位置，无法设置agv.pos'))
                end

                agv.road:removeAgv(agv.roadAgvId) -- 从道路中移除agv
                agv:deltask()
                agv.pos = position
            end
        end
    }



    agv:init(config)
    return agv
end
