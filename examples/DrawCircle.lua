scene.setenv({
    grid = 'plane'
})

-- 圆形参数
local centerPt = {0, 0, 0} -- 圆心
local radius = 10 -- 半径

-- 弧度参数
local fromRadian = 7 --开始位置弧度
local toRradian = 9 --终止位置弧度

-- 绘制起点
local pfrom = scene.addobj('points', {
    vertices = {radius * math.sin(fromRadian) + centerPt[1], centerPt[2], radius * math.cos(fromRadian) + centerPt[3]},
    size = 5,
    color = 'red'
})

-- 绘制终点
local pto = scene.addobj('points', {
    vertices = {radius * math.sin(toRradian) + centerPt[1], centerPt[2], radius * math.cos(toRradian) + centerPt[3]},
    size = 5,
    color = 'blue'
})

-- 计算
local dradian = 0.1 -- 步进弧度长度
local radian = toRradian-fromRadian > math.pi * 2 and math.pi or toRradian-fromRadian -- 旋转弧度
local pointN = math.floor(radian / dradian) -- 步进次数

local vertices = {radius * math.sin(fromRadian) + centerPt[1], 0, radius * math.cos(fromRadian) + centerPt[3]} -- 需要预先绘制原点

for r = 1, pointN do
    local radianWalked = r * dradian + fromRadian

    local i = r * 3
    vertices[i + 1] = radius * math.sin(radianWalked) + centerPt[1]
    vertices[i + 2] = centerPt[2]
    vertices[i + 3] = radius * math.cos(radianWalked) + centerPt[3]
end

-- 绘制polyline
local circle = scene.addobj('polyline', {
    vertices = vertices
})

scene.render()
