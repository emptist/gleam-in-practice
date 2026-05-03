# Chapter 5: Database Operations

> "The database layer is where type safety matters most. One wrong query can destroy data."
> 
> — Every DBA ever

## Type-Safe SQL Queries

### The TypeScript Problem

```typescript
// TypeScript - no type safety for SQL
async function getUser(id: string): Promise<User | null> {
  const result = await db.query(
    'SELECT * FROM users WHERE id = $1',
    [id]
  );
  return result.rows[0] || null; // Any type!
}

// Runtime errors possible:
const user = await getUser("123");
console.log(user.name); // What if name doesn't exist?
console.log(user.emial); // Typo! No error until runtime
```

### The Gleam Solution

```gleam
pub fn get_user(conn: Connection, id: String) -> Promise(Result(Option(User), DbError)) {
  use result <- await(query_one(conn, "SELECT * FROM users WHERE id = $1", [id]))
  
  case result {
    Ok(Some(row)) -> {
      use id <- result.try(dict_get(row, "id"))
      use name <- result.try(dict_get(row, "name"))
      Ok(Some(User(id: id, name: name)))
    }
    Ok(None) -> Ok(None)
    Error(e) -> Error(e)
  }
}
```

---

## Connection Pooling

### Configuration

```gleam
pub type DbConfig {
  DbConfig(
    host: String,
    port: Int,
    database: String,
    user: String,
    password: Option(String),
    max_connections: Int,
    idle_timeout_ms: Int,
    connection_timeout_ms: Int,
  )
}

pub fn default_config() -> DbConfig {
  DbConfig(
    host: "localhost",
    port: 5432,
    database: "traenupi",
    user: "postgres",
    password: None,
    max_connections: 10,
    idle_timeout_ms: 30000,
    connection_timeout_ms: 5000,
  )
}
```

### From Environment

```gleam
pub fn config_from_env() -> Result(DbConfig, DbError) {
  let host = option.unwrap(get_env("DB_HOST"), "localhost")
  let port = case get_env("DB_PORT") {
    Some(p) -> {
      case int.parse(p) {
        Ok(n) -> n
        Error(_) -> 5432
      }
    }
    None -> 5432
  }
  let database = option.unwrap(get_env("DB_NAME"), "traenupi")
  let user = option.unwrap(get_env("DB_USER"), "postgres")
  let password = get_env("DB_PASSWORD")
  
  Ok(DbConfig(
    host: host,
    port: port,
    database: database,
    user: user,
    password: password,
    max_connections: 10,
    idle_timeout_ms: 30000,
    connection_timeout_ms: 5000,
  ))
}
```

---

## FFI for Database Operations

### The Gleam Interface

```gleam
pub type Connection
pub type DbError {
  ConnectionError(String)
  QueryError(String)
  TimeoutError
  PoolExhausted
  InvalidConfig(String)
  ClosedError
}

pub type QueryResult {
  QueryResult(
    rows: List(Dict(String, String)),
    row_count: Int,
  )
}

@external(javascript, "./db_ffi.mjs", "connect")
pub fn connect(config: DbConfig) -> Promise(Result(Connection, DbError))

@external(javascript, "./db_ffi.mjs", "query")
pub fn query(
  conn: Connection,
  sql: String,
  params: List(String),
) -> Promise(Result(QueryResult, DbError))

@external(javascript, "./db_ffi.mjs", "execute")
pub fn execute(
  conn: Connection,
  sql: String,
  params: List(String),
) -> Promise(Result(Int, DbError))

@external(javascript, "./db_ffi.mjs", "close")
pub fn close(conn: Connection) -> Promise(Result(Nil, DbError))
```

### The JavaScript Implementation

