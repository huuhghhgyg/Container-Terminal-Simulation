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

    road.originPt = originPt -- 出发点
    road.destPt = destPt -- 到达点

    -- 绘制路线始终点
    scene.addobj("points", {
        vertices = originPt,
        color = 'blue',
        size = 5
    })
    scene.addobj("points", {
        vertices = destPt,
        color = 'red', --到这个点检查注意是否需要停下来，所以是红色
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

    --- 向道路注册agv
    ---@class agv number agv实体
    ---@param params table 注册参数(targertDistance在道路上的目标移动距离, distance生成在道路上的初始距离)
    ---@return number 注册得到agv的id
    function road:registerAgv(agv, params)
        -- 参数处理，如果没有直接设为空
        if params == nil then
            params = {}
        end

        road.agvId = road.agvId + 1 -- id自增

        -- 向道路中插入对象
        table.insert(road.agvs, {
            agv = agv, -- agv实体
            id = road.agvId, -- 道路为此agv分配的id
            distance = params.distance or 0, -- agv在道路上移动的距离，初始为0
            targetDistance = params.targetDistance or road.length -- agv在道路上移动的目标距离，初始为道路长度（走完道路）
        })

        -- 向agv对象中注入道路对象和信息
        agv.road = road
        agv.roadAgvId = road.agvId

        return road.agvId -- 返回id
    end

    --- 从道路移除agv
    ---@param agvId 指定的agv的id
    function road:removeAgv(agvId)
        table.remove(road.agvs, agvId - road.agvLeaveNum)
        road.agvLeaveNum = road.agvLeaveNum + 1
        print("删除agv，id为", agvId) -- debug
    end

    --- 获取指定id的agv前方的agv
    ---@param agvId number 指定的agv的id
    ---@return number agv对象或nil
    function road:getAgvAhead(agvId)
        if agvId - road.agvLeaveNum - 1 > 0 then
            -- print("找到前方agv,序号为",id - road.agvLeaveNum - 1) --debug
            return road.agvs[agvId - road.agvLeaveNum - 1].agv
        end
        -- print("没有找到前方agv") --debug
        return nil -- 没有找到前方的agv
    end

    --- 设置指定id的agv在道路上的位置(需要提前对dt进行maxstep验证)
    ---@param dt number 步进时间
    ---@param agvId number 指定的agv的id
    function road:setAgvPos(dt, agvId)
        -- 更新agv在道路上的位置
        local roadAgv = road.agvs[agvId - road.agvLeaveNum] -- 获取道路agv对象
        roadAgv.distance = roadAgv.distance + dt * roadAgv.agv.speed

        roadAgv.agv:setpos(originPt[1] + roadAgv.distance * road.vecE[1], originPt[2] + roadAgv.distance * road.vecE[2],
            originPt[3] + roadAgv.distance * road.vecE[3])
    end

    --- 获取指定id的agv的最大推进时间
    ---@param agvId number 指定的agv的id
    function road:maxstep(agvId)
        local roadAgv = road.agvs[agvId - road.agvLeaveNum] -- 获取道路agv对象
        local distanceRemain = roadAgv.targetDistance - roadAgv.distance -- 计算剩余距离
        return distanceRemain / roadAgv.agv.speed -- 计算最大步进时间
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
        return ((destPt[1] - originPt[1]) * (x - originPt[1]) + (destPt[3] - originPt[3]) *
                                    (z - originPt[3])) / road.length -- 投影距离
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
