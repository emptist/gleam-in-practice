# 第八章：验证

## 为什么需要验证？

验证是应用程序安全的第一道防线：

- **数据完整性** - 确保数据符合预期格式
- **安全性** - 防止恶意输入
- **用户体验** - 提供清晰的错误提示

## 验证器类型

### 基本验证器

```gleam
// src/traenupi_core/validation.gleam
pub type Validator(a, e) {
  Validator(validate: fn(a) -> Result(a, List(e)))
}

pub type ValidationError {
  Required(field: String)
  InvalidFormat(field: String, expected: String)
  TooShort(field: String, min: Int)
  TooLong(field: String, max: Int)
  OutOfRange(field: String, min: Float, max: Float)
  Custom(field: String, message: String)
}
```

### 创建验证器

```gleam
pub fn required(field: String) -> Validator(String, ValidationError) {
  Validator(fn(value) {
    case string.length(value) {
      0 -> Error([Required(field)])
      _ -> Ok(value)
    }
  })
}

pub fn min_length(field: String, min: Int) -> Validator(String, ValidationError) {
  Validator(fn(value) {
    case string.length(value) >= min {
      True -> Ok(value)
      False -> Error([TooShort(field, min)])
    }
  })
}

pub fn max_length(field: String, max: Int) -> Validator(String, ValidationError) {
  Validator(fn(value) {
    case string.length(value) <= max {
      True -> Ok(value)
      False -> Error([TooLong(field, max)])
    }
  })
}

pub fn email(field: String) -> Validator(String, ValidationError) {
  Validator(fn(value) {
    case string.contains(value, "@") && string.contains(value, ".") {
      True -> Ok(value)
      False -> Error([InvalidFormat(field, "email")])
    }
  })
}

pub fn range(field: String, min: Float, max: Float) -> Validator(Float, ValidationError) {
  Validator(fn(value) {
    case value >=. min && value <=. max {
      True -> Ok(value)
      False -> Error([OutOfRange(field, min, max)])
    }
  })
}

pub fn int_range(field: String, min: Int, max: Int) -> Validator(Int, ValidationError) {
  Validator(fn(value) {
    case value >= min && value <= max {
      True -> Ok(value)
      False -> Error([OutOfRange(field, int.to_float(min), int.to_float(max))])
    }
  })
}
```

## 组合验证器

### 链式验证

```gleam
pub fn validate(validator: Validator(a, e), value: a) -> Result(a, List(e)) {
  validator.validate(value)
}

pub fn and_then(
  first: Validator(a, e),
  second: Validator(a, e),
) -> Validator(a, e) {
  Validator(fn(value) {
    case first.validate(value) {
      Ok(_) -> second.validate(value)
      Error(errors1) -> {
        case second.validate(value) {
          Ok(_) -> Error(errors1)
          Error(errors2) -> Error(list.append(errors1, errors2))
        }
      }
    }
  })
}

pub fn or_else(
  first: Validator(a, e),
  second: Validator(a, e),
) -> Validator(a, e) {
  Validator(fn(value) {
    case first.validate(value) {
      Ok(v) -> Ok(v)
      Error(_) -> second.validate(value)
    }
  })
}
```

### 对象验证

```gleam
pub type UserInput {
  UserInput(name: String, email: String, age: Int)
}

pub fn validate_user(input: UserInput) -> Result(UserInput, List(ValidationError)) {
  let name_validator = 
    required("name")
    |> and_then(min_length("name", 2))
    |> and_then(max_length("name", 100))
  
  let email_validator =
    required("email")
    |> and_then(email("email"))
  
  let age_validator =
    int_range("age", 0, 150)
  
  // 收集所有验证错误
  let errors = []
  
  let errors = case name_validator.validate(input.name) {
    Ok(_) -> errors
    Error(e) -> list.append(errors, e)
  }
  
  let errors = case email_validator.validate(input.email) {
    Ok(_) -> errors
    Error(e) -> list.append(errors, e)
  }
  
  let errors = case age_validator.validate(input.age) {
    Ok(_) -> errors
    Error(e) -> list.append(errors, e)
  }
  
  case errors {
    [] -> Ok(input)
    _ -> Error(errors)
  }
}
```

## 自定义验证器

### 正则表达式验证

```gleam
pub fn pattern(field: String, regex: String) -> Validator(String, ValidationError) {
  Validator(fn(value) {
    case matches_pattern(value, regex) {
      True -> Ok(value)
      False -> Error([InvalidFormat(field, regex)])
    }
  })
}

@external(javascript, "./validation_ffi.mjs", "matchesPattern")
fn matches_pattern(value: String, pattern: String) -> Bool
```

```javascript
// validation_ffi.mjs
export function matchesPattern(value, pattern) {
  return new RegExp(pattern).test(value);
}
```

### 条件验证

