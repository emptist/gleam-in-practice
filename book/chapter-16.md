# Chapter 16: Pure Gleam - Avoiding FFI

One of the concerns AI developers have when using Gleam is the need for FFI (Foreign Function Interface) to accomplish common tasks. However, the Gleam ecosystem has matured significantly, and there are now pure Gleam libraries for almost every common operation. This chapter will guide you through these libraries so you can write pure Gleam code without FFI concerns.

## Why Avoid FFI?

Before we dive into the libraries, let's understand why avoiding FFI is beneficial:

1. **Portability**: Pure Gleam code works on both Erlang and JavaScript targets
2. **Type Safety**: No need for `dynamic` types or unsafe casts
3. **Maintainability**: All code is in one language
4. **Testability**: Easier to test without mocking FFI calls
5. **AI-Friendly**: AI can understand and modify pure Gleam code more easily

## File System Operations

### simplifile - Cross-Platform File Operations

**Package**: `simplifile`
**Targets**: Erlang, Node.js, Deno, Bun
**Installation**: `gleam add simplifile`

simplifile provides synchronous file operations that work across all targets:

```gleam
import simplifile
import gleam/io

pub fn main() {
  // Read a file
  case simplifile.read("config.txt") {
    Ok(content) -> io.println(content)
    Error(error) -> io.println(simplifile.describe_error(error))
  }
  
  // Write a file
  let content = "Hello, World!"
  case simplifile.write("output.txt", content) {
    Ok(_) -> io.println("File written successfully")
    Error(error) -> io.println(simplifile.describe_error(error))
  }
  
  // Create a directory
  case simplifile.create_directory("my_dir") {
    Ok(_) -> io.println("Directory created")
    Error(error) -> io.println(simplifile.describe_error(error))
  }
  
  // List files in a directory
  case simplifile.get_files("my_dir") {
    Ok(files) -> {
      io.println("Files in directory:")
      files |> list.each(io.println)
    }
    Error(error) -> io.println(simplifile.describe_error(error))
  }
  
  // Delete a file
  case simplifile.delete("old_file.txt") {
    Ok(_) -> io.println("File deleted")
    Error(error) -> io.println(simplifile.describe_error(error))
  }
  
  // Copy a file
  case simplifile.copy_file("source.txt", "destination.txt") {
    Ok(_) -> io.println("File copied")
    Error(error) -> io.println(simplifile.describe_error(error))
  }
}
```

**Key Features**:
- Cross-platform (Erlang + JavaScript)
- Type-safe error handling
- Synchronous operations
- No FFI required

### filepath - Path Manipulation

**Package**: `filepath`
**Installation**: `gleam add filepath`

```gleam
import filepath

pub fn main() {
  // Join paths
  let path = filepath.join("home", "user")
  // -> "home/user"
  
  // Get file extension
  let ext = filepath.extension("document.pdf")
  // -> Ok("pdf")
  
  // Get base name
  let base = filepath.base_name("/home/user/document.pdf")
  // -> "document.pdf"
  
  // Get directory name
  let dir = filepath.directory_name("/home/user/document.pdf")
  // -> "/home/user"
}
```

### fio - Advanced File Operations

**Package**: `fio`
**Installation**: `gleam add fio`

For more advanced file operations with better ergonomics:

```gleam
import fio

pub fn main() {
  // Read with error context
  case fio.read("config.json") {
    Ok(content) -> io.println(content)
    Error(error) -> io.println("Failed to read config: " <> error)
  }
  
  // Write with automatic directory creation
  case fio.write("data/cache/session.json", json_content) {
    Ok(_) -> io.println("Cache saved")
    Error(error) -> io.println("Failed to save cache: " <> error)
  }
}
```

## HTTP and Networking

### gleam_http + gleam_httpc - HTTP Client

**Packages**: `gleam_http`, `gleam_httpc`
**Installation**: `gleam add gleam_http gleam_httpc`

For Erlang target HTTP operations:

