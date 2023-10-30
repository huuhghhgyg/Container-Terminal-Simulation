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
    rmg.speed = {8, 4} -- x,y方向的移动速度
    rmg.zspeed = 2 -- 车移动速度
    rmg.attached = nil -- 抓取的集装箱
    rmg.stash = nil -- io物品暂存
    rmg.agvqueue = {} -- agv服务队列
    rmg.bay = nil

    rmg.outerActionObjs = actionObjs -- 注入的外部动作队列

    -- 初始化位置
    rmg.origin = cy.origin -- 原点
    rmg:setpos(table.unpack(rmg.origin)) -- 设置车的位置
    trolley:setpos(table.unpack(rmg.origin)) -- 设置trolley的位置
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
    function rmg:attach(bay, row, level)
        if bay == nil then -- 如果没有指定位置，则为抓取agv上的集装箱
            -- 从暂存中取出集装箱
            rmg.attached = rmg.stash
            rmg.stash = nil
            return
        end

        -- 抓取堆场中的集装箱
        rmg.attached = rmg.cy.containers[bay][row][level]
        rmg.cy.containers[bay][row][level] = nil
    end

    -- 放箱子
    function rmg:detach(bay, row, level)
        if bay == nil then
            -- 如果没有指定位置，则将集装箱放置到对应bay位置的agv位置上
            rmg.stash = rmg.attached
            rmg.attached = nil
            return
        end

        -- 将集装箱放到船上的指定位置
        rmg.cy.containers[bay][row][level] = rmg.attached
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
            -- 计算移动值
            local ds = {}
            for i = 1, 2 do
                ds[i] = param.speed[i] * dt -- dt移动
            end
            ds[3] = param.speed[3] * dt -- rmg向量速度*时间

            -- 判断bay方向是否已经到达目标
            if not param.arrivedZ then
                -- bay方向没有到达目标
                if (param.movedZ + ds[3]) / (param[3] - param.initalZ) > 1 then -- 首次到达目标
                    rmg:move(param[3] - param.initalZ - param.movedZ)
                    param.arrivedZ = true
                else
                    param.movedZ = param.movedZ + ds[3] -- 已移动bay
                    rmg:move(ds[3])
                end
            end

            for i = 1, 2 do
                -- 判断X/Y方向是否到达目标
                if not param.arrivedXY[i] then
                    -- 未到达目标，判断本次移动是否能到达目标
                    if (param[i] - param.currentXY[i] - ds[i]) * param.vectorXY[i] <= 0 then
                        -- 分方向到达目标/经过此次计算分方向到达目标
                        param.currentXY[i] = param[i] -- 设置到累计移动值
                        param.arrivedXY[i] = true -- 设置到达标志，禁止进入判断
                    else
                        -- 分方向没有到达目标
                        param.currentXY[i] = param.currentXY[i] + ds[i] -- 累计移动
                    end
                end
            end

            -- 执行移动
            rmg:spreaderMove2(param.currentXY[1], param.currentXY[2], 0) -- 设置到累计移动值

            if param.arrivedZ and param.arrivedXY[1] and param.arrivedXY[2] then
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
        elseif taskname == "attach" then -- {"attach", {row, col, level}}
            if param == nil then
                param = {nil, nil, nil}
            end
            rmg:attach(param[1], param[2], param[3])
            rmg:deltask()
        elseif taskname == "detach" then -- {"detach", {row, col, level}}
            if param == nil then
                param = {nil, nil, nil}
            end
            rmg:detach(param[1], param[2], param[3])
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
                    param.initalXY[i] = rmg.spreaderpos[i] -- 初始位置(10,11)
                    param.currentXY[i] = rmg.spreaderpos[i] -- 当前位置(8,9)
                    if param[i] - param.initalXY[i] == 0 then -- 目标距离差为0，向量设为0
                        param.vectorXY[i] = 0
                    else
                        param.vectorXY[i] = param[i] - param.initalXY[i] -- 计算初始向量
                    end
                end

                -- 判断是否到达目标
                param.arrivedZ = (param[3] == param.initalZ)
                param.arrivedXY = {param[1] == param.initalXY[1], param[2] == param.initalXY[2]}

                -- 计算各方向分速度
                param.speed = {param.vectorXY[1] / math.abs(param.vectorXY[1]) * rmg.speed[1],
                               param.vectorXY[2] / math.abs(param.vectorXY[2]) * rmg.speed[2],
                               rmg.zspeed * ((param[3] - rmg.pos) / math.abs(param[3] - rmg.pos))} -- speed[3]:速度乘方向
            end

            if not param.arrivedZ then -- bay方向没有到达目标
                dt = math.min(dt, math.abs((param[3] - param.initalZ - param.movedZ) / param.speed[3]))
            end

            for i = 1, 2 do -- 判断X/Y(col/level)方向有没有到达目标
                if not param.arrivedXY[i] then -- 如果没有达到目标
                    if param.vectorXY[i] ~= 0 then
                        local taskRemainTime = (param[i] - param.currentXY[i]) / param.speed[i] -- 计算本方向任务的剩余时间
                        if taskRemainTime < 0 then
                            print('[警告!] rmg:maxstep(): XY方向[', i, ']的剩余时间小于0,已调整为0') -- 如果print了这行，估计是出问题了
                            taskRemainTime = 0
                        end

                        dt = math.min(dt, taskRemainTime)
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
            x = cy.parkingSpaces[bay].iox + cy.containerPositions[1][cy.row][1][1] -- 加一个cy.origin.x，减一个rmg.origin.x，就没了
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

    -- 将集装箱从agv抓取到目标位置，默认在移动层
    function rmg:lift2TargetPos(bay, row, level)
        rmg:addtask({"move2", rmg:getContainerCoord(bay, -1, 1)}) -- 抓取agv上的箱子
        rmg:addtask({"attach", nil}) -- 抓取
        rmg:addtask({"move2", rmg:getContainerCoord(bay, -1, rmg.toplevel)}) -- 吊具提升到移动层
        rmg:addtask({"move2", rmg:getContainerCoord(bay, row, rmg.toplevel)}) -- 移动爪子到指定位置
        rmg:addtask({"move2", rmg:getContainerCoord(bay, row, level)}) -- 移动爪子到指定位置
        rmg:addtask({"detach", {bay, row, level}}) -- 放下指定箱
        rmg:addtask({"move2", rmg:getContainerCoord(bay, row, rmg.toplevel)}) -- 爪子抬起到移动层
    end

    -- 将集装箱从目标位置移动到agv，默认在移动层
    function rmg:lift2Agv(bay, row, level)
        rmg:addtask({"move2", rmg:getContainerCoord(bay, row, level)}) -- 移动爪子到指定位置
        rmg:addtask({"attach", {bay, row, level}}) -- 抓取
        rmg:addtask({"move2", rmg:getContainerCoord(bay, row, rmg.toplevel)}) -- 吊具提升到移动层
        rmg:addtask({"move2", rmg:getContainerCoord(bay, -1, rmg.toplevel)}) -- 移动爪子到agv上方
        rmg:addtask({"move2", rmg:getContainerCoord(bay, -1, 1)}) -- 移动爪子到agv
        rmg:addtask({"detach", nil}) -- 放下指定箱
        rmg:addtask({"move2", rmg:getContainerCoord(bay, -1, rmg.toplevel)}) -- 爪子抬起到移动层
    end

    -- 移动到目标位置，默认在移动层
    function rmg:move2TargetPos(bay, row)
        rmg:addtask({"move2", rmg:getContainerCoord(bay, row, rmg.toplevel)})
    end

    -- 移动到agv上方，默认在移动层
    function rmg:move2Agv(bay)
        rmg:addtask({"move2", rmg:getContainerCoord(bay, -1, rmg.toplevel)})
    end

    -- 添加任务

    -- 注册到动作队列
    table.insert(actionObjs, rmg) -- 注意！如果以后要管理多个堆场，这行需要修改！

    return rmg
end
