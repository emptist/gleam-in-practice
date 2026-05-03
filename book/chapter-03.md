# Chapter 3: Working with JSON

> "JSON is the lingua franca of modern software. Handle it with care."
> 
> — Every API developer ever

## Building a JSON Parser from Scratch

One of the best ways to understand Gleam's pattern matching is to build a JSON parser. Let's see how TraeNuPI's `jsonx.gleam` handles this.

### The JSON Type

First, we define our JSON type:

```gleam
pub type JsonValue {
  JsonNull
  JsonBool(Bool)
  JsonNumber(Float)
  JsonString(String)
  JsonArray(List(JsonValue))
  JsonObject(Dict(String, JsonValue))
}
```

Compare this to TypeScript:

```typescript
// TypeScript - runtime type checking needed
type JsonValue = 
  | null 
  | boolean 
  | number 
  | string 
  | JsonValue[] 
  | { [key: string]: JsonValue };

// No compile-time guarantees!
const data: JsonValue = JSON.parse(input); // any at runtime
```

### JSON Encoding

**TypeScript:**
```typescript
function encodeJson(value: unknown): string {
  return JSON.stringify(value);
}

// No type safety
encodeJson(undefined); // Returns undefined (not valid JSON!)
encodeJson(() => {});  // Returns undefined
encodeJson(BigInt(123)); // Throws TypeError
```

**Gleam:**
```gleam
pub fn encode(value: JsonValue) -> String {
  case value {
    JsonNull -> "null"
    JsonBool(True) -> "true"
    JsonBool(False) -> "false"
    JsonNumber(n) -> float.to_string(n)
    JsonString(s) -> encode_string(s)
    JsonArray(arr) -> encode_array(arr)
    JsonObject(obj) -> encode_object(obj)
  }
}

fn encode_string(s: String) -> String {
  let escaped = 
    s
    |> string.replace("\\", "\\\\")
    |> string.replace("\"", "\\\"")
    |> string.replace("\n", "\\n")
    |> string.replace("\r", "\\r")
    |> string.replace("\t", "\\t")
  "\"" <> escaped <> "\""
}

fn encode_array(arr: List(JsonValue)) -> String {
  let encoded = 
    arr
    |> list.map(encode)
    |> string.join(", ")
  "[" <> encoded <> "]"
}

fn encode_object(obj: Dict(String, JsonValue)) -> String {
  let pairs = 
    obj
    |> dict.to_list()
    |> list.map(fn(key, value) {
      encode_string(key) <> ": " <> encode(value)
    })
    |> string.join(", ")
  "{" <> pairs <> "}"
}
```

### JSON Decoding

This is where Gleam shines. Let's build a parser:

```gleam
pub type JsonError {
  UnexpectedType(expected: String, found: String)
  MissingField(field: String)
  InvalidJson(message: String)
  IndexOutOfBounds(index: Int, length: Int)
}

pub type Parser {
  Parser(input: String, position: Int, length: Int)
}

pub fn parse(input: String) -> Result(JsonValue, JsonError) {
  let parser = Parser(input: input, position: 0, length: string.length(input))
  use parser <- result.try(skip_whitespace(parser))
  use value, parser <- result.try(parse_value(parser))
  use parser <- result.try(skip_whitespace(parser))
  
  case parser.position == parser.length {
    True -> Ok(value)
    False -> Error(InvalidJson("Unexpected characters after JSON"))
  }
}

fn parse_value(parser: Parser) -> Result(#(JsonValue, Parser), JsonError) {
  case peek_char(parser) {
    Some('n') -> parse_null(parser)
    Some('t') -> parse_true(parser)
    Some('f') -> parse_false(parser)
    Some('"') -> parse_string(parser)
    Some(c) if c == '-' || is_digit(c) -> parse_number(parser)
    Some('[') -> parse_array(parser)
    Some('{') -> parse_object(parser)
    Some(c) -> Error(InvalidJson("Unexpected character: " <> string.from_char(c)))
    None -> Error(InvalidJson("Unexpected end of input"))
  }
}

fn parse_null(parser: Parser) -> Result(#(JsonValue, Parser), JsonError) {
  case string.slice(parser.input, parser.position, 4) {
    "null" -> Ok(#(JsonNull, advance(parser, 4)))
    _ -> Error(InvalidJson("Expected 'null'"))
  }
}

fn parse_true(parser: Parser) -> Result(#(JsonValue, Parser), JsonError) {
  case string.slice(parser.input, parser.position, 4) {
    "true" -> Ok(#(JsonBool(True), advance(parser, 4)))
    _ -> Error(InvalidJson("Expected 'true'"))
  }
}

fn parse_false(parser: Parser) -> Result(#(JsonValue, Parser), JsonError) {
  case string.slice(parser.input, parser.position, 5) {
    "false" -> Ok(#(JsonBool(False), advance(parser, 5)))
    _ -> Error(InvalidJson("Expected 'false'"))
  }
}
```

