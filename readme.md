# Container Terminal Simulation

港口仿真框架及其相关库函数

## 开始使用

以[AgentTest](./tests/AgentTest.lua)为例介绍如何在 MicroCity 中使用本项目。

1. 首先在 MicroCity 中打开 AgentTest.lua 文件。
2. 接着上传相关的库文件到 MicroCity 的虚拟磁盘中。
   - 首先上传[watchdog](./watchdog.lua)，用于控制仿真过程。
   - 然后根据脚本使用的组件上传其他组件。如[AgentTest](./tests/AgentTest.lua#L6)中第 6 行`require('agent')`，表示引用了[agent](./agent.lua)组件，因此也需要上传到 MicroCity 的虚拟磁盘中。
3. 点击运行，即可开始仿真。

## 项目结构

| 目录        | 说明                                                                         |
| ----------- | ---------------------------------------------------------------------------- |
| `/`         | 根目录，存放了所有的组件，包括 agent、watchdog、agv 等                       |
| `tests/`    | 测试目录，存放了测试脚本，用于测试各个组件的功能，同时也作为使用各组件的示例 |
| `docs/`     | 文档目录，存放了各个组件的文档，包括组件的功能、参数、使用方法等             |
| `examples/` | 功能测试目录，存放了一些技术方法的实现的示例脚本                             |
