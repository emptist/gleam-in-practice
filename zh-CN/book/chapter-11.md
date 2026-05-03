# 第十一章：测试策略

## 测试的重要性

测试是保证代码质量的关键：

- **回归测试** - 确保修改不会破坏现有功能
- **文档作用** - 测试展示了代码如何使用
- **设计辅助** - 编写测试帮助改进设计

## 单元测试

### 基本测试

```gleam
// test/traenupi_core_test.gleam
import gleeunit
import gleeunit/should
import traenupi_core/task

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn new_task_test() {
  let task = task.new("测试任务", 1)
  
  task.title |> should.equal("测试任务")
  task.priority |> should.equal(1)
  task.status |> should.equal(Todo)
}

pub fn start_task_test() {
  let task = task.new("测试任务", 1)
  
  case task.start(task) {
    Ok(started) -> {
      started.status |> should.equal(InProgress)
    }
    Error(_) -> {
      should.fail("任务启动失败")
    }
  }
}

pub fn start_completed_task_test() {
  let task = task.new("测试任务", 1)
  let task = Task(..task, status: Done)
  
  case task.start(task) {
    Ok(_) -> should.fail("不应该能启动已完成的任务")
    Error(InvalidTransition) -> should.equal(InvalidTransition, InvalidTransition)
  }
}
```

### 断言函数

```gleam
pub fn should_equal_test() {
  1 + 1 |> should.equal(2)
}

pub fn should_be_ok_test() {
  Ok(42) |> should.be_ok()
}

pub fn should_be_error_test() {
  Error("失败") |> should.be_error()
}

pub fn should_be_some_test() {
  Some(42) |> should.be_some()
}

pub fn should_be_none_test() {
  None |> should.be_none()
}

pub fn should_be_true_test() {
  True |> should.be_true()
}

pub fn should_be_false_test() {
  False |> should.be_false()
}

pub fn list_should_contain_test() {
  [1, 2, 3] |> should.contain(2)
}

pub fn string_should_contain_test() {
  "Hello, World!" |> should.contain("World")
}
```

## 属性测试

### 基本概念

属性测试自动生成测试用例：

```gleam
import gleam/list

pub fn list_reverse_reverse_test() {
  // 对于任意列表，反转两次等于原列表
  fn(list: List(Int)) {
    list
    |> list.reverse()
    |> list.reverse()
    |> should.equal(list)
  }
  |> property.check()
}

pub fn list_length_append_test() {
  // 对于任意两个列表，连接后的长度等于长度之和
  fn(list1: List(Int), list2: List(Int)) {
    let combined = list.append(list1, list2)
    let len1 = list.length(list1)
    let len2 = list.length(list2)
    let len_combined = list.length(combined)
    
    len_combined |> should.equal(len1 + len2)
  }
  |> property.check2()
}
```

### 自定义生成器

```gleam
pub type User {
  User(id: Int, name: String, age: Int)
}

pub fn user_generator() -> Generator(User) {
  use id <- property.int(1, 10000)
  use name <- property.string(1, 20)
  use age <- property.int(0, 120)
  
  property.return(User(id: id, name: name, age: age))
}

pub fn user_validation_test() {
  fn(user: User) {
    case validate_user(user) {
      Ok(valid_user) -> {
        valid_user.id |> should.equal(user.id)
        valid_user.name |> should.equal(user.name)
      }
      Error(_) -> {
        // 无效用户
        should.be_true(user.age < 0 || user.age > 150)
      }
    }
  }
  |> property.check_with(user_generator())
}
```

## 测试组织

### 测试模块

```gleam
// test/task_test.gleam
pub fn task_creation_test() {
  // 创建测试
}

pub fn task_status_transition_test() {
  // 状态转换测试
}

pub fn task_priority_test() {
  // 优先级测试
}

// test/user_test.gleam
pub fn user_creation_test() {
  // 创建测试
}

pub fn user_validation_test() {
  // 验证测试
}
```

### 测试夹具

