# Might be useful

根据两点计算旋转弧度的公式（可能有用）

```lua
cy.rotradian = math.atan2(p2[2] - p1[2], p2[1] - p1[1])
```

## 文件管理
publish按钮的右键是share，可以将文件上传。使用`os.upload`可以将文件从远程拉取到web的虚拟磁盘中。
```lua
os.upload('https://mixwind-1.github.io/test.txt') -- 将内容上传到虚拟磁盘中
os.download('test.txt', 'https://mixwind-1.github.io/test.txt') -- 将虚拟磁盘中的文件下载到本地
```

运行js脚本
使用fastapi与lua交互

## debug
常用debug函数
```lua
debug.watch('x') -- 观察变量x的值（表也可以）
debug.debug()
debug.debug(false) -- 退出debug模式
```

堆栈跟踪
```lua
function myFunction()
    -- 某些代码逻辑
    print(debug.traceback("Stack trace"))
    -- 其他代码逻辑
end

function anotherFunction()
    myFunction()
end

anotherFunction()
```

其他debug命令
https://www.runoob.com/lua/lua-debug.html

Lua版本：5.4

## 执行JS代码
可以使用os.excute直接运行js脚本。

```lua
os.execute()
```

但是由于MicroCity使用了web worker来运行lua，所有不能直接执行js中的DOM方法，如果调用用户界面的命令例如alert可以用MicroCity的辅助函数RemoteCall来调用
```lua
os.execute('RemoteCall("alert","hello")')
```

## 与Python交互
用python的fastapi创建应用，并在MicroCity中调用
首先安装fastapi，pip install fastapi uvicorn
然后新建main.py

```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI()

# middlewares
app.add_middleware(
    CORSMiddleware,
    allow_origins=['*'],
    allow_credentials=True,
    allow_methods=['*'], 
    allow_headers=['*'], 
)

@app.get("/message")
async def read_message():
    return {"message": "Hello from FastAPI"}
```

然后在命令行执行重新加载
```shell
uvicorn main:app --reload
```

最后在MicroCity中运行
```lua
os.execute("fetch('http://127.0.0.1:8000/message').then(response => response.json()).then(data => RemoteCall('alert', data.message))")
```
或者这样写
```lua
os.execute("self.xhr = new XMLHttpRequest()")
os.execute("xhr.open('GET', 'http://127.0.0.1:8000/message', false)")
os.execute("xhr.send()")
print(os.execute("JSON.parse(xhr.responseText).message"))
```

# 常见错误
```lua
agv:addtask('moveon', {road=,}) -- 参数键值列表，记得param加大括号
agv:addtask('onnode', {node, fromRoad, toRoad}) -- 参数列表，顺序参数，记得param加大括号
```

## table
表之间的等值判断使用地址进行判断
使用if判断table变量的时候，只要table不是nil则返回true