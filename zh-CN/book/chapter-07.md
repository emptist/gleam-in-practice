# 第七章：状态管理

## 为什么需要状态管理？

在应用程序中，状态管理是核心问题：

- **可预测性** - 状态变化应该可预测
- **可追溯** - 状态变化历史可追踪
- **可测试** - 状态管理逻辑易于测试

Gleam 的不可变数据结构天然适合状态管理。

## 状态类型

### 基本状态

```gleam
// src/traenupi_core/state.gleam
pub type State {
  State(
    tasks: Dict(String, Task),
    users: Dict(String, User),
    config: Config,
    last_updated: Int,
  )
}

pub type Task {
  Task(
    id: String,
    title: String,
    status: TaskStatus,
    priority: Int,
    created_at: Int,
    updated_at: Int,
  )
}

pub type TaskStatus {
  Todo
  InProgress
  Done
  Cancelled
}

pub type Config {
  Config(
    database_url: String,
    log_level: LogLevel,
    max_tasks: Int,
  )
}

pub type LogLevel {
  Debug
  Info
  Warning
  Error
}
```

### 初始状态

```gleam
pub fn initial_state() -> State {
  State(
    tasks: dict.new(),
    users: dict.new(),
    config: default_config(),
    last_updated: now(),
  )
}

fn default_config() -> Config {
  Config(
    database_url: "postgresql://localhost/traenupi",
    log_level: Info,
    max_tasks: 100,
  )
}
```

## 状态更新

### 动作类型

```gleam
pub type Action {
  // 任务操作
  AddTask(task: Task)
  UpdateTask(id: String, updates: TaskUpdates)
  RemoveTask(id: String)
  CompleteTask(id: String)
  
  // 用户操作
  AddUser(user: User)
  RemoveUser(id: String)
  
  // 配置操作
  UpdateConfig(updates: ConfigUpdates)
  
  // 批量操作
  Batch(actions: List(Action))
}

pub type TaskUpdates {
  TaskUpdates(
    title: Option(String),
    status: Option(TaskStatus),
    priority: Option(Int),
  )
}

pub type ConfigUpdates {
  ConfigUpdates(
    database_url: Option(String),
    log_level: Option(LogLevel),
    max_tasks: Option(Int),
  )
}
```

### 更新函数

```gleam
pub fn update(state: State, action: Action) -> State {
  case action {
    AddTask(task) -> {
      let tasks = dict.insert(state.tasks, task.id, task)
      State(..state, tasks: tasks, last_updated: now())
    }
    
    UpdateTask(id, updates) -> {
      case dict.get(state.tasks, id) {
        Some(task) -> {
          let updated_task = apply_task_updates(task, updates)
          let tasks = dict.insert(state.tasks, id, updated_task)
          State(..state, tasks: tasks, last_updated: now())
        }
        None -> state
      }
    }
    
    RemoveTask(id) -> {
      let tasks = dict.delete(state.tasks, id)
      State(..state, tasks: tasks, last_updated: now())
    }
    
    CompleteTask(id) -> {
      case dict.get(state.tasks, id) {
        Some(task) -> {
          let updated_task = Task(..task, status: Done, updated_at: now())
          let tasks = dict.insert(state.tasks, id, updated_task)
          State(..state, tasks: tasks, last_updated: now())
        }
        None -> state
      }
    }
    
    AddUser(user) -> {
      let users = dict.insert(state.users, user.id, user)
      State(..state, users: users, last_updated: now())
    }
    
    RemoveUser(id) -> {
      let users = dict.delete(state.users, id)
      State(..state, users: users, last_updated: now())
    }
    
    UpdateConfig(updates) -> {
      let config = apply_config_updates(state.config, updates)
      State(..state, config: config, last_updated: now())
    }
    
    Batch(actions) -> {
      list.fold(actions, state, fn(state, action) {
        update(state, action)
      })
    }
  }
}

fn apply_task_updates(task: Task, updates: TaskUpdates) -> Task {
  Task(
    id: task.id,
    title: option.unwrap(updates.title, task.title),
    status: option.unwrap(updates.status, task.status),
    priority: option.unwrap(updates.priority, task.priority),
    created_at: task.created_at,
    updated_at: now(),
  )
}

fn apply_config_updates(config: Config, updates: ConfigUpdates) -> Config {
  Config(
    database_url: option.unwrap(updates.database_url, config.database_url),
    log_level: option.unwrap(updates.log_level, config.log_level),
    max_tasks: option.unwrap(updates.max_tasks, config.max_tasks),
  )
}
```

## 选择器

