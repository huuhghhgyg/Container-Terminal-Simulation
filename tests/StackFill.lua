require('stack')

scene.setenv({
    grid = 'plane'
})
print()

-- 自定义模型地址
-- os.upload('/res/ct/container.glb')
-- local s = Stack({
--     row = 5,
--     col = 10,
--     level = 3,
--     containerUrls = {'container.glb'}
-- })

local s = Stack(5, 10, 3)

-- s:fillAllContainerPositions()
s:fillRandomContainerPositions(60)

local box = scene.addobj('box')
box:setpos(table.unpack(s.anchorPoint))

scene.render()