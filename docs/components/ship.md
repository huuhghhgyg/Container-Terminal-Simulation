# Ship

Ship 主要记录和显示船上存储集装箱，由 RMGQC 负责装卸。

继承: Ship → [Stack](./stack.md)

```lua
local ship = Ship(config)
```

由于船的模型大小固定，因此一般不会修改容量相关参数，如 row、bay。

## 属性

可以通过 config 修改的参数：

- `row` 行数，默认为 9
- `bay` 列数，默认为 8
- `level` 层数，默认为 2
- `cspan` 集装箱之间 x 方向和 z 方向的间距{xspan,zspan}，默认为{0, 0.5}
- `anchorPoint` 船的锚点位置，默认为{0, 0, 0}，用于计算 Crane Attach 位置
- `modelDelta` 模型偏移量，{-4.5 \* 2.44, 11.29, 22}，用于调整集装箱堆存原点位置 origin

其他参数

- `type = ship` 类型
- `origin` 集装箱堆存原点位置，通过 anchorPoint 和 modelDelta 计算得到
- `operator` Ship 对应的 RMGQC
- `bayPosition` 记录每个 bay 的 z 坐标位置

由于 Ship 继承自 Stack，因此沿用了 Stack 的部分属性，详见 [Stack 属性](./stack.md#属性)。

## 函数

### setpos

Ship 重写了 setpos 函数，用于设置船的位置。其中添加了很多位置标记。

```lua
ship:setpos(x, y, z)
```

### getIdlePosition

返回船上空余位置的编号 {row, bay, level}，如果没找到返回 nil

```lua
ship:getIdlePosition()
```
