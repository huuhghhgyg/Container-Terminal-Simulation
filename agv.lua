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
        agv.targetContainerPos = nil -- 目标集装箱位置{row, col, level}

        agv.lastpos = {table.unpack(agv.pos)} -- 设置任务初始位置
    end

    -- 绑定对象
    function agv:bindCrane(targetStack, targetContainer)
        agv.stack = targetStack -- 目标stack
        agv.targetContainerPos = targetContainer -- 目标集装箱{row, col, level}
        -- 由于可能影响waitagent，因此不会在此处设置agv.operator
    end

    -- 动作函数
    function agv:setpos(x, y, z)
        agv.pos = {x, y, z}
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
            -- 参数检查
            if type(params[1]) ~= 'number' or type(params[2]) ~= 'number' or type(params[3]) ~= 'number' then
                print(agv.type .. agv.id, 'move2错误：输入的坐标参数有误:', params[1], params[2], params[3])
                print(debug.traceback())
                os.exit()
            end

            -- 设置任务初始位置
            agv.lastpos = {table.unpack(agv.pos)}

            -- 设置参数
            params.delta = {params[1] - agv.lastpos[1], params[2] - agv.lastpos[2], params[3] - agv.lastpos[3]} -- 位移
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
            local position = {table.unpack(agv.lastpos)}
            for i = 1, 3 do
                position[i] = position[i] + params.speed[i] * dt
            end

            -- 设置agv位置
            agv:setpos(table.unpack(position))

            if math.abs(params.dt - dt) < agv.timeError then -- 如果时间误差小于agv.timeerror，任务结束
                agv.lastpos = position -- 更新位置
                agv:deltask() -- 删除任务
            end
        end
    }

    -- {'waitoperator', {operator = operator}}
    -- operator需要通知本agent结束waitoperator任务
    agv.tasks.waitoperator = {
        init = function(params)
            -- 判断operator是否为空
            if params.operator == nil then
                print(debug.traceback('[agv' .. agv.id .. '] waitoperator错误，没有输入operator参数'))
                os.exit()
            end

            agv.operator = params.operator -- 设置当前agv的占用者
            -- print('agv.operator', agv.operator.type .. tostring(agv.operator.id), 'agv.operator',
            --     agv.operator.type .. tostring(agv.operator.id))

            coroutine.queue(0, agv.operator.execute, agv.operator) -- 通知operator进行检测，第二个参数是为函数传入实例
            params.dt = nil -- 任务所需时间为nil，需要别的任务带动被动运行
            params.init = true -- 标记完成初始化
        end,
        execute = function(dt, params)
            -- print('agv.operator', agv.operator, 'at', coroutine.qtime())
            if agv.operator == nil then
                agv:deltask() -- 删除任务，立刻运行下一个任务
            end
        end
    }

    -- {'moveon', {road=, distance=, targetDistance=, stay=}}
    agv.tasks.moveon = {
        init = function(params)
            -- 设置任务初始位置
            agv.lastpos = {table.unpack(agv.pos)}

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
                    targetDistance = params.targetDistance
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

            if math.abs(params.dt - dt) < agv.timeError then
                -- 参数检查
                if position == nil then
                    print(debug.traceback(agv.type .. agv.id,
                        'moveon错误：没有获取到agv位置，无法设置agv.pos'))
                    os.exit()
                end

                agv.road:removeAgv(agv.roadAgvId) -- 从道路中移除agv
                agv:deltask()
                agv.lastpos = position -- 更新关键节点位置
            end
        end
    }

    -- {'onnode', {node=, fromRoad=, toRoad=, ...}}
    agv.tasks.onnode = {
        init = function(params)
            -- 设置任务初始位置
            agv.lastpos = {table.unpack(agv.pos)}

            -- 默认已经占用了节点
            agv.road = nil -- 清空agv道路信息
            local node = params[1]
            -- 获取道路信息
            local fromRoad = params[2]
            local toRoad = params[3]

            -- 检查参数
            if node == nil then
                print(debug.traceback(agv.type .. agv.id, 'onnode错误：没有输入node参数'))
                os.exit()
            elseif fromRoad == nil then
                print(debug.traceback(agv.type .. agv.id, 'onnode错误：没有输入fromRoad参数'))
                os.exit()
            end

            -- 初始化
            -- 判断是否在本节点终止
            if toRoad == nil then
                -- 在本节点终止，交由execute删除任务
                return
            end

            -- 获取fromRoad的终点坐标
            -- 由于已知角度，toRoad的起点坐标就不需要了
            local fromRoadEndPoint = fromRoad.destPt -- {x,y,z}

            -- 到达节点（转弯）
            -- 计算需要旋转的弧度(两条道路向量之差的弧度，Road1->Road2)
            params.fromRadian = math.atan(fromRoad.vecE[1], fromRoad.vecE[3]) - math.atan(0, 1)
            params.toRadian = math.atan(toRoad.vecE[1], toRoad.vecE[3]) - math.atan(0, 1)
            params.deltaRadian = params.toRadian - params.fromRadian
            -- 模型假设弧度变化在-pi~pi之间，检测是否在这个区间内，如果不在需要修正
            if math.abs(params.deltaRadian) >= math.pi then
                params.deltaRadian = params.deltaRadian * (1 - math.pi * 2 / math.abs(params.deltaRadian))
            end
            params.walked = 0 -- 已经旋转的弧度/已经通过的直线距离

            -- 判断是否需要转弯（可能存在直线通过的情况）
            if params.deltaRadian % math.pi ~= 0 then
                params.radius = node.radius / math.tan(math.abs(params.deltaRadian) / 2) -- 转弯半径
                -- 计算圆心
                -- 判断左转/右转，左转deltaRadian > 0，右转deltaRadian < 0
                params.direction = params.deltaRadian / math.abs(params.deltaRadian) -- 用于设置步进方向

                -- 向左旋转90度坐标为(z,-x)，向右旋转90度坐标为(-z,x)
                if params.deltaRadian > 0 then
                    -- 左转
                    -- 向左旋转90度vecE坐标变为(z,-x)
                    params.center = {fromRoadEndPoint[1] + params.radius * fromRoad.vecE[3], fromRoadEndPoint[2],
                                     fromRoadEndPoint[3] + params.radius * -fromRoad.vecE[1]}
                    params.turnOriginRadian = math.atan(-fromRoad.vecE[3], fromRoad.vecE[1]) -- 转弯圆的起始位置弧度(右转)
                else
                    -- 右转
                    -- 向右旋转90度vecE坐标变为(-z,x)
                    params.center = {fromRoadEndPoint[1] + params.radius * -fromRoad.vecE[3], fromRoadEndPoint[2],
                                     fromRoadEndPoint[3] + params.radius * fromRoad.vecE[1]}
                    params.turnOriginRadian = math.atan(fromRoad.vecE[3], -fromRoad.vecE[1]) -- 转弯圆的起始位置弧度(左转)
                end

                -- 显示转弯圆心
                scene.addobj('points', {
                    vertices = params.center,
                    color = 'red',
                    size = 5
                })
                -- 显示半径连线
                scene.addobj('polyline', {
                    vertices = {fromRoadEndPoint[1], fromRoadEndPoint[2], fromRoadEndPoint[3], params.center[1],
                                params.center[2], params.center[3], toRoad.originPt[1], toRoad.originPt[2],
                                toRoad.originPt[3]},
                    color = 'red'
                })
                -- 计算两段半径的长度
                local l1 = math.sqrt((fromRoadEndPoint[1] - params.center[1]) ^ 2 +
                                         (fromRoadEndPoint[2] - params.center[2]) ^ 2 +
                                         (fromRoadEndPoint[3] - params.center[3]) ^ 2)
                local l2 = math.sqrt((toRoad.originPt[1] - params.center[1]) ^ 2 +
                                         (toRoad.originPt[2] - params.center[2]) ^ 2 +
                                         (toRoad.originPt[3] - params.center[3]) ^ 2)
                -- 初始化轨迹
                params.trail = {fromRoadEndPoint[1], fromRoadEndPoint[2], fromRoadEndPoint[3]}

                -- 计算角速度
                params.angularSpeed = agv.speed / params.radius
            end

            -- 计算任务所需时间
            local timeRemain
            if params.deltaRadian == 0 then
                -- 直线通过，不存在角速度
                local distanceRemain = node.radius * 2 -- 计算剩余距离
                timeRemain = math.abs(distanceRemain / agv.speed)
            else
                -- 转弯，存在角速度
                local radianRemain = params.deltaRadian -- 计算剩余弧度
                timeRemain = math.abs(radianRemain / params.angularSpeed)
            end

            params.dt = timeRemain
            params.init = true -- 标记完成初始化
            coroutine.queue(params.dt, agv.execute, agv) -- 结束时间唤醒execute
        end,
        execute = function(dt, params)
            -- 默认已经占用了节点
            local function tryExitNode()
                local x, y, z = table.unpack(params[3].originPt)
                local radian = math.atan(params[3].vecE[1], params[3].vecE[3]) - math.atan(0, 1)
                agv.roty = radian -- 设置agv旋转，下面的move2会一起设置
                agv.lastpos = {x, y, z} -- 更新位置
                agv:setpos(x, y, z) -- 到达目标

                -- 满足退出条件，删除本任务
                params[1].occupied = nil -- 解除节点占用
                params[1].agv = nil -- 清空节点agv信息
                agv:deltask() -- 删除任务
                return true -- 本轮任务完成
            end

            local fromRoad = params[2]
            local toRoad = params[3]

            -- 判断是否在本节点终止
            if toRoad == nil then
                -- 在本节点终止
                local node = params[1]
                node.occupied = nil -- 解除节点占用
                node.agv = nil -- 清空节点agv信息
                agv:deltask()
                return
            end

            -- 判断是转弯还是直行的情况
            if params.angularSpeed == nil then
                -- 直线
                -- 判断是否到达目标
                if math.abs(params.dt - dt) < agv.timeError then
                    params.arrived = true
                    -- if tryExitNode() then
                    --     -- 正常退出，显示轨迹
                    --     scene.addobj('polyline', {
                    --         vertices = {fromRoad.destPt[1], fromRoad.destPt[2], fromRoad.destPt[3], toRoad.originPt[1],
                    --                     toRoad.originPt[2], toRoad.originPt[3]}
                    --     })
                    -- end
                    tryExitNode()
                    return
                end

                -- 设置步进
                params.walked = agv.speed * dt
                -- 计算坐标
                local position = {table.unpack(agv.lastpos)}
                for i = 1, 3 do
                    position[i] = position[i] + params.walked * fromRoad.vecE[i]
                end
                agv:setpos(table.unpack(position)) -- 设置agv位置
            else
                -- 转弯
                -- 计算位置
                if not params.arrived then
                    params.walked = params.angularSpeed * dt * params.direction
                end

                -- 判断是否到达目标
                if math.abs(params.dt - dt) < agv.timeError then
                    params.arrived = true
                    -- -- 正常退出，显示轨迹
                    -- if tryExitNode() then
                    --     scene.addobj('polyline', {
                    --         vertices = params.trail
                    --     })
                    -- end
                    tryExitNode()
                    return
                end

                -- 计算步进
                local y = agv.lastpos[2] -- y不变
                local x, z = params.radius * math.sin(params.walked + params.turnOriginRadian) + params.center[1],
                    params.radius * math.cos(params.walked + params.turnOriginRadian) + params.center[3]

                -- -- 记录轨迹
                -- table.insert(params.trail, x)
                -- table.insert(params.trail, y)
                -- table.insert(params.trail, z)

                agv.roty = math.atan(params[2].vecE[1], params[2].vecE[3]) + params.walked - math.atan(0, 1)

                -- 应用计算结果
                agv:setpos(x, y, z)
            end
        end
    }

    -- {'register', {operator=, [taskType=,targetContainerPos=,f=]}}
    agv.tasks.register = {
        init = function(params)
            if params.operator == nil then
                print(debug.traceback('[' .. agv.type .. agv.id .. '] register错误，没有输入operator参数'))
                os.exit()
            end

            -- 需要执行的函数
            if type(params.f) == "function" then
                params.f()
            end

            params.operator:registerAgv(agv, params.taskType, params.targetContainerPos)

            agv:deltask() -- 删除任务
            coroutine.queue(0, params.operator.execute, params.operator) -- 通知operator开始运行
        end
    }

    agv:init(config)
    return agv
end
