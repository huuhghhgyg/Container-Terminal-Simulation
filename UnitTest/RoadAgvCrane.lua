require('agv')

-- 控制器
scene.setenv({
    grid = 'plane'
})

-- 参数设置
local simv = 1 -- 仿真速度
local actionObjs = {} -- 动作队列声明
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
    for i = 1, #actionObjs do
        if #actionObjs[i].tasksequence > 0 then
            maxstep = math.min(maxstep, actionObjs[i]:maxstep())
        end
    end

    -- 执行更新
    for i = 1, #actionObjs do
        actionObjs[i]:executeTask(dt)
    end

    -- 回收
    for i = 1, #actionObjs do
        local obj = actionObjs[i]

        if obj.type == "agv" and #obj.tasksequence == 0 then
            recycle(obj)
            table.remove(actionObjs, i)
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

require('road')
require('cy')

--- 起重机对象
---@param cy any 堆场对象
---@param actionObjs table 动作队列，用于向队列中插入对象(DI)
function RMG(cy, actionObjs)
    -- 依赖检查
    if #cy.parkingSpaces == 0 then
        print("RMG错误：RMG注入的堆场对象没有绑定道路。请先绑定道路")
        return
    end

    -- 初始化对象
    local rmg = scene.addobj('/res/ct/rmg.glb')
    local trolley = scene.addobj('/res/ct/trolley.glb')
    local spreader = scene.addobj('/res/ct/spreader.glb')
    local wirerope = scene.addobj('/res/ct/wirerope.glb')

    -- 参数设置
    rmg.type = "rmg" -- 对象种类标识(interface)
    rmg.cy = cy -- 初始化对应堆场
    rmg.cy.rmg = rmg -- 堆场对应rmg(控制反转)
    rmg.level = {}
    for i = 1, #cy.levels do
        rmg.level[i] = cy.levels[i] + cy.cheight
    end
    rmg.toplevel = #rmg.level -- 最高层(吊具行走层)
    rmg.level.agv = 2.1 -- agv高度
    rmg.spreaderpos = {0, rmg.level[2], 0} -- 初始位置(x,y)
    rmg.pos = 0 -- 初始位置(x,y,z)
    rmg.tasksequence = {} -- 初始化任务队列
    rmg.iox = -16 -- 进出口x坐标
    rmg.speed = 4 -- 移动速度
    rmg.zspeed = 2 -- 车移动速度
    rmg.attached = nil -- 抓取的集装箱
    rmg.stash = nil -- io物品暂存
    rmg.agvqueue = {} -- agv服务队列
    rmg.bay = nil

    rmg.outerActionObjs = actionObjs -- 注入的外部动作队列

    -- cy:initqueue(rmg.iox) -- 初始化停车队列

    -- 初始化位置
    rmg.origin = cy.origin -- 原点
    rmg:setpos(rmg.origin[1], rmg.origin[2], rmg.origin[3]) -- 设置车的位置
    trolley:setpos(rmg.origin[1], rmg.origin[2], rmg.origin[3]) -- 设置trolley的位置
    wirerope:setscale(1, rmg.origin[2] + 17.57 - rmg.spreaderpos[2], 1) -- trolly离地面高度17.57，wirerope长宽设为1
    wirerope:setpos(rmg.origin[1] + rmg.spreaderpos[1], rmg.origin[2] + 1.15 + rmg.spreaderpos[2], rmg.origin[3] + 0) -- spreader高度1.1
    spreader:setpos(rmg.origin[1] - 0.01 + rmg.spreaderpos[1], rmg.origin[2] + rmg.spreaderpos[2] + 0.05,
        rmg.origin[3] + 0.012)

    rmg.trolley = trolley
    rmg.spreader = spreader
    rmg.wirerope = wirerope

    -- 函数
    -- 注册agv
    function rmg:registerAgv(agv)
        local targetcontainer = agv.targetcontainer -- 获取目标集装箱
        agv.worktype = "rmg" -- 正在为rmg工作
        table.insert(rmg.agvqueue, agv) -- 加入agv队列
        for i = 1, rmg.cy.agvspan do
            rmg.cy.parkingspace[i].occupied = rmg.cy.parkingspace[i].occupied + 1 -- 停车位占用数+1
        end
        table.insert(rmg.outerActionObjs, agv) -- 加入动作队列

        rmg:attachContainer(table.unpack(targetcontainer)) -- 抓取集装箱
        rmg:addtask({"waitagv"}) -- 等待agv到达
        rmg:lift2Agv(targetcontainer[1], targetcontainer[2]) -- 将抓住的集装箱移动到agv上
    end

    -- 抓箱子
    function rmg:attach(row, col, level)
        rmg.attached = rmg.cy.containers[row][col][level]
        rmg.cy.containers[row][col][level] = nil
    end

    -- 放箱子
    function rmg:detach()
        rmg.stash = rmg.attached
        rmg.attached = nil
    end

    -- 爪子移动
    -- x移动：横向；y移动：上下；z移动(负方向)：纵向(微调,不常用)
    function rmg:spreaderMove(dx, dy, dz)
        rmg.spreaderpos = {rmg.spreaderpos[1] + dx, rmg.spreaderpos[2] + dy, rmg.spreaderpos[3] + dz}
        local wx, wy, wz = rmg.wirerope:getpos()
        local sx, sy, sz = rmg.spreader:getpos()
        local tx, ty, tz = rmg.trolley:getpos()

        rmg.wirerope:setpos(wx + dx, wy + dy, wz - dz)
        rmg.wirerope:setscale(1, 17.57 - wy - dy, 1)
        rmg.trolley:setpos(tx + dx, ty, tz)
        rmg.spreader:setpos(sx + dx, sy + dy, sz - dz)

        -- 移动箱子
        if rmg.attached then
            local cx, cy, cz = rmg.attached:getpos()
            rmg.attached:setpos(cx + dx, cy + dy, cz - dz)
        end
    end

    -- 移动到指定位置
    function rmg:spreaderMove2(x, y, z)
        rmg:spreaderMove(x - rmg.spreaderpos[1], y - rmg.spreaderpos[2], z - rmg.spreaderpos[3])
    end

    -- 车移动(-z方向)
    function rmg:move(dist)
        rmg.pos = rmg.pos + dist
        local wx, wy, wz = rmg.wirerope:getpos()
        local sx, sy, sz = rmg.spreader:getpos()
        local tx, ty, tz = rmg.trolley:getpos()
        local rx, ry, rz = rmg:getpos()

        rmg.wirerope:setpos(wx, wy, wz + dist)
        rmg.spreader:setpos(sx, sy, sz + dist)
        rmg.trolley:setpos(tx, ty, tz + dist)
        rmg:setpos(rx, ry, rz + dist)

        -- 移动箱子
        if rmg.attached then
            local cx, cy, cz = rmg.attached:getpos()
            rmg.attached:setpos(cx, cy, cz + dist)
        end
    end

    -- task: {任务名称,{参数}}
    function rmg:executeTask(dt)
        if #rmg.tasksequence == 0 then
            return
        end

        local task = rmg.tasksequence[1]
        local taskname, param = task[1], task[2]
        if taskname == "move2" then -- 1:col(x), 2:height(y), 3:bay(z), [4:初始bay, 5:已移动bay距离,向量*2(6,7),当前位置*2(8,9),初始位置*2(10,11),到达(12,13)*2]
            local ds = {}
            -- 计算移动值
            for i = 1, 2 do
                ds[i] = param.speed[i] * dt -- dt移动
                param.currentXY[i] = param.currentXY[i] + ds[i] -- 累计移动
            end
            ds[3] = param.speed[3] * dt -- rmg向量速度*时间

            if not param.arrivedZ then -- bay方向没有到达目标                
                if (param.movedZ + ds[3]) / (param[3] - param.initalZ) > 1 then -- 首次到达目标
                    rmg:move(param[3] - param.initalZ - param.movedZ)
                    param.arrivedZ = true
                else
                    param.movedZ = param.movedZ + ds[3] -- 已移动bay
                    rmg:move(ds[3])
                end
            end

            if not param.arrivedX then -- 列方向没有到达目标
                for i = 1, 2 do
                    if param.vectorXY[i] ~= 0 and (param[i] - param.currentXY[i]) * param.vectorXY[i] <= 0 then -- 分方向到达目标
                        rmg:spreaderMove2(param[1], param[2], 0)
                        param.arrivedX = true
                        break
                    end
                end
                rmg:spreaderMove2(param.currentXY[1], param.currentXY[2], 0) -- 设置到累计移动值
            end

            if param.arrivedZ and param.arrivedX then
                rmg:deltask()
            end
        elseif taskname == "waitagv" then -- {"waitagv", nil}
            if rmg.agvqueue[1] == nil then
                print("rmg: rmg.agvqueue[1]=nil, #rmg.agvqueue=", #rmg.agvqueue)
            end
            if rmg.agvqueue[1] ~= nil and rmg.agvqueue[1].arrived then -- agv到达
                table.remove(rmg.agvqueue, 1) -- 移除等待的agv
                rmg:deltask()
            end
        elseif taskname == "attach" then -- {"attach", {cy.row,cy.col,cy.level}}
            rmg:attach(param[1], param[2], param[3])
            rmg.bay = param[1]
            rmg:deltask()
        elseif taskname == "detach" then -- {"detach", nil}
            rmg:detach()
            rmg:deltask()
        end
    end

    -- interface:计算最大允许步进
    function rmg:maxstep()
        local dt = math.huge -- 初始化步进
        if rmg.tasksequence[1] == nil then -- 对象无任务，直接返回0
            return dt
        end

        local taskname = rmg.tasksequence[1][1] -- 任务名称
        local param = rmg.tasksequence[1][2] -- 任务参数
        if taskname == "move2" then
            if param.initalZ == nil then
                param.initalZ = rmg.pos -- 初始位置
                param.movedZ = 0 -- 已经移动的距离

                param.vectorXY = {} -- 初始化向量(6,7)
                param.currentXY = {} -- 初始化当前位置(8,9)
                param.initalXY = {} -- 初始化初始位置(10,11)
                for i = 1, 2 do
                    param.currentXY[i] = rmg.spreaderpos[i] -- 当前位置(8,9)
                    param.initalXY[i] = rmg.spreaderpos[i] -- 初始位置(10,11)
                    if param[i] - param.initalXY[i] == 0 then -- 目标距离差为0，向量设为0
                        param.vectorXY[i] = 0
                    else
                        param.vectorXY[i] = param[i] - param.initalXY[i] -- 计算初始向量
                    end
                end
                param.arrivedZ, param.arrivedX = param[3] == param.initalZ, false

                -- 计算各方向分速度
                local l = math.sqrt(param.vectorXY[1] ^ 2 + param.vectorXY[2] ^ 2)
                param.speed = {param.vectorXY[1] / l * rmg.speed, param.vectorXY[2] / l * rmg.speed,
                               rmg.zspeed * ((param[3] - rmg.pos) / math.abs(param[3] - rmg.pos))} -- speed[3]:速度乘方向
            end

            if not param.arrivedZ then -- bay方向没有到达目标
                dt = math.min(dt, math.abs((param[3] - param.initalZ - param.movedZ) / param.speed[3]))
            end
            if not param.arrivedX then -- 列方向没有到达目标
                for i = 1, 2 do
                    if param.vectorXY[i] ~= 0 then -- 只要分方向移动，就计算最大步进
                        dt = math.min(dt, (param[i] - param.currentXY[i]) / param.speed[i]) -- 根据move2判断条件
                    end
                end
            end
        end
        return dt
    end

    -- 添加任务
    function rmg:addtask(obj)
        table.insert(rmg.tasksequence, obj)
    end

    -- 删除任务
    function rmg:deltask()
        table.remove(rmg.tasksequence, 1)

        if (rmg.tasksequence[1] ~= nil and rmg.tasksequence[1][1] == "detach") then
            print("[rmg] task executing: ", rmg.tasksequence[1][1])
        end
    end

    -- 获取集装箱坐标{x,y,z}
    function rmg:getContainerCoord(bay, row, level)
        local x
        if row == -1 then
            -- x = rmg.iox
            x = cy.parkingSpaces[bay].iox+cy.containerPositions[1][cy.row][1][1] --加一个cy.origin.x，减一个rmg.origin.x，就没了
        else
            x = cy.containerPositions[1][row][1][1] - rmg.origin[1]
        end

        local ry = 0 -- 相对高度
        if row == -1 and level == 1 then -- 如果是要放下，则设置到移动到agv上
            ry = ry + rmg.level.agv -- 加上agv高度
        end
        ry = ry + rmg.level[level] -- 加上层高
        local y = ry - rmg.origin[2]
        local z = cy.containerPositions[bay][1][1][3] - cy.origin[3] -- 通过车移动解决z

        return {x, y, z}
    end

    -- 获取爪子移动坐标长度{dx,dy,dz}
    function rmg:getContainerDelta(dcol, dlevel)
        local dx = dcol * (cy.cwidth + cy.cspan)
        local dy = dlevel * rmg.level[1]
        local dz = 0 -- 通过车移动解决z

        return {dx, dy, dz}
    end

    -- 获取车移动坐标（z）
    function rmg:getlen(bay)
        return {cy.containerPositions[bay][1][1][3] - cy.origin[3]}
    end

    -- 添加任务，抓取指定位置的集装箱
    function rmg:attachContainer(bay, col, level)
        rmg:addtask({"move2", rmg:getContainerCoord(bay, col, rmg.toplevel)}) -- 移动爪子到指定位置
        rmg:addtask({"move2", rmg:getContainerCoord(bay, col, level)}) -- 移动爪子到指定位置
        rmg:addtask({"attach", {bay, col, level}}) -- 抓取指定箱
    end

    -- 添加任务，将attached的集装箱放到agv上
    function rmg:lift2Agv(bay, col)
        rmg:addtask({"move2", rmg:getContainerCoord(bay, col, rmg.toplevel)}) -- 将集装箱从目标向上提升
        rmg:addtask({"move2", rmg:getContainerCoord(bay, -1, rmg.toplevel)}) -- 移动集装箱到agv对应列
        rmg:addtask({"move2", rmg:getContainerCoord(bay, -1, 1)}) -- 放下箱子到agv上
        rmg:addtask({"detach"}) -- 放下指定箱
        rmg:addtask({"move2", rmg:getContainerCoord(bay, -1, rmg.toplevel)}) -- 吊具提升到移动层
    end

    -- 注册到动作队列
    table.insert(actionObjs, rmg) -- 注意！如果以后要管理多个堆场，这行需要修改！

    return rmg
end

-- 创建对象
local cy1 = CY({19.66 / 2, 51.49 / 2}, {-19.66 / 2, -51.49 / 2}, 3) -- 创建堆场
local road1 = Road({-15, 0, -50}, {-15, 0, 50}, roadList) -- 创建道路

-- 绑定道路
cy1:bindRoad(road1)
cy1:showBindingPoint()

local rmg1 = RMG(cy1, actionObjs) -- 创建rmg

scene.render()

-- 仿真任务
rmg1:addtask({'move2', rmg1:getContainerCoord(3, 2, 5)}) 
rmg1:addtask({'move2', rmg1:getContainerCoord(3, 2, 3)})
rmg1:addtask({'attach', {3, 2, 3}})
rmg1:addtask({'move2', rmg1:getContainerCoord(3, 2, 5)})
rmg1:addtask({'move2', rmg1:getContainerCoord(2, -1, 1)})

-- 开始仿真
update()
