# 第一章：TypeScript 开发者入门指南

## 为什么选择 Gleam？

如果你是一名 TypeScript 开发者，你可能会问：为什么要学习 Gleam？

### 类型安全的终极形态

TypeScript 提供了静态类型检查，但它仍然运行在 JavaScript 之上。这意味着：

```typescript
// TypeScript 代码
interface User {
  id: number;
  name: string;
}

function getUser(id: number): User {
  // 运行时可能返回 null，但类型系统不知道
  return fetchUser(id); // 可能抛出异常
}
```

Gleam 则不同：

```gleam
// Gleam 代码
pub type User {
  User(id: Int, name: String)
}

pub fn get_user(id: Int) -> Result(User, UserError) {
  // 必须显式处理错误情况
  case fetch_user(id) {
    Ok(user) -> Ok(user)
    Error(reason) -> Error(UserNotFound(reason))
  }
}
```

### 没有 null，没有 undefined

在 TypeScript 中，`null` 和 `undefined` 是许多运行时错误的根源：

```typescript
// TypeScript
const user = users.find(u => u.id === 1);
console.log(user.name); // 可能崩溃：Cannot read property 'name' of undefined
```

Gleam 使用 `Option` 类型：

```gleam
// Gleam
import gleam/option.{type Option, Some, None}

pub fn main() {
  let user = list.find(users, fn(u) { u.id == 1 })
  
  case user {
    Some(u) -> io.println(u.name)
    None -> io.println("User not found")
  }
}
```

### 模式匹配的力量

TypeScript 的 `switch` 语句功能有限：

```typescript
// TypeScript
type Status = "pending" | "running" | "completed" | "failed";

function getStatusMessage(status: Status): string {
  switch (status) {
    case "pending":
      return "Waiting...";
    case "running":
      return "In progress...";
    case "completed":
      return "Done!";
    case "failed":
      return "Error!";
    default:
      return "Unknown"; // 需要默认分支
  }
}
```

Gleam 的模式匹配更加优雅：

```gleam
// Gleam
pub type Status {
  Pending
  Running
  Completed
  Failed
}

pub fn get_status_message(status: Status) -> String {
  case status {
    Pending -> "Waiting..."
    Running -> "In progress..."
    Completed -> "Done!"
    Failed -> "Error!"
    // 不需要默认分支 - 编译器确保所有情况都被处理
  }
}
```

## Gleam 简介

### 什么是 Gleam？

Gleam 是一门现代的、类型安全的函数式编程语言，可以编译为：

- **Erlang** - 运行在 BEAM 虚拟机上
- **JavaScript** - 运行在 Node.js 或浏览器中

### 核心特性

| 特性 | 描述 |
|------|------|
| 强类型 | 编译时捕获所有类型错误 |
| 不可变数据 | 所有数据结构默认不可变 |
| 模式匹配 | 强大的模式匹配系统 |
| 代数数据类型 | 自定义类型和联合类型 |
| 无空值 | 使用 Option 类型处理可空值 |
| 错误处理 | 使用 Result 类型显式处理错误 |

### 与 TypeScript 的对比

| 方面 | TypeScript | Gleam |
|------|------------|-------|
| 类型系统 | 结构化类型 | 名义类型 |
| 空值 | null/undefined | Option 类型 |
| 错误处理 | try/catch | Result 类型 |
| 可变性 | 可变 | 不可变 |
| 模式匹配 | switch/if | 模式匹配 |
| 运行时 | JavaScript | Erlang/JavaScript |

## 安装 Gleam

### macOS

```bash
# 使用 Homebrew
brew install gleam

# 或使用 asdf
asdf plugin add gleam
asdf install gleam 1.4.0
asdf global gleam 1.4.0
```

### Linux

```bash
# 使用 asdf
asdf plugin add gleam
asdf install gleam 1.4.0
asdf global gleam 1.4.0
```

### Windows

```powershell
# 使用 Scoop
scoop install gleam

# 或使用 Chocolatey
choco install gleam
```

### 验证安装

```bash
gleam --version
# gleam 1.4.0
```

## 创建第一个项目

```bash
# 创建新项目
gleam new my_app

# 进入项目目录
cd my_app

# 项目结构
# my_app/
# ├── gleam.toml          # 项目配置
# ├── manifest.toml       # 依赖锁定
# ├── src/
# │   └── my_app.gleam    # 主模块
# └── test/
#     └── my_app_test.gleam # 测试文件

# 构建项目
gleam build

# 运行项目
gleam run

# 运行测试
gleam test
```

## Hello World

```gleam
// src/my_app.gleam
import gleam/io

pub fn main() -> Nil {
  io.println("Hello, from my_app!")
}
```

## 与 TypeScript 集成

### 项目结构

```
my_project/
├── src/
│   ├── index.ts          # TypeScript 入口
│   └── gleam/            # Gleam 模块
│       └── my_gleam_app/
│           ├── gleam.toml
│           └── src/
│               └── my_gleam_app.gleam
├── package.json
└── tsconfig.json
```

### gleam.toml 配置

```toml
name = "my_gleam_app"
version = "1.0.0"
target = "javascript"

[javascript]
typescript_declarations = true  # 生成 .d.ts 文件
```

### 从 TypeScript 调用 Gleam

```typescript
// src/index.ts
import { main } from './gleam/my_gleam_app/build/dev/javascript/my_gleam_app/my_gleam_app.mjs';

main(); // 调用 Gleam 函数
```

## 开发工具

### 编辑器支持

Gleam 有优秀的编辑器支持：

- **VS Code** - 官方 Gleam 扩展
- **Vim/Neovim** - gleam.vim 插件
- **Emacs** - gleam-mode

### VS Code 扩展功能

- 语法高亮
- 自动补全
- 类型提示
- 跳转到定义
- 内联错误提示
- 代码格式化

### LSP 支持

Gleam 的语言服务器提供：

- 实时类型检查
- 自动补全
- 重命名重构
- 查找引用
- 代码诊断

## 实际案例：TraeNuPI 项目

本书基于 TraeNuPI 项目，这是一个生产级 AI 伴侣系统：

### 项目统计

| 指标 | 数值 |
|------|------|
| Gleam 模块 | 23 |
| 代码行数 | 7,000+ |
| 测试用例 | 343 |
| FFI 文件 | 6 |

### 模块示例

```gleam
// traenupi_core/src/traenupi_core/task.gleam
pub type Task {
  Task(
    id: String,
    title: String,
    status: TaskStatus,
    priority: Int,
    created_at: Int,
  )
}

pub type TaskStatus {
  Pending
  InProgress
  Completed
  Cancelled
}

pub fn new(title: String, priority: Int) -> Task {
  Task(
    id: generate_id(),
    title: title,
    status: Pending,
    priority: priority,
    created_at: now(),
  )
}

pub fn start(task: Task) -> Result(Task, TaskError) {
  case task.status {
    Pending -> Ok(Task(..task, status: InProgress))
    _ -> Error(InvalidTransition)
  }
}
```

## 小结

在本章中，我们学习了：

1. **为什么选择 Gleam** - 类型安全、无空值、模式匹配
2. **Gleam 简介** - 核心特性和与 TypeScript 的对比
3. **安装和设置** - 如何安装 Gleam 和创建项目
4. **与 TypeScript 集成** - 如何在 TypeScript 项目中使用 Gleam
5. **开发工具** - 编辑器支持和 LSP

下一章，我们将深入学习 Gleam 的类型系统和模式匹配。
