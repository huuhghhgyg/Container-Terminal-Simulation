scene.setenv({
    grid = 'plane'
}) -- 设置场景网格背景

-- 车辆
local car = scene.addobj('/res/2axle.glb')
car.speed = 1 -- 车速度
car.origin = {0, 0, 0}

-- 时间参数
local t = os.clock()
local dt = 0
local simv = 100

-- 刷新时间状态t和dt(按照CPU间隔步进，达到和真实时间同步)
function refreshtime()
    dt = (os.clock() - t) * simv
    t = os.clock()
end

-- 协程更新场景
function update()
    if not scene.render() then
        return
    end -- 渲染场景并检查程序是否中止
    if car.arrived then
        return
    end

    carmove() -- 移动车辆
    refreshtime() -- 计算本次dt
    coroutine.queue(dt, update) -- 根据CPU步进时间添加下一次更新
end

-- 初始计算
function carsetup(distz)
    car.distz = distz -- 目标移动距离
    car.tmax = car.distz / car.speed
    car.arrived = false -- 到达标志
    car.tstart = coroutine.qtime() -- 记录开始时间
    coroutine.queue(car.tstart, update)
    coroutine.queue(car.tstart + car.tmax, update)
end

-- 车辆移动
function carmove()
    local runt = coroutine.qtime() - car.tstart
    local z = car.tmax > runt and car.origin[3] + runt * car.speed or car.distz
    car:setpos(car.origin[1], car.origin[2], z)
    if car.tmax <= runt then
        print('car arrived at', coroutine.qtime())
        car.arrived = true
    end
end

carsetup(150)
