scene.setenv({
    grid = 'plane'
})

-- 参数
local degree = 30 -- 角度
local radian = math.pi * degree / 180 -- 角度转弧度
print(math.sin(radian))

-- 线长度
local length = 10

-- 绘制线
local line = scene.addobj("polyline", {
    vertices = {0, 0, 0, length, 0, 0},
    color = 'blue'
})
line:setrot(0, radian, 0)

print('estimate position')

local ex, ez = length * math.cos(radian), length * math.sin(radian) * -1
print('x=', ex, ' z=', ez)

-- 验证
local pointX = scene.addobj('points', {
    vertices = {ex, 0, 0},
    color = 'blue',
    size = 5
})
local labelX = scene.addobj('label', {
    text = 'project x'
})
labelX:setpos(ex, 1, 0)

local pointZ = scene.addobj('points', {
    vertices = {0, 0, ez},
    color = 'red',
    size = 5
})
local labelZ = scene.addobj('label', {
    text = 'project z'
})
labelZ:setpos(0, 1, ez)

local pointEnd = scene.addobj('points', {
    vertices = {ex, 0, ez},
    size = 5
})

scene.render()
