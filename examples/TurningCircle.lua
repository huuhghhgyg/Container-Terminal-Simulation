scene.setenv({
    grid = 'plane'
})

local obj = scene.addobj('box')

-- 运动对象参数
local t = 0
local dt = 0.01
local pos = {0,0,0}
local rot = {0,0,0}

-- 旋转参数
local center = {0,0,0}
local radius = 10

-- 绘制旋转点
local centerPt = scene.addobj('points',{vertices = center, color = 'blue', size = 5})

while scene.render() do
    -- 时间步进
	t = t + dt
	
    -- 设置位置
	pos[1] = center[1] + radius * math.cos(t)
	pos[3] = center[3] + radius * math.sin(t)
	pos[2] = center[2]
	obj:setpos(table.unpack(pos))
	
	-- 设置旋转
	rot[2] = rot[2] - dt
	obj:setrot(table.unpack(rot))
end