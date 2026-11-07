# Chapter 4: FFI - JavaScript Integration

> "FFI is the bridge between Gleam's type safety and JavaScript's ecosystem."
> 
> — Practical Gleam wisdom

## Calling JavaScript from Gleam

### The @external Attribute

Gleam uses `@external` to call JavaScript functions:

```gleam
@external(javascript, "./my_module.mjs", "my_function")
pub fn my_function(input: String) -> Int
```

This tells Gleam:
1. When compiling to JavaScript, import from `./my_module.mjs`
2. Call the function named `my_function`
3. The Gleam function signature defines the types

### Simple Example

**Gleam:**
```gleam
// math.gleam
@external(javascript, "./math_ffi.mjs", "add")
pub fn add(a: Int, b: Int) -> Int
```

**JavaScript:**
```javascript
// math_ffi.mjs
export function add(a, b) {
  return a + b;
}
```

### Working with Options

Gleam's `Option` type maps to JavaScript's nullable values:

**Gleam:**
```gleam
@external(javascript, "./env_ffi.mjs", "get_env")
pub fn get_env(key: String) -> Option(String)
```

**JavaScript:**
```javascript
// env_ffi.mjs
export function get_env(key) {
  const value = process.env[key];
  if (value === undefined || value === '') {
    return { type: 'None' };
  }
  return { type: 'Some', value };
}
```

### Working with Results

**Gleam:**
```gleam
pub type DbError {
  ConnectionError(String)
  QueryError(String)
}

@external(javascript, "./db_ffi.mjs", "connect")
pub fn connect(config: DbConfig) -> Promise(Result(Connection, DbError))
```

**JavaScript:**
```javascript
// db_ffi.mjs
export function connect(config) {
  return new Promise((resolve) => {
    try {
      const pool = new Pool(config);
      resolve({ type: 'Ok', value: pool });
    } catch (e) {
      resolve({ type: 'Error', value: { ConnectionError: e.message } });
    }
  });
}
```

---

## Calling Gleam from TypeScript

### The Build Output

When you run `gleam build`, Gleam generates:

```
build/dev/javascript/traenupi_core/
├── traenupi_core.mjs      # Main module
├── traenupi_core/
│   ├── jsonx.mjs          # JSON module
│   ├── schema.mjs         # Schema module
│   ├── db.mjs             # Database module
│   └── ...
└── gleam_stdlib/          # Standard library
```

### TypeScript Bridge Module

Create a bridge to use Gleam from TypeScript:

```typescript
// gleam-bridge.ts
import * as jsonx from '../gleam/traenupi_core/build/dev/javascript/traenupi_core/traenupi_core/jsonx.mjs';
import * as schema from '../gleam/traenupi_core/build/dev/javascript/traenupi_core/traenupi_core/schema.mjs';
import * as db from '../gleam/traenupi_core/build/dev/javascript/traenupi_core/traenupi_core/db.mjs';
import { toList, Ok, Error as GleamError } from '../gleam/traenupi_core/build/dev/javascript/gleam_stdlib/gleam.mjs';

// Re-export with TypeScript-friendly API
export const Json = {
  parse: (input: string): Result<JsonValue, JsonError> => {
    const result = jsonx.parse(input);
    return gleamResultToTs(result);
  },
  
  encode: (value: JsonValue): string => {
    return jsonx.encode(value);
  },
};

export const Db = {
  connect: async (config: DbConfig): Promise<Result<Connection, DbError>> => {
    const gleamConfig = toDbConfig(config);
    const result = await db.connect(gleamConfig);
    return gleamResultToTs(result);
  },
  
  query: async (conn: Connection, sql: string, params: string[]): Promise<Result<QueryResult, DbError>> => {
    const result = await db.query(conn, sql, toList(params));
    return gleamResultToTs(result);
  },
};

// Helper functions
function gleamResultToTs<T, E>(result: any): Result<T, E> {
  if (result.type === 'Ok') {
    return { ok: true, value: result.value };
  }
  return { ok: false, error: result.value };
}

function toDbConfig(config: DbConfig): any {
  return {
    host: config.host,
    port: config.port,
    database: config.database,
    user: config.user,
    password: config.password ? { type: 'Some', value: config.password } : { type: 'None' },
    max_connections: config.maxConnections,
    idle_timeout_ms: config.idleTimeoutMs,
    connection_timeout_ms: config.connectionTimeoutMs,
  };
}
```

