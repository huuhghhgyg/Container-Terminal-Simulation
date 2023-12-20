--- 道路对象（测试）
---@class Road
---@param originPt table 出发点{x,y,z}
---@param destPt table 到达点{x,y,z}
---@param roadList table 仿真控制器中的道路列表
function Road(originPt, destPt, roadList)
    -- 绘制路线本体
    local road = scene.addobj("polyline", {
        vertices = {originPt[1], originPt[2], originPt[3], destPt[1], destPt[2], destPt[3]},
        color = 'blue'
    })

    -- 起始点信息
    road.originPt = originPt -- 出发点
    road.destPt = destPt -- 到达点
    -- road.node = nil -- 连接到的Node对象等待注册
    road.fromNode = nil
    road.toNode = nil

    -- 绘制路线始终点
    scene.addobj("points", {
        vertices = originPt,
        color = 'blue',
        size = 5
    })
    scene.addobj("points", {
        vertices = destPt,
        color = 'red', -- 到这个点检查注意是否需要停下来，所以是红色
        size = 5
    })

    -- 道路车辆信息
    road.agvs = {} -- {agv=*, id=*}
    road.agvId = 0 -- 初始化id，方便索引
    road.agvLeaveNum = 0 -- 已离开agv数量

    --- 获取道路相关数据信息（单位向量、长度）
    road.vec = {road.destPt[1] - road.originPt[1], road.destPt[2] - road.originPt[2], road.destPt[3] - road.originPt[3]}
    road.length = math.sqrt(road.vec[1] ^ 2 + road.vec[2] ^ 2 + road.vec[3] ^ 2) -- 道路长度
    road.vecE = {road.vec[1] / road.length, road.vec[2] / road.length, road.vec[3] / road.length} -- 道路单位向量

    -- 注册道路
    table.insert(road, roadList)
    road.id = #roadList

    --- 向道路注册agv
    ---@class agv number agv实体
    ---@param params table 注册参数(targertDistance在道路上的目标移动距离, distance生成在道路上的初始距离)
    ---@return number 注册得到agv的id
    function road:registerAgv(agv, params)
        -- 参数处理，如果没有直接设为空
        if params == nil then
            params = {}
        end

        -- 遍历道路上的agv，如果有相同的agv，则不插入
        for k, v in ipairs(road.agvs) do
            if v.agv == agv then
                road.agvs[k].stay = params.stay or false -- 更新stay属性
                agv.state = nil
                road.agvs[k].distance = params.distance or road.agvs[k].distance -- 更新agv在道路上移动的距离，初始为0
                road.agvs[k].targetDistance = params.targetDistance or road.length -- 更新targetDistance属性
                return v.id -- 返回id
            end
        end

        road.agvId = road.agvId + 1 -- id自增

        -- 向道路中插入对象
        table.insert(road.agvs, {
            agv = agv, -- agv实体
            id = road.agvId, -- 道路为此agv分配的id
            distance = params.distance or 0, -- agv在道路上移动的距离，初始为0
            targetDistance = params.targetDistance or road.length, -- agv在道路上移动的目标距离，初始为道路长度（走完道路）
            stay = params.stay or false -- agv到达目标位置后是否停留在道路上，默认不停留
        })
        -- print('road', road.id, '注册agv',agv.id,' {distance=', road.agvs[#road.agvs].distance, ',targetDistance=',
        --     road.agvs[#road.agvs].targetDistance, '}') --debug

        -- 设置agv朝向和道路相同
        agv.roty = math.atan(road.vecE[1], road.vecE[3]) - math.atan(0, 1)
        agv:setrot(0, agv.roty, 0)

        -- 向agv对象中注入道路对象和信息
        agv.road = road -- 注入道路对象
        agv.roadAgvId = road.agvId

        return road.agvId -- 返回id
    end

    --- 从道路移除agv
    ---@param agvId 道路对象中指定的agv的id
    function road:removeAgv(agvId)
        local roadAgvItem = road.agvs[agvId - road.agvLeaveNum]
        if roadAgvItem.stay == true then
            -- debug
            -- print('[road] 由于agv', agvId, '启用了stay，因此不实质性删除\t#road.agvs=', #road.agvs,
            --     ' road.agvLeaveNum=', road.agvLeaveNum, '\t目标(',
            --     road.agvs[agvId - road.agvLeaveNum].agv.targetContainerPos[1],
            --     road.agvs[agvId - road.agvLeaveNum].agv.targetContainerPos[2],
            --     road.agvs[agvId - road.agvLeaveNum].agv.targetContainerPos[3], ')')

            roadAgvItem.agv.state = 'stay' -- 设置agv状态
            return -- 如果agv需要停留在道路上，则不删除
        end
        table.remove(road.agvs, agvId - road.agvLeaveNum)
        road.agvLeaveNum = road.agvLeaveNum + 1
        -- 删除agv上的道路信息
        roadAgvItem.agv.road = nil
        roadAgvItem.agv.roadAgvId = nil
        -- print("road", road.id, "删除agv，id为", agvId) -- debug
    end

    --- 获取指定id的agv前方的agvItem
    ---@param agvId number 道路对象中指定的agv的id
    ---@return agv agv对象或nil
    function road:getAgvAhead(agvId)
        if agvId - road.agvLeaveNum - 1 > 0 then
            -- print("找到前方agv,序号为",id - road.agvLeaveNum - 1) --debug
            return road.agvs[agvId - road.agvLeaveNum - 1]
        end
        -- print("没有找到前方agv") --debug
        return nil -- 没有找到前方的agv
    end

    --- 设置指定id的agv在道路上的位置(需要提前对dt进行maxstep验证)
    ---@param dt number 步进时间
    ---@param agvId number 道路对象中指定的agv的id
    function road:setAgvPos(dt, agvId)
        -- 更新agv在道路上的位置
        local roadAgv = road.agvs[agvId - road.agvLeaveNum] -- 获取道路agv对象

        -- 没有到达
        if roadAgv.distance <= roadAgv.targetDistance then
            roadAgv.distance = roadAgv.distance + dt * roadAgv.agv.speed -- 更新距离
            road:setAgvDistance(roadAgv.distance, agvId)
            return
        end
        -- （暂时不灵）如果到达，由于存在maxstep，所以不会出现超出的情况，因此不需要处理
    end

    --- 设置指定id的agv在道路上的距离
    function road:setAgvDistance(distance, agvId)
        local roadAgv = road.agvs[agvId - road.agvLeaveNum] -- 获取道路agv对象
        roadAgv.agv:move2(originPt[1] + distance * road.vecE[1], originPt[2] + distance * road.vecE[2],
            originPt[3] + distance * road.vecE[3])
    end

    --- 获取指定id的agv的最大推进时间
    ---@param agvId number 道路对象中指定的agv的id
    function road:maxstep(agvId)
        local roadAgv = road.agvs[agvId - road.agvLeaveNum] -- 获取道路agv对象
        -- print('agvId=', agvId, 'road.agvLeaveNum=', road.agvLeaveNum)
        local distanceRemain = roadAgv.targetDistance - roadAgv.distance -- 计算剩余距离
        local timeRemain = distanceRemain / roadAgv.agv.speed -- 计算最大步进时间
        -- print('agv' .. roadAgv.agv.id, 'distance=', roadAgv.distance)

        local roadAgvAhead = road:getAgvAhead(agvId) -- 获取前方agvItem
        -- print('agv' .. roadAgv.agv.id, 'roadAgvAhead=',
        --     roadAgvAhead ~= nil and roadAgvAhead.agv.id .. " agv" .. roadAgv.agv.id .. ".dist=" .. roadAgv.distance)

        -- 判断前方有无agv，且前方agv位置是否小于agv的目标位置
        if roadAgvAhead ~= nil and roadAgvAhead.distance < roadAgv.targetDistance then
            -- 前方有agv，前方agv位置小于道路目标距离位置
            local d = roadAgvAhead.distance - roadAgv.distance -- 计算与前面agv之间的距离
            local dRemain = d - roadAgv.agv.safetyDistance
            -- 根据剩余距离设置状态
            if dRemain < 0 then
                roadAgv.agv.state = 'wait' -- 设置为等待状态
            else
                roadAgv.agv.state = nil -- 设置为正常状态
            end

            local time -- 计算需要的时间

            -- 如果前后方agv的状态不同，则需要计算并判断剩余时间
            if roadAgvAhead.agv.state ~= roadAgv.agv.state then

                if dRemain < 0 then
                    -- dRemain小于0，说明在安全范围内，前方agv正在离开
                    time = -dRemain / roadAgvAhead.agv.speed -- 计算前方agv离开需要的时间
                else
                    -- dRemain大于0，说明在安全范围外，后方agv正在靠近
                    time = dRemain / roadAgv.agv.speed -- 计算后方agv到达需要的时间
                end

            elseif roadAgvAhead.agv.speed > roadAgv.agv.speed then
                -- 前后方agv状态相同，如果后方agv速度较大
                time = dRemain / (roadAgvAhead.agv.speed - roadAgv.agv.speed) -- 计算后方agv到达需要的时间
            end

            -- 判断计算的时间是否符合最小时间范围
            -- if timeRemain > time and time > 10e-3 then
            if time ~= nil and timeRemain > time and time > 10e-6 then
                return time -- 如果需要的时间小于最大步进时间(且在一定范围内)，则更新为最大步进时间
            end
        else
            -- 本道路前方无agv，考虑前方节点是否堵塞。
            -- 如果前方节点不堵塞，在安全距离足够的情况下占用节点。
            -- print('agv' .. roadAgv.agv.id, '前方无agv，道路连接到节点')
            if road.toNode ~= nil then
                -- 道路连接到节点
                if roadAgv.targetDistance == road.length then
                    if distanceRemain > roadAgv.agv.safetyDistance then
                        local checkTimeRemain = (distanceRemain - roadAgv.agv.safetyDistance) / roadAgv.agv.speed -- 计算离开点到安全距离点最大步进时间
                        -- print('agv' .. roadAgv.agv.id, 'checkTimeRemain=', checkTimeRemain)
                        return checkTimeRemain -- 返回最大步进时间
                    end

                    -- 道路剩余距离小于安全距离，判断前方节点是否占用。
                    -- if distanceRemain <= roadAgv.agv.safetyDistance then
                    -- 前方节点被占用，但不是本agv占用
                    if road.toNode.occupied and road.toNode.occupied ~= roadAgv.agv then
                        roadAgv.agv.state = 'wait'
                        return math.huge -- 不参与计算maxstep
                    end

                    -- 前方节点没有被占用/前方节点被本agv占用

                    -- 前方节点没有被占用，则占用节点
                    if not road.toNode.occupied then
                        road.toNode.occupied = roadAgv.agv -- 占用节点
                    end
                    -- 在推进时间过大的情况下，可能由于越过了安全距离导致无法占用，需要在execute中根据dt判断并占用
                    -- 恢复状态并返回timeRemain（相当于直接往下，不需要其他操作。相当于提早返回）
                    -- end
                end
            end

            -- road没有连接到节点
            roadAgv.agv.state = nil -- 设置为正常状态
        end

        -- print('agv' .. roadAgv.agv.id .. '最大步进时间仍为', timeRemain, 'distanceRemain=', distanceRemain)
        return timeRemain >= 0 and timeRemain or 0 -- 返回最大步进时间
    end

    function road:tryOccupyNextNode(roadAgv, occupyMethodText)
        local distanceRemain = roadAgv.targetDistance - roadAgv.distance -- 计算剩余距离

        -- 道路剩余距离小于安全距离，判断前方节点是否占用。
        if roadAgv.targetDistance == road.length and distanceRemain <= roadAgv.agv.safetyDistance then
            -- debug
            if road.toNode.occupied and road.toNode.occupied ~= roadAgv.agv then
                print('占用节点' .. road.toNode.id .. '的agvid为' .. road.toNode.occupied.id)
            end
            -- 前方节点被占用，但不是本agv占用
            if road.toNode.occupied and road.toNode.occupied ~= roadAgv.agv then
                roadAgv.agv.state = 'wait'
                return math.huge -- 不参与计算maxstep
            end

            -- 前方节点没有被占用，则占用节点
            -- 如果已经占用了且走到这里，说明为本agv占用节点
            if not road.toNode.occupied then
                print(
                    'agv' .. roadAgv.agv.id .. '在road的' .. occupyMethodText .. '中设置节点' .. road.toNode.id ..
                        '占用, distanceRemain=' .. distanceRemain, 'node' .. road.toNode.id .. '.occupied=',
                    road.toNode.occupied)
                road.toNode.occupied = roadAgv.agv -- 占用节点
            end
        end

        -- 在推进时间过大的情况下，可能由于越过了安全距离导致无法占用，需要在execute中根据dt判断并占用
    end

    --- 注册道路，返回注册id
    --- @return integer 道路id
    function road:register()
        roadList[#roadList + 1] = road
        return #roadList
    end
    road.id = road:register() -- 注册道路并获取道路id

    --- 获取点在道路方向上投影的距离
    function road:getRelativeDist(x, z)
        return ((destPt[1] - originPt[1]) * (x - originPt[1]) + (destPt[3] - originPt[3]) * (z - originPt[3])) /
                   road.length -- 投影距离
    end

    --- 根据向量，获取点在道路对向量上投影的距离
    ---@param x number 点的x坐标
    ---@param z number 点的z坐标
    ---@param vaX number 向量的a的x值
    ---@param vaZ number 向量的a的z值
    function road:getVectorRelativeDist(x, z, vaX, vaZ)
        local x1, z1 = originPt[1], originPt[3]
        local x2, z2 = x, z
        local vbX, vbZ = road.vecE[1], road.vecE[3]

        local m = ((x2 - x1) * vaX + (z2 - z1 * vaZ)) / (vaX * vbX + vaZ * vbZ) -- 计算参数
        local xm, ym = x1 + m * vbX, z1 + m * vbZ -- 计算投影点

        return math.sqrt((x1 - xm) ^ 2 + (z1 - ym) ^ 2) -- 计算距离
    end

    --- 获取道路上指定距离的点
    function road:getRelativePosition(dist)
        return originPt[1] + dist * road.vecE[1], originPt[2] + dist * road.vecE[2], originPt[3] + dist * road.vecE[3]
    end

    return road
end