### 基本选择器

```gleam
pub fn get_task(state: State, id: String) -> Option(Task) {
  dict.get(state.tasks, id)
}

pub fn get_all_tasks(state: State) -> List(Task) {
  dict.values(state.tasks)
}

pub fn get_tasks_by_status(state: State, status: TaskStatus) -> List(Task) {
  state.tasks
    |> dict.values()
    |> list.filter(fn(task) { task.status == status })
}

pub fn get_active_tasks(state: State) -> List(Task) {
  state.tasks
    |> dict.values()
    |> list.filter(fn(task) {
      task.status == Todo || task.status == InProgress
    })
}

pub fn get_high_priority_tasks(state: State) -> List(Task) {
  state.tasks
    |> dict.values()
    |> list.filter(fn(task) { task.priority >= 3 })
}
```

### 派生状态

```gleam
pub type TaskStats {
  TaskStats(
    total: Int,
    todo: Int,
    in_progress: Int,
    done: Int,
    cancelled: Int,
  )
}

pub fn get_task_stats(state: State) -> TaskStats {
  let tasks = dict.values(state.tasks)
  
  TaskStats(
    total: list.length(tasks),
    todo: count_by_status(tasks, Todo),
    in_progress: count_by_status(tasks, InProgress),
    done: count_by_status(tasks, Done),
    cancelled: count_by_status(tasks, Cancelled),
  )
}

fn count_by_status(tasks: List(Task), status: TaskStatus) -> Int {
  tasks
    |> list.filter(fn(task) { task.status == status })
    |> list.length()
}
```

## 状态持久化

### 序列化

```gleam
pub fn serialize(state: State) -> String {
  json.object([
    #("tasks", serialize_tasks(state.tasks)),
    #("users", serialize_users(state.users)),
    #("config", serialize_config(state.config)),
    #("last_updated", json.int(state.last_updated)),
  ])
  |> json.to_string
}

fn serialize_tasks(tasks: Dict(String, Task)) -> Json {
  tasks
    |> dict.to_list()
    |> list.map(fn(pair) {
      let #(id, task) = pair
      #(id, serialize_task(task))
    })
    |> json.object
}

fn serialize_task(task: Task) -> Json {
  json.object([
    #("id", json.string(task.id)),
    #("title", json.string(task.title)),
    #("status", serialize_status(task.status)),
    #("priority", json.int(task.priority)),
    #("created_at", json.int(task.created_at)),
    #("updated_at", json.int(task.updated_at)),
  ])
}

fn serialize_status(status: TaskStatus) -> Json {
  case status {
    Todo -> json.string("todo")
    InProgress -> json.string("in_progress")
    Done -> json.string("done")
    Cancelled -> json.string("cancelled")
  }
}
```

### 反序列化

```gleam
pub fn deserialize(data: String) -> Result(State, String) {
  case json.decode(data) {
    Ok(dynamic) -> parse_state(dynamic)
    Error(_) -> Error("Invalid JSON")
  }
}

fn parse_state(dynamic: Dynamic) -> Result(State, String) {
  use tasks <- result.try(field("tasks", parse_tasks))
  use users <- result.try(field("users", parse_users))
  use config <- result.try(field("config", parse_config))
  use last_updated <- result.try(field("last_updated", int))
  
  Ok(State(
    tasks: tasks,
    users: users,
    config: config,
    last_updated: last_updated,
  ))
}
```

## 时间旅行调试

### 历史记录

```gleam
pub type History {
  History(
    past: List(State),
    present: State,
    future: List(State),
  )
}

pub fn create_history(initial_state: State) -> History {
  History(
    past: [],
    present: initial_state,
    future: [],
  )
}

pub fn push(history: History, state: State) -> History {
  History(
    past: [history.present, ..history.past],
    present: state,
    future: [],
  )
}

pub fn undo(history: History) -> Option(History) {
  case history.past {
    [present, ..past] -> Some(History(
      past: past,
      present: present,
      future: [history.present, ..history.future],
    ))
    [] -> None
  }
}

pub fn redo(history: History) -> Option(History) {
  case history.future {
    [present, ..future] -> Some(History(
      past: [history.present, ..history.past],
      present: present,
      future: future,
    ))
    [] -> None
  }
}
```

## 小结

在本章中，我们学习了：

1. **状态类型** - 定义应用状态结构
2. **状态更新** - 使用动作更新状态
3. **选择器** - 查询和派生状态
4. **持久化** - 序列化和反序列化状态
5. **时间旅行** - 实现撤销/重做功能

下一章，我们将学习验证。
