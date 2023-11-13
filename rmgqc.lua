function RMGQC(origin, actionObjs) -- origin={x,y,z}
    local rmgqc = scene.addobj('/res/ct/rmqc.glb')
    -- 模型组件
    rmgqc.trolley = scene.addobj('/res/ct/trolley_rmqc.glb')
    rmgqc.wirerope = scene.addobj('/res/ct/wirerope.glb')
    rmgqc.spreader = scene.addobj('/res/ct/spreader.glb')

    -- 参数
    rmgqc.type = 'rmgqc'
    rmgqc.origin = origin -- rmgqc初始位置
    rmgqc.pos = 0
    rmgqc.level = {}
    rmgqc.level.agv = 2.1 + 2.42
    -- rmgqc.shipposx = -30 -- 船离rmg原点的距离
    rmgqc.berthPosition = {origin[1] - 30, origin[2], origin[3]} -- 泊位位置
    rmgqc.ship = {} -- 对应的船
    rmgqc.iox = 0
    rmgqc.tasksequence = {} -- 初始化任务队列
    rmgqc.speed = {8, 5} -- 移动速度
    rmgqc.zspeed = 2 -- 车移动速度
    rmgqc.attached = nil -- 抓取的集装箱
    rmgqc.stash = nil -- io物品暂存
    rmgqc.agvqueue = {} -- agv服务队列
    rmgqc.bindingRoad = nil -- 绑定的道路
    rmgqc.parkingSpaces = {} -- 停车位对象(使用bay位置索引)
    -- rmgqc.queuelen = 11 -- 服务队列长度（额外）
    rmgqc.outerActionObjs = actionObjs -- 外部动作队列

    -- 初始化集装箱船高度
    for i = 1, 4 do
        rmgqc.level[i] = 11.29 + i * 2.42
    end
    rmgqc.toplevel = #rmgqc.level

    rmgqc.spreaderpos = {0, 0, 0}
    -- 初始化位置
    rmgqc.wirerope:setpos(rmgqc.origin[1] + 0, rmgqc.origin[2] + 1.1, rmgqc.origin[3])
    rmgqc.wirerope:setscale(1, (26.54 + 1.32 - 1.1) - (rmgqc.origin[2]), 1)
    rmgqc.spreader:setpos(rmgqc.origin[1] + 0, rmgqc.origin[2], rmgqc.origin[3])
    rmgqc.trolley:setpos(rmgqc.origin[1] + 0, rmgqc.origin[2], rmgqc.origin[3])
    rmgqc:setpos(rmgqc.origin[1], rmgqc.origin[2], rmgqc.origin[3])
    print("初始化：spreader z = ", rmgqc.origin[3])

    function rmgqc:registerAgv(agv)
        -- rmg添加任务
        if agv.taskType == 'unload' then
            -- print('[rmg] agv:unload, targetPos=(', agv.targetContainerPos[1], agv.targetContainerPos[2], agv.targetContainerPos[3], ')') -- debug
            rmgqc:move2Agv(agv.targetContainerPos[1])
            -- print('[rmgqc] move2Agv()完成') -- debug
            rmgqc:lift2TargetPos(table.unpack(agv.targetContainerPos))
            -- print('[rmgqc] lift2TargetPos()完成') -- debug
        elseif agv.taskType == 'load' then
            -- print('[rmgqc] agv:load') -- debug
            rmgqc:move2TargetPos(agv.targetContainerPos[1], agv.targetContainerPos[2])
            -- print('[rmgqc] move2TargetPos()完成') -- debug
            rmgqc:lift2Agv(table.unpack(agv.targetContainerPos))
            -- print('[rmgqc] lift2Agv()完成') -- debug
        else
            print('[rmgqc] 错误，没有检测到agv的任务类型，注册失败。')
            return
        end

        -- 注册agv
        table.insert(rmgqc.agvqueue, agv) -- 加入agv队列
    end

    -- 放箱子
    function rmgqc:detach(bay, row, level)
        if bay == nil then
            -- 如果没有指定位置，则将集装箱放置到对应bay位置的agv位置上
            rmgqc.stash = rmgqc.attached
            rmgqc.attached = nil
            return
        end

        -- 将集装箱放到船上的指定位置
        rmgqc.ship.containers[bay][row][level] = rmgqc.attached
        rmgqc.attached = nil
    end

    -- 抓箱子
    function rmgqc:attach(bay, row, level)
        if bay == nil then -- 如果没有指定位置，则为抓取agv上的集装箱
            -- 判断agv上的集装箱是否为空
            if rmgqc.stash == nil then
                print('[rmgqc] 错误，抓取agv上的集装箱为空')
                -- debug
                os.exit()
            end

            -- 从暂存中取出集装箱
            rmgqc.attached = rmgqc.stash
            rmgqc.stash = nil
            return
        end

        -- 判断抓取的集装箱是否为空
        if rmgqc.ship.containers[bay][row][level] == nil then
            print('[rmgqc] 错误，抓取堆场中的集装箱为空')
            -- debug
            os.exit()
        end

        -- 抓取堆场中的集装箱
        rmgqc.attached = rmgqc.ship.containers[bay][row][level]
        rmgqc.attached.tag = {bay, row, level} -- 给集装箱设置tag
        rmgqc.ship.containers[bay][row][level] = nil
    end

    -- 爪子移动
    -- x移动：横向；y移动：上下；z移动(负方向)：纵向(微调,不常用)
    function rmgqc:spreadermove(dx, dy, dz)
        rmgqc.spreaderpos = {rmgqc.spreaderpos[1] + dx, rmgqc.spreaderpos[2] + dy, rmgqc.spreaderpos[3] + dz}
        local wx, wy, wz = rmgqc.wirerope:getpos()
        local sx, sy, sz = rmgqc.spreader:getpos()
        local tx, ty, tz = rmgqc.trolley:getpos()

        rmgqc.wirerope:setpos(wx + dx, wy + dy, wz - dz)
        rmgqc.wirerope:setscale(1, (26.54 + 1.32 - 1.1) - wy - dy, 1)
        rmgqc.trolley:setpos(tx + dx, ty, tz)
        rmgqc.spreader:setpos(sx + dx, sy + dy, sz - dz)

        -- 移动箱子
        if rmgqc.attached then
            local cx, cy, cz = rmgqc.attached:getpos()
            rmgqc.attached:setpos(cx + dx, cy + dy, cz - dz)
        end
    end

    -- 移动到指定位置
    function rmgqc:spreaderMove2(x, y, z)
        rmgqc:spreadermove(x - rmgqc.spreaderpos[1], y - rmgqc.spreaderpos[2], z - rmgqc.spreaderpos[3])
    end

    -- 车移动(-z方向)
    function rmgqc:move(dist)
        rmgqc.pos = rmgqc.pos + dist
        local wx, wy, wz = rmgqc.wirerope:getpos()
        local sx, sy, sz = rmgqc.spreader:getpos()
        local tx, ty, tz = rmgqc.trolley:getpos()
        local rx, ry, rz = rmgqc:getpos()

        rmgqc.wirerope:setpos(wx, wy, wz + dist)
        rmgqc.spreader:setpos(sx, sy, sz + dist)
        rmgqc.trolley:setpos(tx, ty, tz + dist)
        rmgqc:setpos(rx, ry, rz + dist)

        -- 移动箱子
        if rmgqc.attached then
            local cx, cy, cz = rmgqc.attached:getpos()
            rmgqc.attached:setpos(cx, cy, cz + dist)
        end
    end

    function rmgqc:executeTask(dt)
        if #rmgqc.tasksequence == 0 then
            return
        end

        local task = rmgqc.tasksequence[1]
        local taskname, param = task[1], task[2]

        -- -- debug
        -- if rmgqc.lasttask ~= taskname then
        --     print('[rmgqc', rmgqc.id, '] 当前任务', taskname)
        --     rmgqc.lasttask = taskname
        -- end

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
                    rmgqc:move(param[3] - param.initalZ - param.movedZ)
                    param.arrivedZ = true
                else
                    param.movedZ = param.movedZ + ds[3] -- 已移动bay
                    rmgqc:move(ds[3])
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
            rmgqc:spreaderMove2(param.currentXY[1], param.currentXY[2], 0) -- 设置到累计移动值

            if param.arrivedZ and param.arrivedXY[1] and param.arrivedXY[2] then
                rmgqc:deltask()
            end
        elseif taskname == "waitagv" then -- {"waitagv", nil}
            if rmgqc.agvqueue[1] == nil then
                print("[rmgqc] rmgqc.agvqueue[1]=nil")
            end
            if rmgqc.agvqueue[1] ~= nil and rmgqc.agvqueue[1].arrived then -- agv到达
                rmgqc.currentAgv = rmgqc.agvqueue[1] -- 设置当前agv
                table.remove(rmgqc.agvqueue, 1) -- 移除等待的agv
                rmgqc:deltask()
            end
        elseif taskname == "attach" then -- {"attach", {row, col, level}}
            if param == nil then
                param = {nil, nil, nil}
            end
            rmgqc:attach(param[1], param[2], param[3])
            rmgqc:deltask()
        elseif taskname == "detach" then -- {"detach", {row, col, level}}
            if param == nil then
                param = {nil, nil, nil}
            end
            rmgqc:detach(param[1], param[2], param[3])
            rmgqc:deltask()
        end
    end

    -- interface:计算最大允许步进
    function rmgqc:maxstep()
        local dt = math.huge -- 初始化步进
        if rmgqc.tasksequence[1] == nil then -- 对象无任务，直接返回0
            return dt
        end

        local taskname = rmgqc.tasksequence[1][1] -- 任务名称
        local param = rmgqc.tasksequence[1][2] -- 任务参数

        -- -- debug
        -- if rmgqc.lastmaxstep ~= taskname then
        --     print('[rmgqc', rmgqc.id, '] maxstep:', taskname)
        --     rmgqc.lastmaxstep = taskname
        -- end

        if taskname == "move2" then
            if param.initalZ == nil then
                param.initalZ = rmgqc.pos -- 初始位置
                param.movedZ = 0 -- 已经移动的距离

                param.vectorXY = {} -- 初始化向量(6,7)
                param.currentXY = {} -- 初始化当前位置(8,9)
                param.initalXY = {} -- 初始化初始位置(10,11)
                for i = 1, 2 do
                    param.initalXY[i] = rmgqc.spreaderpos[i] -- 初始位置(10,11)
                    param.currentXY[i] = rmgqc.spreaderpos[i] -- 当前位置(8,9)
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
                param.speed = {param.vectorXY[1] == 0 and 0 or param.vectorXY[1] / math.abs(param.vectorXY[1]) *
                    rmgqc.speed[1],
                               param.vectorXY[2] == 0 and 0 or param.vectorXY[2] / math.abs(param.vectorXY[2]) *
                    rmgqc.speed[2],
                               param[3] == rmgqc.pos and 0 or rmgqc.zspeed *
                    ((param[3] - rmgqc.pos) / math.abs(param[3] - rmgqc.pos))} -- speed[3]:速度乘方向
                print('[rmgqc] speed:', param.speed[1], param.speed[2], param.speed[3])
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
    function rmgqc:addtask(name, param)
        local task = {name, param}
        table.insert(rmgqc.tasksequence, task)
    end

    -- 删除任务
    function rmgqc:deltask()
        table.remove(rmgqc.tasksequence, 1)

        if (rmgqc.tasksequence[1] ~= nil and rmgqc.tasksequence[1][1] == "attach") then
            print("[rmgqc] task executing: ", rmgqc.tasksequence[1][1], " at ", coroutine.qtime())
        end
    end

    -- 获取爪子移动坐标（x,y)
    function rmgqc:getcontainercoord(bay, row, level)
        local x
        if row == -1 then
            x = rmgqc.iox
        else
            x = rmgqc.ship.containerPositions[1][row][1][1] - rmgqc.origin[1]
        end

        local ry = 0 -- 相对高度
        if row == -1 and level == 1 then -- 如果是要放下，则设置到移动到agv上
            ry = ry + rmgqc.level.agv -- 加上agv高度
        else
            ry = ry + rmgqc.level[level] -- 加上层高
        end
        local y = ry - rmgqc.origin[2]
        local z = rmgqc.ship.bayPosition[bay] -- 通过车移动解决z

        return {x, y, z}
    end

    -- 将集装箱从agv抓取到目标位置，默认在移动层
    function rmgqc:lift2TargetPos(bay, row, level)
        rmgqc:addtask("waitagv") -- 等待agv到达
        rmgqc:addtask("move2", rmgqc:getcontainercoord(bay, -1, 1)) -- 抓取agv上的箱子
        rmgqc:addtask("attach", nil) -- 抓取
        rmgqc:addtask("move2", rmgqc:getcontainercoord(bay, -1, rmgqc.toplevel)) -- 吊具提升到移动层
        rmgqc:addtask("move2", rmgqc:getcontainercoord(bay, row, rmgqc.toplevel)) -- 移动爪子到指定位置
        rmgqc:addtask("move2", rmgqc:getcontainercoord(bay, row, level)) -- 移动爪子到指定位置
        rmgqc:addtask("detach", {bay, row, level}) -- 放下指定箱
        rmgqc:addtask("move2", rmgqc:getcontainercoord(bay, row, rmgqc.toplevel)) -- 爪子抬起到移动层
    end

    -- 将集装箱从目标位置移动到agv，默认在移动层
    function rmgqc:lift2Agv(bay, row, level)
        rmgqc:addtask("move2", rmgqc:getcontainercoord(bay, row, level)) -- 移动爪子到指定位置
        rmgqc:addtask("attach", {bay, row, level}) -- 抓取
        rmgqc:addtask("move2", rmgqc:getcontainercoord(bay, row, rmgqc.toplevel)) -- 吊具提升到移动层
        rmgqc:addtask("move2", rmgqc:getcontainercoord(bay, -1, rmgqc.toplevel)) -- 移动爪子到agv上方
        rmgqc:addtask("waitagv") -- 等待agv到达
        rmgqc:addtask("move2", rmgqc:getcontainercoord(bay, -1, 1)) -- 移动爪子到agv
        rmgqc:addtask("detach", nil) -- 放下指定箱
        rmgqc:addtask("move2", rmgqc:getcontainercoord(bay, -1, rmgqc.toplevel)) -- 爪子抬起到移动层
    end

    -- 移动到目标位置，默认在移动层
    function rmgqc:move2TargetPos(bay, row)
        rmgqc:addtask("move2", rmgqc:getcontainercoord(bay, row, rmgqc.toplevel))
    end

    -- 移动到agv上方，默认在移动层
    function rmgqc:move2Agv(bay)
        rmgqc:addtask("move2", rmgqc:getcontainercoord(bay, -1, rmgqc.toplevel))
    end

    function rmgqc:bindShip(ship)
        if rmgqc.bindingRoad == nil then
            print('[rmgqc] bindShip()错误，rmgqc未绑定道路')
            return
        end

        -- 进行绑定（对应rmg的绑定在依赖注入后执行）
        rmgqc.ship = ship
        ship.operator = rmgqc

        local bayPos = {} -- bay的第一行坐标{x,z}
        for i = 1, ship.bay do
            bayPos[i] = {ship.containerPositions[i][1][1][1], ship.containerPositions[i][1][1][3]}
            -- 显示baypos位置
            scene.addobj('points', {
                vertices = {bayPos[i][1], 0, bayPos[i][2]},
                color = 'blue',
                size = 5
            })
        end

        -- 投影
        rmgqc.parkingSpaces = {}
        for i = 1, #bayPos do
            rmgqc.parkingSpaces[i] = {}
            rmgqc.parkingSpaces[i].relativeDist = rmgqc.bindingRoad:getVectorRelativeDist(bayPos[i][1], bayPos[i][2],
                math.cos(ship.rotradian - math.pi / 2), math.sin(ship.rotradian - math.pi / 2) * -1)
            -- print('cy debug: parking space', i, ' relative distance = ', rmgqc.parkingSpaces[i].relativeDist)
        end

        -- 生成停车位并计算iox
        for k, v in ipairs(rmgqc.parkingSpaces) do
            local x, y, z = rmgqc.bindingRoad:getRelativePosition(v.relativeDist)

            -- 计算iox
            rmgqc.parkingSpaces[k].iox = -1 * math.sqrt((x - bayPos[k][1]) ^ 2 + (z - bayPos[k][2]) ^ 2)
            -- print('cy debug: parking space', k, ' iox = ', rmgqc.parkingSpaces[k].iox)
        end
    end

    function rmgqc:bindRoad(road)
        self.bindingRoad = road
    end

    --- 显示绑定道路对应的停车位点（debug用）
    function rmgqc:showBindingPoint()
        -- 显示rmgqc.parkingSpaces的位置
        for k, v in ipairs(rmgqc.parkingSpaces) do
            local x, y, z = rmgqc.bindingRoad:getRelativePosition(v.relativeDist)

            -- 显示位置
            scene.addobj('points', {
                vertices = {x, y, z},
                color = 'red',
                size = 5
            })
            local pointLabel = scene.addobj('label', {
                text = 'no.' .. k
            })
            pointLabel:setpos(x, y, z)

            -- print('rmgqc debug: parking space', k, ' ,iox = ', rmgqc.parkingSpaces[k].iox, ' ,Position=', x, y, z) -- debug
        end
    end

    -- 注册到动作队列(对应rmg)
    table.insert(actionObjs, rmgqc)

    return rmgqc
end
