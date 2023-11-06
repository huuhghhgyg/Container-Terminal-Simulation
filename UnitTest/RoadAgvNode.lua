-- 控制器
scene.setenv({
    grid = 'plane'
})

-- 参数设置
local simv = 4 -- 仿真速度
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

-- 创建节点
local node1 = Node({0, 0, 0}, NodeList)
local node2 = Node({0, 0, 50}, NodeList, {radius = 4})
-- local node3 = Node({50, 0, 50}, NodeList)
local node3 = Node({50, 0, 100}, NodeList)
local node4 = Node({100,0,150}, NodeList)
local node5 = Node({-50, 0, 50}, NodeList)

-- 创建道路
local roadAuto1 = node1:createRoad(node2, RoadList)
local roadAuto2 = node2:createRoad(node3, RoadList)
local roadAuto3 = node3:createRoad(node4, RoadList)
local roadAuto4 = node2:createRoad(node5, RoadList)
print('autogen road:', roadAuto1, ', roadId=', roadAuto1.id)
print('autogen road:', roadAuto2, ', roadId=', roadAuto2.id)

-- 运行时（根据任务）注册道路
local agv1 = AGV()
-- agv3:addtask("move2", {roadAuto1.originPt[1], roadAuto1.originPt[3]})
agv1:addtask("moveon",{road = roadAuto1, distance = 10})
agv1:addtask("onnode",{node2,roadAuto1,roadAuto2})
agv1:addtask("moveon",{road = roadAuto2})
agv1:addtask("onnode",{node3,roadAuto2,roadAuto3})
agv1:addtask("moveon",{road = roadAuto3})
agv1:addtask("onnode",{node4,roadAuto3})
table.insert(actionobj, agv1)

-- 右转的AGV
local agv2 = AGV()
agv2:addtask("moveon",{road = roadAuto1})
agv2:addtask("onnode",{node2,roadAuto1,roadAuto4})
agv2:addtask("moveon",{road = roadAuto4})
agv2:addtask("onnode",{node5,roadAuto4})
table.insert(actionobj, agv2)

-- 测试onnode任务的出口阻塞等待
local agv3 = AGV()
agv3.speed = 1.5 --设置agv低速阻塞，测试onnode任务的阻塞等待
agv3:addtask("moveon",{road = roadAuto3})
agv3:addtask("onnode",{node4,roadAuto3})
table.insert(actionobj, agv3)

-- 测试moveon任务的入口阻塞等待
local agv4 = AGV()
agv4:addtask("onnode",{node2,roadAuto1,roadAuto2})
agv4:addtask("moveon",{road = roadAuto2})
agv4:addtask("onnode",{node3,roadAuto2,roadAuto3})
agv4:addtask("moveon",{road = roadAuto3})
agv4:addtask("onnode",{node4,roadAuto3})
table.insert(actionobj, agv4)

update()