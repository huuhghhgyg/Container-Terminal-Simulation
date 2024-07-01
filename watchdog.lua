-- simv: 仿真速度
-- ActionObjs: 所有需要更新的对象
function WatchDog(simv, ActionObjs, config)
    -- 验证参数
    if type(simv) ~= 'number' then
        print(debug.traceback('[WatchDog] simv: ' .. simv .. ' not a number'))
    elseif type(ActionObjs) ~= 'table' then
        print(debug.traceback('[WatchDog] ActionObjs: ' .. ActionObjs .. ' not a table'))
    end

    local watchdog = {
        -- 时间
        lasttime = nil, -- 上一次更新的系统时间
        -- 程序控制
        runcommand = true,
        isImmediateStop = true -- 没有任务的时候立刻停止
    }

    -- 更新参数
    if config == nil then
        config = {}
    end

    -- 立即停止参数 
    if config.isImmediateStop ~= nil then
        watchdog.isImmediateStop = config.isImmediateStop
    end
    watchdog.recycleType = config.recycleType or {"agv"} -- 需要回收的对象类型

    function watchdog.refresh(f)
        if type(f) == 'function' then
            f()
        end

        -- 参数检查
        if watchdog.lasttime == nil then -- 避免自动开始计时
            watchdog.lasttime = os.clock()
        end

        -- 刷新所有agent的状态
        local actionObjNum = 0 -- 有效更新agent数量
        for i = 1, #ActionObjs do
            local agent = ActionObjs[i]
            if #agent.tasksequence > 0 then
                agent:execute() -- 刷新对象状态，可能导致任务删除并预定新时间
                actionObjNum = actionObjNum + 1
            end
        end

        -- 检查是否需要回收
        watchdog:scanRecycle()

        -- 检查运行许可
        watchdog.runcommand = scene.render(0)
        if not watchdog.runcommand then
            print('刷新已停止')
            return
        end

        -- 检查是否需要立刻停止
        if watchdog.isImmediateStop and actionObjNum == 0 then
            print('无任务，刷新已停止')
            return
        end

        -- 更新时钟
        local now = os.clock()
        local dt = (now - watchdog.lasttime) * simv -- 本次调度与上次调度的时间间隔
        watchdog.lasttime = now -- 刷新调度时间记录

        -- 预定下一次更新
        coroutine.queue(dt * simv, watchdog.refresh, f)
    end

    -- 打印所有组件任务列表
    function watchdog:printTasks(objs)
        print('watchdog debug printTasks at ', coroutine.qtime())
        for k, obj in ipairs(objs) do
            print(obj.type .. obj.id, 'executing', obj.tasksequence[1][1])
            -- 打标签
            if obj.label == nil then
                obj.label = scene.addobj('label', {
                    text = obj.type .. obj.id
                })
            end
            local x, y, z = obj:getpos()
            obj.label:setpos(x, y + 5, z)
        end
        print('===================================')
    end

    function inRecycleList(objTypeStr)
        assert(type(objTypeStr) == "string", "输入的类型不是字符串")
        for _, v in ipairs(watchdog.recycleType) do
            if v == objTypeStr then
                return true
            end
        end
    end

    -- 检测是否需要回收
    function watchdog:scanRecycle()
        for i = 1, #ActionObjs do
            local obj = ActionObjs[i]

            if inRecycleList(obj.type) and #obj.tasksequence == 0 then
                watchdog:recycle(obj)
                table.remove(ActionObjs, i)
                break -- 假设每次同时只能到达一个，因此可以中止
            end
        end
    end

    -- 回收某个对象
    function watchdog:recycle(obj)
        if inRecycleList(obj.type) then
            if obj.container ~= nil then
                obj.container:delete()
            end
            -- print('agv', obj.id, 'leave at ', coroutine.qtime())
            obj:delete()
        end
    end

    function watchdog:beforeStop()
        for i = 1, #ActionObjs do
            local obj = ActionObjs[i]
            if obj.type ~= "container" then
                local x, y, z = obj:getpos()
                local label = scene.addobj('label', {
                    text = obj.type .. obj.id
                })
                label:setpos(x, y + 5, z)
            elseif obj.type == "node" and obj.occupied then
                local x, y, z = obj:getpos()
                local label = scene.addobj('label', {
                    text = 'occupied by ' .. obj.occupied.type .. obj.occupied.id
                })
                label:setpos(x, y - 1, z)
            end
        end
    end

    return watchdog
end
