-- 控制器
scene.setenv({
    grid = 'plane'
})

-- 参数设置
local simv = 1 -- 仿真速度
local actionobj = {} -- 动作队列声明
local roadList = {} -- 道路列表

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

local rd1 = Road({0, 0, 10}, {0, 0, 50}, roadList)
local vec = rd1.vecE
print('rd1 vec:', vec[1], vec[2], vec[3])
scene.render()

-- 预先注册道路并设置道路上的初始距离
local agv2 = AGV()
local agv2Rd1Id = rd1:registerAgv(agv2, {
    distance = 5
})
agv2:addtask({"moveon"})
table.insert(actionobj, agv2)
print('agv2 rd1 id:', agv2Rd1Id)
print('agv2 rd1 distance:', rd1.agvs[agv2Rd1Id].distance)
print('agv2 rd1 target distance:', rd1.agvs[agv2Rd1Id].targetDistance)

-- 创建agv并沿着道路行驶
-- 预先注册道路
local agv1 = AGV()
local agv1Rd1Id = rd1:registerAgv(agv1)
print('agv1 rd1 id:', agv1Rd1Id)
print('agv1 rd1 agv ahead:', rd1:getAgvAhead(agv1Rd1Id))

agv1:addtask({"move2", {0, 10}})
agv1:addtask({"moveon"})
table.insert(actionobj, agv1)

-- 运行时（根据任务）注册道路
local agv3 = AGV()
agv3:addtask({"move2", {0, 10}})
agv3:addtask({"moveon",{road=rd1,distance=5}})
table.insert(actionobj, agv3)

update()
