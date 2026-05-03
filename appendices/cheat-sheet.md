# Appendix A: Gleam Cheat Sheet for TypeScript Developers

## Types

| TypeScript | Gleam |
|------------|-------|
| `string` | `String` |
| `number` | `Int` or `Float` |
| `boolean` | `Bool` |
| `T[]` | `List(T)` |
| `T \| null` | `Option(T)` |
| `T \| U` | `Result(T, U)` |
| `{ key: T }` | `Dict(String, T)` |
| `interface` | `type` |

## Declarations

```gleam
// Type alias
pub type UserId = String

// Custom type (like interface)
pub type User {
  User(id: String, name: String, email: Option(String))
}

// Enum (union type)
pub type Status {
  Pending
  Running
  Completed
  Failed
}

// Generic type
pub type Result(a, e) {
  Ok(a)
  Error(e)
}
```

## Functions

```gleam
// Basic function
pub fn add(a: Int, b: Int) -> Int {
  a + b
}

// Function with pipe
pub fn process(input: String) -> String {
  input
  |> string.trim()
  |> string.lowercase()
}

// Anonymous function
let double = fn(x) { x * 2 }

// Function as parameter
pub fn apply(f: fn(Int) -> Int, x: Int) -> Int {
  f(x)
}
```

## Pattern Matching

```gleam
// Match on values
case status {
  Pending -> "Waiting"
  Running -> "In progress"
  Completed -> "Done"
  Failed -> "Error"
}

// Match with guards
case value {
  n if n < 0 -> "Negative"
  n if n == 0 -> "Zero"
  _ -> "Positive"
}

// Match on tuples
case pair {
  #(x, y) -> x + y
}

// Match on records
case user {
  User(name: n, ..) -> "Hello, " <> n
}

// Destructure in function
pub fn get_name(User(name: n, ..)) -> String {
  n
}
```

## Option Type

```gleam
// Creating
let some_value = Some(42)
let no_value: Option(Int) = None

// Checking
case opt {
  Some(value) -> value
  None -> default
}

// Unwrap with default
option.unwrap(opt, 0)

// Map over option
option.map(opt, fn(x) { x * 2 })

// Chain options
option.then(opt, fn(x) { Some(x + 1) })
```

## Result Type

```gleam
// Creating
let ok_value = Ok(42)
let err_value: Result(Int, String) = Error("failed")

// Checking
case result {
  Ok(value) -> value
  Error(e) -> handle_error(e)
}

// Map over result
result.map(result, fn(x) { x * 2 })

// Chain results
result.then(result, fn(x) { Ok(x + 1) })

// Try pattern (early return)
use value <- result.try(result)
Ok(value + 1)
```

## Lists

```gleam
// Creating
let list = [1, 2, 3]
let list = [1, ..existing]

// Common operations
list.map(list, fn(x) { x * 2 })
list.filter(list, fn(x) { x > 0 })
list.fold(list, 0, fn(acc, x) { acc + x })
list.find(list, fn(x) { x == 2 })
list.length(list)

// Access
list.first(list)
list.at(list, 0)
```

## Dict (Dictionary)

```gleam
// Creating
let dict = dict.from_list([#("key", "value")])

// Operations
dict.insert(dict, "key", "value")
dict.get(dict, "key")
dict.has_key(dict, "key")
dict.delete(dict, "key")
dict.keys(dict)
dict.values(dict)
```

## String

```gleam
// Operations
string.length("hello")
string.lowercase("HELLO")
string.uppercase("hello")
string.trim("  hello  ")
string.split("a,b,c", ",")
string.join(["a", "b"], ",")
string.contains("hello", "ell")
string.starts_with("hello", "hel")
string.replace("hello", "l", "L")
```

## Int and Float

```gleam
// Int operations
int.to_string(42)
int.parse("42")
int.max(10, 20)

// Float operations
float.to_string(3.14)
float.parse("3.14")
float.floor(3.7)
float.ceiling(3.2)
float.absolute_value(-5.0)

// Comparison (note the dot!)
3.14 <. 2.71  // Float comparison
3 < 2         // Int comparison
```

## FFI (Foreign Function Interface)

```gleam
// Declare external function
@external(javascript, "./my_ffi.mjs", "my_function")
pub fn my_function(input: String) -> Int

// JavaScript side (my_ffi.mjs)
export function my_function(input) {
  return input.length;
}
```

## Testing

```gleam
import gleeunit
import gleeunit/should

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn my_test() {
  1 + 1 |> should.equal(2)
}
```

## Common Patterns

### Builder Pattern

```gleam
pub fn new() -> Builder {
  Builder(field1: "", field2: 0)
}

pub fn with_field1(builder: Builder, value: String) -> Builder {
  Builder(..builder, field1: value)
}

pub fn build(builder: Builder) -> Result(Final, Error) {
  Ok(Final(..builder))
}
```

### State Machine

```gleam
pub fn transition(state: State, event: Event) -> State {
  case state, event {
    Idle, Start -> Running
    Running, Stop -> Stopped
    _, _ -> state
  }
}
```

### Error Accumulation

```gleam
pub fn validate(input: Input) -> Result(Output, List(Error)) {
  let errors = []
  let errors = case validate_name(input.name) {
    Ok(_) -> errors
    Error(e) -> [e, ..errors]
  }
  // ... more validations
  case errors {
    [] -> Ok(output)
    _ -> Error(errors)
  }
}
```

## Quick Reference

| Task | Code |
|------|------|
| Define type | `pub type T { ... }` |
| Define function | `pub fn name(args) -> T { ... }` |
| Pattern match | `case value { ... }` |
| Create list | `[1, 2, 3]` |
| Create dict | `dict.from_list([#("k", "v")])` |
| Handle option | `option.unwrap(opt, default)` |
| Handle result | `result.map(res, fn)` |
| Pipe | `value \|> function()` |
| FFI | `@external(javascript, ...)` |
| Test | `value \|> should.equal(expected)` |
