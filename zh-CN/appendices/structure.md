# 附录 D：项目结构指南

## 标准项目结构

```
my_app/
├── gleam.toml           # 项目配置
├── manifest.toml        # 依赖锁定
├── README.md            # 项目说明
├── .gitignore           # Git 忽略文件
├── src/                 # 源代码
│   ├── my_app.gleam     # 主模块
│   ├── my_app/
│   │   ├── user.gleam   # 用户模块
│   │   ├── task.gleam   # 任务模块
│   │   └── utils.gleam  # 工具函数
│   └── my_app_ffi.mjs   # JavaScript FFI
├── test/                # 测试代码
│   ├── my_app_test.gleam
│   └── my_app/
│       ├── user_test.gleam
│       └── task_test.gleam
└── build/               # 构建输出（自动生成）
    └── dev/
        └── javascript/
            └── my_app/
```

## 命名约定

### 文件命名

- 使用 snake_case：`user_repository.gleam`
- 测试文件添加 `_test` 后缀：`user_test.gleam`
- FFI 文件添加 `_ffi` 后缀：`my_app_ffi.mjs`

### 模块命名

```gleam
// src/my_app/user.gleam
pub type User { ... }           // 类型：PascalCase
pub fn create_user() { ... }    // 函数：snake_case
pub const default_role = "user" // 常量：snake_case
```

### 类型命名

```gleam
// 类型：PascalCase
pub type User { ... }
pub type UserRole { ... }

// 变体：PascalCase
pub type Status {
  Pending
  InProgress
  Completed
}

// 记录字段：snake_case
pub type User {
  User(
    id: String,
    user_name: String,
    created_at: Int,
  )
}
```

## 模块组织

### 按功能组织

```
src/
├── my_app.gleam           # 入口点
├── my_app/
│   ├── core/              # 核心功能
│   │   ├── types.gleam    # 类型定义
│   │   └── config.gleam   # 配置
│   ├── domain/            # 领域逻辑
│   │   ├── user.gleam
│   │   └── task.gleam
│   ├── infra/             # 基础设施
│   │   ├── db.gleam
│   │   └── http.gleam
│   └── utils/             # 工具函数
│       ├── string.gleam
│       └── date.gleam
```

### 按层组织

```
src/
├── my_app.gleam
├── my_app/
│   ├── models/            # 数据模型
│   │   ├── user.gleam
│   │   └── task.gleam
│   ├── services/          # 业务逻辑
│   │   ├── user_service.gleam
│   │   └── task_service.gleam
│   ├── repositories/      # 数据访问
│   │   ├── user_repo.gleam
│   │   └── task_repo.gleam
│   └── handlers/          # HTTP 处理器
│       ├── user_handler.gleam
│       └── task_handler.gleam
```

## 依赖管理

### gleam.toml

```toml
name = "my_app"
version = "1.0.0"

[dependencies]
gleam_stdlib = ">= 0.34.0 and < 2.0.0"
gleam_json = ">= 1.0.0 and < 2.0.0"
gleam_http = ">= 3.0.0 and < 4.0.0"

[dev-dependencies]
gleeunit = ">= 1.0.0 and < 2.0.0"

[javascript]
typescript_declarations = true
```

### 添加依赖

```bash
# 添加生产依赖
gleam add gleam_json

# 添加开发依赖
gleam add --dev gleeunit
```

## 测试组织

### 单元测试

```gleam
// test/my_app/user_test.gleam
import gleeunit
import gleeunit/should
import my_app/user

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn create_user_test() {
  let user = user.new("Alice", "alice@example.com")
  
  user.name |> should.equal("Alice")
  user.email |> should.equal("alice@example.com")
}

pub fn validate_user_test() {
  let user = user.new("", "")
  
  case user.validate(user) {
    Ok(_) -> should.fail("应该验证失败")
    Error(errors) -> {
      errors |> should.contain(user.Required("name"))
    }
  }
}
```

### 集成测试

```gleam
// test/my_app/integration_test.gleam
import gleeunit
import my_app/db
import my_app/user_repo

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn save_and_find_user_test() -> Promise(Nil) {
  use conn <- promise.try_await(db.connect())
  
  let user = user.new("Alice", "alice@example.com")
  use _ <- promise.try_await(user_repo.save(conn, user))
  use found <- promise.try_await(user_repo.find_by_email(conn, "alice@example.com"))
  
  case found {
    Some(u) -> {
      u.name |> should.equal("Alice")
      promise.resolve(Ok(Nil))
    }
    None -> {
      should.fail("用户未找到")
      promise.resolve(Ok(Nil))
    }
  }
}
```

## FFI 组织

### JavaScript FFI

```javascript
// src/my_app_ffi.mjs

// 简单函数
export function now() {
  return Date.now();
}

// 异步函数
export async function fetch(url) {
  const response = await fetch(url);
  return response.text();
}

// 错误处理
export function parseJson(text) {
  try {
    return { type: "ok", value: JSON.parse(text) };
  } catch (e) {
    return { type: "error", error: e.message };
  }
}
```

```gleam
// src/my_app.gleam
@external(javascript, "./my_app_ffi.mjs", "now")
pub fn now() -> Int

@external(javascript, "./my_app_ffi.mjs", "fetch")
pub fn fetch(url: String) -> Promise(String)

@external(javascript, "./my_app_ffi.mjs", "parseJson")
pub fn parse_json(text: String) -> Result(Dynamic, String)
```

## 构建配置

### 开发构建

```bash
# 构建开发版本
gleam build

# 运行
gleam run

# 测试
gleam test
```

### 生产构建

```bash
# 构建生产版本
gleam build --target javascript

# 输出到 build/dev/javascript/my_app/
```

## 文档

### 模块文档

```gleam
/// 用户管理模块
///
/// 提供用户创建、验证和管理功能。
///
/// ## 示例
///
/// ```gleam
/// let user = user.new("Alice", "alice@example.com")
/// ```
pub module user {
  ...
}
```

### 函数文档

```gleam
/// 创建新用户
///
/// ## 参数
///
/// - `name`: 用户名，不能为空
/// - `email`: 邮箱地址，必须有效
///
/// ## 返回
///
/// 返回新创建的用户实例
///
/// ## 示例
///
/// ```gleam
/// let user = user.new("Alice", "alice@example.com")
/// ```
pub fn new(name: String, email: String) -> User {
  User(
    id: generate_id(),
    name: name,
    email: email,
  )
}
```

## 最佳实践

1. **模块化** - 每个模块只做一件事
2. **类型安全** - 使用类型表达业务规则
3. **不可变** - 避免可变状态
4. **错误处理** - 使用 Result 和 Option
5. **测试覆盖** - 为所有公共函数编写测试
6. **文档** - 为公共 API 编写文档
7. **格式化** - 使用 `gleam format` 保持代码风格一致