```gleam
pub fn when_(
  condition: fn(a) -> Bool,
  validator: Validator(a, e),
) -> Validator(a, e) {
  Validator(fn(value) {
    case condition(value) {
      True -> validator.validate(value)
      False -> Ok(value)
    }
  })
}

pub fn when_equals(
  field: String,
  expected: a,
  validator: Validator(a, e),
) -> Validator(a, e) {
  Validator(fn(value) {
    case value == expected {
      True -> validator.validate(value)
      False -> Ok(value)
    }
  })
}
```

## 验证结果处理

### 错误消息

```gleam
pub fn error_message(error: ValidationError) -> String {
  case error {
    Required(field) -> field <> " 是必需的"
    InvalidFormat(field, expected) -> field <> " 格式无效，期望: " <> expected
    TooShort(field, min) -> field <> " 太短，最少需要 " <> int.to_string(min) <> " 个字符"
    TooLong(field, max) -> field <> " 太长，最多允许 " <> int.to_string(max) <> " 个字符"
    OutOfRange(field, min, max) -> field <> " 超出范围，应在 " <> float.to_string(min) <> " 和 " <> float.to_string(max) <> " 之间"
    Custom(field, message) -> field <> ": " <> message
  }
}

pub fn error_messages(errors: List(ValidationError)) -> List(String) {
  list.map(errors, error_message)
}
```

### 字段错误分组

```gleam
pub fn group_by_field(errors: List(ValidationError)) -> Dict(String, List(String)) {
  errors
    |> list.fold(dict.new(), fn(acc, error) {
      let field = get_field(error)
      let message = error_message(error)
      
      case dict.get(acc, field) {
        Some(messages) -> dict.insert(acc, field, [message, ..messages])
        None -> dict.insert(acc, field, [message])
      }
    })
}

fn get_field(error: ValidationError) -> String {
  case error {
    Required(field) -> field
    InvalidFormat(field, _) -> field
    TooShort(field, _) -> field
    TooLong(field, _) -> field
    OutOfRange(field, _, _) -> field
    Custom(field, _) -> field
  }
}
```

## 实战案例

### 任务验证

```gleam
pub type TaskInput {
  TaskInput(title: String, priority: Int, due_date: Option(String))
}

pub fn validate_task(input: TaskInput) -> Result(TaskInput, Dict(String, List(String))) {
  let title_validator =
    required("title")
    |> and_then(min_length("title", 1))
    |> and_then(max_length("title", 200))
  
  let priority_validator =
    int_range("priority", 1, 5)
  
  let errors = []
  
  let errors = case title_validator.validate(input.title) {
    Ok(_) -> errors
    Error(e) -> list.append(errors, e)
  }
  
  let errors = case priority_validator.validate(input.priority) {
    Ok(_) -> errors
    Error(e) -> list.append(errors, e)
  }
  
  let errors = case input.due_date {
    Some(date) -> {
      case validate_date(date) {
        Ok(_) -> errors
        Error(e) -> list.append(errors, e)
      }
    }
    None -> errors
  }
  
  case errors {
    [] -> Ok(input)
    _ -> Error(group_by_field(errors))
  }
}

fn validate_date(date: String) -> Result(String, ValidationError) {
  pattern("due_date", "^\\d{4}-\\d{2}-\\d{2}$").validate(date)
}
```

### 表单验证

```gleam
pub type FormField {
  FormField(name: String, value: String, touched: Bool)
}

pub type FormState {
  FormState(
    fields: Dict(String, FormField),
    errors: Dict(String, List(String)),
    submitted: Bool,
  )
}

pub fn validate_field(
  state: FormState,
  field_name: String,
  validator: Validator(String, ValidationError),
) -> FormState {
  case dict.get(state.fields, field_name) {
    Some(FormField(value:, ..)) -> {
      case validator.validate(value) {
        Ok(_) -> {
          let errors = dict.delete(state.errors, field_name)
          FormState(..state, errors: errors)
        }
        Error(validation_errors) -> {
          let messages = error_messages(validation_errors)
          let errors = dict.insert(state.errors, field_name, messages)
          FormState(..state, errors: errors)
        }
      }
    }
    None -> state
  }
}

pub fn validate_all(
  state: FormState,
  validators: Dict(String, Validator(String, ValidationError)),
) -> FormState {
  validators
    |> dict.fold(state, fn(state, field_name, validator) {
      validate_field(state, field_name, validator)
    })
}

pub fn is_valid(state: FormState) -> Bool {
  dict.is_empty(state.errors)
}
```

## 小结

在本章中，我们学习了：

1. **基本验证器** - 必填、长度、格式、范围
2. **组合验证器** - 链式验证、对象验证
3. **自定义验证器** - 正则表达式、条件验证
4. **错误处理** - 错误消息、字段分组
5. **实战案例** - 任务验证、表单验证

下一章，我们将学习缓存策略。
