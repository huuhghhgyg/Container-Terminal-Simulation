# Controller

## 函数
sortRoadIdSequence(nodeId, roadIds): 输入起始节点和对应的乱序道路id列表，返回排序好的路线table，结构为`result = { roads = {}, nodes = {} }`，其中`roads`为排序好的道路id列表，`nodes`为排序好的节点id列表。`nodes`中包含输入的起始节点编号对应的节点。
```text
输入：从节点17到5经过的道路id列表
stpRoadIds: 2,3,4,22,23,24
输出：按照线路顺序整理得到的道路id列表和节点id列表
roads: 22,24,23,2,3,4
nodes: 17,18,19,2,3,4
```
因此，nodes中有起始节点，因此应该先读取nodes，再读取roads。