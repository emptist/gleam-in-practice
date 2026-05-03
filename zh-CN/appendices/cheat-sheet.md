# 附录 A：速查表

## 类型

| TypeScript | Gleam |
|------------|-------|
| `string` | `String` |
| `number` | `Int` 或 `Float` |
| `boolean` | `Bool` |
| `T[]` | `List(T)` |
| `T \| null` | `Option(T)` |
| `T \| U` | `Result(T, U)` |
| `{ key: T }` | `Dict(String, T)` |
| `interface` | `type` |

## 声明

```gleam
// 类型别名
pub type UserId = String

// 自定义类型（类似接口）
pub type User {
  User(id: String, name: String, email: Option(String))
}

// 枚举（联合类型）
pub type Status {
  Pending
  Running
  Completed
  Failed
}
```

## 函数

```gleam
// 基本函数
pub fn add(a: Int, b: Int) -> Int {
  a + b
}

// 管道操作符
pub fn process(input: String) -> String {
  input
  |> string.trim()
  |> string.lowercase()
  |> string.replace(" ", "_")
}

// 匿名函数
let double = fn(x) { x * 2 }
[1, 2, 3] |> list.map(double)
```

## 模式匹配

```gleam
// 基本匹配
case status {
  Pending -> "等待中"
  Running -> "运行中"
  Completed -> "已完成"
  Failed -> "失败"
}

// 解构
case user {
  User(id:, name:, ..) -> name <> " (" <> id <> ")"
}

// 守卫条件
case age {
  n if n < 18 -> "未成年"
  n if n < 60 -> "成年"
  _ -> "老年"
}

// 列表匹配
case items {
  [] -> "空列表"
  [x] -> "单元素"
  [first, ..rest] -> "首元素: " <> first
}
```

## Option 类型

```gleam
import gleam/option.{Some, None}

// 创建
let some_value = Some(42)
let no_value = None

// 匹配
case maybe_value {
  Some(v) -> v
  None -> 0
}

// 默认值
let value = option.unwrap(maybe_value, 0)

// 映射
let doubled = option.map(maybe_value, fn(x) { x * 2 })
```

## Result 类型

```gleam
import gleam/result.{Ok, Error}

// 创建
let success = Ok(42)
let failure = Error("失败")

// 匹配
case result {
  Ok(v) -> v
  Error(e) -> 0
}

// try 链式处理
use a <- result.try(parse_int("10"))
use b <- result.try(parse_int("20"))
Ok(a + b)

// 映射
let doubled = result.map(success, fn(x) { x * 2 })
```

## 列表操作

```gleam
import gleam/list

// 创建
let items = [1, 2, 3]

// 映射
let doubled = list.map(items, fn(x) { x * 2 })

// 过滤
let evens = list.filter(items, fn(x) { x % 2 == 0 })

// 折叠
let sum = list.fold(items, 0, fn(acc, x) { acc + x })

// 查找
let first = list.first(items)  // Some(1)

// 追加
let combined = list.append([1, 2], [3, 4])
```

## 字符串操作

```gleam
import gleam/string

// 拼接
let greeting = "Hello, " <> name

// 方法
string.length("hello")           // 5
string.lowercase("HELLO")        // "hello"
string.uppercase("hello")        // "HELLO"
string.trim("  hello  ")         // "hello"
string.split("a,b,c", ",")       // ["a", "b", "c"]
string.replace("hello", "l", "L") // "heLLo"
string.contains("hello", "ell")  // True
string.starts_with("hello", "he") // True
```

## 字典操作

```gleam
import gleam/dict

// 创建
let empty = dict.new()
let filled = dict.from_list([#("a", 1), #("b", 2)])

// 操作
let updated = dict.insert(filled, "c", 3)
let removed = dict.delete(filled, "a")
let value = dict.get(filled, "a")  // Some(1)
let has_key = dict.has_key(filled, "a")  // True
```

## FFI

```gleam
// 声明外部函数
@external(javascript, "./ffi.mjs", "myFunction")
pub fn my_function(x: Int) -> Int

// JavaScript 实现
// ffi.mjs
// export function myFunction(x) { return x * 2; }
```

## 测试

```gleam
import gleeunit
import gleeunit/should

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn addition_test() {
  1 + 1 |> should.equal(2)
}

pub fn option_test() {
  Some(42) |> should.be_some()
  None |> should.be_none()
}

pub fn result_test() {
  Ok(42) |> should.be_ok()
  Error("失败") |> should.be_error()
}
```

## 命令行

```bash
# 创建项目
gleam new my_app

# 构建
gleam build

# 运行
gleam run

# 测试
gleam test

# 添加依赖
gleam add package_name

# 格式化
gleam format
```
