# Stack

Stack 是存储场的抽象类。由于堆场和船的存储功能和结构类似，所以将存储集装箱的地方抽象为 Stack 类。

```lua
local stack = Stack(row, col, level, config)
```

## 属性

创建 Stack 时可通过 config 属性修改的参数：

- 模型参数

  - `type` 类型，默认值为 stack
  - `clength` 集装箱模型长度，默认为 6.06
  - `cwidth` 集装箱模型宽度，默认为 2.44
  - `cheight` 集装箱模型高度，默认为 2.42
  - `cspan` 集装箱 x 方向和 z 方向的间距{xspan,zspan}，默认为{0.6, 0.6}
  - `containerUrls` 集装箱模型 url 列表

- 位置参数

  - `origin` 原点，用于计算集装箱的相对位置。默认为{0, 0, 0}
  - `rot` 沿 y 轴的旋转弧度，默认为 0

- 容量参数
  - `row` 行数
  - `col` 列数
  - `level` 层数

内置变量
`containerPositions` 堆场各集装箱位置坐标(bay,row,level)的列表
`containers` 集装箱对象列表(使用相对坐标索引)

## 函数

- [fillAllContainerPositions](#fillallcontainerpositions) 将堆场所有可用位置填充集装箱
- [fillRandomContainerPositions](#fillrandomcontainerpositions) 随机生成集装箱
- [fillWithContainer](#fillwithcontainer) 在指定位置生成集装箱

### fillAllContainerPositions

将堆场所有可用位置填充集装箱，一般用于 debug/demo。

```lua
stack:fillAllContainerPositions()
```

### fillRandomContainerPositions

根据总生成集装箱数量 sum 随机生成每个(stack.bay, stack.row)位置的集装箱数量。一般用于 debug/demo。

```lua
stack:fillRandomContainerPositions(sum, containerUrls)
```

其中 containerUrls 为可以使用的三维模型列表

### fillWithContainer

在指定的(row, bay, level)位置生成集装箱

```lua
stack:fillWithContainer(row, bay, level)
```
