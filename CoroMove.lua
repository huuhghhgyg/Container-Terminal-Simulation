scene.setenv({grid='plane'})

-- 车辆
-- local car = scene.addobj('/res/2axle.glb')
local car = scene.addobj('box')
car.speed = 1 --车速度

-- 初始时间
local t = os.clock()
local dt = 0

-- 刷新时间状态(CPU步进)
function refreshtime()
    dt = os.clock() - t
    t = os.clock()
end

function update()
    coroutine.queue(dt, update)
    carmove()
    scene.render()
    refreshtime() --计算本次dt
end

function carmove()
    print("car move at ",t)
    local x, y, z = car:getpos()
    car:setpos(x,y,z+dt*car.speed)
end

coroutine.queue(dt,update)