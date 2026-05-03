# 第二章：类型与模式匹配

## 类型系统基础

Gleam 拥有强大而简洁的类型系统。让我们从基础开始。

### 基本类型

```gleam
// 基本类型
pub fn basics() {
  let int_val: Int = 42
  let float_val: Float = 3.14
  let bool_val: Bool = True
  let string_val: String = "Hello"
  
  // 列表
  let int_list: List(Int) = [1, 2, 3]
  let string_list: List(String) = ["a", "b", "c"]
  
  // 元组
  let pair: #(Int, String) = #(1, "one")
  let triple: #(Int, String, Float) = #(1, "one", 1.0)
}
```

### 与 TypeScript 的对比

| TypeScript | Gleam |
|------------|-------|
| `number` | `Int` 或 `Float` |
| `string` | `String` |
| `boolean` | `Bool` |
| `T[]` | `List(T)` |
| `[T, U]` | `#(T, U)` (元组) |
| `T \| null` | `Option(T)` |
| `T \| U` | `Result(T, U)` |

## 自定义类型

### 类型别名

```gleam
// 类型别名
pub type UserId = String
pub type Age = Int
pub type Email = String

pub fn validate_email(email: Email) -> Bool {
  string.contains(email, "@")
}
```

### 记录类型（类似 TypeScript 接口）

```gleam
// Gleam 自定义类型
pub type User {
  User(
    id: UserId,
    name: String,
    email: Option(String),
    age: Age,
  )
}

// 创建实例
pub fn create_user(id: String, name: String) -> User {
  User(
    id: id,
    name: name,
    email: None,
    age: 0,
  )
}

// 访问字段
pub fn get_name(user: User) -> String {
  user.name
}
```

TypeScript 对比：

```typescript
// TypeScript 接口
interface User {
  id: string;
  name: string;
  email?: string;  // 可选
  age: number;
}

function createUser(id: string, name: string): User {
  return {
    id,
    name,
    age: 0,
  };
}
```

### 枚举类型

```gleam
// Gleam 枚举
pub type Status {
  Pending
  InProgress
  Completed
  Failed
}

pub type Priority {
  Low
  Medium
  High
  Urgent
}

// 带数据的枚举
pub type TaskError {
  NotFound(task_id: String)
  InvalidStatus(from: Status, to: Status)
  PermissionDenied(user_id: String)
}
```

TypeScript 对比：

```typescript
// TypeScript 枚举
enum Status {
  Pending = "pending",
  InProgress = "in_progress",
  Completed = "completed",
  Failed = "failed",
}

// 带数据的联合类型
type TaskError =
  | { type: "not_found"; taskId: string }
  | { type: "invalid_status"; from: Status; to: Status }
  | { type: "permission_denied"; userId: string };
```

## 模式匹配

### 基本模式匹配

```gleam
pub fn describe_status(status: Status) -> String {
  case status {
    Pending -> "等待中"
    InProgress -> "进行中"
    Completed -> "已完成"
    Failed -> "失败"
  }
}

pub fn describe_priority(priority: Priority) -> String {
  case priority {
    Low -> "低优先级"
    Medium -> "中优先级"
    High -> "高优先级"
    Urgent -> "紧急"
  }
}
```

### 解构记录

```gleam
pub fn get_user_info(user: User) -> String {
  case user {
    User(id:, name:, email:, age:) if age >= 18 -> {
      case email {
        Some(e) -> name <> " (" <> e <> ") - 成年用户"
        None -> name <> " - 成年用户"
      }
    }
    User(name:, age:) -> name <> " - 未成年用户"
  }
}

// 部分解构
pub fn get_email_domain(user: User) -> Option(String) {
  case user.email {
    Some(email) -> {
      case string.split(email, "@") {
        [_, domain] -> Some(domain)
        _ -> None
      }
    }
    None -> None
  }
}
```

### 解构元组

```gleam
pub fn describe_pair(pair: #(Int, String)) -> String {
  case pair {
    #(0, name) -> "零号: " <> name
    #(n, name) -> int.to_string(n) <> "号: " <> name
  }
}

pub fn swap_pair(pair: #(a, b)) -> #(b, a) {
  case pair {
    #(a, b) -> #(b, a)
  }
}
```

### 解构列表

```gleam
pub fn describe_list(items: List(Int)) -> String {
  case items {
    [] -> "空列表"
    [x] -> "单元素: " <> int.to_string(x)
    [x, y] -> "两个元素: " <> int.to_string(x) <> ", " <> int.to_string(y)
    [first, ..rest] -> "首元素: " <> int.to_string(first)
  }
}

pub fn head(items: List(a)) -> Option(a) {
  case items {
    [first, ..] -> Some(first)
    [] -> None
  }
}

pub fn tail(items: List(a)) -> Option(List(a)) {
  case items {
    [_, ..rest] -> Some(rest)
    [] -> None
  }
}
```

### 嵌套模式匹配

```gleam
pub type Address {
  Address(street: String, city: String, country: String)
}

pub type Person {
  Person(name: String, address: Option(Address))
}

pub fn get_city(person: Person) -> String {
  case person {
    Person(address: Some(Address(city: city))) -> city
    _ -> "未知城市"
  }
}
```

### 守卫条件

```gleam
pub fn categorize_age(age: Int) -> String {
  case age {
    n if n < 0 -> "无效年龄"
    n if n < 13 -> "儿童"
    n if n < 20 -> "青少年"
    n if n < 60 -> "成年人"
    _ -> "老年人"
  }
}

pub fn compare_numbers(a: Int, b: Int) -> String {
  case #(a, b) {
    #(x, y) if x > y -> "大于"
    #(x, y) if x < y -> "小于"
    _ -> "等于"
  }
}
```