### Pattern Matching for Number Parsing

```gleam
fn parse_number(parser: Parser) -> Result(#(JsonValue, Parser), JsonError) {
  let start = parser.position
  let parser = case peek_char(parser) {
    Some('-') -> advance(parser, 1)
    _ -> parser
  }
  
  use parser <- result.try(parse_integer_part(parser))
  let parser = parse_fraction_part(parser)
  let parser = parse_exponent_part(parser)
  
  let num_str = string.slice(parser.input, start, parser.position - start)
  
  case float.parse(num_str) {
    Ok(n) -> Ok(#(JsonNumber(n), parser))
    Error(_) -> Error(InvalidJson("Invalid number: " <> num_str))
  }
}

fn parse_integer_part(parser: Parser) -> Result(Parser, JsonError) {
  case peek_char(parser) {
    Some('0') -> Ok(advance(parser, 1))
    Some(c) if is_digit(c) -> parse_digits(parser)
    _ -> Error(InvalidJson("Expected digit"))
  }
}

fn parse_digits(parser: Parser) -> Result(Parser, JsonError) {
  case peek_char(parser) {
    Some(c) if is_digit(c) -> parse_digits(advance(parser, 1))
    _ -> Ok(parser)
  }
}

fn is_digit(char: Char) -> Bool {
  char >= '0' && char <= '9'
}
```

---

## Type-Safe JSON Handling

### The TypeScript Problem

```typescript
interface User {
  id: string;
  name: string;
  email?: string;
}

// TypeScript's JSON.parse returns any
const response = await fetch('/api/user/123');
const user: User = await response.json(); // No validation!

// Runtime errors possible:
console.log(user.name.toUpperCase()); // What if name is missing?
console.log(user.email.toLowerCase()); // What if email is undefined?
```

### The Gleam Solution

```gleam
pub type User {
  User(id: String, name: String, email: Option(String))
}

pub fn decode_user(json: JsonValue) -> Result(User, JsonError) {
  use obj <- result.try(json_to_object(json))
  
  use id <- result.try(get_string(obj, "id"))
  use name <- result.try(get_string(obj, "name"))
  let email = get_optional_string(obj, "email")
  
  Ok(User(id: id, name: name, email: email))
}

fn get_string(obj: Dict(String, JsonValue), field: String) -> Result(String, JsonError) {
  case dict.get(obj, field) {
    Ok(JsonString(s)) -> Ok(s)
    Ok(other) -> Error(UnexpectedType("String", json_value_type(other)))
    Error(_) -> Error(MissingField(field))
  }
}

fn get_optional_string(obj: Dict(String, JsonValue), field: String) -> Option(String) {
  case dict.get(obj, field) {
    Ok(JsonString(s)) -> Some(s)
    Ok(JsonNull) -> None
    _ -> None
  }
}
```

### Decoder Combinators

Build complex decoders from simple ones:

