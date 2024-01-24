function Crane(config)
    if config == nil then
        config = {}
    end

    local crane = Agent()

    crane.agentqueue = {} -- 等待服务的agent队列

    -- 初始化参数
    function crane:init(config)
        crane.type = config.type or 'crane' -- 类型
        crane.stack = nil -- 对应的stack对象
        crane.anchorPoint = config.anchorPoint or {0, 0, 0} -- crane锚点坐标
        crane.pos = config.pos or {0, 0, 0} -- crane位置坐标
        crane.speed = config.speed or {2, 4, 8} -- 各方向速度
        crane.attached = nil -- 当前吊具挂载的集装箱

        crane.lastpos = crane.pos -- 设置任务初始位置
    end

    -- 对象相关函数
    function crane:getpos()
        return table.unpack(crane.anchorPoint)
    end

    function crane:setpos(x, y, z)
        print(debug.traceback(crane.type .. crane.id .. ':setpos(x,y,z) 没有定义,无法调用'))
        os.exit()
    end

    -- 驱动函数

    -- 抓箱子
    -- bay:堆场位置，row:行，level:层
    -- 如果bay为nil，则抓取agv上的集装箱(stash)
    function crane:attach(row, bay, level)
        if bay == nil then -- 如果没有指定位置，则为抓取agv上的集装箱
            -- 判断agv上的集装箱是否为空
            if crane.agentqueue[1] ~= nil and crane.agentqueue[1].container ~= nil then
                local agent = crane.agentqueue[1]
                print('[crane' .. crane.id .. '] 从agent:', agent.type .. agent.id, '处attach') -- debug
                -- 从agv上取出集装箱
                crane.attached = agent.container
                agent.container = nil
            else
                print('[crane' .. crane.id .. '] 错误，目标agent为nil')
                print('[crane' .. crane.id .. '] crane.agentqueue[1]=', crane.agentqueue[1])
                -- debug
                print(debug.traceback())
                os.exit()
            end

            return
        end

        -- 判断抓取的集装箱是否为空
        if crane.stack.containers[row][bay][level] == nil then
            print(debug.traceback('[crane' .. crane.id .. '] 错误，抓取堆场中的集装箱为空'))
            -- debug
            os.exit()
        end

        -- 抓取堆场中的集装箱
        crane.attached = crane.stack.containers[row][bay][level]
        crane.stack.containers[row][bay][level] = nil
    end

    -- 放箱子
    function crane:detach(row, bay, level)
        -- 判断是否指定位置
        if bay == nil then
            if crane.agentqueue[1] ~= nil and crane.agentqueue[1].container == nil then
                local agent = crane.agentqueue[1]
                print('[crane' .. crane.id .. '] detach到agent:', agent.type .. agent.id, '处') -- debug
                -- 将集装箱放置到对应agv上
                agent.container = crane.attached
                crane.attached = nil
            else
                print('crane' .. crane.id .. ': agent.container不为nil')
                print('agent:', crane.agentqueue[1])
                print(debug.traceback())
                os.exit()
            end

            return
        end

        -- 将集装箱放到船上的指定位置
        crane.stack.containers[row][bay][level] = crane.attached
        crane.attached = nil
    end

    -- 绑定其他对象
    -- 绑定stack
    function crane:bindStack(stack)
        -- 包括最大能够访问的高度:levelPos, topLevel
        crane.stack = stack
        stack.operator = crane
        crane.anchorPoint = {table.unpack(stack.anchorPoint)}
        crane:setpos(stack.anchorPoint[1], stack.levelPos[#stack.levelPos], stack.anchorPoint[3])
    end

    -- 绑定道路
    function crane:bindRoad(road)
        crane.road = road
    end

    -- crane将agent作为agv注册。agent已经设置agent.taskType和agent.targetContainerPos
    function crane:registerAgv(agent)
        -- 检查参数
        if agent.targetContainerPos == nil then
            print(debug.traceback('[' .. crane.type .. crane.id .. '] 错误，agent没有设置targetContainerPos'))
            os.exit() -- 检测到出错立刻停止,方便发现错误
        end

        -- crane添加任务
        local row, bay, level = table.unpack(agent.targetContainerPos)

        if agent.taskType == 'unload' then
            -- print('['..crane.type..crane.id..'] agent:unload, targetPos=(', row, bay, level, ')') -- debug
            crane:move2Agent(bay)
            -- print('['..crane.type..crane.id..'] move2Agent()完成') -- debug
            crane:lift2TargetPos(row, bay, level, agent)
            -- print('['..crane.type..crane.id..'] lift2TargetPos()完成') -- debug
        elseif agent.taskType == 'load' then
            -- print('['..crane.type..crane.id..'] agent:load, targetPos=(', row, bay, level, ')') -- debug
            crane:move2TargetPos(row, bay)
            -- print('['..crane.type..crane.id..'] move2TargetPos()完成') -- debug
            crane:lift2Agent(row, bay, level, agent)
            -- print('['..crane.type..crane.id..'] lift2Agent()完成') -- debug
        else
            print(debug.traceback('[' .. crane.type .. crane.id .. '] 错误，没有检测到' .. agent.type ..
                                      '的任务类型，注册失败'))
            os.exit()
        end

        -- 注册agv
        table.insert(crane.agentqueue, agent) -- 加入agv队列
        -- print('[rmg] agv注册完成, #agv.tasksequence=', #agent.tasksequence, ' #actionObjs=', #actionObjs) -- debug
    end

    -- 转换函数
    -- 输入(row, bay, level)获取当前绑定stack的集装箱的绝对坐标{x,y,z}
    function crane:getContainerCoord(row, bay, level)
        -- 检验参数
        if type(row) ~= 'number' or type(bay) ~= 'number' or type(level) ~= 'number' then
            print('[' .. crane.type .. crane.id .. '] 错误，getContainerCoord()参数类型错误')
            print('row, bay, level=', row, bay, level)
            print(debug.traceback())
            os.exit() -- 检测到出错立刻停止,方便发现错误
        end

        -- 检验条件
        if crane.stack == nil then
            print(debug.traceback('[' .. crane.type .. crane.id ..
                                      '] 错误，没有绑定 stack，无法使用 getContainerCoord()'))
            os.exit() -- 检测到出错立刻停止,方便发现错误
        end
        local stack = crane.stack -- 绑定的stack

        if row > stack.row or level > #stack.levelPos or bay > stack.col then
            print(stack.type .. tostring(stack.id) .. '输入位置超出范围:')
            print('input row, bay, level=', row, bay, level)
            print('max row, col, level=', stack.row, stack.col, #stack.levelPos)
            print(debug.traceback())
            os.exit() -- 检测到出错立刻停止,方便发现错误
        end

        -- 获取坐标
        local x, rx
        if row == -1 then
            rx = stack.parkingSpaces[bay].iox + stack.cwidth / 2
            x = rx + stack.origin[1]
        else
            x = stack.containerPositions[row][1][1][1]
            rx = x - stack.origin[1]
        end

        local y = 0 -- 相对高度
        if row == -1 and level == 1 then -- 如果是要放下，则设置到移动到agv上
            y = crane.agvHeight -- 加上agv高度
        else
            y = stack.levelPos[level] -- 加上层高
        end
        local ry = y - stack.origin[2]

        local z = stack.containerPositions[1][bay][1][3]
        local rz = z - stack.origin[3] -- 通过车移动解决z

        return {x, y, z}
    end

    -- 集合流程函数
    -- 将集装箱从agent抓取到目标位置，默认在移动层。这个函数会标记当前rmg任务目标位置
    function crane:lift2TargetPos(row, bay, level, operatedAgent)
        crane:addtask("waitagent", {
            agent = operatedAgent
        }) -- 等待agent到达
        crane:addtask("move2", crane:getContainerCoord(-1, bay, 1)) -- 抓取agent上的箱子
        crane:addtask("attach", nil) -- 抓取
        crane:addtask("unwaitagent", {
            index = 1
        }) -- 发送信号，解除agent的阻塞
        crane:addtask("move2", crane:getContainerCoord(-1, bay, #crane.stack.levelPos)) -- 吊具提升到移动层
        crane:addtask("move2", crane:getContainerCoord(row, bay, #crane.stack.levelPos)) -- 移动爪子到指定位置
        crane:addtask("move2", crane:getContainerCoord(row, bay, level)) -- 移动爪子到指定位置
        crane:addtask("detach", {row, bay, level}) -- 放下指定箱
        crane:addtask("move2", crane:getContainerCoord(row, bay, #crane.stack.levelPos)) -- 爪子抬起到移动层
    end

    -- 将集装箱从目标位置移动到agent，默认在移动层。这个函数会标记当前crane任务目标位置
    function crane:lift2Agent(row, bay, level, operatedAgent)
        crane:addtask("move2", crane:getContainerCoord(row, bay, level)) -- 移动爪子到指定位置
        crane:addtask("attach", {row, bay, level}) -- 抓取
        crane:addtask("move2", crane:getContainerCoord(row, bay, #crane.stack.levelPos)) -- 吊具提升到移动层
        crane:addtask("move2", crane:getContainerCoord(-1, bay, #crane.stack.levelPos)) -- 移动爪子到agent上方
        crane:addtask("waitagent", {
            agent = operatedAgent
        }) -- 等待agent到达
        crane:addtask("move2", crane:getContainerCoord(-1, bay, 1)) -- 移动爪子到agent
        crane:addtask("detach", nil) -- 放下指定箱
        crane:addtask("unwaitagent", {
            index = 1
        }) -- 发送信号，解除agent的阻塞
        crane:addtask("move2", crane:getContainerCoord(-1, bay, #crane.stack.levelPos)) -- 爪子抬起到移动层
    end

    -- 移动到目标位置，默认在移动层
    function crane:move2TargetPos(row, bay)
        crane:addtask("move2", crane:getContainerCoord(row, bay, #crane.stack.levelPos))
    end

    -- 移动到agv上方，默认在移动层
    function crane:move2Agent(bay)
        crane:addtask("move2", crane:getContainerCoord(-1, bay, #crane.stack.levelPos))
    end

    -- 内置任务
    -- 'move2', {x, y, z, params}
    crane.tasks.move2 = {
        init = function(params)
            -- 记录初始位置
            crane.lastpos = {table.unpack(crane.pos)}

            -- 计算三个方向的向量
            params.vecE = {}
            for i = 1, 3 do
                local d = params[i] - crane.pos[i] -- 计算距离差值
                params.vecE[i] = d == 0 and 0 or d / math.abs(d)
            end
            params.delta = {} -- 初始化参数：各方向运动距离
            params.runtime = {} -- 初始化参数：各方向所需时间

            -- 计算各方向所需时间
            for i = 1, 3 do
                params.delta[i] = params[i] - crane.pos[i]
                params.runtime[i] = params.delta[i] * params.vecE[i] / crane.speed[i]
                -- print('direction', i, 'delta =', params.delta[i])
                -- print('direction', i, 'runtime =', params.runtime[i])
            end
            local maxRuntime = math.max(table.unpack(params.runtime)) -- 获取各方向上的最大值

            params.dt = maxRuntime -- 任务所需时间
            params.init = true
            coroutine.queue(params.dt, crane.execute, crane)
        end,
        execute = function(dt, params)
            -- 计算步进
            local position = {} -- 各方向位置
            for i = 1, 3 do
                if params.runtime[i] >= dt then
                    position[i] = crane.lastpos[i] + crane.speed[i] * params.vecE[i] * dt -- 步进
                else
                    position[i] = params[i] -- 设置为终点
                end
            end

            crane:setpos(table.unpack(position))

            -- -- debug
            -- print()
            -- print('runtime=', table.unpack(params.runtime))
            -- print('params.dt=', params.dt, 'dt=', dt)
            -- print('delta=', table.unpack(params.delta))
            -- print('pos=', table.unpack(crane.pos))
            -- print('position=', table.unpack(position))

            if math.abs(params.dt - dt) < crane.timeError then
                print('[' .. crane.type .. crane.id .. '] 到达目标位置 at', coroutine.qtime()) -- debug
                crane:deltask()
                crane.lastpos = {table.unpack(position)} -- 更新位置
            end
        end
    }

    -- {'attach', {row, col, level}}
    crane.tasks.attach = {
        init = function(params)
            if params == nil then
                params = {nil, nil, nil}
            end

            params.init = true
            coroutine.queue(0, crane.execute, crane)
            -- 设置状态，不需要设置dt
        end,
        execute = function(dt, params)
            crane:attach(params[1], params[2], params[3])
            crane:deltask()
        end
    }

    -- {'detach', {row, col, level}}
    crane.tasks.detach = {
        init = function(params)
            if params == nil then
                params = {nil, nil, nil}
            end

            params.init = true
            coroutine.queue(0, crane.execute, crane)
            -- 设置状态，不需要设置dt
        end,
        execute = function(dt, params)
            crane:detach(params[1], params[2], params[3])
            crane:deltask()
        end
    }

    -- {'waitagent', {agent=,...}} -- crane等待agent到达
    -- agent需要通知（唤醒）本operator，agent已经到达
    crane.tasks.waitagent = {
        init = function(params)
            -- 参数检查
            if params.agent == nil then
                print(debug.traceback('[' .. crane.type .. crane.id .. '] waitagent错误，没有输入agent'))
            end
            crane.occupier = params.agent -- 当前crane被agent占用

            params.dt = nil -- 任务所需时间为nil，需要别的任务带动被动运行
            params.init = true -- 标记完成初始化
        end,
        execute = function(dt, params)
            -- 检测目标agent是否被当前crane有效占用
            if #crane.agentqueue > 0 and params.agent.operator == crane then
                print('['..crane.type..crane.id..']', params.agent.type .. params.agent.id .. '已经被' .. crane.type .. crane.id ..
                    '占用，crane删除waitagent任务 at', coroutine.qtime())

                crane:deltask() -- 删除本任务，解除阻塞（避免相互等待），继续执行下一个任务
            end
        end
    }

    -- {'unwaitagent', {index=}} -- 解除agent的阻塞，使agent继续执行其他任务
    crane.tasks.unwaitagent = {
        init = function(params)
            -- 检查参数
            if type(params.index) ~= "number" then
                print('[' .. crane.type .. crane.id .. '] unwaitagent错误，输入index参数错误:', params.index)
                print(debug.traceback())
            end

            params.dt = nil -- 任务所需时间为nil，设置状态，通知目标agent
        end,
        execute = function(dt, params)
            local index = params.index
            local targetAgent = crane.agentqueue[index]
            -- 解除阻塞
            targetAgent.operator = nil -- 结束占用目标agent
            -- print('[' .. crane.type .. crane.id .. '] unwaitagent, 解除' .. crane.agentqueue[index].type ..
            --           crane.agentqueue[index].id .. '的阻塞')
            table.remove(crane.agentqueue, index)

            coroutine.queue(0, targetAgent.execute, targetAgent) -- 通知目标agent继续运行
            crane:deltask()
        end
    }

    crane:init(config)
    return crane
end
