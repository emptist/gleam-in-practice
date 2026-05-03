# Chapter 2: Types and Pattern Matching

> "Pattern matching is not just syntax sugar. It's a different way of thinking about data."
> 
> — From a TypeScript convert

## Custom Types vs TypeScript Interfaces

### TypeScript Interfaces

TypeScript interfaces are flexible but have limitations:

```typescript
// TypeScript
interface User {
  id: string;
  name: string;
  role: 'admin' | 'user' | 'guest';
  email?: string;
}

interface AdminUser extends User {
  role: 'admin';
  permissions: string[];
}

// Runtime check needed
function isAdmin(user: User): user is AdminUser {
  return user.role === 'admin';
}

// Type guard needed
const user: User = getUser();
if (isAdmin(user)) {
  console.log(user.permissions); // Only now TypeScript knows
}
```

### Gleam Custom Types

Gleam types are explicit and compiler-enforced:

```gleam
// Gleam
pub type Role {
  Admin
  User
  Guest
}

pub type User {
  User(id: String, name: String, role: Role, email: Option(String))
  AdminUser(id: String, name: String, email: Option(String), permissions: List(String))
}

// No runtime check needed - pattern matching handles it
pub fn get_permissions(user: User) -> List(String) {
  case user {
    AdminUser(permissions: perms, ..) -> perms
    User(role: Admin, ..) -> ["read", "write"] // Admin role
    _ -> [] // Others
  }
}
```

### Key Differences

| Feature | TypeScript | Gleam |
|---------|------------|-------|
| Union types | String literals | Custom type variants |
| Optional fields | `email?: string` | `email: Option(String)` |
| Type guards | Manual functions | Pattern matching |
| Runtime checks | Required | Compile-time |
| Discriminated unions | Possible | Natural |

---

## Pattern Matching: The Superpower

### Basic Pattern Matching

**TypeScript:**
```typescript
function getStatusMessage(status: string): string {
  switch (status) {
    case 'pending':
      return 'Waiting...';
    case 'running':
      return 'In progress...';
    case 'done':
      return 'Completed!';
    case 'failed':
      return 'Error occurred';
    default:
      return 'Unknown status';
  }
}
```

**Gleam:**
```gleam
pub fn get_status_message(status: Status) -> String {
  case status {
    Pending -> "Waiting..."
    Running -> "In progress..."
    Done -> "Completed!"
    Failed -> "Error occurred"
  }
}
```

Notice: No default case needed! The compiler ensures all cases are covered.

### Pattern Matching with Data

**TypeScript:**
```typescript
interface Result {
  type: 'success' | 'error';
  value?: string;
  error?: string;
}

function handleResult(result: Result): string {
  if (result.type === 'success' && result.value) {
    return `Success: ${result.value}`;
  } else if (result.type === 'error' && result.error) {
    return `Error: ${result.error}`;
  }
  return 'Unknown result';
}
```

**Gleam:**
```gleam
pub type Result {
  Success(value: String)
  Error(error: String)
}

pub fn handle_result(result: Result) -> String {
  case result {
    Success(value: v) -> "Success: " <> v
    Error(error: e) -> "Error: " <> e
  }
}
```

### Destructuring Patterns

**TypeScript:**
```typescript
interface Point { x: number; y: number; }

function describePoint(point: Point): string {
  const { x, y } = point;
  if (x === 0 && y === 0) return "Origin";
  if (x === 0) return `On Y-axis at ${y}`;
  if (y === 0) return `On X-axis at ${x}`;
  return `At (${x}, ${y})`;
}
```

**Gleam:**
```gleam
pub type Point {
  Point(x: Int, y: Int)
}

pub fn describe_point(point: Point) -> String {
  case point {
    Point(0, 0) -> "Origin"
    Point(0, y) -> "On Y-axis at " <> int.to_string(y)
    Point(x, 0) -> "On X-axis at " <> int.to_string(x)
    Point(x, y) -> "At (" <> int.to_string(x) <> ", " <> int.to_string(y) <> ")"
  }
}
```

### Guard Clauses

**TypeScript:**
```typescript
function categorizeAge(age: number): string {
  if (age < 0) return "Invalid";
  if (age < 13) return "Child";
  if (age < 20) return "Teenager";
  if (age < 65) return "Adult";
  return "Senior";
}
```

**Gleam:**
```gleam
pub fn categorize_age(age: Int) -> String {
  case age {
    a if a < 0 -> "Invalid"
    a if a < 13 -> "Child"
    a if a < 20 -> "Teenager"
    a if a < 65 -> "Adult"
    _ -> "Senior"
  }
}
```

### Multiple Subject Pattern Matching

