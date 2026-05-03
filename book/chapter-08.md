# Chapter 8: Validation

> "Validate early, validate often, and make invalid states unrepresentable."
> 
> — Type-driven development wisdom

## Composable Validators

### The TypeScript Approach

```typescript
// TypeScript - often uses libraries like zod or yup
import { z } from 'zod';

const UserSchema = z.object({
  name: z.string().min(1).max(100),
  email: z.string().email(),
  age: z.number().min(0).max(150).optional(),
});

type User = z.infer<typeof UserSchema>;

const result = UserSchema.safeParse(input);
if (result.success) {
  const user: User = result.data;
} else {
  const errors = result.error.errors;
}
```

### The Gleam Approach

```gleam
pub type Validator(a, e) {
  Validator(validate: fn(a) -> Result(a, List(e)))
}

pub fn validate(validator: Validator(a, e), input: a) -> Result(a, List(e)) {
  validator.validate(input)
}

pub fn string_min(length: Int, error: e) -> Validator(String, e) {
  Validator(fn(input) {
    case string.length(input) >= length {
      True -> Ok(input)
      False -> Error([error])
    }
  })
}

pub fn string_max(length: Int, error: e) -> Validator(String, e) {
  Validator(fn(input) {
    case string.length(input) <= length {
      True -> Ok(input)
      False -> Error([error])
    }
  })
}

pub fn string_email(error: e) -> Validator(String, e) {
  Validator(fn(input) {
    case string.contains(input, "@") {
      True -> Ok(input)
      False -> Error([error])
    }
  })
}
```

---

## Combining Validators

### Sequential Composition (&&)

```gleam
pub fn and(
  first: Validator(a, e),
  second: Validator(a, e),
) -> Validator(a, e) {
  Validator(fn(input) {
    case first.validate(input) {
      Ok(_) -> second.validate(input)
      Error(errors) -> {
        case second.validate(input) {
          Ok(_) -> Error(errors)
          Error(more_errors) -> Error(errors ++ more_errors)
        }
      }
    }
  })
}

// Usage
pub fn valid_name(error: ValidationError) -> Validator(String, ValidationError) {
  string_min(1, error)
  |> and(string_max(100, error))
}
```

### Parallel Composition (||)

```gleam
pub fn or(
  first: Validator(a, e),
  second: Validator(a, e),
) -> Validator(a, e) {
  Validator(fn(input) {
    case first.validate(input) {
      Ok(_) -> Ok(input)
      Error(_) -> second.validate(input)
    }
  })
}

// Usage: Either email or phone
pub fn valid_contact(error: ValidationError) -> Validator(String, ValidationError) {
  string_email(error)
  |> or(string_phone(error))
}
```

---

## Object Validation

### Field Validators

```gleam
pub type User {
  User(name: String, email: String, age: Option(Int))
}

pub type ValidationError {
  NameTooShort
  NameTooLong
  InvalidEmail
  AgeOutOfRange
}

pub fn validate_user(user: User) -> Result(User, List(ValidationError)) {
  let name_errors = 
    valid_name(user.name)
    |> validate(user.name)
    |> errors_to_list()
  
  let email_errors = 
    string_email(InvalidEmail)
    |> validate(user.email)
    |> errors_to_list()
  
  let age_errors = 
    case user.age {
      Some(age) -> {
        case age >= 0 && age <= 150 {
          True -> []
          False -> [AgeOutOfRange]
        }
      }
      None -> []
    }
  
  let all_errors = name_errors ++ email_errors ++ age_errors
  
  case all_errors {
    [] -> Ok(user)
    errors -> Error(errors)
  }
}

fn errors_to_list(result: Result(a, List(e))) -> List(e) {
  case result {
    Ok(_) -> []
    Error(errors) -> errors
  }
}
```

---

## Real Example: schema.gleam

From TraeNuPI's JSON Schema validation (841 lines):

```gleam
// schema.gleam - JSON Schema validation

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

pub type ValidationError {
  TypeMismatch(expected: String, actual: String)
  MinimumViolation(value: Float, minimum: Float)
  MaximumViolation(value: Float, maximum: Float)
  MinLengthViolation(length: Int, minimum: Int)
  MaxLengthViolation(length: Int, maximum: Int)
  PatternMismatch(input: String, pattern: String)
  RequiredFieldMissing(field: String)
  AdditionalFieldDisallowed(field: String)
  EnumViolation(value: String, allowed: List(String))
}

pub fn validate(schema: Schema, value: JsonValue) -> Result(JsonValue, List(ValidationError)) {
  case schema, value {
    NullSchema, JsonNull -> Ok(JsonNull)
    NullSchema, _ -> Error([TypeMismatch("null", json_type(value))])
    
    BooleanSchema, JsonBool(_) -> Ok(value)
    BooleanSchema, _ -> Error([TypeMismatch("boolean", json_type(value))])
    
    NumberSchema(constraints), JsonNumber(n) -> validate_number(constraints, n, value)
    NumberSchema(_), _ -> Error([TypeMismatch("number", json_type(value))])
    
    StringSchema(constraints), JsonString(s) -> validate_string(constraints, s, value)
    StringSchema(_), _ -> Error([TypeMismatch("string", json_type(value))])
    
    ArraySchema(constraints), JsonArray(items) -> validate_array(constraints, items, value)
    ArraySchema(_), _ -> Error([TypeMismatch("array", json_type(value))])
    
    ObjectSchema(constraints), JsonObject(obj) -> validate_object(constraints, obj, value)
    ObjectSchema(_), _ -> Error([TypeMismatch("object", json_type(value))])
    
    AllOf(schemas), _ -> validate_all_of(schemas, value)
    AnyOf(schemas), _ -> validate_any_of(schemas, value)
    OneOf(schemas), _ -> validate_one_of(schemas, value)
    Not(schema), _ -> validate_not(schema, value)
    Ref(uri), _ -> validate_ref(uri, value)
  }
}

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
    Some(min) if n <=. min -> [MinimumViolation(n, min), ..errors]
    _ -> errors
  }
  
  let errors = case constraints.exclusive_maximum {
    Some(max) if n >=. max -> [MaximumViolation(n, max), ..errors]
    _ -> errors
  }
  
  let errors = case constraints.multiple_of {
    Some(divisor) -> {
      let remainder = n -. divisor *. float.floor(n /. divisor)
      case remainder == 0.0 {
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

---

## Error Accumulation

### Collecting All Errors

```gleam
pub type ValidationResult(a, e) {
  Valid(a)
  Invalid(List(e))
}

