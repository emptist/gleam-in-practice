# 第四章：FFI - JavaScript 交互

## 什么是 FFI？

FFI（Foreign Function Interface）允许 Gleam 代码调用其他语言编写的函数。对于 JavaScript 目标，Gleam 可以直接调用 JavaScript 代码。

## 基本语法

### 外部函数声明

```gleam
// 声明一个外部 JavaScript 函数
@external(javascript, "./my_ffi.mjs", "myFunction")
pub fn my_function(x: Int) -> Int
```

### JavaScript 实现

```javascript
// my_ffi.mjs
export function myFunction(x) {
  return x * 2;
}
```

## 类型映射

### 基本类型映射

| Gleam 类型 | JavaScript 类型 |
|-----------|----------------|
| `Int` | `number` |
| `Float` | `number` |
| `Bool` | `boolean` |
| `String` | `string` |
| `List(a)` | `Array` |
| `Result(a, e)` | `{type: "Ok", value: a} \| {type: "Error", value: e}` |
| `Option(a)` | `{type: "Some", value: a} \| {type: "None"}` |

### 自定义类型映射

```gleam
// Gleam
pub type User {
  User(id: Int, name: String)
}

// JavaScript 表示
// { type: "User", id: 1, name: "Alice" }
```

## 实战案例

### 案例 1：控制台输出

```gleam
// src/my_app/console.gleam
@external(javascript, "./console_ffi.mjs", "log")
pub fn log(message: String) -> Nil
```

```javascript
// src/my_app/console_ffi.mjs
export function log(message) {
  console.log(message);
  return null;
}
```

### 案例 2：定时器

```gleam
// src/my_app/timer.gleam
import gleam/javascript/promise.{type Promise}

@external(javascript, "./timer_ffi.mjs", "setTimeout")
pub fn set_timeout(delay: Int, callback: fn() -> Nil) -> Promise(Nil)
```

```javascript
// src/my_app/timer_ffi.mjs
export function setTimeout(delay, callback) {
  return new Promise((resolve) => {
    globalThis.setTimeout(() => {
      callback();
      resolve(null);
    }, delay);
  });
}
```

### 案例 3：文件系统

```gleam
// src/my_app/fs.gleam
import gleam/javascript/promise.{type Promise}

pub type FileError {
  FileNotFound(path: String)
  PermissionDenied(path: String)
  UnknownError(message: String)
}

@external(javascript, "./fs_ffi.mjs", "readFile")
pub fn read_file(path: String) -> Promise(Result(String, FileError))

@external(javascript, "./fs_ffi.mjs", "writeFile")
pub fn write_file(path: String, content: String) -> Promise(Result(Nil, FileError))
```

```javascript
// src/my_app/fs_ffi.mjs
import { readFile as fsReadFile, writeFile as fsWriteFile } from "fs/promises";

export async function readFile(path) {
  try {
    const content = await fsReadFile(path, "utf-8");
    return { type: "Ok", value: content };
  } catch (error) {
    if (error.code === "ENOENT") {
      return { type: "Error", value: { type: "FileNotFound", path } };
    }
    if (error.code === "EACCES") {
      return { type: "Error", value: { type: "PermissionDenied", path } };
    }
    return { type: "Error", value: { type: "UnknownError", message: error.message } };
  }
}

export async function writeFile(path, content) {
  try {
    await fsWriteFile(path, content, "utf-8");
    return { type: "Ok", value: null };
  } catch (error) {
    if (error.code === "ENOENT") {
      return { type: "Error", value: { type: "FileNotFound", path } };
    }
    if (error.code === "EACCES") {
      return { type: "Error", value: { type: "PermissionDenied", path } };
    }
    return { type: "Error", value: { type: "UnknownError", message: error.message } };
  }
}
```

### 案例 4：HTTP 请求

```gleam
// src/my_app/http.gleam
import gleam/javascript/promise.{type Promise}

pub type HttpMethod {
  Get
  Post
  Put
  Delete
}

pub type HttpResponse {
  HttpResponse(status: Int, body: String, headers: Dict(String, String))
}

pub type HttpError {
  NetworkError(message: String)
  Timeout
  InvalidResponse
}

@external(javascript, "./http_ffi.mjs", "request")
pub fn request(
  method: HttpMethod,
  url: String,
  headers: Dict(String, String),
  body: Option(String),
) -> Promise(Result(HttpResponse, HttpError))
```

```javascript
// src/my_app/http_ffi.mjs
export async function request(method, url, headers, body) {
  const methodMap = {
    type: method.type,
  };
  
  const methodName = method.type === "Get" ? "GET" 
    : method.type === "Post" ? "POST"
    : method.type === "Put" ? "PUT"
    : "DELETE";
  
  const fetchOptions = {
    method: methodName,
    headers: Object.fromEntries(
      Object.entries(headers).map(([k, v]) => [k, v[0]])
    ),
  };
  
  if (body.type === "Some") {
    fetchOptions.body = body.value;
  }
  
  try {
    const response = await fetch(url, fetchOptions);
    const responseText = await response.text();
    
    const responseHeaders = {};
    response.headers.forEach((value, key) => {
      responseHeaders[key] = [value];
    });
    
    return {
      type: "Ok",
      value: {
        status: response.status,
        body: responseText,
        headers: responseHeaders,
      },
    };
  } catch (error) {
    return {
      type: "Error",
      value: { type: "NetworkError", message: error.message },
    };
  }
}
```

### 案例 5：数据库操作

