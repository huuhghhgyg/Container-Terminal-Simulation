# RMGQC

RMGQC 通常用于表示对船进行装卸的岸边集装箱起重机。

继承：RMGQC → [Crane](./crane.md)

```lua
local rmgqc = RMGQC(config)
```

## 属性

- `type = "rmgqc"` 类型
- `id` id，默认为 body 的 id
- `agvHeight` AGV 平台的高度，默认为 2.1
- `stack` 绑定的 Stack 对象，默认为 nil，通过 bindStack 函数绑定

## 函数

### bindStack

用于绑定 Stack 对象，主要是船。

```lua
rmgqc:bindStack(stack)
```

绑定的过程中计算了 Ship(Stack) 对应的停车位的位置，存储在 `rmgqc.stack.parkingSpaces.relativeDist` 和 `rmgqc.stack.parkingSpaces.iox` 中，分别表示停车位在道路上的相对位置和停车位对应到堆场的距离。换句话说，parkingSpaces 是 `{relativeDist, iox}` 的列表。

### showBindingPoint

显示绑定 Stack 对象的位置，通常用于 debug 或更清晰的显示。

```lua
rmgqc:showBindingPoint()
```

### setpos

RMGQC 根据各个部件重构了 setpos 函数，实现设置 RMGQC 的位置。

```lua
rmgqc:setpos(x, y, z)
```

RMGQC 中有 body, trolley, wirerope, spreader 四个部件，这些部件只能通过 RMGQC 内部进行访问。setpos 函数分别设置了这四个部件的位置。
