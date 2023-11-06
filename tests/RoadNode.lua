-- 控制器
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

-- 引用库
require('agv')
require('road')
require('node')

-- 创建道路系统
local RoadList = {} -- 道路列表
local NodeList = {} -- 节点列表

local node1 = Node({0, 0, 10}, NodeList)
local node2 = Node({0, 0, 50}, NodeList)
local node3 = Node({30, 0, 50}, NodeList)

-- 手动绘制道路并连接
-- local road1 = Road({0, 0, 10}, {0, 0, 30}, RoadList)
-- node3:connectRoad(road1.id)
-- local road2 = Road({10, 0, 40}, {30, 0, 40}, RoadList)

local roadAuto1 = node1:createRoad(node2, RoadList)
local roadAuto2 = node2:createRoad(node3, RoadList)
print('autogen road:', roadAuto1, ', roadId=', roadAuto1.id)
print('autogen road:', roadAuto2, ', roadId=', roadAuto2.id)

-- 显示节点连接道路的状态
print('node1 connectedRoad:', #node1.connectedRoads)
print('node2 connectedRoad:', #node2.connectedRoads)
print('node3 connectedRoad:', #node3.connectedRoads)

scene.render()