This is where Gleam truly shines:

**TypeScript:**
```typescript
function compare(a: number, b: number): string {
  if (a === b) return "Equal";
  if (a < b) return "Less than";
  return "Greater than";
}

function handleCommand(cmd: string, args: string[]): string {
  if (cmd === "create" && args.length === 1) {
    return `Creating ${args[0]}`;
  } else if (cmd === "delete" && args.length === 1) {
    return `Deleting ${args[0]}`;
  } else if (cmd === "list" && args.length === 0) {
    return "Listing all";
  }
  return "Unknown command";
}
```

**Gleam:**
```gleam
pub fn compare(a: Int, b: Int) -> String {
  case a, b {
    x, y if x == y -> "Equal"
    x, y if x < y -> "Less than"
    _, _ -> "Greater than"
  }
}

pub fn handle_command(cmd: String, args: List(String)) -> String {
  case cmd, args {
    "create", [name] -> "Creating " <> name
    "delete", [id] -> "Deleting " <> id
    "list", [] -> "Listing all"
    _, _ -> "Unknown command"
  }
}
```

---

## Result Type: Errors Done Right

### The Problem with Exceptions

**TypeScript:**
```typescript
function divide(a: number, b: number): number {
  if (b === 0) {
    throw new Error("Division by zero");
  }
  return a / b;
}

// Caller must remember to catch
try {
  const result = divide(10, 0);
  console.log(result);
} catch (e) {
  console.error(e);
}
```

### The Gleam Way

```gleam
pub type DivisionError {
  DivisionByZero
}

pub fn divide(a: Float, b: Float) -> Result(Float, DivisionError) {
  case b {
    0.0 -> Error(DivisionByZero)
    _ -> Ok(a /. b)
  }
}

// Caller MUST handle the error
case divide(10.0, 0.0) {
  Ok(result) -> io.debug(result)
  Error(DivisionByZero) -> io.debug("Cannot divide by zero")
}
```

### Result Combinators

Gleam provides powerful combinators for working with Results:

```gleam
import gleam/result.{map, then, try_map}

pub fn safe_divide(a: Float, b: Float) -> Result(Float, String) {
  case b {
    0.0 -> Error("Division by zero")
    _ -> Ok(a /. b)
  }
}

pub fn calculate(a: Float, b: Float, c: Float) -> Result(Float, String) {
  use first <- result.try(safe_divide(a, b))
  use second <- result.try(safe_divide(first, c))
  Ok(second)
}

// Or with pipe
pub fn calculate_piped(a: Float, b: Float, c: Float) -> Result(Float, String) {
  safe_divide(a, b)
  |> result.try(fn(first) { safe_divide(first, c) })
}
```

### Real Example from TraeNuPI

```gleam
// From jsonx.gleam
pub type JsonError {
  InvalidJson(message: String)
  UnexpectedEnd
  UnexpectedToken(found: String, expected: String)
}

pub fn parse(input: String) -> Result(JsonValue, JsonError) {
  let parser = Parser(input: input, position: 0, length: string.length(input))
  parse_value(parser)
}

pub fn parse_int(input: String) -> Result(Int, JsonError) {
  case parse(input) {
    Ok(JsonNumber(n)) -> 
      case float.truncate(n) == n {
        True -> Ok(float.truncate(n))
        False -> Error(InvalidJson("Not an integer: " <> input))
      }
    Ok(_) -> Error(InvalidJson("Not a number: " <> input))
    Error(e) -> Error(e)
  }
}
```

---

## Option Type: No More Null Checks

### The Billion Dollar Mistake

**TypeScript:**
```typescript
interface User {
  id: string;
  name: string;
  email?: string; // Optional - could be undefined
}

function getEmail(user: User): string {
  return user.email || "No email"; // Safe? Maybe...
}

function sendEmail(user: User): void {
  const email = user.email;
  if (email) {
    // TypeScript knows email is string here
    console.log(`Sending to ${email}`);
  } else {
    console.log("No email address");
  }
}
```

### The Gleam Way

```gleam
pub type User {
  User(id: String, name: String, email: Option(String))
}

pub fn get_email(user: User) -> String {
  case user.email {
    Some(email) -> email
    None -> "No email"
  }
}

pub fn send_email(user: User) -> Nil {
  case user.email {
    Some(email) -> io.debug("Sending to " <> email)
    None -> io.debug("No email address")
  }
}
```

### Option Combinators

