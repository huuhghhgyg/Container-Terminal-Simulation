require('agv')

scene.setenv({
    grid = 'plane'
})

-- 参数设置
local simv = 1 -- 仿真速度
local actionobj = {} -- 动作队列声明

-- 程序控制
local runcommand = true

-- 初始时间
local t = os.clock()
local dt = 0

function update()
    if runcommand then
        coroutine.queue(dt, update)
    end

    -- 计算最大更新时间
    local maxstep = math.huge
    for i = 1, #actionobj do
        if #actionobj[i].tasksequence > 0 then
            maxstep = math.min(maxstep, actionobj[i]:maxstep())
        end
    end

    -- 执行更新
    for i = 1, #actionobj do
        actionobj[i]:executeTask(dt)
    end

    -- 回收
    for i = 1, #actionobj do
        local obj = actionobj[i]

        if obj.type == "agv" and #obj.tasksequence == 0 then
            recycle(obj)
            table.remove(actionobj, i)
            break -- 假设每次同时只能到达一个，因此可以中止
        end
    end

    -- 绘图
    runcommand = scene.render()

    -- 刷新时间间隔
    dt = (os.clock() - t) * simv
    dt = math.min(dt, maxstep)
    t = os.clock()
end

function recycle(obj)
    if obj.type == "agv" then
        if obj.container ~= nil then
            obj.container:delete()
        end
        obj:delete()
    end
end

-- 以上都是控制器的必要部分

--- 道路对象（测试）
---@param originPt table 出发点{x,y,z}
---@param destPt table 到达点{x,y,z}
function Road(originPt, destPt)
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
        color = 'red',
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
        -- 参数处理
        -- 目标距离参数处理
        if params==nil then
            params = {}
        end
        if params.targetDistance == nil then
            params.targetDistance = road.length -- 默认移动到道路末端
        end
        -- 初始距离参数处理
        if params.distance == nil then
            params.distance = 0 -- 默认初始距离为0
        end
        
        road.agvId = road.agvId + 1 -- id自增

        -- 向道路中插入对象
        table.insert(road.agvs, {
            agv = agv, -- agv实体
            id = road.agvId, -- 道路为此agv分配的id
            distance = params.distance, -- agv在道路上移动的距离
            targetDistance = params.targetDistance -- agv在道路上移动的目标距离
        })

        -- 向agv对象中注入道路对象和信息
        agv.road = road
        agv.roadAgvId = road.agvId

        return road.agvId -- 返回id
    end

    --- 从道路移除agv
    ---@param id 指定的agv的id
    function road:removeAgv(id)
        table.remove(road.agvs, id - road.agvLeaveNum)
        road.agvLeaveNum = road.agvLeaveNum + 1
        print("删除agv，id为", id) --debug
    end

    --- 获取指定id的agv前方的agv
    ---@param id number 指定的agv的id
    ---@return number agv对象或nil
    function road:getAgvAhead(id)
        if id - road.agvLeaveNum - 1 > 0 then
            -- print("找到前方agv,序号为",id - road.agvLeaveNum - 1) --debug
            return road.agvs[id - road.agvLeaveNum - 1].agv
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

    return road
end

-- 创建agv并执行一个简单的任务
local agv1 = AGV()

local rd1 = Road({0, 0, 10}, {0, 0, 50})
local vec = rd1.vecE
print('rd1 vec:', vec[1], vec[2], vec[3])
scene.render()

local agv2 = AGV()
local agv2Rd1Id = rd1:registerAgv(agv2,{distance=5})
agv2:addtask({"moveon"})
table.insert(actionobj, agv2)
print('agv2 rd1 id:', agv2Rd1Id)
print('agv2 rd1 distance:',rd1.agvs[agv2Rd1Id].distance)
print('agv2 rd1 target distance:',rd1.agvs[agv2Rd1Id].targetDistance)


local agv1Rd1Id = rd1:registerAgv(agv1)
print('agv1 rd1 id:', agv1Rd1Id)
print('agv1 rd1 agv ahead:', rd1:getAgvAhead(agv1Rd1Id))

agv1:addtask({"move2", {0, 10}})
agv1:addtask({"moveon"})
table.insert(actionobj, agv1)

local agv3 = AGV()
rd1:registerAgv(agv3)
agv3:addtask({"move2", {0, 10}})
agv3:addtask({"moveon"})
table.insert(actionobj, agv3)

update()