```gleam
import gleam/http.{Get, Post}
import gleam/httpc
import gleam/io

pub fn main() {
  // GET request
  let request = http.request()
    |> http.set_method(Get)
    |> http.set_host("api.example.com")
    |> http.set_path("/users")
  
  case httpc.send(request) {
    Ok(response) -> {
      io.println("Status: " <> int.to_string(response.status))
      io.println("Body: " <> response.body)
    }
    Error(error) -> io.println("Request failed")
  }
  
  // POST request with JSON body
  let body = "{\"name\": \"Alice\"}"
  let request = http.request()
    |> http.set_method(Post)
    |> http.set_host("api.example.com")
    |> http.set_path("/users")
    |> http.set_body(body)
    |> http.set_header("content-type", "application/json")
  
  case httpc.send(request) {
    Ok(response) -> io.println("User created: " <> response.body)
    Error(error) -> io.println("Failed to create user")
  }
}
```

### gossamer - Web API Bindings for JavaScript

**Package**: `gossamer`
**Targets**: JavaScript (Node.js, Deno, Bun, Browser)
**Installation**: `gleam add gossamer`

For JavaScript target HTTP operations:

```gleam
import gossamer
import gossamer/promise
import gossamer/response
import gossamer/url
import gleam/io

pub fn main() {
  // Parse URL
  let parsed = url.new("https://api.example.com/users?q=gleam")
  let hostname = url.hostname(parsed)
  // -> "api.example.com"
  
  // Fetch API
  use resp <- promise.then(gossamer.fetch("https://api.example.com/users"))
  use body <- promise.then(response.text(resp))
  
  io.println("Response: " <> body)
  promise.resolve(body)
}
```

**Features**:
- Complete Web API bindings
- Promise support
- WebSocket client
- Headers, Request, Response types
- URL parsing
- FormData support
- Streams API
- Crypto API

### mist - HTTP Server

**Package**: `mist`
**Installation**: `gleam add mist`

For building HTTP servers:

```gleam
import mist
import gleam/http.{Get}
import gleam/io

pub fn handle_request(request) {
  case request.method {
    Get -> {
      case request.path {
        ["/"] -> {
          mist.Response(200, [], "Hello, World!")
        }
        ["/users"] -> {
          mist.Response(200, [], "[{\"name\": \"Alice\"}]")
        }
        _ -> {
          mist.Response(404, [], "Not Found")
        }
      }
    }
    _ -> {
      mist.Response(405, [], "Method Not Allowed")
    }
  }
}

pub fn main() {
  mist.new(handle_request)
    |> mist.port(3000)
    |> mist.start
}
```

### glisten - TCP Server

**Package**: `glisten`
**Installation**: `gleam add glisten`

For low-level TCP networking:

```gleam
import glisten
import gleam/io

pub fn handle_connection(socket) {
  // Read from socket
  let assert Ok(data) = glisten.receive(socket, 1024)
  io.println("Received: " <> data)
  
  // Write to socket
  let assert Ok(_) = glisten.send(socket, "Echo: " <> data)
  
  // Close connection
  glisten.close(socket)
}

pub fn main() {
  glisten.new(handle_connection)
    |> glisten.port(8080)
    |> glisten.start
}
```

## Data Formats

### gleam_json - JSON Parsing and Encoding

**Package**: `gleam_json`
**Installation**: `gleam add gleam_json`

```gleam
import gleam/json
import gleam/dynamic/decode

// Encoding
pub fn encode_user(user: User) -> String {
  json.object([
    #("name", json.string(user.name)),
    #("age", json.int(user.age)),
    #("email", json.string(user.email)),
    #("active", json.bool(user.active)),
  ])
  |> json.to_string
}

// Decoding
pub fn decode_user(json_string: String) -> Result(User, json.DecodeError) {
  let user_decoder = {
    use name <- decode.field("name", decode.string)
    use age <- decode.field("age", decode.int)
    use email <- decode.field("email", decode.string)
    use active <- decode.field("active", decode.bool)
    decode.success(User(name:, age:, email:, active:))
  }
  
  json.parse(from: json_string, using: user_decoder)
}
```

### tom - TOML Parsing

**Package**: `tom`
**Installation**: `gleam add tom`