```gleam
pub fn with_test_task(test: fn(Task) -> a) -> a {
  let task = task.new("测试任务", 1)
  test(task)
}

pub fn with_test_user(test: fn(User) -> a) -> a {
  let user = User(id: 1, name: "测试用户", email: "test@example.com")
  test(user)
}

pub fn with_test_state(test: fn(State) -> a) -> a {
  let state = initial_state()
  test(state)
}

// 使用夹具
pub fn complete_task_test() {
  with_test_task(fn(task) {
    case task.complete(task) {
      Ok(completed) -> {
        completed.status |> should.equal(Done)
      }
      Error(_) -> should.fail("任务完成失败")
    }
  })
}
```

## 模拟和存根

### 函数模拟

```gleam
pub type Fetcher {
  Fetcher(fetch: fn(String) -> Promise(Result(String, String)))
}

pub fn mock_fetcher(responses: Dict(String, String)) -> Fetcher {
  Fetcher(fn(url) {
    case dict.get(responses, url) {
      Some(response) -> resolve(Ok(response))
      None -> resolve(Error("未找到"))
    }
  })
}

pub fn test_with_mock() {
  let fetcher = mock_fetcher(dict.from_list([
    #("https://api.example.com/user/1", "{\"id\": 1, \"name\": \"Alice\"}"),
  ]))
  
  use result <- promise.try_await(fetcher.fetch("https://api.example.com/user/1"))
  
  case result {
    Ok(data) -> data |> should.contain("Alice")
    Error(_) -> should.fail("请求失败")
  }
}
```

### 时间模拟

```gleam
pub type Clock {
  Clock(now: fn() -> Int)
}

pub fn real_clock() -> Clock {
  Clock(fn() { system_now() })
}

pub fn mock_clock(time: Int) -> Clock {
  Clock(fn() { time })
}

pub fn test_with_mock_time() {
  let clock = mock_clock(1000000)
  
  let task = task.new_with_clock("测试任务", 1, clock)
  
  task.created_at |> should.equal(1000000)
}
```

## 集成测试

### 数据库测试

```gleam
pub fn with_test_db(test: fn(DbConnection) -> Promise(a)) -> Promise(a) {
  use conn <- promise.try_await(setup_test_db())
  
  use result <- promise.try_await(test(conn))
  
  use _ <- promise.try_await(teardown_test_db(conn))
  
  resolve(result)
}

pub fn save_and_retrieve_user_test() -> Promise(Nil) {
  with_test_db(fn(conn) {
    let user = User(id: 1, name: "测试用户")
    
    use _ <- promise.try_await(user_repo.save(conn, user))
    use found <- promise.try_await(user_repo.find_by_id(conn, 1))
    
    case found {
      Some(u) -> {
        u.name |> should.equal("测试用户")
        resolve(Ok(Nil))
      }
      None -> {
        should.fail("用户未找到")
        resolve(Ok(Nil))
      }
    }
  })
}
```

### API 测试

```gleam
pub fn api_create_user_test() -> Promise(Nil) {
  use response <- promise.try_await(
    http.post(
      "http://localhost:3000/api/users",
      json.object([
        #("name", json.string("测试用户")),
        #("email", json.string("test@example.com")),
      ]),
    )
  )
  
  response.status |> should.equal(201)
  
  case json.decode(response.body) {
    Ok(data) -> {
      data.name |> should.equal("测试用户")
      resolve(Ok(Nil))
    }
    Error(_) -> {
      should.fail("无效的 JSON 响应")
      resolve(Ok(Nil))
    }
  }
}
```

## 测试覆盖率

### 运行测试

```bash
# 运行所有测试
gleam test

# 运行特定测试
gleam test --filter "task"

# 详细输出
gleam test --verbose
```

### 覆盖率目标

| 类型 | 目标 |
|------|------|
| 行覆盖率 | 80%+ |
| 分支覆盖率 | 70%+ |
| 函数覆盖率 | 90%+ |

## 小结

在本章中，我们学习了：

1. **单元测试** - 基本测试和断言
2. **属性测试** - 自动生成测试用例
3. **测试组织** - 模块和夹具
4. **模拟和存根** - 隔离外部依赖
5. **集成测试** - 数据库和 API 测试

下一章，我们将通过案例研究深入实践。