```javascript
// db_ffi.mjs
import pg from 'pg';

const { Pool } = pg;

export function connect(config) {
  return new Promise((resolve) => {
    try {
      const poolConfig = {
        host: config.host,
        port: config.port,
        database: config.database,
        user: config.user,
        max: config.max_connections,
        idleTimeoutMillis: config.idle_timeout_ms,
        connectionTimeoutMillis: config.connection_timeout_ms,
      };

      if (config.password && config.password.type === 'Some') {
        poolConfig.password = config.password[0];
      }

      const pool = new Pool(poolConfig);

      pool.on('error', (err) => {
        console.error('[DB] Unexpected error on idle client', err);
      });

      resolve({ type: 'Ok', value: { pool, isClosed: false } });
    } catch (e) {
      resolve({ type: 'Error', value: { ConnectionError: e.message } });
    }
  });
}

export function query(conn, sql, params) {
  return new Promise(async (resolve) => {
    if (conn.isClosed) {
      resolve({ type: 'Error', value: { ClosedError: 'Connection is closed' } });
      return;
    }

    try {
      const result = await conn.pool.query(sql, params);
      const rows = result.rows.map(row => {
        const dict = {};
        for (const [key, value] of Object.entries(row)) {
          dict[key] = value === null ? 'null' : String(value);
        }
        return dict;
      });

      resolve({
        type: 'Ok',
        value: {
          rows: rows,
          row_count: result.rowCount || 0,
        },
      });
    } catch (e) {
      resolve({ type: 'Error', value: { QueryError: e.message } });
    }
  });
}

export function close(conn) {
  return new Promise(async (resolve) => {
    if (conn.isClosed) {
      resolve({ type: 'Ok', value: null });
      return;
    }

    try {
      await conn.pool.end();
      conn.isClosed = true;
      resolve({ type: 'Ok', value: null });
    } catch (e) {
      resolve({ type: 'Error', value: { QueryError: e.message } });
    }
  });
}
```

---

## CRUD Operations

### Create (Insert)

```gleam
pub fn insert(
  conn: Connection,
  table: String,
  columns: List(String),
  values: List(String),
) -> Promise(Result(Int, DbError)) {
  let cols = string.join(columns, ", ")
  let placeholders = 
    range_list(1, list.length(columns))
    |> list.map(fn(i) { "$" <> int.to_string(i) })
    |> string.join(", ")
  let sql = "INSERT INTO " <> table <> " (" <> cols <> ") VALUES (" <> placeholders <> ")"
  execute(conn, sql, values)
}

// Usage
insert(conn, "users", ["id", "name", "email"], ["123", "Alice", "alice@example.com"])
```

### Read (Select)

```gleam
pub fn select_all(conn: Connection, table: String) -> Promise(Result(QueryResult, DbError)) {
  let sql = "SELECT * FROM " <> table
  query(conn, sql, [])
}

pub fn select_by_id(
  conn: Connection,
  table: String,
  id: String,
) -> Promise(Result(Option(Dict(String, String)), DbError)) {
  let sql = "SELECT * FROM " <> table <> " WHERE id = $1"
  query_one(conn, sql, [id])
}
```

### Update

```gleam
pub fn update(
  conn: Connection,
  table: String,
  id: String,
  columns: List(String),
  values: List(String),
) -> Promise(Result(Int, DbError)) {
  let sets = 
    list.index_map(columns, fn(col, idx) {
      col <> " = $" <> int.to_string(idx + 1)
    })
    |> string.join(", ")
  let sql = "UPDATE " <> table <> " SET " <> sets <> " WHERE id = $" <> int.to_string(list.length(columns) + 1)
  execute(conn, sql, list.append(values, [id]))
}
```

### Delete

```gleam
pub fn delete(
  conn: Connection,
  table: String,
  id: String,
) -> Promise(Result(Int, DbError)) {
  let sql = "DELETE FROM " <> table <> " WHERE id = $1"
  execute(conn, sql, [id])
}
```

---

## Query Builders

### WHERE Clause Builder

```gleam
pub fn build_where_clause(conditions: List(#(String, String))) -> String {
  case conditions {
    [] -> ""
    _ -> {
      let clauses = 
        conditions
        |> list.index_map(fn(cond, idx) {
          let #(col, _val) = cond
          col <> " = $" <> int.to_string(idx + 1)
        })
        |> string.join(" AND ")
      " WHERE " <> clauses
    }
  }
}

// Usage
build_where_clause([#("status", "active"), #("role", "admin")])
// Returns: " WHERE status = $1 AND role = $2"
```

### ORDER BY Builder

```gleam
pub fn build_order_clause(columns: List(String), direction: String) -> String {
  case columns {
    [] -> ""
    _ -> {
      let cols = string.join(columns, ", ")
      " ORDER BY " <> cols <> " " <> direction
    }
  }
}
```

### LIMIT/OFFSET Builders

```gleam
pub fn build_limit_clause(limit: Int) -> String {
  " LIMIT " <> int.to_string(limit)
}

pub fn build_offset_clause(offset: Int) -> String {
  " OFFSET " <> int.to_string(offset)
}
```