```gleam
import tom

pub fn main() {
  let config = "
    [database]
    host = \"localhost\"
    port = 5432
    
    [server]
    host = \"0.0.0.0\"
    port = 8080
  "
  
  case tom.parse(config) {
    Ok(parsed) -> {
      // Get values
      let assert Ok(host) = tom.get_string(parsed, ["database", "host"])
      let assert Ok(port) = tom.get_int(parsed, ["database", "port"])
      
      io.println("Database: " <> host <> ":" <> int.to_string(port))
    }
    Error(error) -> io.println("Failed to parse TOML")
  }
}
```

### taffy - YAML Parsing

**Package**: `taffy`
**Installation**: `gleam add taffy`

Pure Gleam YAML parser with optional native backend:

```gleam
import taffy

pub fn main() {
  let yaml = "
    name: John Doe
    age: 30
    active: true
    tags:
      - gleam
      - erlang
  "
  
  case taffy.parse(yaml) {
    Ok(value) -> {
      // Access fields
      let assert Ok(name) = taffy.get(value, "name")
      let assert Ok(age) = taffy.get(value, "age")
      
      // Convert to JSON
      let json = taffy.to_json_string(value)
      io.println("JSON: " <> json)
    }
    Error(error) -> io.println("Failed to parse YAML")
  }
}
```

**Features**:
- Pure Gleam (no FFI required)
- YAML 1.2 compliant
- Optional native C NIF backend for performance
- Merge keys support
- JSON output

### gsv - CSV Parsing

**Package**: `gsv`
**Installation**: `gleam add gsv`

```gleam
import gsv

pub fn main() {
  let csv = "name,age,city\nAlice,30,New York\nBob,25,Los Angeles"
  
  // Parse CSV to list of lists
  case gsv.to_lists(csv) {
    Ok(records) -> {
      records |> list.each(fn(record) {
        io.println(record)
      })
    }
    Error(error) -> io.println("Failed to parse CSV")
  }
  
  // Write CSV
  let data = [
    ["name", "age", "city"],
    ["Alice", "30", "New York"],
    ["Bob", "25", "Los Angeles"],
  ]
  
  let csv_string = gsv.from_lists(data, separator: ",", line_ending: gsv.Unix)
  io.println(csv_string)
}
```

## Environment and System

### envoy - Environment Variables

**Package**: `envoy`
**Installation**: `gleam add envoy`

```gleam
import envoy
import gleam/io

pub fn main() {
  // Get environment variable
  case envoy.get("DATABASE_URL") {
    Ok(url) -> io.println("Database URL: " <> url)
    Error(_) -> io.println("DATABASE_URL not set")
  }
  
  // Get with default
  let port = envoy.get("PORT") |> result.unwrap("3000")
  io.println("Port: " <> port)
}
```

### argv - Command Line Arguments

**Package**: `argv`
**Installation**: `gleam add argv`

```gleam
import argv
import gleam/io

pub fn main() {
  // Get all arguments
  let args = argv.load().arguments
  
  case args {
    ["help"] -> io.println("Usage: myapp <command>")
    ["greet", name] -> io.println("Hello, " <> name <> "!")
    _ -> io.println("Unknown command")
  }
}
```

### directories - Platform-Specific Directories

**Package**: `directories`
**Installation**: `gleam add directories`

```gleam
import directories
import gleam/io

pub fn main() {
  // Get platform-specific directories
  let assert Ok(dirs) = directories.directories("myapp", "MyApp")
  
  // Config directory
  let config_dir = dirs.config_dir
  io.println("Config: " <> config_dir)
  
  // Data directory
  let data_dir = dirs.data_dir
  io.println("Data: " <> data_dir)
  
  // Cache directory
  let cache_dir = dirs.cache_dir
  io.println("Cache: " <> cache_dir)
}
```

## Logging and Monitoring

### logging - Structured Logging

**Package**: `logging`
**Installation**: `gleam add logging`

```gleam
import logging
import gleam/io

pub fn main() {
  // Initialize logging
  logging.configure()
  
  // Log at different levels
  logging.debug("Debug message")
  logging.info("Info message")
  logging.warning("Warning message")
  logging.error("Error message")
  
  // Log with context
  logging.info_with("User logged in", [#("user_id", "123"), #("ip", "192.168.1.1")])
}
```