```gleam
// src/my_app/db.gleam
import gleam/javascript/promise.{type Promise}

pub type DbConnection

pub type DbError {
  ConnectionError(message: String)
  QueryError(message: String)
}

@external(javascript, "./db_ffi.mjs", "connect")
pub fn connect(connection_string: String) -> Promise(Result(DbConnection, DbError))

@external(javascript, "./db_ffi.mjs", "query")
pub fn query(
  conn: DbConnection,
  sql: String,
  params: List(JsonValue),
) -> Promise(Result(List(Dict(String, JsonValue)), DbError))

@external(javascript, "./db_ffi.mjs", "close")
pub fn close(conn: DbConnection) -> Promise(Nil)
```

```javascript
// src/my_app/db_ffi.mjs
import pg from "pg";

const { Pool } = pg;
const pools = new Map();

export async function connect(connectionString) {
  try {
    const pool = new Pool({ connectionString });
    await pool.query("SELECT 1");
    const id = crypto.randomUUID();
    pools.set(id, pool);
    return { type: "Ok", value: { type: "DbConnection", id } };
  } catch (error) {
    return { type: "Error", value: { type: "ConnectionError", message: error.message } };
  }
}

export async function query(conn, sql, params) {
  const pool = pools.get(conn.id);
  if (!pool) {
    return { type: "Error", value: { type: "ConnectionError", message: "Connection not found" } };
  }
  
  try {
    const result = await pool.query(sql, params);
    return { type: "Ok", value: result.rows };
  } catch (error) {
    return { type: "Error", value: { type: "QueryError", message: error.message } };
  }
}

export async function close(conn) {
  const pool = pools.get(conn.id);
  if (pool) {
    await pool.end();
    pools.delete(conn.id);
  }
  return null;
}
```

## TypeScript 类型声明

### 自动生成声明

在 `gleam.toml` 中启用 TypeScript 声明：

```toml
[javascript]
typescript_declarations = true
```

生成的 `.d.ts` 文件：

```typescript
// build/dev/javascript/my_app/my_app.d.ts
export function myFunction(x: number): number;

export type User = {
  type: "User";
  id: number;
  name: string;
};

export type Result<a, e> = 
  | { type: "Ok"; value: a }
  | { type: "Error"; value: e };

export type Option<a> = 
  | { type: "Some"; value: a }
  | { type: "None" };
```

### 手动类型声明

对于复杂的 FFI，可以手动编写类型声明：

```typescript
// src/types/gleam.d.ts
declare module "my_app" {
  export function myFunction(x: number): number;
  
  export interface User {
    type: "User";
    id: number;
    name: string;
  }
  
  export type Result<a, e> = 
    | { type: "Ok"; value: a }
    | { type: "Error"; value: e };
}
```

## 从 TypeScript 调用 Gleam

### 基本调用

```typescript
// src/index.ts
import { myFunction, User } from "./gleam/my_app/build/dev/javascript/my_app/my_app.mjs";

const result = myFunction(42); // 84

const user: User = {
  type: "User",
  id: 1,
  name: "Alice",
};
```

### 处理 Result 类型

```typescript
// src/index.ts
import { divide } from "./gleam/my_app/build/dev/javascript/my_app/my_app.mjs";

const result = divide(10, 2);

if (result.type === "Ok") {
  console.log("Result:", result.value);
} else {
  console.error("Error:", result.value);
}
```

### 处理 Option 类型

```typescript
// src/index.ts
import { findUser } from "./gleam/my_app/build/dev/javascript/my_app/my_app.mjs";

const maybeUser = findUser(users, 1);

if (maybeUser.type === "Some") {
  console.log("Found user:", maybeUser.value);
} else {
  console.log("User not found");
}
```

## 最佳实践

### 1. 错误处理

始终使用 `Result` 类型处理可能的错误：

```gleam
// 好
@external(javascript, "./ffi.mjs", "readFile")
pub fn read_file(path: String) -> Promise(Result(String, FileError))

// 避免
@external(javascript, "./ffi.mjs", "readFile")
pub fn read_file(path: String) -> Promise(String)  // 可能抛出异常
```

### 2. 类型安全

确保 JavaScript 返回正确的类型：

```javascript
// 好
export function getValue() {
  return { type: "Ok", value: 42 };
}

// 避免
export function getValue() {
  return 42;  // 缺少类型包装
}
```

### 3. 异步操作

使用 `Promise` 处理异步操作：

```gleam
import gleam/javascript/promise.{type Promise}

@external(javascript, "./ffi.mjs", "fetchData")
pub fn fetch_data(url: String) -> Promise(Result(Data, Error))
```

### 4. 文档注释

为 FFI 函数添加文档：

```gleam
/// 从文件系统读取文件内容
/// 
/// # 参数
/// - `path`: 文件路径
/// 
/// # 返回
/// - `Ok(content)`: 文件内容
/// - `Error(FileNotFound)`: 文件不存在
/// - `Error(PermissionDenied)`: 无权限
@external(javascript, "./fs_ffi.mjs", "readFile")
pub fn read_file(path: String) -> Promise(Result(String, FileError))
```

## 小结

在本章中，我们学习了：

1. **FFI 基础** - 如何声明和实现外部函数
2. **类型映射** - Gleam 和 JavaScript 类型之间的映射
3. **实战案例** - 控制台、定时器、文件系统、HTTP、数据库
4. **TypeScript 集成** - 类型声明和调用 Gleam 代码
5. **最佳实践** - 错误处理、类型安全、异步操作

下一章，我们将学习数据库操作。
