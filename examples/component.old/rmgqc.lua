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
    rmgqc.tasks = {} -- 可用任务列表(数字索引为可用任务，字符索引为任务函数)
    rmgqc.speed = {8, 5} -- 移动速度
    rmgqc.zspeed = 2 -- 车移动速度
    rmgqc.attached = nil -- 抓取的集装箱
    rmgqc.stash = nil -- io物品暂存
    rmgqc.agentqueue = {} -- agent服务队列
    rmgqc.bindingRoad = nil -- 绑定的道路
    rmgqc.parkingSpaces = {} -- 停车位对象(使用bay位置索引)

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
    -- print("初始化：spreader z = ", rmgqc.origin[3]) --debug

    -- rmgqc注册agent。agent已经设置agent.taskType和agent.targetContainerPos
    function rmgqc:registerAgent(agent)
        -- rmg添加任务
        local bay, row, level = table.unpack(agent.targetContainerPos)

        if agent.taskType == 'unload' then
            -- print('[rmg] agv:unload, targetPos=(', agv.targetContainerPos[1], agv.targetContainerPos[2], agv.targetContainerPos[3], ')') -- debug
            rmgqc:move2Agent(bay)
            -- print('[rmgqc] move2Agv()完成') -- debug
            rmgqc:lift2TargetPos(bay, row, level, agent)
            -- print('[rmgqc] lift2TargetPos()完成') -- debug
        elseif agent.taskType == 'load' then
            -- print('[rmgqc] agv:load') -- debug
            rmgqc:move2TargetPos(bay, row)
            -- print('[rmgqc] move2TargetPos()完成') -- debug
            rmgqc:lift2Agent(bay, row, level, agent)
            -- print('[rmgqc] lift2Agent()完成') -- debug
        else
            print('[rmgqc] 错误，没有检测到agv的任务类型，注册失败。')
            return
        end

        -- 注册agv
        table.insert(rmgqc.agentqueue, agent) -- 加入agv队列
    end

    -- 放箱子
    function rmgqc:detach(bay, row, level)
        -- 判断是否指定位置
        if bay == nil then
            if rmgqc.agentqueue[1] ~= nil and rmgqc.agentqueue[1].container == nil then
                local agent = rmgqc.agentqueue[1]
                print('rmgqc'..rmgqc.id..': detach到agent:', agent.type .. agent.id, '处') -- debug
                -- 将集装箱放置到对应agv上
                agent.container = rmgqc.attached
                rmgqc.attached = nil
            elseif rmgqc.stash == nil then
                print('rmgqc'..rmgqc.id..': detach到stash处') -- debug
                -- 将集装箱放置到对应bay位置的agv位置上
                rmgqc.stash = rmgqc.attached
                rmgqc.attached = nil
            else
                print('rmgqc'..rmgqc.id..': agent,stash均不为nil')
            end

            return
        end

        -- 将集装箱放到船上的指定位置
        rmgqc.ship.containers[bay][row][level] = rmgqc.attached
        rmgqc.attached = nil
    end

    -- 抓箱子
    -- bay:堆场位置，row:行，level:层
    -- 如果bay为nil，则抓取agv上的集装箱(stash)
    function rmgqc:attach(bay, row, level)
        if bay == nil then -- 如果没有指定位置，则为抓取agv上的集装箱
            -- 判断agv上的集装箱是否为空
            if rmgqc.agentqueue[1] ~= nil and rmgqc.agentqueue[1].container ~= nil then
                local agent = rmgqc.agentqueue[1]
                print('rmgqc'..rmgqc.id..': 从agent:', agent.type .. agent.id, '处attach') -- debug
                -- 从agv上取出集装箱
                rmgqc.attached = agent.container
                agent.container = nil
            elseif rmgqc.stash ~= nil then
                print('rmgqc'..rmgqc.id..': 从stash处attach') -- debug
                -- 从暂存中取出集装箱
                rmgqc.attached = rmgqc.stash
                rmgqc.stash = nil
            else
                print('[rmgqc] 错误，agent,stash均为nil')
                print('[rmgqc] rmgqc.agentqueue[1]=', rmgqc.agentqueue[1])
                -- debug
                os.exit()
            end

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
        local taskname, params = task[1], task[2]

        -- -- debug
        -- if rmgqc.lasttask ~= taskname then
        --     print('[rmgqc] 当前任务', taskname, 'at', coroutine.qtime())
        --     rmgqc.lasttask = taskname
        -- end

        if rmgqc.tasks[taskname] == nil then
            print('[rmgqc] 错误，没有找到任务', taskname)
        end

        if rmgqc.tasks[taskname].execute ~= nil then
            rmgqc.tasks[taskname].execute(dt, params)
        end
    end

    -- interface:计算最大允许步进
    function rmgqc:maxstep()
        local dt = math.huge -- 初始化步进
        if rmgqc.tasksequence[1] == nil then -- 对象无任务，直接返回0
            return dt
        end

        local taskname = rmgqc.tasksequence[1][1] -- 任务名称
        local params = rmgqc.tasksequence[1][2] -- 任务参数

        -- -- debug
        -- if rmgqc.lastmaxstep ~= taskname then
        --     print('[rmgqc', rmgqc.id, '] maxstep:', taskname)
        --     rmgqc.lastmaxstep = taskname
        -- end

        if rmgqc.tasks[taskname] == nil then
            print('[rmgqc] 错误，没有找到任务', taskname)
        end

        if rmgqc.tasks[taskname].maxstep ~= nil then
            dt = math.min(dt, rmgqc.tasks[taskname].maxstep(params))
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
        rmgqc.lasttask = nil -- 重置debug记录的上一个任务

        -- if (rmgqc.tasksequence[1] ~= nil and rmgqc.tasksequence[1][1] == "attach") then
        --     print("[rmgqc] task executing: ", rmgqc.tasksequence[1][1], " at ", coroutine.qtime())
        -- end
    end

    rmgqc.tasks.move2 = {
        execute = function(dt, params)
            -- 计算移动值
            local ds = {}
            for i = 1, 2 do
                ds[i] = params.speed[i] * dt -- dt移动
            end
            ds[3] = params.speed[3] * dt -- rmg向量速度*时间

            -- debug
            -- print('[rmgqc] move2:', params[1], params[2], params[3], ' now:', params.currentXY[1], params.currentXY[2],
            --     params.movedZ + params.initalZ)

            -- 判断bay方向是否已经到达目标
            if not params.arrivedZ then
                -- bay方向没有到达目标
                if (params.movedZ + ds[3]) / (params[3] - params.initalZ) >= 1 then -- 首次到达目标
                    rmgqc:move(params[3] - params.initalZ - params.movedZ)
                    params.arrivedZ = true
                else
                    params.movedZ = params.movedZ + ds[3] -- 已移动bay
                    rmgqc:move(ds[3])
                end
            end

            for i = 1, 2 do
                -- 判断X/Y方向是否到达目标
                if not params.arrivedXY[i] then
                    -- 未到达目标，判断本次移动是否能到达目标
                    if (params[i] - params.currentXY[i] - ds[i]) * params.vectorXY[i] <= 0 then
                        -- 分方向到达目标/经过此次计算分方向到达目标
                        params.currentXY[i] = params[i] -- 设置到累计移动值
                        params.arrivedXY[i] = true -- 设置到达标志，禁止进入判断
                    else
                        -- 分方向没有到达目标
                        params.currentXY[i] = params.currentXY[i] + ds[i] -- 累计移动
                    end
                end
            end

            -- 执行移动
            rmgqc:spreaderMove2(params.currentXY[1], params.currentXY[2], 0) -- 设置到累计移动值

            if params.arrivedZ and params.arrivedXY[1] and params.arrivedXY[2] then
                rmgqc:deltask()
            end
        end,
        maxstep = function(params)
            local dt = 0 -- 初始化步进

            if params.initalZ == nil then
                params.initalZ = rmgqc.pos -- 初始位置
                params.movedZ = 0 -- 已经移动的距离

                params.vectorXY = {} -- 初始化向量(6,7)
                params.currentXY = {} -- 初始化当前位置(8,9)
                params.initalXY = {} -- 初始化初始位置(10,11)
                for i = 1, 2 do
                    params.initalXY[i] = rmgqc.spreaderpos[i] -- 初始位置(10,11)
                    params.currentXY[i] = rmgqc.spreaderpos[i] -- 当前位置(8,9)
                    if params[i] - params.initalXY[i] == 0 then -- 目标距离差为0，向量设为0
                        params.vectorXY[i] = 0
                    else
                        params.vectorXY[i] = params[i] - params.initalXY[i] -- 计算初始向量
                    end
                end

                -- 判断是否到达目标
                params.arrivedZ = (params[3] == params.initalZ)
                params.arrivedXY = {params[1] == params.initalXY[1], params[2] == params.initalXY[2]}

                -- 计算各方向分速度
                params.speed = {params.vectorXY[1] == 0 and 0 or params.vectorXY[1] / math.abs(params.vectorXY[1]) *
                    rmgqc.speed[1],
                                params.vectorXY[2] == 0 and 0 or params.vectorXY[2] / math.abs(params.vectorXY[2]) *
                    rmgqc.speed[2],
                                params[3] == rmgqc.pos and 0 or rmgqc.zspeed *
                    ((params[3] - rmgqc.pos) / math.abs(params[3] - rmgqc.pos))} -- speed[3]:速度乘方向
                -- print('[rmgqc] speed:', param.speed[1], param.speed[2], param.speed[3])
            end

            if not params.arrivedZ then -- bay方向没有到达目标
                dt = math.max(dt, math.abs((params[3] - params.initalZ - params.movedZ) / params.speed[3]))
            end

            for i = 1, 2 do -- 判断X/Y(col/level)方向有没有到达目标
                if not params.arrivedXY[i] then -- 如果没有达到目标
                    if params.vectorXY[i] ~= 0 then
                        local taskRemainTime = (params[i] - params.currentXY[i]) / params.speed[i] -- 计算本方向任务的剩余时间
                        if taskRemainTime < 0 then
                            print('[警告!] rmg:maxstep(): XY方向[', i, ']的剩余时间小于0,已调整为0') -- 如果print了这行，估计是出问题了
                            taskRemainTime = 0
                        end

                        dt = math.max(dt, taskRemainTime)
                    end
                end
            end

            -- print('[rmgqc] maxstep:', dt)
            return dt
        end
    }

    -- {'waitagent', agent} -- rmg等待agent到达
    rmgqc.tasks.waitagent = {
        maxstep = function(params)
            local agent = params

            -- 临时debug，判断是否第一次进入waitagent
            if agent.waitagentft == nil then
                agent.waitagentft = false
                -- print('[rmgqc' .. rmgqc.id .. '] waitagent', agent.type .. agent.id, ' at', coroutine.qtime())
            end

            -- 判断agent是否被当前rmg有效占用
            if #rmgqc.agentqueue > 0 and agent.occupier == rmgqc then
                -- print('[rmgqc]', agent.type .. agent.id .. '已经被' .. rmgqc.type .. rmgqc.id ..
                --     '占用，rmgqc删除waitagent任务 at', coroutine.qtime())
                agent.waitagentft = nil -- 重置waitagentft

                rmgqc:deltask() -- 删除本任务，解除阻塞（避免相互等待），继续执行下一个任务
                return rmgqc:maxstep() -- 本任务不影响其他agent，因此可以直接递归调用，消除本任务的影响
            end

            -- print('rmgqc' .. rmgqc.id, 'waitagent', agent.type .. agent.id) -- debug
            return math.huge
        end
    }

    -- {'unwaitagent', agentqueue_pos} -- 解除agent的阻塞，使agent继续执行其他任务
    rmgqc.tasks.unwaitagent = {
        maxstep = function(params)
            rmgqc.agentqueue[params].occupier = nil -- 解除阻塞
            -- print('unwaitagent 解除'..rmgqc.agentqueue[params].type..rmgqc.agentqueue[params].id..'的阻塞')
            table.remove(rmgqc.agentqueue, params)
            rmgqc:deltask()
            return rmgqc:maxstep() -- 本任务不影响其他agent，因此可以直接递归调用，消除本任务的影响
        end
    }

    rmgqc.tasks.attach = {
        execute = function(dt, params)
            if params == nil then
                params = {nil, nil, nil}
            end
            rmgqc:attach(params[1], params[2], params[3])
            rmgqc:deltask()
        end,
        maxstep = function(params)
            return 0
        end
    }

    rmgqc.tasks.detach = {
        execute = function(dt, params)
            if params == nil then
                params = {nil, nil, nil}
            end
            rmgqc:detach(params[1], params[2], params[3])
            rmgqc:deltask()
        end,
        maxstep = function(params)
            return 0
        end
    }

    -- 获取集装箱位置相对origin的坐标{x,y,z}
    function rmgqc:getContainerCoord(bay, row, level)
        local x, rx
        if row == -1 then
            rx = rmgqc.iox
            x = rx + rmgqc.ship.origin[1]
        else
            x = rmgqc.ship.containerPositions[1][row][1][1]
            rx = x - rmgqc.origin[1]
        end

        local y = 0 -- 相对高度
        if row == -1 and level == 1 then -- 如果是要放下，则设置到移动到agv上
            y = rmgqc.level.agv -- 加上agv高度
        else
            y = rmgqc.level[level] -- 加上层高
        end
        local ry = y - rmgqc.origin[2]
        local z = rmgqc.ship.bayPosition[bay]
        local rz = z - rmgqc.ship.origin[3] -- 通过车移动解决z

        -- debug
        -- local point = scene.addobj('points', {
        --     vertices = {x, y, z},
        --     color = 'red',
        --     size = 5
        -- })
        -- local label = scene.addobj('label', {
        --     text = bay .. ',' .. row .. ',' .. level..'('..rx..','..y..','..rz..')'
        -- })
        -- label:setpos(x, y, z)

        return {rx, ry, rz}
    end

    -- 将集装箱从agent抓取到目标位置，默认在移动层。这个函数会标记当前rmg任务目标位置
    function rmgqc:lift2TargetPos(bay, row, level, operatedAgent)
        rmgqc:addtask("waitagent", operatedAgent) -- 等待agent到达
        rmgqc:addtask("move2", rmgqc:getContainerCoord(bay, -1, 1)) -- 抓取agent上的箱子
        rmgqc:addtask("attach", nil) -- 抓取
        rmgqc:addtask("unwaitagent", 1) -- 发送信号，解除agent的阻塞
        rmgqc:addtask("move2", rmgqc:getContainerCoord(bay, -1, rmgqc.toplevel)) -- 吊具提升到移动层
        rmgqc:addtask("move2", rmgqc:getContainerCoord(bay, row, rmgqc.toplevel)) -- 移动爪子到指定位置
        rmgqc:addtask("move2", rmgqc:getContainerCoord(bay, row, level)) -- 移动爪子到指定位置
        rmgqc:addtask("detach", {bay, row, level}) -- 放下指定箱
        rmgqc:addtask("move2", rmgqc:getContainerCoord(bay, row, rmgqc.toplevel)) -- 爪子抬起到移动层
    end

    -- 将集装箱从目标位置移动到agent，默认在移动层。这个函数会标记当前rmgqc任务目标位置
    function rmgqc:lift2Agent(bay, row, level, operatedAgent)
        rmgqc:addtask("move2", rmgqc:getContainerCoord(bay, row, level)) -- 移动爪子到指定位置
        rmgqc:addtask("attach", {bay, row, level}) -- 抓取
        rmgqc:addtask("move2", rmgqc:getContainerCoord(bay, row, rmgqc.toplevel)) -- 吊具提升到移动层
        rmgqc:addtask("move2", rmgqc:getContainerCoord(bay, -1, rmgqc.toplevel)) -- 移动爪子到agent上方
        rmgqc:addtask("waitagent", operatedAgent) -- 等待agent到达
        rmgqc:addtask("move2", rmgqc:getContainerCoord(bay, -1, 1)) -- 移动爪子到agent
        rmgqc:addtask("detach", nil) -- 放下指定箱
        rmgqc:addtask("unwaitagent", 1) -- 发送信号，解除agent的阻塞
        rmgqc:addtask("move2", rmgqc:getContainerCoord(bay, -1, rmgqc.toplevel)) -- 爪子抬起到移动层
    end

    -- 移动到目标位置，默认在移动层
    function rmgqc:move2TargetPos(bay, row)
        rmgqc:addtask("move2", rmgqc:getContainerCoord(bay, row, rmgqc.toplevel))
    end

    -- 移动到agv上方，默认在移动层
    function rmgqc:move2Agent(bay)
        rmgqc:addtask("move2", rmgqc:getContainerCoord(bay, -1, rmgqc.toplevel))
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
                math.cos(ship.rot - math.pi / 2), math.sin(ship.rot - math.pi / 2) * -1)
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