### woof - Simple Logging

**Package**: `woof`
**Installation**: `gleam add woof`

```gleam
import woof
import gleam/io

pub fn main() {
  // Create logger
  let logger = woof.new()
  
  // Log messages
  logger |> woof.info("Application started")
  logger |> woof.error("Something went wrong")
  
  // With context
  logger |> woof.with_context([#("request_id", "abc123")])
  logger |> woof.info("Processing request")
}
```

## Cryptography and Security

### gleam_crypto - Cryptographic Operations

**Package**: `gleam_crypto`
**Installation**: `gleam add gleam_crypto`

```gleam
import gleam/crypto
import gleam/io

pub fn main() {
  // Hash a password
  let password = "my_secret_password"
  let hash = crypto.hash_password(password)
  io.println("Hashed: " <> hash)
  
  // Verify password
  let is_valid = crypto.verify_password(password, hash)
  io.println("Valid: " <> bool.to_string(is_valid))
  
  // Generate random bytes
  let assert Ok(bytes) = crypto.strong_random_bytes(32)
  io.println("Random bytes: " <> bytes)
  
  // Hash data
  let data = "Hello, World!"
  let hash = crypto.sha256(data)
  io.println("SHA256: " <> hash)
}
```

## Time Operations

### gleam_time - Date and Time

**Package**: `gleam_time`
**Installation**: `gleam add gleam_time`

```gleam
import gleam/time
import gleam/io

pub fn main() {
  // Get current time
  let now = time.system_time()
  io.println("Current time: " <> int.to_string(now))
  
  // Format time
  let formatted = time.format(now, time.ISO8601)
  io.println("Formatted: " <> formatted)
  
  // Parse time
  let assert Ok(parsed) = time.parse("2024-01-01T00:00:00Z", time.ISO8601)
  io.println("Parsed: " <> int.to_string(parsed))
  
  // Duration operations
  let duration = time.Duration(1000) // 1 second
  let later = time.add(now, duration)
  io.println("Later: " <> int.to_string(later))
}
```

## Binary Data

### bison - Binary Parsing

**Package**: `bison`
**Installation**: `gleam add bison`

```gleam
import bison

pub fn main() {
  // Parse binary data
  let data = <<0x01, 0x02, 0x03, 0x04>>
  
  case bison.parse(data) {
    Ok(value) -> io.println("Parsed: " <> bison.to_string(value))
    Error(error) -> io.println("Failed to parse binary data")
  }
  
  // Encode to binary
  let binary = bison.encode(#(1, 2, 3))
  io.println("Encoded: " <> binary)
}
```

## Database Operations

### pgl - PostgreSQL Driver

**Package**: `pgl`
**Installation**: `gleam add pgl`

```gleam
import pgl
import gleam/io

pub fn main() {
  // Connect to database
  let assert Ok(conn) = pgl.connect("postgres://user:pass@localhost/db")
  
  // Execute query
  let assert Ok(rows) = pgl.query(conn, "SELECT * FROM users WHERE active = $1", [pgl.bool(True)])
  
  rows |> list.each(fn(row) {
    io.println(row)
  })
  
  // Close connection
  pgl.close(conn)
}
```

### based - Database-Agnostic Query Builder

**Package**: `based`
**Installation**: `gleam add based`

```gleam
import based
import gleam/io

pub fn main() {
  // Build query
  let query = based.new()
    |> based.select(["name", "email"])
    |> based.from("users")
    |> based.where_("active", based.eq(True))
    |> based.order_by(["name"])
    |> based.limit(10)
  
  // Get SQL
  let sql = based.to_sql(query)
  io.println("SQL: " <> sql)
}
```

## Testing

### gleeunit - Test Framework

**Package**: `gleeunit`
**Installation**: `gleam add gleeunit`

```gleam
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn add_test() {
  add(2, 3) |> should.equal(5)
}
```

## Practical Testing Experiences

### Real-World Library Testing