```gleam
import gleam/option.{map, unwrap}

pub fn get_email_domain(user: User) -> Option(String) {
  user.email
  |> option.map(fn(email) {
    email
    |> string.split("@")
    |> list.at(1)
    |> option.unwrap("")
  })
}

// Or with pattern matching
pub fn get_email_domain_match(user: User) -> Option(String) {
  case user.email {
    Some(email) -> {
      case string.split(email, "@") {
        [_, domain] -> Some(domain)
        _ -> None
      }
    }
    None -> None
  }
}
```

### Chaining Options

```gleam
pub fn find_user(id: String) -> Option(User) {
  // Database lookup
}

pub fn get_user_email(id: String) -> Option(String) {
  case find_user(id) {
    Some(User(email: Some(email), ..)) -> Some(email)
    Some(User(email: None, ..)) -> None
    None -> None
  }
}

// Or with 'use' syntax
pub fn get_user_email_use(id: String) -> Option(String) {
  use user <- option.try(find_user(id))
  user.email
}
```

---

## Building a Real Validation Module

Let's build a practical validation module that demonstrates all these concepts:

```gleam
// validation.gleam
pub type ValidationError {
  RequiredField(field: String)
  InvalidFormat(field: String, message: String)
  TooShort(field: String, min: Int, actual: Int)
  TooLong(field: String, max: Int, actual: Int)
  InvalidRange(field: String, min: Int, max: Int, actual: Int)
}

pub type ValidationResult(a) {
  Valid(a)
  Invalid(List(ValidationError))
}

pub fn required(field: String, value: Option(String)) -> ValidationResult(String) {
  case value {
    Some(v) if v != "" -> Valid(v)
    Some(_) -> Invalid([RequiredField(field)])
    None -> Invalid([RequiredField(field)])
  }
}

pub fn min_length(field: String, min: Int, value: String) -> ValidationResult(String) {
  let len = string.length(value)
  case len >= min {
    True -> Valid(value)
    False -> Invalid([TooShort(field, min, len)])
  }
}

pub fn max_length(field: String, max: Int, value: String) -> ValidationResult(String) {
  let len = string.length(value)
  case len <= max {
    True -> Valid(value)
    False -> Invalid([TooLong(field, max, len)])
  }
}

pub fn email(field: String, value: String) -> ValidationResult(String) {
  case string.contains(value, "@") && string.contains(value, ".") {
    True -> Valid(value)
    False -> Invalid([InvalidFormat(field, "Must be a valid email")])
  }
}

pub fn combine(results: List(ValidationResult(a))) -> ValidationResult(List(a)) {
  let errors = 
    results
    |> list.filter_map(fn(r) {
      case r {
        Invalid(errs) -> Some(errs)
        Valid(_) -> None
      }
    })
    |> list.flatten()

  case errors {
    [] -> {
      let values = 
        results
        |> list.filter_map(fn(r) {
          case r {
            Valid(v) -> Some(v)
            Invalid(_) -> None
          }
        })
      Valid(values)
    }
    errs -> Invalid(errs)
  }
}

pub fn and_then(
  result: ValidationResult(a),
  next: fn(a) -> ValidationResult(b)
) -> ValidationResult(b) {
  case result {
    Valid(v) -> next(v)
    Invalid(errs) -> Invalid(errs)
  }
}
```

### Using the Validation Module

```gleam
pub type UserInput {
  UserInput(name: Option(String), email: Option(String), age: Int)
}

pub fn validate_user(input: UserInput) -> ValidationResult(User) {
  use name <- and_then(required("name", input.name))
  use name <- and_then(min_length("name", 2, name))
  use email <- and_then(required("email", input.email))
  use email <- and_then(email("email", email))
  
  case input.age >= 0 && input.age < 150 {
    True -> Valid(User(name: name, email: email, age: input.age))
    False -> Invalid([InvalidRange("age", 0, 150, input.age)])
  }
}
```

---

## Summary

| Concept | TypeScript | Gleam |
|---------|------------|-------|
| Custom types | Interface + union | Custom type variants |
| Pattern matching | switch/if | case expressions |
| Null handling | `null` / `undefined` | `Option` type |
| Error handling | try/catch | `Result` type |
| Type guards | Manual functions | Pattern matching |
| Exhaustiveness | Not enforced | Compiler enforced |

## Key Takeaways

1. **Pattern matching eliminates nested conditionals** - Each case is explicit
2. **No null means no null pointer exceptions** - Use Option
3. **Errors are values** - Use Result, not exceptions
4. **The compiler is your friend** - It catches what you miss
5. **Small types lead to big clarity** - Each type has one purpose

## Next Steps

In **Chapter 3**, we'll explore:
- Building a JSON parser from scratch
- Type-safe JSON handling
- JSON Schema validation
- Real example: jsonx.gleam (601 lines)

---

*Continue to [Chapter 3: Working with JSON](./chapter-03.md)*