---

## Type Conversions

### Gleam → JavaScript

| Gleam Type | JavaScript Representation |
|------------|-------------------------|
| `Int` | `number` |
| `Float` | `number` |
| `String` | `string` |
| `Bool` | `boolean` |
| `List(a)` | `Array` with `toList()` wrapper |
| `Option(a)` | `{ type: 'None' }` or `{ type: 'Some', value }` |
| `Result(a, e)` | `{ type: 'Ok', value }` or `{ type: 'Error', value }` |
| Custom type | Object with variant name as key |

### Custom Type Example

**Gleam:**
```gleam
pub type TaskStatus {
  Pending
  Running
  Done
  Failed
}

pub type Task {
  Task(id: String, title: String, status: TaskStatus)
}
```

**JavaScript representation:**
```javascript
// Pending
{ type: 'Pending' }

// Task
{ type: 'Task', id: '123', title: 'My Task', status: { type: 'Pending' } }
```

---

## Real Example: gleam-bridge.ts

From TraeNuPI's actual implementation:

```typescript
// gleam-bridge.ts
import {
  parse as jsonParse,
  encode as jsonEncode,
  json_to_string,
  json_to_array,
  json_to_object,
  type JsonValue,
  type JsonError,
} from '../../gleam/traenupi_core/build/dev/javascript/traenupi_core/traenupi_core/jsonx.mjs';

import {
  validate as schemaValidate,
  type Schema,
  type ValidationError,
} from '../../gleam/traenupi_core/build/dev/javascript/traenupi_core/traenupi_core/schema.mjs';

import { toList, Ok, Error as GleamError } from '../../gleam/traenupi_core/build/dev/javascript/gleam_stdlib/gleam.mjs';

export class GleamBridge {
  // JSON operations
  static parseJson(input: string): Result<JsonValue, JsonError> {
    const result = jsonParse(input);
    return this.gleamResultToTs(result);
  }

  static encodeJson(value: JsonValue): string {
    return jsonEncode(value);
  }

  // Schema validation
  static validateJson(schema: Schema, value: JsonValue): Result<null, ValidationError[]> {
    const result = schemaValidate(schema, value);
    return this.gleamResultToTs(result);
  }

  // Helper: Convert Gleam Result to TypeScript Result
  private static gleamResultToTs<T, E>(result: any): Result<T, E> {
    if (result.type === 'Ok') {
      return { ok: true, value: result.value };
    }
    return { ok: false, error: result.value };
  }

  // Helper: Convert TypeScript array to Gleam List
  private static toGleamList<T>(arr: T[]): any {
    return toList(arr);
  }
}

// TypeScript Result type
export type Result<T, E> = 
  | { ok: true; value: T }
  | { ok: false; error: E };
```

---

## Best Practices

### 1. Keep FFI Functions Small

**Good:**
```gleam
@external(javascript, "./ffi.mjs", "get_timestamp")
pub fn get_timestamp() -> Int

@external(javascript, "./ffi.mjs", "format_date")
pub fn format_date(timestamp: Int) -> String
```

**Bad:**
```gleam
@external(javascript, "./ffi.mjs", "do_everything")
pub fn do_everything(input: String) -> Result(ComplexType, ManyErrors)
```

### 2. Use Type Aliases for Clarity

```gleam
pub type JsPromise(a)
pub type JsArray(a)

@external(javascript, "./ffi.mjs", "promise_all")
pub fn promise_all(promises: List(JsPromise(a))) -> JsPromise(List(a))
```

### 3. Handle All Cases in Pattern Matching

```gleam
pub fn handle_js_result(result: JsResult(a)) -> Result(a, String) {
  case result {
    { type: "Ok", value: v } -> Ok(v)
    { type: "Error", error: e } -> Error(e)
    _ -> Error("Unknown result type from JavaScript")
  }
}
```

### 4. Document FFI Boundaries

```gleam
// FFI: Calls Node.js process.env
// Returns None if the environment variable is not set
@external(javascript, "./env_ffi.mjs", "get_env")
pub fn get_env(key: String) -> Option(String)
```

---

## Common Patterns

### Pattern 1: Async Operations

