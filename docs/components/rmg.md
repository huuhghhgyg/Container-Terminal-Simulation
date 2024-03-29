# RMG

RMG 通常用于表示在堆场中工作的轨道式龙门起重机。
此处 RMG 主要基于 Crane 基类中的逻辑，通过对应的三位模型对 RMG 进行具体实现。

继承: RMG → [Crane](./crane.md)

```lua
local rmg = RMG(config)
```

## 属性

- `agvHeight` AGV 平台的高度，默认为 2.1
- `id` id，默认为 body 的 id

RMG 的属性基本继承自 Crane，具体参见[Crane 属性](./crane.md#属性)

## 函数

### setpos

RMG 根据各个部件重构了 setpos 函数，实现设置 RMG 的位置。

```lua
rmg:setpos(x, y, z)
```

RMG 中有 body, trolley, wirerope, spreader 四个部件，这些部件只能通过 RMG 内部进行访问。setpos 函数分别设置了这四个部件的位置。

## 任务

由于 RMG 继承自 Crane 且没有新增任务，因此 RMG 的任务与 Crane 相同，具体参见[Crane 任务](./crane.md#任务)
