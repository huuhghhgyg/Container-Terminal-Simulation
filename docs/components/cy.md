# CY

CY 主要记录和显示堆场中存储的集装箱，由 RMG 负责装卸。

继承: CY → [Stack](./stack.md)

```lua
local cy = CY(row, col, level, config)
```

修改堆场容量相关参数的情况比较常见，因此 row,bay,level 直接作为必需参数传入。

## 属性

- `type = 'cy'` 类型
- `parkingSpaces` 停车位置（使用相对坐标索引），表示对应 bay 停车位置对应道路上的停车位置，是 `{relativeDist, iox}` 的列表。
  - `relativeDist` 停车位置在道路上的相对位置
  - `iox` 停车位对应到堆场的 iox 距离
    main.lua 中的 cy.positionLevels: 对应每个{bay, row}位置的集装箱层数。结合层高限制可以用于判断可以进行装卸操作的类型。
- `bindingRoad` 绑定的道路对象，默认为 nil，通过 bindRoad 函数绑定。

由于 CY 继承自 Stack，因此沿用了 Stack 的部分属性，详见 [Stack 属性](./stack.md#属性)。

## 函数

### bindRoad

绑定道路，并获取各 bay 对应的停车位置。

```lua
cy:bindRoad(road)
```

每个 CY 只能绑定一条道路，通过 `cy.bindingRoad` 记录。
绑定道路时，会根据 bay 的位置计算停车位的位置，存储在 `cy.parkingSpaces.relativeDist` 和 `cy.parkingSpaces.iox` 中，分别表示停车位在道路上的相对位置和停车位对应到堆场的距离。

### showBindingPoint

显示绑定道路对应的停车位点，通常用于 debug 或更清晰的显示。

```lua
cy:showBindingPoint()
```