pub fn combine(
  first: ValidationResult(a, e),
  second: ValidationResult(a, e),
) -> ValidationResult(a, e) {
  case first, second {
    Valid(_), Valid(_) -> first
    Valid(_), Invalid(errors) -> Invalid(errors)
    Invalid(errors), Valid(_) -> Invalid(errors)
    Invalid(e1), Invalid(e2) -> Invalid(e1 ++ e2)
  }
}

pub fn validate_all(
  validators: List(Validator(a, e)),
  input: a,
) -> ValidationResult(a, e) {
  validators
  |> list.map(fn(v) { v.validate(input) })
  |> list.fold(Valid(input), fn(acc, result) {
    case acc, result {
      Valid(_), Ok(_) -> acc
      Valid(_), Error(errors) -> Invalid(errors)
      Invalid(errors), Ok(_) -> Invalid(errors)
      Invalid(e1), Error(e2) -> Invalid(e1 ++ e2)
    }
  })
}
```

---

## Custom Validators

### Business Rule Validation

```gleam
pub type Task {
  Task(title: String, priority: Int, due_date: Option(Int))
}

pub type TaskError {
  TitleEmpty
  TitleTooLong
  PriorityOutOfRange
  DueDateInPast
  DependencyCycle
}

pub fn validate_task(task: Task, now: Int) -> Result(Task, List(TaskError)) {
  let title_errors = validate_title(task.title)
  let priority_errors = validate_priority(task.priority)
  let due_date_errors = validate_due_date(task.due_date, now)
  
  let all_errors = title_errors ++ priority_errors ++ due_date_errors
  
  case all_errors {
    [] -> Ok(task)
    errors -> Error(errors)
  }
}

fn validate_title(title: String) -> List(TaskError) {
  let errors = []
  
  let errors = case string.length(title) < 1 {
    True -> [TitleEmpty, ..errors]
    False -> errors
  }
  
  let errors = case string.length(title) > 200 {
    True -> [TitleTooLong, ..errors]
    False -> errors
  }
  
  errors
}

fn validate_priority(priority: Int) -> List(TaskError) {
  case priority >= 0 && priority <= 10 {
    True -> []
    False -> [PriorityOutOfRange]
  }
}

fn validate_due_date(due_date: Option(Int), now: Int) -> List(TaskError) {
  case due_date {
    Some(date) if date < now -> [DueDateInPast]
    _ -> []
  }
}
```

---

## Integration with TypeScript

### Validation Bridge

```typescript
// validation-bridge.ts
import * as schema from './gleam/traenupi_core/build/dev/javascript/traenupi_core/traenupi_core/schema.mjs';
import { toList } from './gleam/traenupi_core/build/dev/javascript/gleam_stdlib/gleam.mjs';

export class Validator {
  static validateJson(schemaDef: any, value: any): ValidationResult {
    const gleamSchema = this.toGleamSchema(schemaDef);
    const gleamValue = this.toGleamJson(value);
    
    const result = schema.validate(gleamSchema, gleamValue);
    
    if (result.type === 'Ok') {
      return { valid: true, value: this.fromGleamJson(result.value) };
    }
    
    return {
      valid: false,
      errors: result.value.map((e: any) => this.formatError(e)),
    };
  }

  private static formatError(error: any): string {
    switch (error.type) {
      case 'TypeMismatch':
        return `Expected ${error.expected}, got ${error.actual}`;
      case 'MinimumViolation':
        return `Value ${error.value} is below minimum ${error.minimum}`;
      case 'MaximumViolation':
        return `Value ${error.value} exceeds maximum ${error.maximum}`;
      case 'RequiredFieldMissing':
        return `Required field '${error.field}' is missing`;
      default:
        return JSON.stringify(error);
    }
  }
}

export interface ValidationResult {
  valid: boolean;
  value?: any;
  errors?: string[];
}
```

---

## Summary

| Aspect | TypeScript | Gleam |
|--------|------------|-------|
| Validation | Libraries (zod, yup) | Custom validators |
| Composition | Method chaining | Function composition |
| Error accumulation | Manual | Built into Result |
| Type safety | Runtime | Compile-time |
| Custom rules | Schema methods | Pure functions |

## Key Takeaways

1. **Validators are composable** - Build complex from simple
2. **Collect all errors** - Don't stop at first failure
3. **Type-driven validation** - Invalid states unrepresentable
4. **Pure functions** - Easy to test and reason about
5. **Integration is simple** - Bridge to TypeScript

## Next Steps

In **Chapter 9**, we'll explore:
- Building a real application
- Putting it all together

---

*Continue to [Chapter 9: Building a Real Application](./chapter-09.md)*
