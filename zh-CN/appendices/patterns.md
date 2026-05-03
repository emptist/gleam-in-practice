# 附录 B：常见模式

## 1. 构建器模式

逐步构建复杂对象：

```gleam
pub type QueryBuilder {
  QueryBuilder(
    table: String,
    columns: List(String),
    where_clause: Option(String),
    order_by: Option(String),
    limit: Option(Int),
  )
}

pub fn new(table: String) -> QueryBuilder {
  QueryBuilder(
    table: table,
    columns: [],
    where_clause: None,
    order_by: None,
    limit: None,
  )
}

pub fn select(builder: QueryBuilder, columns: List(String)) -> QueryBuilder {
  QueryBuilder(..builder, columns: columns)
}

pub fn where_(builder: QueryBuilder, clause: String) -> QueryBuilder {
  QueryBuilder(..builder, where_clause: Some(clause))
}

pub fn order_by(builder: QueryBuilder, column: String) -> QueryBuilder {
  QueryBuilder(..builder, order_by: Some(column))
}

pub fn limit(builder: QueryBuilder, n: Int) -> QueryBuilder {
  QueryBuilder(..builder, limit: Some(n))
}

pub fn build(builder: QueryBuilder) -> String {
  let columns = case builder.columns {
    [] -> "*"
    cols -> cols |> list.map(fn(c) { c }) |> string.join(", ")
  }
  
  let where_str = case builder.where_clause {
    Some(clause) -> " WHERE " <> clause
    None -> ""
  }
  
  let order_str = case builder.order_by {
    Some(col) -> " ORDER BY " <> col
    None -> ""
  }
  
  let limit_str = case builder.limit {
    Some(n) -> " LIMIT " <> int.to_string(n)
    None -> ""
  }
  
  "SELECT " <> columns <> " FROM " <> builder.table <> where_str <> order_str <> limit_str
}

// 使用
let query = 
  new("users")
  |> select(["id", "name", "email"])
  |> where_("active = true")
  |> order_by("created_at")
  |> limit(10)
  |> build()
```

## 2. 状态机

使用类型确保有效转换：

```gleam
pub type OrderStatus {
  Created
  Paid
  Shipped
  Delivered
  Cancelled
}

pub type OrderEvent {
  Pay
  Ship
  Deliver
  Cancel
}

pub fn transition(status: OrderStatus, event: OrderEvent) -> Result(OrderStatus, String) {
  case #(status, event) {
    #(Created, Pay) -> Ok(Paid)
    #(Paid, Ship) -> Ok(Shipped)
    #(Shipped, Deliver) -> Ok(Delivered)
    #(Created, Cancel) -> Ok(Cancelled)
    #(Paid, Cancel) -> Ok(Cancelled)
    _ -> Error("无效的状态转换")
  }
}
```

## 3. 仓库模式

封装数据访问：

```gleam
pub type UserRepository {
  UserRepository(db: DbConnection)
}

pub fn new_user_repository(db: DbConnection) -> UserRepository {
  UserRepository(db: db)
}

pub fn find_by_id(repo: UserRepository, id: String) -> Promise(Result(Option(User), DbError)) {
  use result <- promise.try_await(query_one(repo.db, "SELECT * FROM users WHERE id = $1", [StringParam(id)]))
  
  case result {
    Some(row) -> {
      case user_from_row(row) {
        Ok(user) -> promise.resolve(Ok(Some(user)))
        Error(e) -> promise.resolve(Error(QueryFailed(e)))
      }
    }
    None -> promise.resolve(Ok(None))
  }
}

pub fn save(repo: UserRepository, user: User) -> Promise(Result(User, DbError)) {
  use _ <- promise.try_await(execute(repo.db, "INSERT INTO users (id, name, email) VALUES ($1, $2, $3)", [
    StringParam(user.id),
    StringParam(user.name),
    StringParam(user.email),
  ]))
  
  promise.resolve(Ok(user))
}
```

## 4. 观察者模式

事件订阅系统：

```gleam
pub type Event {
  UserCreated(user: User)
  UserUpdated(user: User)
  UserDeleted(id: String)
}

pub type EventHandler = fn(Event) -> Nil

pub type EventBus {
  EventBus(handlers: Dict(String, List(EventHandler)))
}

pub fn new_bus() -> EventBus {
  EventBus(handlers: dict.new())
}

pub fn subscribe(bus: EventBus, event_type: String, handler: EventHandler) -> EventBus {
  let handlers = case dict.get(bus.handlers, event_type) {
    Some(existing) -> [handler, ..existing]
    None -> [handler]
  }
  
  EventBus(handlers: dict.insert(bus.handlers, event_type, handlers))
}

pub fn publish(bus: EventBus, event: Event) -> Nil {
  let event_type = event_type_name(event)
  
  case dict.get(bus.handlers, event_type) {
    Some(handlers) -> list.each(handlers, fn(h) { h(event) })
    None -> Nil
  }
}

fn event_type_name(event: Event) -> String {
  case event {
    UserCreated(_) -> "UserCreated"
    UserUpdated(_) -> "UserUpdated"
    UserDeleted(_) -> "UserDeleted"
  }
}
```