To validate the pure Gleam approach, we tested the most commonly used libraries in real scenarios. Here's what we learned:

#### File Operations with simplifile

**Test Results**: ✅ All tests passed

```gleam
// Write and read operations work perfectly
let content = "Hello, Gleam! This is a test file.\nLine 2\nLine 3"
case simplifile.write("test_file.txt", content) {
  Ok(_) -> io.println("File written successfully")
  Error(error) -> io.println(simplifile.describe_error(error))
}

// Read back the content
case simplifile.read("test_file.txt") {
  Ok(read_content) -> {
    case read_content == content {
      True -> io.println("✓ Content matches")
      False -> io.println("✗ Content mismatch")
    }
  }
  Error(error) -> io.println("Read failed")
}
```

**Key Insights**:
- `simplifile.create_directory_all()` is essential for nested directories
- `simplifile.describe_error()` provides helpful error messages
- `simplifile.is_file()` and `simplifile.is_directory()` work reliably
- File copy and delete operations are straightforward

#### HTTP Client with gleam_httpc

**Test Results**: ✅ All tests passed

```gleam
// GET request
let assert Ok(base_req) = request.to("https://httpbin.org/get")
let req = request.set_method(base_req, Get)

case httpc.send(req) {
  Ok(response) -> {
    io.println("Status: " <> int.to_string(response.status))
    // Status: 200
  }
  Error(_) -> io.println("Request failed")
}

// POST request with JSON
let body = "{\"name\": \"Alice\", \"age\": 30}"
let assert Ok(base_req) = request.to("https://httpbin.org/post")
let req = 
  base_req
  |> request.set_method(Post)
  |> request.set_body(body)
  |> request.prepend_header("content-type", "application/json")

case httpc.send(req) {
  Ok(response) -> io.println("Status: " <> int.to_string(response.status))
  Error(_) -> io.println("Request failed")
}
```

**Key Insights**:
- Use `request.to()` to create a base request from URL
- Use `request.prepend_header()` to add headers
- The API is clean and composable with pipe operators
- Error handling is straightforward with `Result` types

#### JSON with gleam_json

**Test Results**: ✅ All tests passed

```gleam
// Encoding
pub fn encode_user(user: User) -> String {
  json.object([
    #("name", json.string(user.name)),
    #("age", json.int(user.age)),
    #("email", json.string(user.email)),
    #("active", json.bool(user.active)),
  ])
  |> json.to_string
}

// Decoding
pub fn decode_user(json_string: String) -> Result(User, json.DecodeError) {
  let user_decoder = {
    use name <- decode.field("name", decode.string)
    use age <- decode.field("age", decode.int)
    use email <- decode.field("email", decode.string)
    use active <- decode.field("active", decode.bool)
    decode.success(User(name:, age:, email:, active:))
  }
  
  json.parse(from: json_string, using: user_decoder)
}

// Array encoding
let tags = ["developer", "gleam", "functional"]
let json_tags = json.array(from: tags, of: json.string)
// Result: ["developer","gleam","functional"]
```

**Key Insights**:
- `json.array()` requires both `from:` (the list) and `of:` (converter function)
- Use `decode.field()` with the `use` syntax for clean decoder definitions
- `decode.list(of:)` for decoding arrays
- Error messages are helpful for debugging JSON issues

### Common Patterns Discovered

#### 1. Error Handling Pattern

Always use `case` expressions for proper error handling:

```gleam
case simplifile.read("config.json") {
  Ok(content) -> {
    case json.parse(from: content, using: config_decoder) {
      Ok(config) -> use_config(config)
      Error(json_error) -> handle_json_error(json_error)
    }
  }
  Error(file_error) -> handle_file_error(file_error)
}
```

#### 2. Builder Pattern for Requests

Use pipe operators to build HTTP requests:

```gleam
let req = 
  request.to("https://api.example.com/users")
  |> request.set_method(Post)
  |> request.set_body(json_body)
  |> request.prepend_header("content-type", "application/json")
  |> request.prepend_header("authorization", "Bearer " <> token)
```

#### 3. Decoder Composition

Build complex decoders by composing simple ones:

