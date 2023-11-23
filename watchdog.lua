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
        for i = 1, #ActionObjs do
            local obj = ActionObjs[i]
            
            if obj.type == "agv" and #obj.tasksequence == 0 then
                watchdog:recycle(obj)
                table.remove(ActionObjs, i)
                break -- 假设每次同时只能到达一个，因此可以中止
            end
        end
        
        -- 检测暂停指令
        if not watchdog.runcommand then
            scene.render() -- 最后一次绘图
            print('仿真推进停止')
            return
        end
        
        -- 刷新运行时间间隔
        watchdog.dt = (os.clock() - watchdog.t) * simv
        watchdog.t = os.clock() -- 刷新update时间

        -- 计算最大更新时间
        local maxstep = watchdog.dt
        local laststep = watchdog.dt -- debug 严格模式
        for i = 1, #ActionObjs do
            if #ActionObjs[i].tasksequence > 0 then
                maxstep = math.min(maxstep, ActionObjs[i]:maxstep())
                -- 严格模式debug
                if maxstep ~= laststep and maxstep < 0.000001 then
                    print(ActionObjs[i].type, ActionObjs[i].id, ActionObjs[i].tasksequence[1][1], 'set maxstep=',
                        maxstep, ' ----------------------------------------------------------')
                    if ActionObjs[i].type == 'agv' and ActionObjs[i].tasksequence[1][1] == 'moveon' then
                        print('agv', ActionObjs[i].id, 'moveon', ActionObjs[i].road.id)
                    end
                end
                laststep = maxstep
            end
        end

        watchdog.dt = maxstep -- 修正dt(严格模式)
        -- watchdog.dt = maxstep > 0 and maxstep or watchdog.dt -- 修正dt

        -- 执行更新
        for i = 1, #ActionObjs do
            ActionObjs[i]:executeTask(watchdog.dt)
        end

        if watchdog.dt < 0.0001 then
            print('dt < 0.0001, dt=', watchdog.dt,
                ' =================================================================')
        end

        -- 下一次更新
        coroutine.queue(watchdog.dt, watchdog.update)
    end

    function watchdog:queueAt(dt)
        coroutine.queue(dt, watchdog.update)
    end

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
