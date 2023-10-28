# AGV

## 属性
- `agv.type = "agv"` 记录对象类型
- `agv.speed = 10` agv速度
- `agv.roty = 0` 以y为轴的旋转弧度默认方向为0
- `agv.tasksequence = {}` 初始化务队列
- `agv.container = nil` 初始化集装箱
- `agv.height = 2.10` agv平台高度
- `agv.safetyDistance = 20` 安全离
- `agv.road = nil` agv当前绑定的道路对象。相对应road:registerAgv中设置agv的road属性。
- `agv.state` agv状态，包括`nil` 正常,`wait` 等待（用于避免计算`maxstep`）

## 任务

### move2
```lua
{"move2", x, z, [occupied=bool, vectorDistanceXZ={dx, dz}, movedXZ={mx, mz}, originXZ={ox, oz}]}
```

#### 参数列表
- `param[1], param[2]` 目标位置(x,z)，默认y=0且所有设备均在初始平面
- `occupy` 元胞自动机排队模型中元胞位置是否占用
- `param.vectorDistanceXZ` xz方向向量距离（原函数 3，4）
- `param.movedXZ` xz方向已经移动的距离（原函数 5，6）
- `param.originXZ` xz方向初始位置（原函数 7，8）
- `param.speed` 各个方向的分速度，也用于判断是否已经初始化

### onnode
```lua
{"onnode", node, fromRoad, toRoad}
```

可能存在deltaRadians为0的情况，此时不需要转弯，因此不存在转弯半径

#### 参数列表
- `node` 节点对象
- `fromRoad` 从哪条道路进入
- `toRoad` 进入到哪条道路
- `param.fromRadian` 从Road1进入到Node的旋转弧度（Road1方向向量的弧度）
- `param.toRadian` 从Node进入到Road2的旋转弧度（Road2方向向量的弧度）
- `param.deltaRadian` 从Road1转向Road2的旋转弧度。用于判断左转还是右转，如果`deltaRadian > 0`则为左转，反之为右转，如果`deltaRadian = 0`则不需要转弯
- `param.walked` 已经旋转的弧度/已经通过的直线距离
- `param.radius` 转弯半径
- `param.center` 转弯中心(圆心)
- `param.turnOriginRadian` 转弯起始弧度，旋转90度方向与转弯方向相反
- `param.angularSpeed` 角速度