---

## Health Checks and Monitoring

### Pool Statistics

```gleam
pub type PoolStats {
  PoolStats(
    total_connections: Int,
    idle_connections: Int,
    active_connections: Int,
    waiting_clients: Int,
  )
}

@external(javascript, "./db_ffi.mjs", "get_pool_stats")
pub fn get_pool_stats(conn: Connection) -> Promise(PoolStats)
```

### Health Check

```gleam
pub type HealthStatus {
  Healthy(latency_ms: Int)
  Unhealthy(error: String)
}

@external(javascript, "./db_ffi.mjs", "health_check")
pub fn health_check(conn: Connection) -> Promise(HealthStatus)
```

### JavaScript Implementation

```javascript
export function get_pool_stats(conn) {
  const pool = conn.pool;
  const total = pool.totalCount || 0;
  const idle = pool.idleCount || 0;

  return {
    total_connections: total,
    idle_connections: idle,
    active_connections: total - idle,
    waiting_clients: pool.waitingCount || 0,
  };
}

export function health_check(conn) {
  return new Promise(async (resolve) => {
    const start = Date.now();
    try {
      await conn.pool.query('SELECT 1');
      resolve({ Healthy: Date.now() - start });
    } catch (e) {
      resolve({ Unhealthy: e.message });
    }
  });
}
```

---

## Practical Example: User Repository

```gleam
pub type User {
  User(id: String, name: String, email: String, created_at: Int)
}

pub type UserError {
  UserNotFound(id: String)
  DatabaseError(DbError)
  InvalidData(String)
}

pub fn create_user(conn: Connection, name: String, email: String) 
    -> Promise(Result(User, UserError)) {
  let id = generate_id()
  let sql = "INSERT INTO users (id, name, email) VALUES ($1, $2, $3)"
  
  use result <- await(execute(conn, sql, [id, name, email]))
  
  case result {
    Ok(1) -> {
      let user = User(id: id, name: name, email: email, created_at: now())
      resolve(Ok(user))
    }
    Ok(_) -> resolve(Error(DatabaseError(QueryError("Unexpected row count"))))
    Error(e) -> resolve(Error(DatabaseError(e)))
  }
}

pub fn get_user(conn: Connection, id: String) 
    -> Promise(Result(User, UserError)) {
  use result <- await(query_one(conn, "SELECT * FROM users WHERE id = $1", [id]))
  
  case result {
    Ok(Some(row)) -> {
      case decode_user(row) {
        Ok(user) -> resolve(Ok(user))
        Error(e) -> resolve(Error(e))
      }
    }
    Ok(None) -> resolve(Error(UserNotFound(id)))
    Error(e) -> resolve(Error(DatabaseError(e)))
  }
}

fn decode_user(row: Dict(String, String)) -> Result(User, UserError) {
  use id <- result.try(dict_get(row, "id"))
  use name <- result.try(dict_get(row, "name"))
  use email <- result.try(dict_get(row, "email"))
  use created_at_str <- result.try(dict_get(row, "created_at"))
  
  case int.parse(created_at_str) {
    Ok(created_at) -> Ok(User(id: id, name: name, email: email, created_at: created_at))
    Error(_) -> Error(InvalidData("Invalid created_at"))
  }
}

fn dict_get(dict: Dict(String, String), key: String) -> Result(String, UserError) {
  case dict.get(dict, key) {
    Ok(value) -> Ok(value)
    Error(_) -> Error(InvalidData("Missing field: " <> key))
  }
}
```

---

## Summary

| Aspect | TypeScript | Gleam |
|--------|------------|-------|
| SQL safety | No type checking | Type-safe queries |
| Connection pooling | Manual | Built-in via FFI |
| Error handling | Try/catch | Result type |
| Health checks | Manual | Built-in functions |
| Query builders | String concatenation | Type-safe builders |

## Key Takeaways

1. **FFI bridges Gleam and JavaScript** - Use @external for database operations
2. **Result type for errors** - No exceptions, explicit error handling
3. **Query builders are type-safe** - No string concatenation errors
4. **Pool management is explicit** - Health checks and stats available
5. **CRUD operations are reusable** - Generic functions for any table

## Next Steps

In **Chapter 6**, we'll explore:
- Building a CLI with Gleam
- Argument parsing
- Command dispatch
- Help generation

---

*Continue to [Chapter 6: Building a CLI](./chapter-06.md)*
