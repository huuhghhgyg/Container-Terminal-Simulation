scene.setenv({grid='plane'})
local obj = scene.addobj('/res/2axle.glb')

local center = {1,0,1}
local radius = 10

for i = 0,math.pi*2,0.01 do
    local x = center[1]+radius*math.cos(i)
    local y = center[2]
    local z = center[3]+radius*math.sin(i)
    
    obj:setpos(x,y,z)
    
    local roty = math.atan(radius*math.cos(i),radius*math.sin(i))-math.atan(1,0)
    obj:setrot(0,roty,0)
    
    os.sleep(20) -- 速度放缓
    scene.render()
end
