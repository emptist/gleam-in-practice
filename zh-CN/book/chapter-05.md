# 第五章：数据库操作

## 为什么需要类型安全的数据库操作？

数据库操作是应用程序的核心，但传统的 SQL 查询容易出现：

- SQL 注入攻击
- 类型不匹配
- 运行时错误

Gleam 的类型系统可以在编译时捕获这些问题。

## 数据库连接

### 连接池

```gleam
// src/traenupi_core/db.gleam
import gleam/javascript/promise.{type Promise}

pub type DbConnection

pub type DbError {
  ConnectionFailed(message: String)
  QueryFailed(message: String)
  ConnectionTimeout
  PoolExhausted
}

pub type ConnectionConfig {
  ConnectionConfig(
    host: String,
    port: Int,
    database: String,
    user: String,
    password: String,
    pool_size: Int,
    timeout_ms: Int,
  )
}

@external(javascript, "./db_ffi.mjs", "createPool")
pub fn create_pool(config: ConnectionConfig) -> Promise(Result(DbConnection, DbError))

@external(javascript, "./db_ffi.mjs", "closePool")
pub fn close_pool(pool: DbConnection) -> Promise(Nil)
```

### JavaScript FFI 实现

```javascript
// src/traenupi_core/db_ffi.mjs
import pg from "pg";

const pools = new Map();

export async function createPool(config) {
  try {
    const pool = new pg.Pool({
      host: config.host,
      port: config.port,
      database: config.database,
      user: config.user,
      password: config.password,
      max: config.pool_size,
      connectionTimeoutMillis: config.timeout_ms,
    });
    
    // 测试连接
    await pool.query("SELECT 1");
    
    const id = crypto.randomUUID();
    pools.set(id, pool);
    
    return { type: "Ok", value: { type: "DbConnection", id } };
  } catch (error) {
    return { type: "Error", value: { type: "ConnectionFailed", message: error.message } };
  }
}

export async function closePool(conn) {
  const pool = pools.get(conn.id);
  if (pool) {
    await pool.end();
    pools.delete(conn.id);
  }
  return null;
}
```

## 查询构建器

### 类型安全查询

```gleam
pub type QueryParam {
  IntParam(Int)
  StringParam(String)
  FloatParam(Float)
  BoolParam(Bool)
  NullParam
}

pub type Query {
  Query(sql: String, params: List(QueryParam))
}

pub fn query(sql: String) -> Query {
  Query(sql: sql, params: [])
}

pub fn with_param(query: Query, param: QueryParam) -> Query {
  Query(..query, params: list.append(query.params, [param]))
}

// 使用示例
pub fn find_user_by_id(user_id: Int) -> Query {
  query("SELECT * FROM users WHERE id = $1")
  |> with_param(IntParam(user_id))
}

pub fn find_users_by_status(status: String) -> Query {
  query("SELECT * FROM users WHERE status = $1")
  |> with_param(StringParam(status))
}
```

### 执行查询

```gleam
import gleam/dict.{type Dict}

@external(javascript, "./db_ffi.mjs", "executeQuery")
pub fn execute(
  pool: DbConnection,
  query: Query,
) -> Promise(Result(List(Dict(String, JsonValue)), DbError))

@external(javascript, "./db_ffi.mjs", "executeOne")
pub fn execute_one(
  pool: DbConnection,
  query: Query,
) -> Promise(Result(Option(Dict(String, JsonValue)), DbError))
```

```javascript
// db_ffi.mjs
export async function executeQuery(pool, query) {
  const p = pools.get(pool.id);
  if (!p) {
    return { type: "Error", value: { type: "ConnectionFailed", message: "Pool not found" } };
  }
  
  try {
    const params = query.params.map(p => {
      switch (p.type) {
        case "IntParam": return p[0];
        case "StringParam": return p[0];
        case "FloatParam": return p[0];
        case "BoolParam": return p[0];
        case "NullParam": return null;
      }
    });
    
    const result = await p.query(query.sql, params);
    
    // 转换为 Dict 格式
    const rows = result.rows.map(row => {
      const dict = {};
      for (const [key, value] of Object.entries(row)) {
        dict[key] = jsonToGleam(value);
      }
      return dict;
    });
    
    return { type: "Ok", value: rows };
  } catch (error) {
    return { type: "Error", value: { type: "QueryFailed", message: error.message } };
  }
}

function jsonToGleam(value) {
  if (value === null) return { type: "JsonNull" };
  if (typeof value === "boolean") return { type: "JsonBool", 0: value };
  if (typeof value === "number") return { type: "JsonNumber", 0: value };
  if (typeof value === "string") return { type: "JsonString", 0: value };
  if (Array.isArray(value)) return { type: "JsonArray", 0: value.map(jsonToGleam) };
  return { type: "JsonObject", 0: Object.fromEntries(Object.entries(value).map(([k, v]) => [k, jsonToGleam(v)])) };
}
```

## 事务处理

### 事务类型

```gleam
pub type Transaction

pub type TransactionError {
  BeginFailed(message: String)
  CommitFailed(message: String)
  RollbackFailed(message: String)
}

@external(javascript, "./db_ffi.mjs", "beginTransaction")
pub fn begin_transaction(pool: DbConnection) -> Promise(Result(Transaction, TransactionError))

@external(javascript, "./db_ffi.mjs", "commit")
pub fn commit(tx: Transaction) -> Promise(Result(Nil, TransactionError))

@external(javascript, "./db_ffi.mjs", "rollback")
pub fn rollback(tx: Transaction) -> Promise(Result(Nil, TransactionError))
```