## 5. 工厂模式

创建对象：

```gleam
pub type Document {
  PdfDocument(content: String)
  WordDocument(content: String)
  TextDocument(content: String)
}

pub type DocumentType {
  Pdf
  Word
  Text
}

pub fn create_document(type_: DocumentType, content: String) -> Document {
  case type_ {
    Pdf -> PdfDocument(content: content)
    Word -> WordDocument(content: content)
    Text -> TextDocument(content: content)
  }
}

pub fn get_content(doc: Document) -> String {
  case doc {
    PdfDocument(content:) -> content
    WordDocument(content:) -> content
    TextDocument(content:) -> content
  }
}
```

## 6. 策略模式

可互换的算法：

```gleam
pub type PaymentStrategy {
  CreditCard(card_number: String, cvv: String)
  PayPal(email: String)
  BankTransfer(account: String)
}

pub fn process_payment(strategy: PaymentStrategy, amount: Float) -> Result(Nil, String) {
  case strategy {
    CreditCard(card_number:, cvv:) -> {
      // 处理信用卡支付
      Ok(Nil)
    }
    PayPal(email:) -> {
      // 处理 PayPal 支付
      Ok(Nil)
    }
    BankTransfer(account:) -> {
      // 处理银行转账
      Ok(Nil)
    }
  }
}
```

## 7. 装饰器模式

添加功能：

```gleam
pub type Logger {
  Logger(log: fn(String) -> Nil)
}

pub fn base_logger() -> Logger {
  Logger(log: fn(message) { io.println(message) })
}

pub fn with_timestamp(logger: Logger) -> Logger {
  Logger(log: fn(message) {
    let timestamp = get_timestamp()
    logger.log("[" <> timestamp <> "] " <> message)
  })
}

pub fn with_level(logger: Logger, level: String) -> Logger {
  Logger(log: fn(message) {
    logger.log("[" <> level <> "] " <> message)
  })
}

// 使用
let logger = base_logger()
  |> with_timestamp()
  |> with_level("INFO")

logger.log("应用程序启动")
```

## 8. 单例模式

全局状态：

```gleam
pub type AppState {
  AppState(
    config: Config,
    cache: Cache(Data),
  )
}

let app_state: Ref(AppState) = ref.new(initial_state())

pub fn get_state() -> AppState {
  ref.get(app_state)
}

pub fn update_state(f: fn(AppState) -> AppState) -> Nil {
  let current = ref.get(app_state)
  ref.set(app_state, f(current))
}
```

## 9. 命令模式

封装操作：

```gleam
pub type Command {
  CreateUser(name: String, email: String)
  UpdateUser(id: String, updates: UserUpdates)
  DeleteUser(id: String)
}

pub fn execute(command: Command, state: State) -> Result(State, String) {
  case command {
    CreateUser(name:, email:) -> {
      let user = User(id: generate_id(), name: name, email: email)
      Ok(State(..state, users: dict.insert(state.users, user.id, user)))
    }
    
    UpdateUser(id:, updates:) -> {
      case dict.get(state.users, id) {
        Some(user) -> {
          let updated = apply_updates(user, updates)
          Ok(State(..state, users: dict.insert(state.users, id, updated)))
        }
        None -> Error("用户未找到")
      }
    }
    
    DeleteUser(id:) -> {
      Ok(State(..state, users: dict.delete(state.users, id)))
    }
  }
}
```

## 10. 组合模式

树形结构：

```gleam
pub type FileSystemItem {
  File(name: String, size: Int)
  Directory(name: String, items: List(FileSystemItem))
}

pub fn get_size(item: FileSystemItem) -> Int {
  case item {
    File(size:) -> size
    Directory(items:) -> {
      items
      |> list.map(get_size)
      |> list.fold(0, fn(acc, size) { acc + size })
    }
  }
}

pub fn find_by_name(item: FileSystemItem, name: String) -> Option(FileSystemItem) {
  case item {
    File(name: n) if n == name -> Some(item)
    Directory(items:) -> {
      items
      |> list.find(fn(i) { 
        case find_by_name(i, name) {
          Some(_) -> True
          None -> False
        }
      })
    }
    _ -> None
  }
}
```
