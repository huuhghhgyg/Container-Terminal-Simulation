function WatchDog(simv, ActionObjs)
    local watchdog = {
        -- 时间
        t = os.clock(),
        dt = 0,
        -- 程序控制
        runcommand = true
    }

    -- todo: 此处的控制程序修改过，可能需要更新到正式使用的文件中
    function watchdog:update()
        -- 刷新时间间隔
        watchdog.dt = (os.clock() - watchdog.t) * simv
        watchdog.t = os.clock()

        -- 计算最大更新时间
        local maxstep = watchdog.dt
        for i = 1, #ActionObjs do
            if #ActionObjs[i].tasksequence > 0 then
                maxstep = math.min(maxstep, ActionObjs[i]:maxstep())
            end
        end

        -- 执行更新
        for i = 1, #ActionObjs do
            ActionObjs[i]:executeTask(watchdog.dt)
        end

        -- 回收
        for i = 1, #ActionObjs do
            local obj = ActionObjs[i]

            if obj.type == "agv" and #obj.tasksequence == 0 then
                recycle(obj)
                table.remove(ActionObjs, i)
                break -- 假设每次同时只能到达一个，因此可以中止
            end
        end

        -- 绘图
        watchdog.runcommand = scene.render()

        -- 下一次更新
        if watchdog.runcommand then
            coroutine.queue(watchdog.dt, watchdog.update)
        end
    end

    function watchdog:recycle(obj)
        if obj.type == "agv" then
            if obj.container ~= nil then
                obj.container:delete()
            end
            obj:delete()
        end
    end

    return watchdog
end
