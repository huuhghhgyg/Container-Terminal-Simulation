function WatchDog(simv, ActionObjs)
    local watchdog = {
        -- 时间
        t = os.clock(),
        dt = 0,
        -- 程序控制
        runcommand = true,
        isImmediateStop = true -- 没有任务的时候立刻停止
    }

    function watchdog:update()
        -- 绘图
        watchdog.runcommand = scene.render()

        -- 回收
        watchdog:scanRecycle()

        -- 检测暂停指令
        if not watchdog.runcommand then
            watchdog:beforeStop()
            scene.render() -- 最后一次绘图
            print('仿真推进停止')
            return
        end

        -- 刷新运行时间间隔
        watchdog.dt = (os.clock() - watchdog.t) * simv
        watchdog.t = os.clock() -- 刷新update时间

        local maxstep
        local maxstepItem = 0 -- 作用于isImmediateStop
        repeat
            maxstep = watchdog.dt

            -- 计算最大更新时间
            for i = 1, #ActionObjs do
                if #ActionObjs[i].tasksequence > 0 then
                    maxstepItem = maxstepItem + 1 -- 记录起作用的item

                    local objectTask = ActionObjs[i].tasksequence[1][1]
                    local objectMaxstep = ActionObjs[i]:maxstep()
                    -- print('[' .. ActionObjs[i].type .. ActionObjs[i].id .. ']', objectTask, 'maxstep=', objectMaxstep)
                    maxstep = math.min(maxstep, objectMaxstep)

                    if maxstep < 0 then
                        -- print('maxstep < 0，跳出actionobjs循环')
                        break -- 立刻跳出循环
                    end
                end
            end

            -- 如果正常可以直接跳出循环
            if maxstep > 0 then
                break
            end
            watchdog:scanRecycle() -- 检查回收

        until maxstep >= 0

        watchdog.dt = maxstep -- 修正dt(严格模式)

        -- 执行更新
        for i = 1, #ActionObjs do
            -- print('[' .. ActionObjs[i].type .. ActionObjs[i].id .. '] executeTask', ActionObjs[i].tasksequence[1][1],
            --     'at ', coroutine.qtime())
            ActionObjs[i]:executeTask(watchdog.dt)
        end

        -- 防止无限推进
        if #ActionObjs == 0 or watchdog.isImmediateStop and maxstepItem == 0 then
            scene.render()
            print('无任务实体，仿真停止 t=', coroutine.qtime())
            return
        end

        -- -- debug 检测是否有删除任务
        -- local isItemDeletedTask = false
        -- for k, v in ipairs(ActionObjs) do
        --     if v.isDeletedTask then
        --         isItemDeletedTask = true -- 标记flag
        --         v.isDeletedTask = false -- 恢复标记
        --         print("watchdog debug 检测到"..v.type..v.id.."有删除任务，已暂停==")
        --         break
        --     end
        -- end
        -- -- 打印所有组件任务列表
        -- if isItemDeletedTask then
        --     watchdog:printTasks(ActionObjs)
        --     scene.render()
        --     -- debug.pause()
        -- end

        -- 下一次更新
        coroutine.queue(watchdog.dt, watchdog.update)
    end

    function watchdog:queueAt(dt)
        coroutine.queue(dt, watchdog.update)
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

    -- 检测是否需要回收
    function watchdog:scanRecycle()
        for i = 1, #ActionObjs do
            local obj = ActionObjs[i]

            if obj.type == "agv" and #obj.tasksequence == 0 then
                watchdog:recycle(obj)
                table.remove(ActionObjs, i)
                break -- 假设每次同时只能到达一个，因此可以中止
            end
        end
    end

    -- 回收某个对象
    function watchdog:recycle(obj)
        if obj.type == "agv" then
            if obj.container ~= nil then
                obj.container:delete()
            end
            print('agv', obj.id, 'leave at ', coroutine.qtime())
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
