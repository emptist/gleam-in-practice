# Chapter 12: JSON Schema Validation - A Case Study

> "841 lines of type-safe validation that would be 2,500+ lines in TypeScript."
> 
> — TraeNuPI statistics

## The Problem

JSON Schema validation is complex:
- Multiple schema types (string, number, object, array, etc.)
- Constraints (minLength, maximum, pattern, etc.)
- Composition (allOf, anyOf, oneOf, not)
- References ($ref)
- Error accumulation

## The Solution: schema.gleam

### Core Types

```gleam
pub type Schema {
  NullSchema
  BooleanSchema
  NumberSchema(NumberConstraints)
  StringSchema(StringConstraints)
  ArraySchema(ArrayConstraints)
  ObjectSchema(ObjectConstraints)
  AllOf(schemas: List(Schema))
  AnyOf(schemas: List(Schema))
  OneOf(schemas: List(Schema))
  Not(schema: Schema)
  Ref(uri: String)
  Enum(values: List(JsonValue))
  Const(value: JsonValue)
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

pub type ArrayConstraints {
  ArrayConstraints(
    items: Option(Schema),
    min_items: Option(Int),
    max_items: Option(Int),
    unique_items: Bool,
  )
}

pub type ObjectConstraints {
  ObjectConstraints(
    properties: Dict(String, Schema),
    required: List(String),
    additional_properties: Option(Schema),
    pattern_properties: Dict(String, Schema),
    min_properties: Option(Int),
    max_properties: Option(Int),
  )
}
```

### Validation Function

```gleam
pub fn validate(schema: Schema, value: JsonValue) 
    -> Result(JsonValue, List(ValidationError)) {
  case schema, value {
    NullSchema, JsonNull -> Ok(JsonNull)
    NullSchema, _ -> Error([TypeMismatch("null", json_type(value))])
    
    BooleanSchema, JsonBool(_) -> Ok(value)
    BooleanSchema, _ -> Error([TypeMismatch("boolean", json_type(value))])
    
    NumberSchema(constraints), JsonNumber(n) -> 
      validate_number(constraints, n, value)
    NumberSchema(_), _ -> 
      Error([TypeMismatch("number", json_type(value))])
    
    StringSchema(constraints), JsonString(s) -> 
      validate_string(constraints, s, value)
    StringSchema(_), _ -> 
      Error([TypeMismatch("string", json_type(value))])
    
    ArraySchema(constraints), JsonArray(items) -> 
      validate_array(constraints, items, value)
    ArraySchema(_), _ -> 
      Error([TypeMismatch("array", json_type(value))])
    
    ObjectSchema(constraints), JsonObject(obj) -> 
      validate_object(constraints, obj, value)
    ObjectSchema(_), _ -> 
      Error([TypeMismatch("object", json_type(value))])
    
    AllOf(schemas), _ -> validate_all_of(schemas, value)
    AnyOf(schemas), _ -> validate_any_of(schemas, value)
    OneOf(schemas), _ -> validate_one_of(schemas, value)
    Not(schema), _ -> validate_not(schema, value)
    Ref(uri), _ -> validate_ref(uri, value)
    Enum(values), _ -> validate_enum(values, value)
    Const(expected), _ -> validate_const(expected, value)
  }
}
```

### Number Validation

```gleam
fn validate_number(
  constraints: NumberConstraints,
  n: Float,
  value: JsonValue,
) -> Result(JsonValue, List(ValidationError)) {
  let errors = []
  
  let errors = case constraints.minimum {
    Some(min) if n <. min -> [MinimumViolation(n, min), ..errors]
    _ -> errors
  }
  
  let errors = case constraints.maximum {
    Some(max) if n >. max -> [MaximumViolation(n, max), ..errors]
    _ -> errors
  }
  
  let errors = case constraints.exclusive_minimum {
    Some(min) if n <=. min -> [ExclusiveMinimumViolation(n, min), ..errors]
    _ -> errors
  }
  
  let errors = case constraints.exclusive_maximum {
    Some(max) if n >=. max -> [ExclusiveMaximumViolation(n, max), ..errors]
    _ -> errors
  }
  
  let errors = case constraints.multiple_of {
    Some(divisor) -> {
      let remainder = n -. divisor *. float.floor(n /. divisor)
      case float.absolute_value(remainder) <. 0.0001 {
        True -> errors
        False -> [MultipleOfViolation(n, divisor), ..errors]
      }
    }
    None -> errors
  }
  
  case errors {
    [] -> Ok(value)
    _ -> Error(errors)
  }
}
```