```gleam
pub type Decoder(a) {
  Decoder(fn(JsonValue) -> Result(a, JsonError))
}

pub fn decode_string() -> Decoder(String) {
  Decoder(fn(json) {
    case json {
      JsonString(s) -> Ok(s)
      _ -> Error(UnexpectedType("String", json_value_type(json)))
    }
  })
}

pub fn decode_int() -> Decoder(Int) {
  Decoder(fn(json) {
    case json {
      JsonNumber(n) -> Ok(float.round(n))
      _ -> Error(UnexpectedType("Int", json_value_type(json)))
    }
  })
}

pub fn decode_list(decoder: Decoder(a)) -> Decoder(List(a)) {
  Decoder(fn(json) {
    case json {
      JsonArray(arr) -> {
        arr
        |> list.map(fn(item) { run_decoder(decoder, item) })
        |> result.all
      }
      _ -> Error(UnexpectedType("Array", json_value_type(json)))
    }
  })
}

pub fn decode_field(name: String, decoder: Decoder(a)) -> Decoder(a) {
  Decoder(fn(json) {
    use obj <- result.try(json_to_object(json))
    case dict.get(obj, name) {
      Ok(value) -> run_decoder(decoder, value)
      Error(_) -> Error(MissingField(name))
    }
  })
}

pub fn run_decoder(decoder: Decoder(a), json: JsonValue) -> Result(a, JsonError) {
  let Decoder(decode_fn) = decoder
  decode_fn(json)
}
```

### Using Decoders

```gleam
pub fn user_decoder() -> Decoder(User) {
  use id <- decode_field("id", decode_string())
  use name <- decode_field("name", decode_string())
  let email = decode_optional(decode_field("email", decode_string()))
  
  Decoder(fn(json) {
    Ok(User(id: id, name: name, email: email))
  })
}

pub fn decode_users(json: JsonValue) -> Result(List(User), JsonError) {
  run_decoder(decode_list(user_decoder()), json)
}
```

---

## JSON Schema Validation

TraeNuPI's `schema.gleam` implements JSON Schema validation in 841 lines. Here's a taste:

### Schema Types

```gleam
pub type Schema {
  NullSchema
  BoolSchema
  NumberSchema(NumberConstraints)
  StringSchema(StringConstraints)
  ArraySchema(ArrayConstraints)
  ObjectSchema(ObjectConstraints)
  // ... more types
}

pub type NumberConstraints {
  NumberConstraints(
    minimum: Option(Float),
    maximum: Option(Float),
    exclusive_minimum: Option(Float),
    exclusive_maximum: Option(Float),
    multiple_of: Option(Float),
  )
}

pub type StringConstraints {
  StringConstraints(
    min_length: Option(Int),
    max_length: Option(Int),
    pattern: Option(String),
    format: Option(String),
  )
}
```

### Validation Function

```gleam
pub fn validate(schema: Schema, value: JsonValue) -> Result(Nil, ValidationError) {
  case schema, value {
    NullSchema, JsonNull -> Ok(Nil)
    NullSchema, _ -> Error(ExpectedType("null", json_value_type(value)))
    
    BoolSchema, JsonBool(_) -> Ok(Nil)
    BoolSchema, _ -> Error(ExpectedType("boolean", json_value_type(value)))
    
    NumberSchema(constraints), JsonNumber(n) -> validate_number(constraints, n)
    NumberSchema(_), _ -> Error(ExpectedType("number", json_value_type(value)))
    
    StringSchema(constraints), JsonString(s) -> validate_string(constraints, s)
    StringSchema(_), _ -> Error(ExpectedType("string", json_value_type(value)))
    
    ArraySchema(constraints), JsonArray(arr) -> validate_array(constraints, arr)
    ArraySchema(_), _ -> Error(ExpectedType("array", json_value_type(value)))
    
    ObjectSchema(constraints), JsonObject(obj) -> validate_object(constraints, obj)
    ObjectSchema(_), _ -> Error(ExpectedType("object", json_value_type(value)))
  }
}

fn validate_number(constraints: NumberConstraints, n: Float) -> Result(Nil, ValidationError) {
  use _ <- result.try(validate_minimum(constraints.minimum, n))
  use _ <- result.try(validate_maximum(constraints.maximum, n))
  use _ <- result.try(validate_exclusive_minimum(constraints.exclusive_minimum, n))
  use _ <- result.try(validate_exclusive_maximum(constraints.exclusive_maximum, n))
  use _ <- result.try(validate_multiple_of(constraints.multiple_of, n))
  Ok(Nil)
}

fn validate_minimum(min: Option(Float), n: Float) -> Result(Nil, ValidationError) {
  case min {
    Some(min_val) if n < min_val -> Error(NumberTooSmall(n, min_val))
    _ -> Ok(Nil)
  }
}
```

