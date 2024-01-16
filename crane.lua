function Crane(config)
    if config == nil then
        config = {}
    end

    local crane = {
        -- 基本参数
        type = config.type or 'crane', -- 类型
        stack = nil, -- 对应的stack对象
        anchorPoint = config.anchorPoint or {0, 0, 0}, -- crane锚点坐标
        pos = config.pos or {0, 0, 0}, -- crane位置坐标
        speed = config.speed or {2, 4, 8}, -- 各方向速度
        attached = nil, -- 当前吊具挂载的集装箱
        -- 任务相关
        tasksequence = {}, -- 任务序列
        tasks = {}, -- 支持的任务类型
        agentqueue = {} -- 等待服务的agent队列
    }

    -- 对象相关函数
    function crane:getpos()
        return table.unpack(crane.anchorPoint)
    end

    function crane:setpos(x, y, z)
        print(debug.traceback(crane.type .. crane.id .. ':setpos(x,y,z) 没有定义,无法调用'))
        os.exit()
    end

    -- 驱动函数
    -- 涉及到具体的流程会留空
    function crane:move2(x, y, z)
        print(debug.traceback(crane.type .. crane.id .. ':move2(x,y,z) 没有定义,无法调用'))
        os.exit()
    end

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
        if crane.stack.containers[bay][row][level] == nil then
            print(debug.traceback('[crane' .. crane.id .. '] 错误，抓取堆场中的集装箱为空'))
            -- debug
            os.exit()
        end

        -- 抓取堆场中的集装箱
        crane.attached = crane.stack.containers[bay][row][level]
        crane.stack.containers[bay][row][level] = nil
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
        crane.stack.containers[bay][row][level] = crane.attached
        crane.attached = nil
    end

    -- 绑定其他对象
    -- 绑定stack
    function crane:bindStack(stack)
        -- 包括最大能够访问的高度:levelPos, topLevel
        crane.stack = stack
        crane:setpos(stack.anchorPoint[1], stack.levelPos[#stack.levelPos], stack.anchorPoint[3])
    end

    -- 绑定道路
    function crane:bindRoad(road)

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
        local stack = crane.stack

        -- print('crane:getContainerCoord', row, bay, level) -- debug

        local x, rx
        if row == -1 then
            rx = stack.parkingSpaces[bay].iox + stack.cwidth / 2
            x = rx + stack.origin[1]
        else
            x = stack.containerPositions[1][row][1][1]
            rx = x - stack.origin[1]
        end

        local y = 0 -- 相对高度
        if row == -1 and level == 1 then -- 如果是要放下，则设置到移动到agv上
            y = crane.agvHeight -- 加上agv高度
        else
            y = stack.levelPos[level] -- 加上层高
        end
        local ry = y - stack.origin[2]
        local z = stack.containerPositions[bay][1][1][3]
        local rz = z - stack.origin[3] -- 通过车移动解决z

        -- return {rx, ry, rz}
        return {x, y, z}
    end

    -- 集合流程函数
    -- 将集装箱从agent抓取到目标位置，默认在移动层。这个函数会标记当前rmg任务目标位置
    function crane:lift2TargetPos(row, bay, level, operatedAgent)
        crane:addtask("waitagent", operatedAgent) -- 等待agent到达
        crane:addtask("move2", crane:getContainerCoord(-1, bay, 1)) -- 抓取agent上的箱子
        crane:addtask("attach", nil) -- 抓取
        crane:addtask("unwaitagent", 1) -- 发送信号，解除agent的阻塞
        crane:addtask("move2", crane:getContainerCoord(-1, bay, crane.toplevel)) -- 吊具提升到移动层
        crane:addtask("move2", crane:getContainerCoord(row, bay, crane.toplevel)) -- 移动爪子到指定位置
        crane:addtask("move2", crane:getContainerCoord(row, bay, level)) -- 移动爪子到指定位置
        crane:addtask("detach", {row, bay, level}) -- 放下指定箱
        crane:addtask("move2", crane:getContainerCoord(row, bay, crane.toplevel)) -- 爪子抬起到移动层
    end

    -- 将集装箱从目标位置移动到agent，默认在移动层。这个函数会标记当前crane任务目标位置
    function crane:lift2Agent(row, bay, level, operatedAgent)
        crane:addtask("move2", crane:getContainerCoord(row, bay, level)) -- 移动爪子到指定位置
        crane:addtask("attach", {row, bay, level}) -- 抓取
        crane:addtask("move2", crane:getContainerCoord(row, bay, crane.toplevel)) -- 吊具提升到移动层
        crane:addtask("move2", crane:getContainerCoord(-1, bay, crane.toplevel)) -- 移动爪子到agent上方
        crane:addtask("waitagent", operatedAgent) -- 等待agent到达
        crane:addtask("move2", crane:getContainerCoord(-1, bay, 1)) -- 移动爪子到agent
        crane:addtask("detach", nil) -- 放下指定箱
        crane:addtask("unwaitagent", 1) -- 发送信号，解除agent的阻塞
        crane:addtask("move2", crane:getContainerCoord(-1, bay, crane.toplevel)) -- 爪子抬起到移动层
    end

    -- 移动到目标位置，默认在移动层
    function crane:move2TargetPos(row, bay)
        crane:addtask("move2", crane:getContainerCoord(row, bay, crane.toplevel))
    end

    -- 移动到agv上方，默认在移动层
    function crane:move2Agent(bay)
        crane:addtask("move2", crane:getContainerCoord(-1, bay, crane.toplevel))
    end

    -- 任务相关函数
    -- 添加任务
    function crane:addtask(name, param)
        local task = {name, param}
        table.insert(crane.tasksequence, task)
    end

    -- 删除任务
    function crane:deltask()
        -- debug
        -- print('delete task', crane.tasksequence[1][1], 'at', coroutine.qtime())
        table.remove(crane.tasksequence, 1)
        crane.lasttask = nil -- 重置debug记录的上一个任务

        -- debug
        -- if (crane.tasksequence[1] ~= nil) then
        --     print('['..crane.type..crane.id..'] task executing: ', crane.tasksequence[1][1], 'at', coroutine.qtime())
        -- end
    end

    -- interface:计算最大允许步进
    function crane:maxstep()
        local dt = math.huge -- 初始化步进
        if crane.tasksequence[1] == nil then -- 对象无任务，直接返回0
            return dt
        end

        local taskname = crane.tasksequence[1][1] -- 任务名称
        local params = crane.tasksequence[1][2] -- 任务参数

        -- -- debug
        -- if taskname ~= crane.lasttask then
        --     print('[crane] maxstep task', taskname)
        -- end

        if crane.tasks[taskname] == nil then
            print(debug.traceback('[' .. crane.type .. crane.id .. '] 错误，没有找到任务' .. taskname))
            os.exit() -- 检测到出错立刻停止,方便发现错误
        end

        if crane.tasks[taskname].maxstep ~= nil then
            dt = math.min(dt, crane.tasks[taskname].maxstep(params))
        end

        return dt
    end

    -- 获取当前控件支持的任务的列表
    function crane:getSupportedTasks()
        local supportedTasks = {}
        for key in pairs(crane.tasks) do
            table.insert(supportedTasks, key)
        end
        return supportedTasks
    end

    -- 执行任务
    -- task: {任务名称,{参数}}
    function crane:executeTask(dt)
        if #crane.tasksequence == 0 then
            return
        end

        local task = crane.tasksequence[1]
        local taskname, params = task[1], task[2]

        -- -- debug
        -- if crane.lasttask ~= taskname then
        --     print('[crane] 当前任务', taskname, 'at', coroutine.qtime())
        --     crane.lasttask = taskname
        -- end

        if crane.tasks[taskname] == nil then
            print(debug.traceback('[' .. crane.type .. crane.id .. '] 错误，没有找到任务' .. taskname))
            os.exit() -- 检测到出错立刻停止,方便发现错误
        end

        if crane.tasks[taskname].execute ~= nil then
            crane.tasks[taskname].execute(dt, params)
        end
    end

    -- 内置任务
    -- 'move2', {x, y, z, params}
    crane.tasks.move2 = {
        maxstep = function(params)
            -- 判断是否已经初始化
            if params.vecE == nil then
                -- 计算三个方向的向量
                params.vecE = {}
                for i = 1, 3 do
                    local d = params[i] - crane.pos[i] -- 计算距离差值
                    params.vecE[i] = d == 0 and 0 or d / math.abs(d)
                end
                params.timeRemain = {} -- 初始化参数：各方向剩余时间
                params.distRemain = {} -- 初始化参数：初次执行任务时各方向剩余距离
            end

            -- 计算各方向剩余时间
            -- print()
            for i = 1, 3 do
                params.distRemain[i] = params[i] - crane.pos[i]
                params.timeRemain[i] = params.distRemain[i] * params.vecE[i] / crane.speed[i]
                -- print('direction', i, 'distRemain =', params.distRemain[i])
            end
            -- print('distRemain', TableString(params.distRemain))
            -- print('timeRemain', TableString(params.timeRemain))

            local maxRemainTime = math.max(table.unpack(params.timeRemain)) -- 获取各方向上的最大值
            return maxRemainTime
        end,
        execute = function(dt, params)
            -- 计算步进
            local nextPosition = {} -- 各方向下一步位置
            for i = 1, 3 do
                if params.timeRemain[i] >= dt then
                    nextPosition[i] = crane.pos[i] + crane.speed[i] * params.vecE[i] * dt -- 步进
                else
                    nextPosition[i] = params[i] -- 设置为终点
                end
            end
            -- print('[' .. crane.type .. crane.id .. '] pos', crane.pos[1], crane.pos[2],
            --       crane.pos[3])
            -- print('[' .. crane.type .. crane.id .. '] move2 timeRemain', params.timeRemain[1], params.timeRemain[2],
            --       params.timeRemain[3], 'dt=', dt)
            -- print('[' .. crane.type .. crane.id .. '] move2 nextPosition', nextPosition[1], nextPosition[2],
            --       nextPosition[3])

            crane:move2(table.unpack(nextPosition))

            -- 判断是否到达目标位置
            if crane.pos[1] == params[1] and crane.pos[2] == params[2] and crane.pos[3] == params[3] then
                print('[' .. crane.type .. crane.id .. '] 到达目标位置 at', coroutine.qtime() + dt) -- 下一次推进时间才是到达时间
                crane:deltask()
            end
        end
    }

    -- {'attach', {row, col, level}}
    crane.tasks.attach = {
        execute = function(dt, params)
            if params == nil then
                params = {nil, nil, nil}
            end
            crane:attach(params[1], params[2], params[3])
            crane:deltask()
        end,
        maxstep = function(params)
            return 0
        end
    }

    -- {'detach', {row, col, level}}
    crane.tasks.detach = {
        execute = function(dt, params)
            if params == nil then
                params = {nil, nil, nil}
            end
            crane:detach(params[1], params[2], params[3])
            crane:deltask()
        end,
        maxstep = function(params)
            return 0
        end
    }

    -- {'waitagent', agent} -- crane等待agent到达
    crane.tasks.waitagent = {
        maxstep = function(params)
            local agent = params
            -- 判断agent是否被当前crane有效占用
            if #crane.agentqueue > 0 and agent.occupier == crane then
                -- print('['..crane.type..crane.id..']', agent.type .. agent.id .. '已经被' .. crane.type .. crane.id ..
                --     '占用，crane删除waitagent任务 at', coroutine.qtime())

                crane:deltask() -- 删除本任务，解除阻塞（避免相互等待），继续执行下一个任务
                return crane:maxstep() -- 本任务不影响其他agent，因此可以直接递归调用，消除本任务的影响
            end

            -- print('crane' .. crane.id, 'waitagent', agent.type .. agent.id) -- debug
            return math.huge
        end
    }

    -- {'unwaitagent', agentqueue_pos} -- 解除agent的阻塞，使agent继续执行其他任务
    crane.tasks.unwaitagent = {
        maxstep = function(params)
            crane.agentqueue[params].occupier = nil -- 解除阻塞
            -- print('['..crane.type..crane.id..']' unwaitagent, 解除'..crane.agentqueue[params].type..crane.agentqueue[params].id..'的阻塞')
            table.remove(crane.agentqueue, params)
            crane:deltask()
            return crane:maxstep() -- 本任务不影响其他agent，因此可以直接递归调用，消除本任务的影响
        end
    }

    return crane
end
