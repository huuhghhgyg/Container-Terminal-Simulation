local obj = scene.addobj('box')
local sbj = scene.addobj('box')
obj:setscale(5, 5, 5)
sbj:setpos(10,0,0)
sbj:setparent(obj)

local x, y, z = 0, 0, 0
while scene.render() do
--   x = x + 0.1
  y = y + 0.01
  obj:setrot(x, y, z)
  sbj:setrot(y, x, z)
end