---

## Real Example: jsonx.gleam

The full implementation in TraeNuPI is 601 lines. Here's a summary:

| Function | Lines | Purpose |
|----------|-------|---------|
| `parse` | ~50 | Main entry point |
| `parse_value` | ~30 | Dispatch to type parsers |
| `parse_string` | ~80 | String with escapes |
| `parse_number` | ~60 | Int/float parsing |
| `parse_array` | ~40 | Array parsing |
| `parse_object` | ~50 | Object parsing |
| `encode` | ~60 | JSON encoding |
| Type helpers | ~100 | Type conversions |
| Decoder combinators | ~130 | Decoder building |

### Key Insights

1. **Pattern matching eliminates nested conditionals** - Each JSON type is one case
2. **Result type forces error handling** - Can't forget to handle parse errors
3. **Parser state is explicit** - No hidden mutable state
4. **Testing is easy** - Each function is pure

---

## Practical Exercise

Build a JSON Path query function:

```gleam
pub fn query(json: JsonValue, path: String) -> Result(JsonValue, JsonError) {
  // "$.store.books[0].title"
  // Parse path and navigate JSON
}
```

**Solution sketch:**

```gleam
pub type PathSegment {
  Root
  Field(String)
  Index(Int)
}

pub fn parse_path(path: String) -> Result(List(PathSegment), String) {
  case path {
    "$" -> Ok([Root])
    _ -> {
      path
      |> string.split(".")
      |> list.map(parse_segment)
      |> result.all
    }
  }
}

pub fn query(json: JsonValue, path: String) -> Result(JsonValue, JsonError) {
  use segments <- result.try(parse_path(path))
  navigate(json, segments)
}

fn navigate(json: JsonValue, segments: List(PathSegment)) -> Result(JsonValue, JsonError) {
  case segments {
    [] -> Ok(json)
    [Root, ..rest] -> navigate(json, rest)
    [Field(name), ..rest] -> {
      case json {
        JsonObject(obj) -> {
          case dict.get(obj, name) {
            Ok(value) -> navigate(value, rest)
            Error(_) -> Error(MissingField(name))
          }
        }
        _ -> Error(UnexpectedType("Object", json_value_type(json)))
      }
    }
    [Index(idx), ..rest] -> {
      case json {
        JsonArray(arr) -> {
          case list.at(arr, idx) {
            Ok(value) -> navigate(value, rest)
            Error(_) -> Error(IndexOutOfBounds(idx, list.length(arr)))
          }
        }
        _ -> Error(UnexpectedType("Array", json_value_type(json)))
      }
    }
  }
}
```

---

## Summary

| Aspect | TypeScript | Gleam |
|--------|------------|-------|
| JSON parsing | `JSON.parse()` returns any | Explicit parser with types |
| Type safety | Runtime validation needed | Compile-time guarantees |
| Error handling | Try/catch | Result type |
| Decoder pattern | Manual | Composable |
| Schema validation | External libraries | Built-in (841 lines) |

## Key Takeaways

1. **Pattern matching makes parsing elegant** - Each case is explicit
2. **Result type prevents runtime errors** - Must handle parse errors
3. **Decoder combinators are reusable** - Build complex from simple
4. **Schema validation is type-safe** - 841 lines of production code
5. **No null means no null pointer exceptions** - Option type everywhere

## Next Steps

In **Chapter 4**, we'll explore:
- Calling JavaScript from Gleam via FFI
- Calling Gleam from TypeScript
- Building a bridge module
- Real example: gleam-bridge.ts

---

*Continue to [Chapter 4: FFI - JavaScript Integration](./chapter-04.md)*
