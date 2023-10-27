scene.setenv({
    grid = 'plane'
})

-- local vec={10,-10} -- -135
-- local vec={10,10} -- -45
local vec = {-10, 10} -- 45

local radian = math.atan(0, 1) - math.atan(table.unpack(vec))

-- z轴
scene.addobj('points', {
    vertices = {0, 0, 0},
    size = 4
})
scene.addobj('polyline', {
    vertices = {0, 0, 0, 0, 0, 10},
    color = 'red'
})

-- 输入点
scene.addobj('points', {
    vertices = {vec[1], 0, vec[2]},
    size = 4
})
scene.addobj('polyline', {
    vertices = {0, 0, 0, vec[1], 0, vec[2]},
    color = 'blue'
})

scene.render()

print("弧度差=", radian, "\t补偿弧度=", -radian)
print("角度差=", radian * 180 / math.pi, "\t补偿角度=", -radian * 180 / math.pi)