### 事务操作

```gleam
pub fn in_transaction(
  pool: DbConnection,
  operations: fn(Transaction) -> Promise(Result(a, DbError)),
) -> Promise(Result(a, DbError)) {
  use tx <- promise.try_await(begin_transaction(pool))
  
  case operations(tx) {
    Ok(value) -> {
      use _ <- promise.try_await(commit(tx))
      promise.resolve(Ok(value))
    }
    Error(error) -> {
      use _ <- promise.try_await(rollback(tx))
      promise.resolve(Error(error))
    }
  }
}
```

### 使用示例

```gleam
pub fn transfer_funds(
  pool: DbConnection,
  from_id: Int,
  to_id: Int,
  amount: Float,
) -> Promise(Result(Nil, DbError)) {
  in_transaction(pool, fn(tx) {
    // 扣除源账户
    use _ <- promise.try_await(execute(tx, 
      query("UPDATE accounts SET balance = balance - $1 WHERE id = $2")
      |> with_param(FloatParam(amount))
      |> with_param(IntParam(from_id))
    ))
    
    // 增加目标账户
    use _ <- promise.try_await(execute(tx,
      query("UPDATE accounts SET balance = balance + $1 WHERE id = $2")
      |> with_param(FloatParam(amount))
      |> with_param(IntParam(to_id))
    ))
    
    promise.resolve(Ok(Nil))
  })
}
```

## 数据模型

### 用户模型

```gleam
pub type User {
  User(
    id: Int,
    name: String,
    email: String,
    created_at: Int,
    updated_at: Int,
  )
}

pub fn user_from_row(row: Dict(String, JsonValue)) -> Result(User, String) {
  use id <- result.try(get_int(row, "id"))
  use name <- result.try(get_string(row, "name"))
  use email <- result.try(get_string(row, "email"))
  use created_at <- result.try(get_int(row, "created_at"))
  use updated_at <- result.try(get_int(row, "updated_at"))
  
  Ok(User(
    id: id,
    name: name,
    email: email,
    created_at: created_at,
    updated_at: updated_at,
  ))
}

fn get_int(dict: Dict(String, JsonValue), key: String) -> Result(Int, String) {
  case dict.get(dict, key) {
    Some(JsonNumber(n)) -> Ok(float.truncate(n))
    _ -> Error("Missing or invalid field: " <> key)
  }
}

fn get_string(dict: Dict(String, JsonValue), key: String) -> Result(String, String) {
  case dict.get(dict, key) {
    Some(JsonString(s)) -> Ok(s)
    _ -> Error("Missing or invalid field: " <> key)
  }
}
```

### 仓库模式

```gleam
pub type UserRepository {
  UserRepository(pool: DbConnection)
}

pub fn new_user_repository(pool: DbConnection) -> UserRepository {
  UserRepository(pool: pool)
}

pub fn find_by_id(repo: UserRepository, id: Int) -> Promise(Result(Option(User), DbError)) {
  use result <- promise.try_await(execute_one(repo.pool, find_user_by_id(id)))
  
  case result {
    Some(row) -> {
      case user_from_row(row) {
        Ok(user) -> promise.resolve(Ok(Some(user)))
        Error(msg) -> promise.resolve(Error(QueryFailed(message: msg)))
      }
    }
    None -> promise.resolve(Ok(None))
  }
}

pub fn find_all(repo: UserRepository) -> Promise(Result(List(User), DbError)) {
  use rows <- promise.try_await(execute(repo.pool, query("SELECT * FROM users")))
  
  let users = rows
    |> list.map(user_from_row)
    |> result.all
  
  case users {
    Ok(users) -> promise.resolve(Ok(users))
    Error(msg) -> promise.resolve(Error(QueryFailed(message: msg)))
  }
}

pub fn save(repo: UserRepository, user: User) -> Promise(Result(User, DbError)) {
  use _ <- promise.try_await(execute(repo.pool,
    query("INSERT INTO users (name, email) VALUES ($1, $2) RETURNING *")
    |> with_param(StringParam(user.name))
    |> with_param(StringParam(user.email))
  ))
  
  promise.resolve(Ok(user))
}
```

## 健康检查

```gleam
pub type HealthStatus {
  Healthy
  Unhealthy(reason: String)
}

pub fn health_check(pool: DbConnection) -> Promise(HealthStatus) {
  use result <- promise.await(execute(pool, query("SELECT 1")))
  
  case result {
    Ok(_) -> promise.resolve(Healthy)
    Error(error) -> promise.resolve(Unhealthy(reason: error.message))
  }
}
```

## 小结

在本章中，我们学习了：

1. **连接池** - 创建和管理数据库连接
2. **查询构建器** - 类型安全的 SQL 查询
3. **事务处理** - 安全的事务操作
4. **数据模型** - 从数据库行映射到 Gleam 类型
5. **仓库模式** - 封装数据库操作
6. **健康检查** - 监控数据库状态

下一章，我们将学习如何构建命令行工具。