## Option 和 Result

### Option 类型

```gleam
import gleam/option.{type Option, Some, None}

// Option 类型定义
// pub type Option(a) {
//   Some(a)
//   None
// }

pub fn safe_divide(a: Float, b: Float) -> Option(Float) {
  case b {
    0.0 -> None
    _ -> Some(a /. b)
  }
}

pub fn find_user(users: List(User), id: String) -> Option(User) {
  list.find(users, fn(user) { user.id == id })
}

// 链式 Option 操作
pub fn get_user_email(users: List(User), id: String) -> Option(String) {
  case find_user(users, id) {
    Some(user) -> user.email
    None -> None
  }
}
```

### Result 类型

```gleam
import gleam/result.{type Result, Ok, Error}

// Result 类型定义
// pub type Result(a, e) {
//   Ok(a)
//   Error(e)
// }

pub type DivisionError {
  DivisionByZero
}

pub fn divide(a: Float, b: Float) -> Result(Float, DivisionError) {
  case b {
    0.0 -> Error(DivisionByZero)
    _ -> Ok(a /. b)
  }
}

pub type ParseError {
  InvalidNumber
  InvalidFormat
}

pub fn parse_int(s: String) -> Result(Int, ParseError) {
  case int.parse(s) {
    Ok(n) -> Ok(n)
    Error(_) -> Error(InvalidNumber)
  }
}
```

### Result 组合子

```gleam
import gleam/result

pub fn safe_calculation() -> Result(Int, String) {
  let a = parse_int("10")
  let b = parse_int("20")
  
  // 使用 try 链式处理
  use n1 <- result.try(a)
  use n2 <- result.try(b)
  
  Ok(n1 + n2)
}

// map 转换成功值
pub fn double_result(r: Result(Int, e)) -> Result(Int, e) {
  result.map(r, fn(n) { n * 2 })
}

// map_error 转换错误
pub fn error_to_string(r: Result(a, e), to_string: fn(e) -> String) -> Result(a, String) {
  result.map_error(r, to_string)
}
```

## 泛型

### 泛型函数

```gleam
// 泛型函数
pub fn identity(x: a) -> a {
  x
}

pub fn first(pair: #(a, b)) -> a {
  case pair {
    #(a, _) -> a
  }
}

pub fn second(pair: #(a, b)) -> b {
  case pair {
    #(_, b) -> b
  }
}

pub fn swap(pair: #(a, b)) -> #(b, a) {
  case pair {
    #(a, b) -> #(b, a)
  }
}
```

### 泛型类型

```gleam
// 泛型类型
pub type Box(a) {
  Box(value: a)
}

pub fn box(value: a) -> Box(a) {
  Box(value)
}

pub fn unbox(boxed: Box(a)) -> a {
  boxed.value
}

// 多参数泛型
pub type Pair(a, b) {
  Pair(first: a, second: b)
}

pub fn make_pair(a: a, b: b) -> Pair(a, b) {
  Pair(first: a, second: b)
}
```

## 实战案例

### 任务状态机

```gleam
pub type TaskStatus {
  Todo
  InProgress(assignee: String)
  InReview(reviewer: String)
  Done
  Cancelled(reason: String)
}

pub fn can_transition(from: TaskStatus, to: TaskStatus) -> Bool {
  case #(from, to) {
    #(Todo, InProgress(_)) -> True
    #(InProgress(_), InReview(_)) -> True
    #(InReview(_), Done) -> True
    #(InReview(_), InProgress(_)) -> True
    #(_, Cancelled(_)) -> True
    _ -> False
  }
}

pub fn transition(task_status: TaskStatus, to: TaskStatus) -> Result(TaskStatus, String) {
  case can_transition(task_status, to) {
    True -> Ok(to)
    False -> Error("无效的状态转换")
  }
}
```

### 用户验证

```gleam
pub type ValidationError {
  InvalidEmail
  InvalidAge
  InvalidName
}

pub type ValidUser {
  ValidUser(email: String, name: String, age: Int)
}

pub fn validate_user(email: String, name: String, age: Int) -> Result(ValidUser, ValidationError) {
  use _ <- result.try(validate_email(email))
  use _ <- result.try(validate_name(name))
  use _ <- result.try(validate_age(age))
  
  Ok(ValidUser(email: email, name: name, age: age))
}

fn validate_email(email: String) -> Result(Nil, ValidationError) {
  case string.contains(email, "@") {
    True -> Ok(Nil)
    False -> Error(InvalidEmail)
  }
}

fn validate_name(name: String) -> Result(Nil, ValidationError) {
  case string.length(name) > 0 {
    True -> Ok(Nil)
    False -> Error(InvalidName)
  }
}

fn validate_age(age: Int) -> Result(Nil, ValidationError) {
  case age >= 0 && age <= 150 {
    True -> Ok(Nil)
    False -> Error(InvalidAge)
  }
}
```

## 小结

在本章中，我们学习了：

1. **基本类型** - Int, Float, Bool, String, List, Tuple
2. **自定义类型** - 类型别名、记录类型、枚举
3. **模式匹配** - 解构、守卫条件、嵌套匹配
4. **Option 和 Result** - 处理可空值和错误
5. **泛型** - 泛型函数和泛型类型

下一章，我们将学习如何处理 JSON 数据。
