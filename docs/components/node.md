# Node

## 字段
- `center`：中心点
- `radius`：节点半径
- `connectedRoad`：连接的道路列表。以固定的格式添加
  - `{roadId, roty}`：道路ID、道路在节点处对于y轴的旋转弧度值
- `occupied`：指示道路当前是否被占用
- `id`: Node对象添加到NodeList中后在NodeList中的索引

Controller模块注入的属性
- `fromNodesId`：来自节点，记录节点的O信息
- `toNodesId`：去向节点，记录节点的D信息


## 函数
### connectRoad
将指定id的道路连接到本节点，本节点作为其起点。
```lua
node:connectRoad(roadId)
```
- `roadId`：道路id

只需要将道路的起点连接到本节点即可，因为车辆会自动进入节点，而离开的时候需要进入到道路，一个节点可能可以到达多条道路。通过节点选择要进入的道路，从而获得道路参数，确定转弯的各个系数。

类似于`--- o--`的形式。

### createRoad
根据本节点和输入的终点节点创建一条道路。道路连接到输入的终点节点

```lua
node:createRoad(destNode, roadList)
```
- `destNode`：终点节点
- `roadList`：外部道路列表，将新建的道路添加进道路列表中

## 其他说明
线路一定要以Node结束，否则会造成空占用无法解除。