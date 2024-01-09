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
    rmg.cy.operator = rmg -- 堆场对应rmg(控制反转)
    rmg.level = {}
    for i = 1, #cy.levels do
        rmg.level[i] = cy.levels[i] + cy.cheight
    end
    rmg.toplevel = #rmg.level -- 最高层(吊具行走层)
    rmg.level.agv = 2.1 -- agv高度
    rmg.spreaderpos = {0, rmg.level[2], 0} -- 初始位置(x,y)
    rmg.zpos = 0 -- 初始位置z
    rmg.tasksequence = {} -- 初始化任务队列
    rmg.tasks = {} -- 可用任务列表(数字索引为可用任务，字符索引为任务函数)
    rmg.speed = {8, 4} -- x,y方向的移动速度
    rmg.zspeed = 2 -- 车移动速度
    rmg.attached = nil -- 抓取的集装箱
    rmg.stash = nil -- io物品暂存
    rmg.agentqueue = {} -- agv服务队列，用于堆存需要服务的agv对象

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
    -- rmg注册agent。agent已经设置agent.taskType和agent.targetContainerPos
    function rmg:registerAgent(agent)
        -- rmg添加任务
        local bay, row, level = table.unpack(agent.targetContainerPos)

        if agent.taskType == 'unload' then
            -- print('[rmg] agent:unload, targetPos=(', bay, row, level, ')') -- debug
            rmg:move2Agent(bay)
            -- print('[rmg] move2Agent()完成') -- debug
            rmg:lift2TargetPos(bay, row, level, agent)
            -- print('[rmg] lift2TargetPos()完成') -- debug
        elseif agent.taskType == 'load' then
            -- print('[rmg] agent:load, targetPos=(', bay, row, level, ')') -- debug
            rmg:move2TargetPos(bay, row)
            -- print('[rmg] move2TargetPos()完成') -- debug
            rmg:lift2Agent(bay, row, level, agent)
            -- print('[rmg] lift2Agent()完成') -- debug
        else
            print('[rmg] 错误，没有检测到' .. agent.type .. '的任务类型，注册失败。')
            return
        end

        -- 注册agv
        table.insert(rmg.agentqueue, agent) -- 加入agv队列
        -- print('[rmg] agv注册完成, #agv.tasksequence=', #agent.tasksequence, ' #actionObjs=', #actionObjs) -- debug
    end

    -- 抓箱子
    -- bay:堆场位置，row:行，level:层
    -- 如果bay为nil，则抓取agv上的集装箱(stash)
    function rmg:attach(bay, row, level)
        if bay == nil then -- 如果没有指定位置，则为抓取agv上的集装箱
            -- 判断agv上的集装箱是否为空
            if rmg.agentqueue[1] ~= nil and rmg.agentqueue[1].container ~= nil then
                print('rmg: 从agent处attach') -- debug
                -- 从agv上取出集装箱
                rmg.attached = rmg.agentqueue[1].container
                rmg.agentqueue[1].container = nil
            elseif rmg.stash ~= nil then
                print('rmg: 从stash处attach') -- debug
                -- 从暂存中取出集装箱
                rmg.attached = rmg.stash
                rmg.stash = nil
            else
                print('[rmg] 错误，agent,stash均为nil')
                print('[rmg] rmg.agentqueue[1]=', rmg.agentqueue[1])
                -- debug
                os.exit()
            end

            return
        end

        -- 判断抓取的集装箱是否为空
        if rmg.cy.containers[bay][row][level] == nil then
            print('[rmg] 错误，抓取堆场中的集装箱为空')
            -- debug
            os.exit()
        end

        -- 抓取堆场中的集装箱
        rmg.attached = rmg.cy.containers[bay][row][level]
        rmg.attached.tag = {bay, row, level} -- 给集装箱设置tag
        rmg.cy.containers[bay][row][level] = nil
    end

    -- 放箱子
    function rmg:detach(bay, row, level)
        -- 判断是否指定位置
        if bay == nil then
            if rmg.agentqueue[1] ~= nil and rmg.agentqueue[1].container == nil then
                print('rmg: detach到agent处') -- debug
                -- 将集装箱放置到对应agv上
                rmg.agentqueue[1].container = rmg.attached
                rmg.attached = nil
            elseif rmg.stash == nil then
                print('rmg: detach到stash处') -- debug
                -- 将集装箱放置到对应bay位置的agv位置上
                rmg.stash = rmg.attached
                rmg.attached = nil
            else
                print('rmg: agent,stash均不为nil')
            end

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
        rmg.zpos = rmg.zpos + dist
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
        local taskname, params = task[1], task[2]

        -- -- debug
        -- if rmg.lasttask ~= taskname then
        --     print('[rmg] 当前任务', taskname, 'at', coroutine.qtime())
        --     rmg.lasttask = taskname
        -- end

        if rmg.tasks[taskname] == nil then
            print('[rmg] 错误，没有找到任务', taskname)
        end

        if rmg.tasks[taskname].execute ~= nil then
            rmg.tasks[taskname].execute(dt, params)
        end
    end

    -- interface:计算最大允许步进
    function rmg:maxstep()
        local dt = math.huge -- 初始化步进
        if rmg.tasksequence[1] == nil then -- 对象无任务，直接返回0
            return dt
        end

        local taskname = rmg.tasksequence[1][1] -- 任务名称
        local params = rmg.tasksequence[1][2] -- 任务参数

        -- -- debug
        -- if taskname ~= rmg.lasttask then
        --     print('[rmg] maxstep task', taskname)
        -- end

        if rmg.tasks[taskname] == nil then
            print('[rmg] 错误，没有找到任务', taskname)
        end

        if rmg.tasks[taskname].maxstep ~= nil then
            dt = math.min(dt, rmg.tasks[taskname].maxstep(params))
        end

        return dt
    end

    -- {'move2', {x, y, z}}
    -- 1:col(x), 2:height(y), 3:bay(z), [4:初始bay, 5:已移动bay距离,向量*2(6,7),当前位置*2(8,9),初始位置*2(10,11),到达(12,13)*2]
    rmg.tasks.move2 = {
        execute = function(dt, params)
            -- 计算移动值
            local ds = {}
            for i = 1, 2 do
                ds[i] = params.speed[i] * dt -- dt移动
            end
            ds[3] = params.speed[3] * dt -- rmg向量速度*时间

            -- 判断bay方向是否已经到达目标
            if not params.arrivedZ then
                -- bay方向没有到达目标
                if (params.movedZ + ds[3]) / (params[3] - params.initalZ) >= 1 then -- 首次到达目标
                    rmg:move(params[3] - params.initalZ - params.movedZ)
                    params.arrivedZ = true
                else
                    params.movedZ = params.movedZ + ds[3] -- 已移动bay
                    rmg:move(ds[3])
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
            rmg:spreaderMove2(params.currentXY[1], params.currentXY[2], 0) -- 设置到累计移动值

            if params.arrivedZ and params.arrivedXY[1] and params.arrivedXY[2] then
                rmg:deltask()
            end
        end,
        maxstep = function(params)
            local dt = 0 -- 初始化步进

            if params.initalZ == nil then
                params.initalZ = rmg.zpos -- 初始位置
                params.movedZ = 0 -- 已经移动的距离

                params.vectorXY = {} -- 初始化向量(6,7)
                params.currentXY = {} -- 初始化当前位置(8,9)
                params.initalXY = {} -- 初始化初始位置(10,11)
                for i = 1, 2 do
                    params.initalXY[i] = rmg.spreaderpos[i] -- 初始位置(10,11)
                    params.currentXY[i] = rmg.spreaderpos[i] -- 当前位置(8,9)
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
                    rmg.speed[1],
                                params.vectorXY[2] == 0 and 0 or params.vectorXY[2] / math.abs(params.vectorXY[2]) *
                    rmg.speed[2],
                                params[3] == rmg.zpos and 0 or rmg.zspeed *
                    ((params[3] - rmg.zpos) / math.abs(params[3] - rmg.zpos))} -- speed[3]:速度乘方向
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

            return dt
        end
    }

    -- {'waitagent', agent} -- rmg等待agent到达
    rmg.tasks.waitagent = {
        maxstep = function(params)
            local agent = params
            -- 判断agent是否被当前rmg有效占用
            if #rmg.agentqueue > 0 and agent.occupier == rmg then
                -- print('[rmg]', agent.type .. agent.id .. '已经被' .. rmg.type .. rmg.id ..
                --     '占用，rmg删除waitagent任务 at', coroutine.qtime())

                rmg:deltask() -- 删除本任务，解除阻塞（避免相互等待），继续执行下一个任务
                return rmg:maxstep() -- 本任务不影响其他agent，因此可以直接递归调用，消除本任务的影响
            end

            -- print('rmg' .. rmg.id, 'waitagent', agent.type .. agent.id) -- debug
            return math.huge
        end
    }

    -- {'unwaitagent', agentqueue_pos} -- 解除agent的阻塞，使agent继续执行其他任务
    rmg.tasks.unwaitagent = {
        maxstep = function(params)
            rmg.agentqueue[params].occupier = nil -- 解除阻塞
            -- print('unwaitagent 解除'..rmg.agentqueue[params].type..rmg.agentqueue[params].id..'的阻塞')
            table.remove(rmg.agentqueue, params)
            rmg:deltask()
            return rmg:maxstep() -- 本任务不影响其他agent，因此可以直接递归调用，消除本任务的影响
        end
    }

    -- {'attach', {row, col, level}}
    rmg.tasks.attach = {
        execute = function(dt, params)
            if params == nil then
                params = {nil, nil, nil}
            end
            rmg:attach(params[1], params[2], params[3])
            rmg:deltask()
        end,
        maxstep = function(params)
            return 0
        end
    }

    -- {'detach', {row, col, level}}
    rmg.tasks.detach = {
        execute = function(dt, params)
            if params == nil then
                params = {nil, nil, nil}
            end
            rmg:detach(params[1], params[2], params[3])
            rmg:deltask()
        end,
        maxstep = function(params)
            return 0
        end
    }

    -- 添加任务
    function rmg:addtask(name, param)
        local task = {name, param}
        table.insert(rmg.tasksequence, task)
    end

    -- 删除任务
    function rmg:deltask()
        -- debug
        -- print('delete task', rmg.tasksequence[1][1], 'at', coroutine.qtime())
        table.remove(rmg.tasksequence, 1)
        rmg.lasttask = nil -- 重置debug记录的上一个任务

        -- debug
        -- if (rmg.tasksequence[1] ~= nil) then
        --     print("[rmg] task executing: ", rmg.tasksequence[1][1], 'at', coroutine.qtime())
        -- end
    end

    -- 获取集装箱相对origin的坐标{x,y,z}
    function rmg:getContainerCoord(bay, row, level)
        local x
        if row == -1 then
            x = rmg.cy.parkingSpaces[bay].iox + rmg.cy.containerPositions[bay][1][1][1] - rmg.origin[1]
        else
            x = rmg.cy.containerPositions[1][row][1][1] - rmg.origin[1]
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

    -- 将集装箱从agent抓取到目标位置，默认在移动层。这个函数会标记当前rmg任务目标位置
    function rmg:lift2TargetPos(bay, row, level, operatedAgent)
        rmg:addtask("waitagent", operatedAgent) -- 等待agent到达
        rmg:addtask("move2", rmg:getContainerCoord(bay, -1, 1)) -- 抓取agent上的箱子
        rmg:addtask("attach", nil) -- 抓取
        rmg:addtask("unwaitagent", 1) -- 发送信号，解除agent的阻塞
        rmg:addtask("move2", rmg:getContainerCoord(bay, -1, rmg.toplevel)) -- 吊具提升到移动层
        rmg:addtask("move2", rmg:getContainerCoord(bay, row, rmg.toplevel)) -- 移动爪子到指定位置
        rmg:addtask("move2", rmg:getContainerCoord(bay, row, level)) -- 移动爪子到指定位置
        rmg:addtask("detach", {bay, row, level}) -- 放下指定箱
        rmg:addtask("move2", rmg:getContainerCoord(bay, row, rmg.toplevel)) -- 爪子抬起到移动层
    end

    -- 将集装箱从目标位置移动到agent，默认在移动层。这个函数会标记当前rmg任务目标位置
    function rmg:lift2Agent(bay, row, level, operatedAgent)
        rmg:addtask("move2", rmg:getContainerCoord(bay, row, level)) -- 移动爪子到指定位置
        rmg:addtask("attach", {bay, row, level}) -- 抓取
        rmg:addtask("move2", rmg:getContainerCoord(bay, row, rmg.toplevel)) -- 吊具提升到移动层
        rmg:addtask("move2", rmg:getContainerCoord(bay, -1, rmg.toplevel)) -- 移动爪子到agent上方
        rmg:addtask("waitagent", operatedAgent) -- 等待agent到达
        rmg:addtask("move2", rmg:getContainerCoord(bay, -1, 1)) -- 移动爪子到agent
        rmg:addtask("detach", nil) -- 放下指定箱
        rmg:addtask("unwaitagent", 1) -- 发送信号，解除agent的阻塞
        rmg:addtask("move2", rmg:getContainerCoord(bay, -1, rmg.toplevel)) -- 爪子抬起到移动层
    end

    -- 移动到目标位置，默认在移动层
    function rmg:move2TargetPos(bay, row)
        rmg:addtask("move2", rmg:getContainerCoord(bay, row, rmg.toplevel))
    end

    -- 移动到agv上方，默认在移动层
    function rmg:move2Agent(bay)
        rmg:addtask("move2", rmg:getContainerCoord(bay, -1, rmg.toplevel))
    end

    -- 注册到动作队列
    table.insert(actionObjs, rmg) -- 注意！如果以后要管理多个堆场，这行需要修改！

    return rmg
end