### String Validation

```gleam
fn validate_string(
  constraints: StringConstraints,
  s: String,
  value: JsonValue,
) -> Result(JsonValue, List(ValidationError)) {
  let errors = []
  let len = string.length(s)
  
  let errors = case constraints.min_length {
    Some(min) if len < min -> [MinLengthViolation(len, min), ..errors]
    _ -> errors
  }
  
  let errors = case constraints.max_length {
    Some(max) if len > max -> [MaxLengthViolation(len, max), ..errors]
    _ -> errors
  }
  
  let errors = case constraints.pattern {
    Some(pattern) -> {
      case regex.matches(pattern, s) {
        Ok(matches) -> {
          case list.any(matches, fn(m) { m }) {
            True -> errors
            False -> [PatternMismatch(s, pattern), ..errors]
          }
        }
        Error(_) -> [InvalidPattern(pattern), ..errors]
      }
    }
    None -> errors
  }
  
  let errors = case constraints.format {
    Some(format) -> validate_format(format, s, errors)
    None -> errors
  }
  
  case errors {
    [] -> Ok(value)
    _ -> Error(errors)
  }
}
```

### Object Validation

```gleam
fn validate_object(
  constraints: ObjectConstraints,
  obj: Dict(String, JsonValue),
  value: JsonValue,
) -> Result(JsonValue, List(ValidationError)) {
  let errors = []
  let keys = dict.keys(obj)
  
  let errors = case constraints.min_properties {
    Some(min) if dict.size(obj) < min -> 
      [MinPropertiesViolation(dict.size(obj), min), ..errors]
    _ -> errors
  }
  
  let errors = case constraints.max_properties {
    Some(max) if dict.size(obj) > max -> 
      [MaxPropertiesViolation(dict.size(obj), max), ..errors]
    _ -> errors
  }
  
  let errors = 
    constraints.required
    |> list.fold(errors, fn(errs, required_key) {
      case dict.has_key(obj, required_key) {
        True -> errs
        False -> [RequiredFieldMissing(required_key), ..errs]
      }
    })
  
  let property_errors = 
    dict.to_list(constraints.properties)
    |> list.flat_map(fn(pair) {
      let #(key, schema) = pair
      case dict.get(obj, key) {
        Ok(prop_value) -> {
          case validate(schema, prop_value) {
            Ok(_) -> []
            Error(e) -> 
              e |> list.map(fn(err) { PropertyError(key, err) })
          }
        }
        Error(_) -> []
      }
    })
  
  let additional_errors = 
    keys
    |> list.filter(fn(key) { 
      !dict.has_key(constraints.properties, key) 
    })
    |> list.flat_map(fn(key) {
      case constraints.additional_properties {
        Some(schema) -> {
          case dict.get(obj, key) {
            Ok(prop_value) -> {
              case validate(schema, prop_value) {
                Ok(_) -> []
                Error(e) -> 
                  e |> list.map(fn(err) { PropertyError(key, err) })
              }
            }
            Error(_) -> []
          }
        }
        None -> [AdditionalFieldDisallowed(key)]
      }
    })
  
  let all_errors = errors ++ property_errors ++ additional_errors
  
  case all_errors {
    [] -> Ok(value)
    _ -> Error(all_errors)
  }
}
```

### Composition Validators