```gleam
import gleam/javascript/promise.{type Promise}

@external(javascript, "./http_ffi.mjs", "fetch")
pub fn fetch(url: String) -> Promise(Result(String, HttpError))

// Usage
pub fn get_user(id: String) -> Promise(Result(User, Error)) {
  use response <- promise.await(fetch("/api/users/" <> id))
  
  case response {
    Ok(json) -> {
      case json_parse(json) {
        Ok(data) -> decode_user(data)
        Error(e) -> promise.resolve(Error(ParseError(e)))
      }
    }
    Error(e) -> promise.resolve(Error(HttpError(e)))
  }
}
```

### Pattern 2: Event Handlers

```gleam
pub type EventHandler(a) =
  fn(a) -> Nil

@external(javascript, "./events_ffi.mjs", "on_click")
pub fn on_click(handler: EventHandler(MouseEvent)) -> Nil
```

### Pattern 3: Configuration

```gleam
pub type AppConfig {
  AppConfig(
    api_url: String,
    timeout_ms: Int,
    debug: Bool,
  )
}

@external(javascript, "./config_ffi.mjs", "load_config")
pub fn load_config() -> AppConfig
```

---

## Debugging FFI

### Console Logging

```gleam
@external(javascript, "./debug_ffi.mjs", "log")
pub fn log(message: a) -> Nil

// JavaScript
export function log(message) {
  console.log(message);
  return null;
}
```

### Error Handling

```gleam
pub fn safe_call(fn_name: String, args: List(Dynamic)) -> Result(Dynamic, FfiError) {
  case call_js(fn_name, args) {
    Ok(result) -> Ok(result)
    Error(e) -> Error(FfiError(fn_name, e))
  }
}
```

---

## Summary

FFI enables Gleam to:
- Use JavaScript's vast ecosystem
- Integrate with existing TypeScript code
- Build hybrid applications
- Leverage platform-specific features

## Advanced FFI Patterns

### Pattern 4: Event Emitter Integration

Real-world example from PI Agent:

**Gleam Interface:**
```gleam
pub type EventEmitter

pub type EventHandler =
  fn(AgentEvent) -> Nil

@external(javascript, "./event_ffi.mjs", "newEmitter")
pub fn new_emitter() -> EventEmitter

@external(javascript, "./event_ffi.mjs", "on")
pub fn on(emitter: EventEmitter, handler: EventHandler) -> EventEmitter

@external(javascript, "./event_ffi.mjs", "emit")
pub fn emit(emitter: EventEmitter, event: AgentEvent) -> EventEmitter
```

**JavaScript Implementation:**
```javascript
import { EventEmitter } from 'events'

export function newEmitter() {
  return new EventEmitter()
}

export function on(emitter, handler) {
  emitter.on('agent-event', handler)
  return emitter
}

export function emit(emitter, event) {
  emitter.emit('agent-event', event)
  return emitter
}
```

**Usage:**
```gleam
let emitter = new_emitter()
let emitter = on(emitter, fn(event) {
  case event {
    AgentStart -> io.println("Agent started")
    Error(msg) -> io.println("Error: " <> msg)
    _ -> Nil
  }
})
let _ = emit(emitter, AgentStart)
```

### Pattern 5: Streaming with Callbacks

Real-world example for LLM streaming:

**Gleam Interface:**
```gleam
pub type StreamCallback =
  fn(String, Bool) -> Nil

pub type StreamHandle {
  StreamHandle(cleanup: fn() -> Nil)
}

@external(javascript, "./streaming_ffi.mjs", "createStreamingRequest")
pub fn create_streaming_request(
  url: String,
  headers: List(#(String, String)),
  body: String,
  on_chunk: StreamCallback,
) -> Promise(Result(StreamHandle, String))
```

**JavaScript Implementation:**
```javascript
export function createStreamingRequest(url, headers, body, onChunk) {
  return new Promise((resolve, reject) => {
    const controller = new AbortController()
    
    fetch(url, {
      method: 'POST',
      headers: Object.fromEntries(headers),
      body: body,
      signal: controller.signal,
    })
    .then(response => {
      const reader = response.body.getReader()
      const decoder = new TextDecoder()
      
      function readChunk() {
        reader.read().then(({ done, value }) => {
          if (done) {
            onChunk('', true)  // Signal completion
            resolve({ cleanup: () => controller.abort() })
            return
          }
          
          const chunk = decoder.decode(value, { stream: true })
          onChunk(chunk, false)
          readChunk()
        })
      }
      
      readChunk()
    })
    .catch(error => reject(error.message))
  })
}
```

