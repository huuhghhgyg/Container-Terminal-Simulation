scene.setenv({
    grid = 'plane'
})

require('cy')

local cy = CY(5, 10, 3)

-- 绘制锚点
scene.addobj('points', {
    vertices = {cy.anchorPoint[1], cy.anchorPoint[2], cy.anchorPoint[3]},
    color = 'red',
    size = 5
})
local anchorPointLabel = scene.addobj('label',{text='Anchor Point'})
anchorPointLabel:setpos(cy.anchorPoint[1], cy.anchorPoint[2], cy.anchorPoint[3])

-- cy:fillContainerPositions()
cy:fillRandomContainerPositions(60)

scene.render()