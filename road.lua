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
    road.agvItems = {} -- {agv=*, id=*}
    road.agvItemId = 0 -- 初始化id，方便索引

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

        road.agvItemId = road.agvItemId + 1 -- id自增

        -- 向道路中插入对象
        table.insert(road.agvItems, {
            agv = agv, -- agv实体
            id = road.agvItemId, -- 道路为此agv分配的id
            distance = params.distance or 0, -- agv在道路上移动的距离，初始为0
            initDistance = params.distance or 0, -- 输入的初始距离，赋值为distance
            targetDistance = params.targetDistance or road.length -- agv在道路上移动的目标距离，初始为道路长度（走完道路）
        })

        -- 设置agv朝向和道路相同
        agv.roty = math.atan(road.vecE[1], road.vecE[3]) - math.atan(0, 1)
        agv:setrot(0, agv.roty, 0)

        -- 向agv对象中注入道路对象和信息
        agv.road = road -- 注入道路对象
        agv.roadAgvId = road.agvItemId

        return road.agvItemId -- 返回id
    end

    --- 从道路移除agv
    ---@param agvItemId number 道路对象中指定agvItem的id
    function road:removeAgv(agvItemId)
        local agvItem, agvItemIndex = road:getAgvItem(agvItemId) -- 获取道路agv对象和索引

        table.remove(road.agvItems, agvItemIndex)

        -- 删除agv上的道路信息
        agvItem.agv.road = nil
        agvItem.agv.roadAgvId = nil
    end

    -- 获取指定id的agvItem
    ---@param agvItemId number 道路对象中指定的agvItem的id
    ---@return table agvItem agvItem对象或nil
    ---@return number agvItemIndex agvItem在道路对象.agvs中的索引
    function road:getAgvItem(agvItemId)
        local agvItem = nil
        local agvItemIndex = nil
        for k, item in ipairs(road.agvItems) do
            if item.id == agvItemId then
                agvItem = item
                agvItemIndex = k
                return agvItem, agvItemIndex
            end
        end
    end

    --- 获取指定id的agv前方的agvItem
    ---@param agvItemId number 道路对象中指定的agv的id
    ---@return agv agv对象或nil
    function road:getAgvAhead(agvItemId)
        -- 如果道路上的agv数量小于2，说明只有当前agv在道路上，直接返回nil
        if #road.agvItems < 2 then
            return nil
        end

        local agvItem = road:getAgvItem(agvItemId) -- 获取道路agv对象和索引
        local lastItemDistance = math.huge
        local agvAhead = nil
        -- 由于agvItem的距离可能是乱序的，不一定符合FIFO，所以需要遍历所有agvItem
        -- 遍历道路上的agv，找到距离当前agv最近的agv
        for k, item in ipairs(road.agvItems) do
            if item.distance - agvItem.distance > 0 and item.distance - agvItem.distance < lastItemDistance then
                lastItemDistance = item.distance - agvItem.distance
                agvAhead = item.agv
            end
        end

        return agvAhead -- 返回值可能为nil
    end

    --- 设置指定id的agv在道路上的位置(需要提前对dt进行maxstep验证)
    ---@param dt number 本任务开始到现在的时间差
    ---@param agvItemId number 道路对象中指定的agv的id
    ---@return table position agv的位置
    function road:setAgvDistance(dt, agvItemId)
        -- 更新agv在道路上的位置
        local roadAgv = road:getAgvItem(agvItemId) -- 获取agvItem

        -- 不管是否到达，都根据dt计算距离
        roadAgv.distance = roadAgv.initDistance + dt * roadAgv.agv.speed -- 更新距离
        return road:setAgvPosition(roadAgv.distance, agvItemId)
    end

    --- 根据指定id的agv在道路上的距离设置agv坐标位置
    -- @param distance number 距离
    -- @param agvItemId number 道路对象中指定的agv的id
    -- @return table position agv的位置
    function road:setAgvPosition(distance, agvItemId)
        local roadAgv = road:getAgvItem(agvItemId) -- 获取agvItem
        -- 计算位置
        local position = {}
        for i = 1, 3 do
            position[i] = originPt[i] + distance * road.vecE[i]
        end
        roadAgv.agv:setpos(table.unpack(position)) -- 设置agv位置
        return position
    end

    --- 获取指定id的agv的最大推进时间
    ---@param agvItemId number 道路对象中指定的agv的id
    function road:timeRemain(agvItemId)
        local roadAgv = road:getAgvItem(agvItemId) -- 获取agvItem
        local distanceRemain = roadAgv.targetDistance - roadAgv.distance -- 计算剩余距离
        local timeRemain = distanceRemain / roadAgv.agv.speed -- 计算最大步进时间

        -- road没有连接到节点
        if road.toNode ~= nil then
            roadAgv.agv.state = nil -- 设置为正常状态
        end

        -- 检查timeRemain有效性
        if timeRemain < 0 then
            print(debug.traceback('road.timeRemain错误：剩余时间小于0'))
            os.exit()
        end

        return timeRemain -- 返回最大步进时间
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