```gleam
fn validate_all_of(
  schemas: List(Schema),
  value: JsonValue,
) -> Result(JsonValue, List(ValidationError)) {
  let results = 
    schemas
    |> list.map(fn(schema) { validate(schema, value) })
  
  let errors = 
    results
    |> list.filter_map(fn(r) {
      case r {
        Error(e) -> Some(e)
        Ok(_) -> None
      }
    })
    |> list.flatten()
  
  case errors {
    [] -> Ok(value)
    _ -> Error(errors)
  }
}

fn validate_any_of(
  schemas: List(Schema),
  value: JsonValue,
) -> Result(JsonValue, List(ValidationError)) {
  let results = 
    schemas
    |> list.map(fn(schema) { validate(schema, value) })
  
  let has_valid = 
    results
    |> list.any(fn(r) {
      case r {
        Ok(_) -> True
        Error(_) -> False
      }
    })
  
  case has_valid {
    True -> Ok(value)
    False -> {
      let all_errors = 
        results
        |> list.filter_map(fn(r) {
          case r {
            Error(e) -> Some(e)
            Ok(_) -> None
          }
        })
        |> list.flatten()
      Error([AnyOfFailed(all_errors)])
    }
  }
}

fn validate_one_of(
  schemas: List(Schema),
  value: JsonValue,
) -> Result(JsonValue, List(ValidationError)) {
  let results = 
    schemas
    |> list.map(fn(schema) { validate(schema, value) })
  
  let valid_count = 
    results
    |> list.filter(fn(r) {
      case r {
        Ok(_) -> True
        Error(_) -> False
      }
    })
    |> list.length()
  
  case valid_count {
    1 -> Ok(value)
    0 -> Error([OneOfNoMatch])
    _ -> Error([OneOfMultipleMatch(valid_count)])
  }
}
```

## Key Design Decisions

### 1. Error Accumulation

```gleam
pub type ValidationError {
  TypeMismatch(expected: String, actual: String)
  MinimumViolation(value: Float, minimum: Float)
  MaximumViolation(value: Float, maximum: Float)
  MinLengthViolation(length: Int, minimum: Int)
  MaxLengthViolation(length: Int, maximum: Int)
  PatternMismatch(input: String, pattern: String)
  RequiredFieldMissing(field: String)
  AdditionalFieldDisallowed(field: String)
  PropertyError(property: String, error: ValidationError)
  AnyOfFailed(errors: List(ValidationError))
  OneOfNoMatch
  OneOfMultipleMatch(count: Int)
}
```

### 2. Schema Builder

```gleam
pub fn string() -> Schema {
  StringSchema(StringConstraints(
    min_length: None,
    max_length: None,
    pattern: None,
    format: None,
  ))
}

pub fn with_min_length(schema: Schema, min: Int) -> Schema {
  case schema {
    StringSchema(c) -> StringSchema(StringConstraints(..c, min_length: Some(min)))
    _ -> schema
  }
}

pub fn with_max_length(schema: Schema, max: Int) -> Schema {
  case schema {
    StringSchema(c) -> StringSchema(StringConstraints(..c, max_length: Some(max)))
    _ -> schema
  }
}

pub fn with_pattern(schema: Schema, pattern: String) -> Schema {
  case schema {
    StringSchema(c) -> StringSchema(StringConstraints(..c, pattern: Some(pattern)))
    _ -> schema
  }
}
```

### 3. Usage Example

```gleam
let user_schema = 
  object()
  |> with_property("name", string() |> with_min_length(1) |> with_max_length(100))
  |> with_property("email", string() |> with_format("email"))
  |> with_property("age", number() |> with_minimum(0.0) |> with_maximum(150.0))
  |> with_required(["name", "email"])

case validate(user_schema, json_value) {
  Ok(_) -> io.println("Valid!")
  Error(errors) -> {
    errors
    |> list.each(fn(e) { io.println(error_to_string(e)) })
  }
}
```

## Summary

| Metric | Value |
|--------|-------|
| Total lines | 841 |
| Schema types | 12 |
| Constraint types | 4 |
| Error types | 15+ |
| Test coverage | 343 tests |

## Key Takeaways

1. **Pattern matching eliminates conditionals** - Each schema type is one case
2. **Error accumulation is natural** - List of errors, not exceptions
3. **Schema builders are fluent** - Chain methods for readability
4. **Type safety catches bugs** - Impossible to create invalid schemas
5. **Composition is powerful** - allOf, anyOf, oneOf built from primitives

## Next Steps

In **Chapter 13**, we'll explore:
- JSON Path query language
- 442 lines of query implementation
- Parsing and evaluation strategies

---

*Continue to [Chapter 13: JSON Path Query Language Case Study](./chapter-13.md)*
