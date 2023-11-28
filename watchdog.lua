function WatchDog(simv, ActionObjs)
    local watchdog = {
        -- 时间
        t = os.clock(),
        dt = 0,
        -- 程序控制
        runcommand = true
    }

    function watchdog:update()
        -- 绘图
        watchdog.runcommand = scene.render()

        -- 回收
        watchdog:scanRecycle()

        -- 检测暂停指令
        if not watchdog.runcommand then
            scene.render() -- 最后一次绘图
            print('仿真推进停止')
            return
        end

        -- 刷新运行时间间隔
        watchdog.dt = (os.clock() - watchdog.t) * simv
        watchdog.t = os.clock() -- 刷新update时间

        local maxstep
        repeat
            maxstep = watchdog.dt

            -- 计算最大更新时间
            -- local laststep = watchdog.dt -- debug 严格模式

            -- print('[watchdog] maxstep, ObjCount=', #ActionObjs)
            for i = 1, #ActionObjs do
                if #ActionObjs[i].tasksequence > 0 then
                    -- print('[' .. ActionObjs[i].type .. ActionObjs[i].id .. '] maxstep')
                    maxstep = math.min(maxstep, ActionObjs[i]:maxstep())
                    -- 严格模式debug
                    -- if maxstep ~= laststep and maxstep < 0.000001 and ActionObjs[i].tasksequence[1][1]~='onnode' then
                    --     print(ActionObjs[i].type, ActionObjs[i].id, ActionObjs[i].tasksequence[1][1], 'set maxstep=',
                    --         maxstep, ' ----------------------------------------------------------')
                    -- end
                    -- laststep = maxstep

                    if maxstep < 0 then
                        break -- 立刻跳出循环
                    end
                end
            end

            -- 如果正常可以直接跳出循环
            if maxstep > 0 then
                break
            end
            print('[watchdog] maxstep < 0 触发maxstep重新运行并删除实体, ObjCount=', #ActionObjs) -- debug 显示触发maxstep重新运行
            watchdog:scanRecycle() -- 检查回收

        until maxstep >= 0

        watchdog.dt = maxstep -- 修正dt(严格模式)
        -- watchdog.dt = maxstep > 0 and maxstep or watchdog.dt -- 修正dt

        -- 执行更新
        for i = 1, #ActionObjs do
            -- print('[' .. ActionObjs[i].type .. ActionObjs[i].id .. '] executeTask')
            ActionObjs[i]:executeTask(watchdog.dt)
        end

        -- debug 唤醒时间间隔监测
        -- if watchdog.dt < 0.0001 then
        --     print('dt < 0.0001, dt=', watchdog.dt,
        --         ' =================================================================')
        -- end

        -- 下一次更新
        coroutine.queue(watchdog.dt, watchdog.update)
    end

    function watchdog:queueAt(dt)
        coroutine.queue(dt, watchdog.update)
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

    return watchdog
end
