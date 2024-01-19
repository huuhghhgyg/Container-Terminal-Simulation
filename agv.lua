--- 创建一个新的AGV对象
---@param targetCY 目标堆场
---@param targetContainer 目标集装箱{bay, col, level}
function AGV()
    local agv = scene.addobj("/res/ct/agv.glb")
    agv.type = "agv" -- 记录对象类型
    agv.speed = 10 -- agv速度
    agv.roty = 0 -- 以y为轴的旋转弧度，默认方向为0
    agv.tasksequence = {} -- 初始化任务队列
    agv.tasks = {} -- 可用任务列表(数字索引为可用任务，字符索引为任务函数)
    agv.container = nil -- 初始化集装箱
    agv.height = 2.10 -- agv平台高度

    -- 新增（by road)
    -- agv.safetyDistance = 5 -- 安全距离
    agv.safetyDistance = 20 -- 安全距离
    agv.road = nil -- 相对应road:registerAgv中设置agv的road属性.
    agv.state = nil -- 正常状态
    agv.targetContainerPos = nil -- 目标集装箱位置{bay, col, level}

    -- 绑定起重机（RMG/RMGQC）
    function agv:bindCrane(targetCY, targetContainer)
        agv.datamodel = targetCY -- 目标堆场(数据模型)
        agv.operator = targetCY.operator -- 目标场桥(操作器)
        agv.targetContainerPos = targetContainer -- 目标集装箱{bay, col, level}
        agv.arrived = false -- 是否到达目标
    end

    function agv:move2(x, y, z) -- 直接移动到指定坐标
        agv:setpos(x, y, z)
        agv:setrot(0, agv.roty, 0)
        if agv.container ~= nil then
            agv.container:setpos(x, y + agv.height, z)
            agv.container:setrot(0, agv.roty, 0)
        end
    end

    function agv:attach()
        agv.container = agv.operator.stash
        agv.operator.stash = nil
    end

    function agv:detach()
        agv.operator.stash = agv.container
        agv.container = nil
    end

    -- 任务相关函数
    function agv:executeTask(dt) -- 执行任务 task: {任务名称,{参数}}
        if agv.tasksequence[1] == nil or #agv.tasksequence == 0 then
            return
        end

        local task = agv.tasksequence[1]
        local taskname, params = task[1], task[2]

        -- -- debug
        -- if agv.lasttask ~= taskname then
        --     print('[agv', agv.id, '] executing', taskname, 'at', coroutine.qtime())
        --     agv.lasttask = taskname
        -- end

        if agv.tasks[taskname] == nil then
            print('[agv] 错误，没有找到任务', taskname)
        end

        -- 执行任务
        if agv.tasks[taskname].execute ~= nil then
            agv.tasks[taskname].execute(dt, params)
            -- print('[agv', agv.id, '] task executing: ', taskname, 'dt=', dt)
        end
    end

    -- 添加任务
    function agv:addtask(name, param)
        local task = {name, param}
        table.insert(agv.tasksequence, task)
    end

    -- 删除任务
    function agv:deltask()
        -- debug
        -- print('agv' .. agv.id, 'deltask', agv.tasksequence[1][1], 'at', coroutine.qtime())
        -- agv.isDeletedTask = true -- watchdog标记
        -- debug.pause()

        -- 判断是否具有子任务序列
        if agv.tasksequence[1].subtask ~= nil and #agv.tasksequence[1].subtask > 0 then -- 子任务序列不为空，删除子任务中的任务
            table.remove(agv.tasksequence[1].subtask, 1)
            return
        end

        table.remove(agv.tasksequence, 1)

        if (agv.tasksequence[1] ~= nil and agv.tasksequence[1][1] == "attach") then
            print("[agv", agv.roadAgvId or agv.id, "] task executing: ", agv.tasksequence[1][1])
        end
    end

    function agv:maxstep() -- 初始化和计算最大允许步进时间
        local dt = math.huge -- 初始化步进
        if agv.tasksequence[1] == nil then -- 对象无任务，直接返回最大值
            print('此处agv无任务，maxstep直接返回math.huge')
            return dt
        end

        local taskname = agv.tasksequence[1][1] -- 任务名称
        local params = agv.tasksequence[1][2] -- 任务参数

        -- -- debug
        -- if agv.lastmaxstep ~= taskname then
        --     agv.lastmaxstep = taskname
        --     print('[agv' .. agv.id .. '] maxstep', taskname, 'at', coroutine.qtime())
        -- end

        -- 计算maxstep
        if agv.tasks[taskname] ~= nil and agv.tasks[taskname].maxstep ~= nil then
            dt = agv.tasks[taskname].maxstep(params)
        end

        return dt
    end

    -- {"move2",x,z} 移动到指定位置 {x,z, 向量距离*2(3,4), moved*2(5,6), 初始位置*2(7,8)},occupy:当前占用道路位置
    agv.tasks.move2 = {
        execute = function(dt, params)

            local ds = {params.speed[1] * dt, params.speed[2] * dt} -- xz方向移动距离
            params.movedXZ[1], params.movedXZ[2] = params.movedXZ[1] + ds[1], params.movedXZ[2] + ds[2] -- xz方向已经移动的距离

            -- 判断是否到达
            for i = 1, 2 do
                if params.vectorDistanceXZ[i] ~= 0 and (params[i] - params.originXZ[i] - params.movedXZ[i]) *
                    params.vectorDistanceXZ[i] <= 0 then -- 如果分方向到达则视为到达
                    agv:move2(params[1], 0, params[2])
                    agv:deltask()
                    return
                end
            end

            -- 设置步进移动
            agv:move2(params.originXZ[1] + params.movedXZ[1], 0, params.originXZ[2] + params.movedXZ[2])
        end,
        maxstep = function(params)
            local dt = math.huge -- 初始化本任务最大步进

            -- 初始判断
            if params.vectorDistanceXZ == nil then -- 没有计算出向量距离，说明没有初始化
                local x, _, z = agv:getpos() -- 获取当前位置

                params.vectorDistanceXZ = {params[1] - x, params[2] - z} -- xz方向需要移动的距离
                if params.vectorDistanceXZ[1] == 0 and params.vectorDistanceXZ[2] == 0 then
                    print("Exception: agv不需要移动", " currentoccupy=", params.occupy)
                    agv:deltask()
                    -- return
                    return agv:maxstep() -- 重新计算
                end

                params.movedXZ = {0, 0} -- xz方向已经移动的距离
                params.originXZ = {x, z} -- xz方向初始位置

                local l = math.sqrt(params.vectorDistanceXZ[1] ^ 2 + params.vectorDistanceXZ[2] ^ 2)
                params.speed = {params.vectorDistanceXZ[1] / l * agv.speed, params.vectorDistanceXZ[2] / l * agv.speed} -- xz向量速度分量
            end

            for i = 1, 2 do
                if params.vectorDistanceXZ[i] ~= 0 then -- 只要分方向移动，就计算最大步进
                    dt = math.min(dt, math.abs((params[i] - params.originXZ[i] - params.movedXZ[i]) / params.speed[i]))
                end
            end
            return dt
        end
    }

    -- {"waitoperator", {operator=agent}} 等待operator改变自身状态。当自身状态为nil时，删除任务；wait则继续等待。
    agv.tasks.waitoperator = {
        maxstep = function(params)
            -- 初始化
            if not params.init then
                -- 判断operator是否为空
                if params.operator == nil then
                    print('[agv' .. agv.id .. '] waitoperator错误，没有输入operator参数')
                    os.exit()
                end

                agv.occupier = params.operator -- 设置当前agv被哪个agent占用
                -- print('[agv' .. agv.id .. '] waitoperator 任务初始化，occupier=', agv.occupier.type,
                --     agv.occupier.id, 'at', coroutine.qtime())
                params.init = true -- 设置初始化标记
                return -1
            end

            -- 检测状态，能否结束任务
            if agv.occupier == nil then
                -- print('[agv' .. agv.id .. '] waitoperator 任务结束 at' .. coroutine.qtime())
                agv:deltask()
                return agv:maxstep() -- 结束占用任务，maxstep自调用
            end

            -- print('agv' .. agv.id, 'waitoperator', agv.operator.type, agv.operator.id)

            return math.huge
        end
    }

    -- {"moveon",{road=,distance=,targetDistance=,stay=}} 沿着当前道路行驶。注意事项：param可能为nil
    agv.tasks.moveon = {
        execute = function(dt, params)
            -- 获取道路
            local road = agv.road
            local roadAgvItem = road:getAgvItem(agv.roadAgvId) -- 获取道路agv对象

            -- 判断是否到达目标
            if roadAgvItem.distance + dt * agv.speed >= roadAgvItem.targetDistance then
                -- 到达目标
                road:setAgvDistance(roadAgvItem.targetDistance, agv.roadAgvId) -- 设置agv位置为终点位置

                -- 结束任务
                agv.state = nil -- 设置agv状态为空(正常)

                -- -- 如果存在目标节点，则设置目标节点占用(如果推进太多可能会造成maxstep漏占用)
                -- if road.toNode and not road.toNode.occupied then
                --     local distanceRemain = roadAgvItem.targetDistance - roadAgvItem.distance
                --     if roadAgvItem.targetDistance == road.length and distanceRemain <= roadAgvItem.agv.safetyDistance then
                --         road.toNode.occupied = agv -- 设置节点占用
                --         -- print('agv' .. agv.id .. '在moveon.execute设置节点' .. road.toNode.id .. '的占用')
                --     end
                -- end

                road:removeAgv(agv.roadAgvId) -- 从道路中移除agv
                agv:deltask()
                return
            end

            -- 步进
            road:setAgvPos(dt, agv.roadAgvId)
        end,
        maxstep = function(params)
            local dt = math.huge -- 初始化本任务最大步进

            -- 未注册道路
            if agv.road == nil or agv.state == 'stay' then
                if params.road == nil then -- agv未注册道路且没有输入道路参数
                    print("Exception: agv未注册道路")
                    agv:deltask()
                    return agv:maxstep() -- 重新计算
                end

                -- 注册道路
                params.road:registerAgv(agv, {
                    -- 输入参数，并使用registerAgv的nil检测
                    distance = params.distance,
                    targetDistance = params.targetDistance,
                    stay = params.stay
                })
                -- print('agv' .. agv.id .. '注册得到roadAgvId=' .. agv.roadAgvId)
            end

            dt = agv.road:maxstep(agv.roadAgvId) -- 使用road中的方法计算最大步进
            return dt
        end
    }

    -- {"onnode", node, fromRoad, toRoad} 输入通过节点到达的道路id
    agv.tasks.onnode = {
        execute = function(dt, params)
            -- 默认已经占用了节点
            local function tryExitNode()
                local x, y, z = table.unpack(params[3].originPt)
                local radian = math.atan(params[3].vecE[1], params[3].vecE[3]) - math.atan(0, 1)
                agv.roty = radian -- 设置agv旋转，下面的move2会一起设置
                agv:move2(x, y, z) -- 到达目标

                -- 满足退出条件，删除本任务
                params[1].occupied = nil -- 解除节点占用
                params[1].agv = nil -- 清空节点agv信息
                agv:deltask() -- 删除任务
                return true -- 本轮任务完成
            end

            local fromRoad = params[2]
            local toRoad = params[3]

            -- 判断是转弯还是直行的情况
            if params.angularSpeed == nil then
                -- 直线
                -- 计算步进
                local ds = agv.speed * dt

                -- 判断是否到达目标
                if params.arrived or math.abs(ds + params.walked) >= params[1].radius * 2 then
                    params.arrived = true
                    if tryExitNode() then
                        -- 正常退出，显示轨迹
                        scene.addobj('polyline', {
                            vertices = {fromRoad.destPt[1], fromRoad.destPt[2], fromRoad.destPt[3], toRoad.originPt[1],
                                        toRoad.originPt[2], toRoad.originPt[3]}
                        })
                    end
                    return
                end

                -- 设置步进
                params.walked = params.walked + ds
                local x, y, z = agv:getpos()
                agv:move2(x + ds * fromRoad.vecE[1], y + ds * fromRoad.vecE[2], z + ds * fromRoad.vecE[3]) -- 设置agv位置
            else
                -- 转弯
                -- 计算步进
                local dRadian = params.angularSpeed * dt * params.direction
                if not params.arrived then
                    params.walked = params.walked + dRadian
                end

                -- 判断是否到达目标
                if params.walked / params.deltaRadian >= 1 then
                    params.arrived = true
                    if tryExitNode() then
                        -- 正常退出，显示轨迹
                        scene.addobj('polyline', {
                            vertices = params.trail
                        })
                    end
                    return
                end

                -- 计算步进
                local _, y, _ = agv:getpos()
                local x, z = params.radius * math.sin(params.walked + params.turnOriginRadian) + params.center[1],
                    params.radius * math.cos(params.walked + params.turnOriginRadian) + params.center[3]

                -- 记录轨迹
                table.insert(params.trail, x)
                table.insert(params.trail, y)
                table.insert(params.trail, z)

                -- agv.roty = agv.roty + dRadian*2 --为什么要*2 ???
                agv.roty = math.atan(params[2].vecE[1], params[2].vecE[3]) + params.walked - math.atan(0, 1)

                -- 应用计算结果
                agv:move2(x, y, z)
            end
        end,
        maxstep = function(params)
            local dt = math.huge -- 初始化本任务最大步进

            -- 默认已经占用了节点
            agv.road = nil -- 清空agv道路信息
            local node = params[1]
            -- 获取道路信息
            local fromRoad = params[2]
            local toRoad = params[3]

            -- 判断是否初始化
            if params.deltaRadian == nil then
                -- 判断是否在本节点终止
                if toRoad == nil then
                    -- 在本节点终止
                    node.occupied = nil -- 解除节点占用
                    node.agv = nil -- 清空节点agv信息
                    agv:deltask()

                    return -1 -- 需要空转到execute删除任务，可能触发删除实体
                end

                -- 获取fromRoad的终点坐标。由于已知角度，toRoad的起点坐标就不需要了
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
            end

            -- 计算最大步进
            local timeRemain
            if params.deltaRadian == 0 then
                -- 直线通过，不存在角速度
                local distanceRemain = node.radius * 2 - params.walked -- 计算剩余距离
                timeRemain = math.abs(distanceRemain / agv.speed)
            else
                -- 转弯，存在角速度
                local radianRemain = params.deltaRadian - params.walked -- 计算剩余弧度
                timeRemain = math.abs(radianRemain / params.angularSpeed)
            end

            return math.min(dt, timeRemain)
        end
    }

    -- {"register", {operator=, f=}} 注册agv到operator
    agv.tasks.register = {
        maxstep = function(params)
            if params.operator == nil then
                print(debug.traceback('[agv' .. agv.id .. '] register错误，没有输入operator参数'))
                os.exit()
            end

            -- 需要执行的函数
            if type(params.f) == "function" then
                params.f()
            end

            params.operator:registerAgv(agv)

            agv:deltask() -- 删除任务
            return -1 -- maxstep触发重算
        end
    }

    function agv:InSafetyDistance(targetAgv)
        local tx, ty, tz = targetAgv:getpos()
        local x, y, z = agv:getpos()
        local d = math.sqrt((tx - x) ^ 2 + (tz - z) ^ 2)
        return d < agv.safetyDistance
    end

    -- 计算圆弧长度
    function agv:arcLength(radian, radius)
        return math.abs(radian) * radius
    end

    function agv.isSameContainerPosition(pos1, pos2)
        if pos1 == nil or pos2 == nil then
            return false
        end
        return pos1[1] == pos2[1] and pos1[2] == pos2[2] and pos1[3] == pos2[3]
    end

    return agv
end