```gleam
let user_decoder = {
  use name <- decode.field("name", decode.string)
  use age <- decode.field("age", decode.int)
  use emails <- decode.field("emails", decode.list(of: decode.string))
  decode.success(User(name:, age:, emails:))
}
```

### Performance Observations

Based on our testing:

1. **File Operations**: `simplifile` is fast enough for most use cases
2. **HTTP Requests**: `gleam_httpc` performs well with Erlang's built-in HTTP client
3. **JSON Parsing**: `gleam_json` uses Thoas, which is highly optimized
4. **Memory Usage**: Pure Gleam code has predictable memory behavior

### Cross-Platform Compatibility

All tested libraries work on both Erlang and JavaScript targets:

| Library | Erlang | JavaScript | Notes |
|---------|--------|------------|-------|
| simplifile | ✅ | ✅ | Cross-platform file ops |
| gleam_httpc | ✅ | ❌ | Erlang-only HTTP client |
| gossamer | ❌ | ✅ | JavaScript-only HTTP client |
| gleam_json | ✅ | ✅ | Works on both targets |

### Recommendations

Based on our testing experience:

1. **Start with pure Gleam**: Always check if a pure Gleam library exists before using FFI
2. **Test on both targets**: Ensure your code works on both Erlang and JavaScript
3. **Use type-safe APIs**: Leverage Gleam's type system for safety
4. **Handle errors explicitly**: Don't ignore `Result` types
5. **Read the docs**: Libraries have well-documented APIs on Hexdocs

## Best Practices

### 1. Choose the Right Package for Your Target

```gleam
// For Erlang target
gleam add gleam_httpc

// For JavaScript target
gleam add gossamer

// For cross-platform
gleam add simplifile
```

### 2. Use Type-Safe Decoders

```gleam
// Instead of dynamic
let user = dynamic.from(json)

// Use decoders
let user = json.parse(from: json_string, using: user_decoder)
```

### 3. Handle Errors Properly

```gleam
// Don't use assert for file operations
let assert Ok(content) = simplifile.read("file.txt")

// Use proper error handling
case simplifile.read("file.txt") {
  Ok(content) -> // handle success
  Error(error) -> io.println(simplifile.describe_error(error))
}
```

### 4. Prefer Pure Gleam Libraries

When available, prefer pure Gleam libraries over FFI:

```gleam
// Instead of FFI for YAML
@external(javascript, "./yaml_ffi.mjs", "parse")
pub fn parse_yaml(input: String) -> YamlValue

// Use taffy (pure Gleam)
let yaml = taffy.parse(input)
```

### 5. Check Package Compatibility

Before adding a dependency, check:
- Target compatibility (Erlang/JavaScript)
- Dependencies
- Maintenance status
- Documentation quality

## Package Discovery

### Gleam Package Index

Visit [packages.gleam.run](https://packages.gleam.run) to discover packages.

### Awesome Gleam

Check [github.com/gleam-lang/awesome-gleam](https://github.com/gleam-lang/awesome-gleam) for curated list of packages.

### Hex.pm

Search [hex.pm](https://hex.pm) with "gleam" tag for all Gleam packages.

## Summary

The Gleam ecosystem has matured significantly, and you can now write production-ready applications without FFI. Key takeaways:

1. **File Operations**: Use `simplifile` for cross-platform file operations
2. **HTTP**: Use `gleam_httpc` for Erlang, `gossamer` for JavaScript
3. **Formats**: Use `gleam_json`, `tom`, `taffy`, `gsv` for data formats
4. **System**: Use `envoy`, `argv`, `directories` for system operations
5. **Logging**: Use `logging` or `woof` for logging
6. **Security**: Use `gleam_crypto` for cryptographic operations
7. **Time**: Use `gleam_time` for date and time operations
8. **Testing**: Use `gleeunit` for testing

By using these pure Gleam libraries, you can:
- Write code that works on both Erlang and JavaScript targets
- Avoid FFI complexity and maintenance burden
- Keep your codebase type-safe and maintainable
- Make it easier for AI to understand and modify your code

The Gleam ecosystem continues to grow, so check the package index regularly for new libraries and updates!