**Usage:**
```gleam
let request = create_streaming_request(
  "https://api.openrouter.ai/v1/chat/completions",
  [#("Authorization", "Bearer " <> api_key)],
  json_body,
  fn(chunk, is_done) {
    case is_done {
      True -> io.println("Stream complete")
      False -> io.println("Received: " <> chunk)
    }
  },
)
```

### Pattern 6: Session Management

Complete FFI bridge for stateful operations:

**Gleam Interface:**
```gleam
pub type PiAgentSession

@external(javascript, "./pi_agent_ffi.mjs", "createSession")
pub fn create_session(api_key: String, system_prompt: String) -> PiAgentSession

@external(javascript, "./pi_agent_ffi.mjs", "sendMessage")
pub fn send_message(
  session: PiAgentSession,
  message: String,
) -> Promise(String)

@external(javascript, "./pi_agent_ffi.mjs", "sendMessageStreaming")
pub fn send_message_streaming(
  session: PiAgentSession,
  message: String,
  on_chunk: fn(String) -> Nil,
) -> Promise(String)
```

**JavaScript Implementation:**
```javascript
import { Agent } from './agent.mjs'

export function createSession(apiKey, systemPrompt) {
  return {
    agent: new Agent(systemPrompt, apiKey),
    apiKey: apiKey
  }
}

export function sendMessage(session, message) {
  return session.agent.run([{ role: 'user', content: message }])
    .then(response => response.content)
}

export function sendMessageStreaming(session, message, onChunk) {
  return session.agent.runStreaming(
    [{ role: 'user', content: message }],
    onChunk
  )
  .then(response => response.content)
}
```

**TypeScript Consumer:**
```typescript
import { createPiAgentSession } from './pi-agent-bridge.js'

const session = createPiAgentSession(
  process.env.OPENROUTER_API_KEY,
  "You are a helpful assistant"
)

// Simple message
const response = await session.sendMessage("What is 2 + 2?")

// Streaming message
const streamingResponse = await session.sendMessageStreaming(
  "Tell me a story",
  (chunk) => console.log("Chunk:", chunk)
)
```

### Pattern 7: Tool System with JSON Schema

Type-safe tool definitions:

**Gleam:**
```gleam
pub type Tool {
  Tool(
    name: String,
    description: String,
    parameters: JsonSchema,
    execution_mode: ToolExecutionMode,
  )
}

pub type JsonSchema {
  ObjectSchema(properties: List(#(String, JsonSchema)), required: List(String))
  StringSchema(description: Option(String))
  IntegerSchema(description: Option(String))
  BooleanSchema(description: Option(String))
  ArraySchema(items: JsonSchema, description: Option(String))
}

pub fn tool_to_json(tool: Tool) -> json.Json {
  json.object([
    #("type", json.string("function")),
    #(
      "function",
      json.object([
        #("name", json.string(tool.name)),
        #("description", json.string(tool.description)),
        #("parameters", json_schema_to_json(tool.parameters)),
      ]),
    ),
  ])
}
```

**JavaScript FFI:**
```javascript
export function executeToolCall(toolCall, handlers) {
  const { name, arguments: args } = toolCall.function
  const handler = handlers[name]
  
  if (!handler) {
    return {
      tool_call_id: toolCall.id,
      content: JSON.stringify({ error: `Unknown tool: ${name}` }),
      is_error: true
    }
  }
  
  try {
    const result = handler(JSON.parse(args))
    return {
      tool_call_id: toolCall.id,
      content: JSON.stringify(result),
      is_error: false
    }
  } catch (e) {
    return {
      tool_call_id: toolCall.id,
      content: JSON.stringify({ error: e.message }),
      is_error: true
    }
  }
}
```

## Key Takeaways

1. **FFI is straightforward** - Direct function mapping with type annotations
2. **Type safety preserved** - Gleam types guide JavaScript implementation
3. **Event systems work** - EventEmitter integrates cleanly
4. **Streaming is simple** - Callbacks handle real-time data
5. **State management** - Sessions maintain state across FFI boundary
6. **Tool systems** - JSON schema provides type safety

## Next Steps

In the next chapter, we'll explore database operations with type-safe SQL queries and connection pooling.
