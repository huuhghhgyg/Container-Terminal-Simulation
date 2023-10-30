--- 创建一个新的AGV对象
---@param targetCY 目标堆场
---@param targetContainer 目标集装箱{bay, col, level}
function AGV()
    local agv = scene.addobj("/res/ct/agv.glb")
    agv.type = "agv" -- 记录对象类型
    agv.speed = 10 -- agv速度
    agv.roty = 0 -- 以y为轴的旋转弧度，默认方向为0
    agv.tasksequence = {} -- 初始化任务队列
    agv.container = nil -- 初始化集装箱
    agv.height = 2.10 -- agv平台高度

    -- 新增（by road)
    -- agv.safetyDistance = 5 -- 安全距离
    agv.safetyDistance = 20 -- 安全距离
    agv.road = nil -- 相对应road:registerAgv中设置agv的road属性.
    agv.state = nil -- 正常状态

    -- 绑定起重机（RMG/RMGQC）
    function agv:bindCrane(targetCY, targetContainer)
        agv.datamodel = targetCY -- 目标堆场(数据模型)
        agv.operator = targetCY.rmg -- 目标场桥(操作器)
        agv.targetcontainer = targetContainer -- 目标集装箱{bay, col, level}
        agv.targetbay = targetContainer[1] -- 目标bay
        agv.arrived = false -- 是否到达目标

        agv.operator:registeragv(agv) -- 向operator注册agv
    end

    function agv:move2(x, y, z) -- 直接移动到指定坐标
        agv:setpos(x, y, z)
        if agv.container ~= nil then
            agv.container:setpos(x, y + agv.height, z)
        end
    end

    function agv:attach()
        agv.container = agv.operator.stash
        agv.operator.stash = nil
    end

    function agv:executeTask(dt) -- 执行任务 task: {任务名称,{参数}}
        if agv.tasksequence[1] == nil or #agv.tasksequence == 0 then
            return
        end

        local task = agv.tasksequence[1]
        local taskname, param = task[1], task[2]

        -- 判断子任务序列
        if taskname == "queue" then -- {"queue", subtask={...}}
            print("判定为子任务序列(queue)") -- debug
            if #param.subtask == 0 then -- 子任务序列为空，删除queue任务
                agv:deltask()
                return agv:maxstep() -- 重新计算
            end

            -- 执行子任务
            taskname = param.subtask[1][1]
            param = param.subtask[1][2]
        end

        -- print("正在执行任务", taskname)

        if taskname == "move2" then -- {"move2",x,z} 移动到指定位置 {x,z, 向量距离*2(3,4), moved*2(5,6), 初始位置*2(7,8)},occupy:当前占用道路位置
            if param.speed == nil then
                agv:maxstep() -- 计算最大步进
            end

            local ds = {param.speed[1] * dt, param.speed[2] * dt} -- xz方向移动距离
            param.movedXZ[1], param.movedXZ[2] = param.movedXZ[1] + ds[1], param.movedXZ[2] + ds[2] -- xz方向已经移动的距离

            -- 判断是否到达
            for i = 1, 2 do
                if param.vectorDistanceXZ[i] ~= 0 and (param[i] - param.originXZ[i] - param.movedXZ[i]) *
                    param.vectorDistanceXZ[i] <= 0 then -- 如果分方向到达则视为到达
                    agv:move2(param[1], 0, param[2])
                    agv:deltask()
                    return
                end
            end

            -- 设置步进移动
            agv:move2(param.originXZ[1] + param.movedXZ[1], 0, param.originXZ[2] + param.movedXZ[2])
        elseif taskname == "attach" then
            if agv.operator.stash ~= nil and agv.targetbay == agv.operator.bay or agv.targetbay == nil then
                agv:attach()
                print("[agv] attached container at ", coroutine.qtime())
                agv:deltask()
            end
        elseif taskname == "waitrmg" then -- {"waitrmg"} 等待rmg移动
            -- 检测rmg.stash是否为空，如果为空则等待；否则进行所有权转移，并设置move2
            if agv.operator.stash ~= nil then
                agv:deltask()
            end
        elseif taskname == "waitrmgqc" then -- {"waitrmgqc"} 等待rmg移动
            if agv.container == nil then
                agv:deltask()
            end
        elseif taskname == "onboard" then
            param[1]:registeragv(agv)
            agv:deltask()
        elseif taskname == "moveon" then
            -- 获取道路
            local road = agv.road
            local roadAgvItem = road.agvs[agv.roadAgvId - road.agvLeaveNum]

            -- 判断前方是否被堵塞
            local agvAhead = road:getAgvAhead(agv.roadAgvId)
            if agvAhead ~= nil then
                local ax, _, az = agvAhead:getpos()
                local x, _, z = agv:getpos()
                local d = math.sqrt((ax - x) ^ 2 + (az - z) ^ 2)

                if d < agv.safetyDistance then -- 前方被堵塞
                    return -- 直接返回
                end
            end

            -- 步进
            road:setAgvPos(dt, agv.roadAgvId)
            if roadAgvItem.distance >= roadAgvItem.targetDistance then -- 判断是否到达目标
                -- 到达目标
                -- 判断是否连接节点，节点是否可用
                -- 如果节点可用，则删除本任务，否则阻塞
                if road.toNode ~= nil then
                    if road.toNode.occupied then
                        -- 节点被占用，本轮等待
                        agv.state = "wait" -- 设置agv状态为等待
                        print('agv', agv.id, '前方节点(', road.toNode.id, ')被堵塞，正在等待') -- debug
                        return
                    end

                    -- 节点没有被占用
                    road.toNode.occupied = true -- 设置节点占用
                end

                -- 结束任务
                agv.state = nil -- 设置agv状态为空(正常)
                road:removeAgv(agv.roadAgvId) -- 从道路中移除agv
                agv:deltask()
            end
        elseif taskname == "onnode" then -- {"onnode", node, fromRoad, toRoad} 输入通过节点到达的道路id
            -- 默认已经占用了节点

            local function tryExitNode()
                local x, y, z = table.unpack(param[3].originPt)
                agv:setpos(x, y, z) -- 到达目标
                local radian = math.atan(param[3].vecE[1], param[3].vecE[3]) - math.atan(0, 1)
                agv:setrot(0, radian, 0)

                -- 判断出口是否占用，如果占用则在Node中等待，阻止其他agv进入Node
                if #param[3].agvs > 0 then -- 目标道路是否有agv
                    if agv:InSafetyDistance(param[3].agvs[#param[3].agvs].agv) then
                        agv.state = "wait" -- 设置agv状态为等待
                        return false -- 本轮等待
                    end
                end

                -- 满足退出条件，删除本任务
                agv.state = nil -- 设置agv状态为空(正常)
                param[1].occupied = false -- 解除节点占用
                agv:deltask() -- 删除任务
                return true -- 本轮任务完成
            end

            local fromRoad = param[2]
            if param.angularSpeed == nil then -- 判断是否转弯
                -- 直线
                -- 计算步进
                local ds = agv.speed * dt
                local dx, dz = ds * fromRoad.vecE[1], ds * fromRoad.vecE[3]

                -- 判断是否到达目标
                if math.abs(ds + param.walked) >= param[1].radius * 2 then
                    if tryExitNode() then
                        local toRoad = param[3]
                        -- 显示轨迹
                        scene.addobj('polyline', {
                            vertices = {fromRoad.destPt[1], fromRoad.destPt[2], fromRoad.destPt[3], toRoad.originPt[1],
                                        toRoad.originPt[2], toRoad.originPt[3]}
                        })

                        return
                    end
                end

                -- 设置步进
                param.walked = param.walked + ds
                local x, y, z = agv:getpos()
                agv:setpos(x + ds * fromRoad.vecE[1], y + ds * fromRoad.vecE[2], z + ds * fromRoad.vecE[3]) -- 设置agv位置
            else
                -- 转弯
                -- 计算步进
                local dRadian = param.angularSpeed * dt * param.direction
                param.walked = param.walked + dRadian

                -- 判断是否到达目标
                if (dRadian + param.walked) / param.deltaRadian >= 1 then
                    if tryExitNode() then
                        -- 显示轨迹
                        scene.addobj('polyline', {
                            vertices = param.trail
                        })
                        return
                    end
                end

                -- 计算步进并设置位置
                local _, y, _ = agv:getpos()
                local x, z = param.radius * math.sin(param.walked + param.turnOriginRadian) + param.center[1],
                    param.radius * math.cos(param.walked + param.turnOriginRadian) + param.center[3]
                agv:setpos(x, y, z)
                -- 记录轨迹
                table.insert(param.trail, x)
                table.insert(param.trail, y)
                table.insert(param.trail, z)

                -- 设置旋转
                param.walked = param.walked + dRadian
                -- agv.roty = agv.roty + dRadian*2 --为什么要*2 ???
                agv.roty = math.atan(param[2].vecE[1], param[2].vecE[3]) + param.walked - math.atan(0, 1)
                agv:setrot(0, agv.roty, 0)
            end
        end
    end

    -- 添加任务
    function agv:addtask(obj)
        table.insert(agv.tasksequence, obj)
    end

    -- 删除任务
    function agv:deltask()
        -- 判断是否具有子任务序列
        if agv.tasksequence[1].subtask ~= nil and #agv.tasksequence[1].subtask > 0 then -- 子任务序列不为空，删除子任务中的任务
            table.remove(agv.tasksequence[1].subtask, 1)
            return
        end

        table.remove(agv.tasksequence, 1)

        if (agv.tasksequence[1] ~= nil and agv.tasksequence[1][1] == "attach") then
            print("[agv] task executing: ", agv.tasksequence[1][1])
        end
    end

    function agv:maxstep() -- 初始化和计算最大允许步进时间
        local dt = math.huge -- 初始化步进
        if agv.tasksequence[1] == nil then -- 对象无任务，直接返回最大值
            return dt
        end

        local taskname = agv.tasksequence[1][1] -- 任务名称
        local param = agv.tasksequence[1][2] -- 任务参数

        -- 判断子任务序列
        if taskname == "queue" then -- {"queue", subtask={...}}
            if #param.subtask == 0 then -- 子任务序列为空，删除queue任务
                agv:deltask()
                return agv:maxstep() -- 重新计算
            end

            -- 执行子任务
            taskname = param.subtask[1][1]
            param = param.subtask[1][2]
        end

        if taskname == "move2" then -- {"move2",x,z,[occupy=,]} 移动到指定位置 {x,z, 向量距离*2(3,4), moved*2(5,6), 初始位置*2(7,8)},occupy:当前占用道路位置
            -- 初始判断
            if param.vectorDistanceXZ == nil then -- 没有计算出向量距离，说明没有初始化
                local x, _, z = agv:getpos() -- 获取当前位置

                param.vectorDistanceXZ = {param[1] - x, param[2] - z} -- xz方向需要移动的距离
                if param.vectorDistanceXZ[1] == 0 and param.vectorDistanceXZ[2] == 0 then
                    print("Exception: agv不需要移动", " currentoccupy=", param.occupy)
                    agv:deltask()
                    -- return
                    return agv:maxstep() -- 重新计算
                end

                param.movedXZ = {0, 0} -- xz方向已经移动的距离
                param.originXZ = {x, z} -- xz方向初始位置

                local l = math.sqrt(param.vectorDistanceXZ[1] ^ 2 + param.vectorDistanceXZ[2] ^ 2)
                param.speed = {param.vectorDistanceXZ[1] / l * agv.speed, param.vectorDistanceXZ[2] / l * agv.speed} -- xz向量速度分量
            end

            for i = 1, 2 do
                if param.vectorDistanceXZ[i] ~= 0 then -- 只要分方向移动，就计算最大步进
                    dt = math.min(dt, math.abs((param[i] - param.originXZ[i] - param.movedXZ[i]) / param.speed[i]))
                end
            end
        elseif taskname == "moveon" then -- {"moveon",{road=,distance=,targetDistance=}} 沿着当前道路行驶
            -- 未注册道路
            if agv.road == nil then
                if param.road == nil then -- 未注册道路
                    print("Exception: agv未注册道路")
                    agv:deltask()
                    return agv:maxstep() -- 重新计算
                end

                -- 注册道路
                param.road:registerAgv(agv, {
                    -- 输入参数，并使用registerAgv的nil检测
                    distance = param.distance,
                    targetDistance = param.targetDistance
                })
            end

            -- 判断agv状态
            if agv.state == "wait" then -- agv状态为等待
                return dt -- 不做计算
            end

            local road = agv.road -- 获取道路
            dt = math.min(dt, road:maxstep(agv.roadAgvId)) -- 使用road中的方法计算最大步进
        elseif taskname == "onnode" then -- {"onnode", node, fromRoad, toRoad} 输入通过节点到达的道路id
            agv.road = nil -- 清空agv道路信息
            -- 默认已经占用了节点
            local node = param[1]

            -- 判断是否初始化
            if param.deltaRadian == nil then
                -- 判断是否在本节点终止
                if param[3] == nil then
                    -- 在本节点终止
                    node.occupied = false -- 解除节点占用

                    agv:deltask()
                    return agv:maxstep() -- 重新计算
                end

                -- print("agv", agv.id, " 'onnode' ", param[1].id) -- debug
                -- 获取道路信息
                local fromRoad = param[2]
                local toRoad = param[3]

                -- 获取fromRoad的终点坐标。由于已知角度，toRoad的起点坐标就不需要了
                local fromRoadEndPoint = fromRoad.destPt -- {x,y,z}

                -- 到达节点（转弯）
                -- 计算需要旋转的弧度(两条道路向量之差的弧度，Road1->Road2)
                param.fromRadian = math.atan(fromRoad.vecE[1], fromRoad.vecE[3]) - math.atan(0, 1)
                param.toRadian = math.atan(toRoad.vecE[1], toRoad.vecE[3]) - math.atan(0, 1)
                param.deltaRadian = param.toRadian - param.fromRadian
                param.walked = 0 -- 已经旋转的弧度/已经通过的直线距离

                -- 判断是否需要转弯（可能存在直线通过的情况）
                if param.deltaRadian % math.pi ~= 0 then
                    param.radius = node.radius / math.tan(math.abs(param.deltaRadian) / 2) -- 转弯半径
                    -- debug
                    -- print('node radius:', node.radius, 'param deltaRadian:', param.deltaRadian)
                    -- print('radius:', param.radius)

                    -- 计算圆心
                    -- 判断左转/右转，左转deltaRadian > 0，右转deltaRadian < 0
                    param.direction = param.deltaRadian / math.abs(param.deltaRadian) -- 用于设置步进方向

                    -- 向左旋转90度坐标为(z,-x)，向右旋转90度坐标为(-z,x)
                    if param.deltaRadian > 0 then
                        -- 左转
                        -- 向左旋转90度vecE坐标变为(z,-x)
                        param.center = {fromRoadEndPoint[1] + param.radius * fromRoad.vecE[3], fromRoadEndPoint[2],
                                        fromRoadEndPoint[3] + param.radius * -fromRoad.vecE[1]}
                        param.turnOriginRadian = math.atan(-fromRoad.vecE[3], fromRoad.vecE[1]) -- 转弯圆的起始位置弧度(右转)
                    else
                        -- 右转
                        -- 向右旋转90度vecE坐标变为(-z,x)
                        param.center = {fromRoadEndPoint[1] + param.radius * -fromRoad.vecE[3], fromRoadEndPoint[2],
                                        fromRoadEndPoint[3] + param.radius * fromRoad.vecE[1]}
                        param.turnOriginRadian = math.atan(fromRoad.vecE[3], -fromRoad.vecE[1]) -- 转弯圆的起始位置弧度(左转)
                    end

                    -- print('agv', agv.id, '在node', node.id, (param.deltaRadian > 0 and '左' or '右'),
                    --     '转 (deltaRadian=', param.deltaRadian, ')') -- debug

                    -- 显示转弯圆心
                    scene.addobj('points', {
                        vertices = param.center,
                        color = 'red',
                        size = 5
                    })
                    -- 显示半径连线
                    scene.addobj('polyline', {
                        vertices = {fromRoadEndPoint[1], fromRoadEndPoint[2], fromRoadEndPoint[3], param.center[1],
                                    param.center[2], param.center[3], toRoad.originPt[1], toRoad.originPt[2],
                                    toRoad.originPt[3]},
                        color = 'red'
                    })
                    -- 计算两段半径的长度
                    local l1 = math.sqrt((fromRoadEndPoint[1] - param.center[1]) ^ 2 +
                                             (fromRoadEndPoint[2] - param.center[2]) ^ 2 +
                                             (fromRoadEndPoint[3] - param.center[3]) ^ 2)
                    local l2 = math.sqrt((toRoad.originPt[1] - param.center[1]) ^ 2 +
                                             (toRoad.originPt[2] - param.center[2]) ^ 2 +
                                             (toRoad.originPt[3] - param.center[3]) ^ 2)
                    -- print('Rfrom:', l1, '\tRto:', l2) --debug
                    -- 初始化轨迹
                    param.trail = {fromRoadEndPoint[1], fromRoadEndPoint[2], fromRoadEndPoint[3]}

                    -- 计算角速度
                    param.angularSpeed = agv.speed / param.radius / 2
                end
            end

            -- 计算最大步进
            local timeRemain
            if param.deltaRadian == 0 then
                -- 直线通过，不存在角速度
                local distanceRemain = node.radius * 2 - param.walked -- 计算剩余距离
                timeRemain = math.abs(distanceRemain / agv.speed)
            else
                -- 转弯，存在角速度
                local radianRemain = param.deltaRadian - param.walked -- 计算剩余弧度
                timeRemain = math.abs(radianRemain / param.angularSpeed)
            end

            dt = math.min(dt, agv.state == nil and timeRemain or dt) -- 计算最大步进，跳过agv等待状态的情况
        end
        return dt
    end

    function agv:InSafetyDistance(targetAgv)
        local tx, ty, tz = targetAgv:getpos()
        local x, y, z = agv:getpos()
        local d = math.sqrt((tx - x) ^ 2 + (tz - z) ^ 2)
        return d < agv.safetyDistance
    end

    return agv
end
