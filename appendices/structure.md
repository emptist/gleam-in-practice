# Appendix D: Project Structure

## Recommended Structure

```
my_gleam_project/
├── README.md                 # Project documentation
├── CHANGELOG.md              # Version history
├── LICENSE                   # License file
├── gleam.toml                # Project configuration
├── manifest.toml             # Dependency lock file
├── src/
│   └── my_app/               # Main source directory
│       ├── my_app.gleam      # Main module (public API)
│       ├── types.gleam       # Type definitions
│       ├── utils.gleam       # Utility functions
│       ├── ffi.mjs           # JavaScript FFI
│       └── internal/         # Private modules
│           ├── helpers.gleam
│           └── constants.gleam
├── test/
│   └── my_app_test.gleam     # Test file
├── build/                    # Build output (gitignored)
│   └── dev/
│       └── javascript/
│           └── my_app/       # Compiled JavaScript
└── examples/                 # Example code
    └── basic_example.gleam
```

## TraeNuPI Structure

```
traenupi/
├── gleam/
│   └── traenupi_core/
│       ├── gleam.toml
│       ├── src/
│       │   └── traenupi_core/
│       │       ├── traenupi_core.gleam  # Main entry
│       │       ├── jsonx.gleam          # JSON handling
│       │       ├── schema.gleam         # Schema validation
│       │       ├── json_path.gleam      # JSON Path
│       │       ├── db.gleam             # Database
│       │       ├── db_ffi.mjs           # DB FFI
│       │       ├── task.gleam           # Tasks
│       │       ├── task_ffi.mjs         # Task FFI
│       │       ├── meeting.gleam        # Meetings
│       │       ├── meeting_ffi.mjs      # Meeting FFI
│       │       ├── cache.gleam          # Caching
│       │       ├── async.gleam          # Async utilities
│       │       ├── state.gleam          # State management
│       │       ├── cli.gleam            # CLI parsing
│       │       ├── validation.gleam     # Validation
│       │       ├── datetime.gleam       # Date/time
│       │       ├── str.gleam            # String utils
│       │       ├── resultx.gleam        # Result combinators
│       │       ├── collection.gleam     # Collections
│       │       ├── config.gleam         # Configuration
│       │       ├── fs.gleam             # File system
│       │       ├── http.gleam           # HTTP client
│       │       ├── logger.gleam         # Logging
│       │       ├── utils.gleam          # General utils
│       │       └── property.gleam       # Property testing
│       └── test/
│           └── traenupi_core_test.gleam
├── src/
│   └── trae/
│       ├── index.ts          # Main entry
│       ├── baby-ai.ts        # Pi integration
│       └── gleam-bridge.ts   # TypeScript bridge
└── package.json
```

## Module Organization

### Single Responsibility

Each module should have one responsibility:

```gleam
// types.gleam - Type definitions only
pub type User { ... }
pub type Task { ... }
pub type Error { ... }

// user.gleam - User operations
pub fn new_user(...) { ... }
pub fn validate_user(...) { ... }

// task.gleam - Task operations
pub fn new_task(...) { ... }
pub fn start_task(...) { ... }
```

### Public API

Main module exports public API:

```gleam
// my_app.gleam
pub type User = types.User
pub type Task = types.Task

pub fn new_user(name: String) -> User {
  user.new(name)
}

pub fn new_task(title: String) -> Task {
  task.new(title)
}
```

### Internal Modules

Private modules go in `internal/`:

```gleam
// internal/helpers.gleam
// Not exported, used internally

fn helper_function() -> Int {
  42
}
```

## Configuration

### gleam.toml

```toml
name = "my_app"
version = "1.0.0"
target = "javascript"

[dependencies]
gleam_stdlib = ">= 0.34.0 and < 2.0.0"
gleeunit = ">= 1.0.0 and < 2.0.0"

[dev-dependencies]
gleeunit = ">= 1.0.0 and < 2.0.0"

[javascript]
typescript_declarations = true
```

### TypeScript Integration

```json
// tsconfig.json
{
  "compilerOptions": {
    "paths": {
      "my_app": ["./gleam/my_app/build/dev/javascript/my_app"]
    }
  }
}
```

## Build Commands

```bash
# Build the project
gleam build

# Run tests
gleam test

# Run the project
gleam run

# Format code
gleam format

# Add dependency
gleam add package_name

# Publish to Hex
gleam publish
```

## File Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Modules | snake_case | `user_manager.gleam` |
| Types | PascalCase | `UserManager` |
| Functions | snake_case | `get_user()` |
| Constants | SCREAMING_SNAKE | `MAX_RETRIES` |
| FFI files | module_ffi.mjs | `db_ffi.mjs` |

## Dependency Management

```bash
# Add production dependency
gleam add gleam_http

# Add dev dependency
gleam add --dev gleeunit

# Update dependencies
gleam update

# Download dependencies
gleam deps download
```

## Testing Structure

```gleam
// test/my_app_test.gleam
import gleeunit
import gleeunit/should
import my_app

pub fn main() -> Nil {
  gleeunit.main()
}

// Group related tests with naming convention
pub fn user_new_test() {
  let user = my_app.new_user("Alice")
  user.name |> should.equal("Alice")
}

pub fn user_validate_test() {
  let result = my_app.validate_user("")
  result |> should.be_error()
}
```

## Documentation

```gleam
/// Creates a new user with the given name.
///
/// # Examples
///
/// ```gleam
/// let user = new_user("Alice")
/// user.name == "Alice"
/// ```
///
pub fn new_user(name: String) -> User {
  User(name: name, created_at: now())
}
```

## Best Practices

1. **Keep modules small** - Max 500 lines
2. **One type per file** - For complex types
3. **Separate FFI** - `module_ffi.mjs` pattern
4. **Test everything** - 100% coverage goal
5. **Document public API** - Use doc comments
6. **Use internal/** - For private modules
7. **Export types** - `pub type T = module.T`
8. **Consistent naming** - Follow conventions
