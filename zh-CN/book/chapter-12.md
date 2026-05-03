# 第十二章：案例研究 - JSON Schema 验证

## 项目背景

JSON Schema 是一种用于描述和验证 JSON 文档结构的规范。本章我们将实现一个完整的 JSON Schema 验证器。

## 核心类型

### Schema 类型

```gleam
// src/traenupi_core/schema.gleam
pub type Schema {
  // 基本类型
  NullSchema
  BooleanSchema
  NumberSchema(NumberConstraints)
  StringSchema(StringConstraints)
  ArraySchema(ArrayConstraints)
  ObjectSchema(ObjectConstraints)
  
  // 组合类型
  AllOf(schemas: List(Schema))
  AnyOf(schemas: List(Schema))
  OneOf(schemas: List(Schema))
  Not(schema: Schema)
  
  // 引用
  Ref(uri: String)
  
  // 枚举和常量
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
    min_properties: Option(Int),
    max_properties: Option(Int),
  )
}
```

### 验证错误

```gleam
pub type ValidationError {
  TypeMismatch(expected: String, actual: String)
  ValueTooSmall(field: String, minimum: Float)
  ValueTooLarge(field: String, maximum: Float)
  StringTooShort(field: String, minimum: Int)
  StringTooLong(field: String, maximum: Int)
  PatternMismatch(field: String, pattern: String)
  ArrayTooShort(field: String, minimum: Int)
  ArrayTooLong(field: String, maximum: Int)
  DuplicateItems(field: String)
  MissingRequired(field: String)
  AdditionalProperty(field: String)
  NoMatch(schema: String)
  MultipleMatch(schema: String)
  InvalidEnumValue(value: JsonValue, allowed: List(JsonValue))
  ConstMismatch(expected: JsonValue, actual: JsonValue)
}
```

## 验证函数

### 主验证函数

```gleam
pub fn validate(schema: Schema, value: JsonValue) -> Result(JsonValue, List(ValidationError)) {
  case schema, value {
    // Null
    NullSchema, JsonNull -> Ok(JsonNull)
    NullSchema, _ -> Error([TypeMismatch(expected: "null", actual: json_type(value))])
    
    // Boolean
    BooleanSchema, JsonBool(_) -> Ok(value)
    BooleanSchema, _ -> Error([TypeMismatch(expected: "boolean", actual: json_type(value))])
    
    // Number
    NumberSchema(constraints), JsonNumber(n) -> validate_number(constraints, n, value)
    NumberSchema(_), _ -> Error([TypeMismatch(expected: "number", actual: json_type(value))])
    
    // String
    StringSchema(constraints), JsonString(s) -> validate_string(constraints, s, value)
    StringSchema(_), _ -> Error([TypeMismatch(expected: "string", actual: json_type(value))])
    
    // Array
    ArraySchema(constraints), JsonArray(items) -> validate_array(constraints, items, value)
    ArraySchema(_), _ -> Error([TypeMismatch(expected: "array", actual: json_type(value))])
    
    // Object
    ObjectSchema(constraints), JsonObject(props) -> validate_object(constraints, props, value)
    ObjectSchema(_), _ -> Error([TypeMismatch(expected: "object", actual: json_type(value))])
    
    // AllOf
    AllOf(schemas), _ -> validate_all_of(schemas, value)
    
    // AnyOf
    AnyOf(schemas), _ -> validate_any_of(schemas, value)
    
    // OneOf
    OneOf(schemas), _ -> validate_one_of(schemas, value)
    
    // Not
    Not(schema), _ -> validate_not(schema, value)
    
    // Enum
    Enum(values), _ -> validate_enum(value, values)
    
    // Const
    Const(expected), _ -> validate_const(expected, value)
    
    // Ref - 需要解析器支持
    Ref(uri), _ -> Error([NoMatch(schema: "Ref not supported: " <> uri)])
  }
}
```

### 数字验证

```gleam
fn validate_number(
  constraints: NumberConstraints,
  n: Float,
  value: JsonValue,
) -> Result(JsonValue, List(ValidationError)) {
  let errors = []
  
  // minimum
  let errors = case constraints.minimum {
    Some(min) if n <. min -> [ValueTooSmall(field: "number", minimum: min), ..errors]
    _ -> errors
  }
  
  // maximum
  let errors = case constraints.maximum {
    Some(max) if n >. max -> [ValueTooLarge(field: "number", maximum: max), ..errors]
    _ -> errors
  }
  
  // exclusiveMinimum
  let errors = case constraints.exclusive_minimum {
    Some(min) if n <=. min -> [ValueTooSmall(field: "number", minimum: min), ..errors]
    _ -> errors
  }
  
  // exclusiveMaximum
  let errors = case constraints.exclusive_maximum {
    Some(max) if n >=. max -> [ValueTooLarge(field: "number", maximum: max), ..errors]
    _ -> errors
  }
  
  // multipleOf
  let errors = case constraints.multiple_of {
    Some(multiple) -> {
      let remainder = n -. float.floor(n /. multiple) *. multiple
      case remainder == 0.0 {
        True -> errors
        False -> [ValueTooSmall(field: "multipleOf", minimum: multiple), ..errors]
      }
    }
    None -> errors
  }
  
  case errors {
    [] -> Ok(value)
    _ -> Error(list.reverse(errors))
  }
}
```

### 字符串验证

```gleam
fn validate_string(
  constraints: StringConstraints,
  s: String,
  value: JsonValue,
) -> Result(JsonValue, List(ValidationError)) {
  let errors = []
  let len = string.length(s)
  
  // minLength
  let errors = case constraints.min_length {
    Some(min) if len < min -> [StringTooShort(field: "string", minimum: min), ..errors]
    _ -> errors
  }
  
  // maxLength
  let errors = case constraints.max_length {
    Some(max) if len > max -> [StringTooLong(field: "string", maximum: max), ..errors]
    _ -> errors
  }
  
  // pattern
  let errors = case constraints.pattern {
    Some(pattern) -> {
      case matches_pattern(s, pattern) {
        True -> errors
        False -> [PatternMismatch(field: "string", pattern: pattern), ..errors]
      }
    }
    None -> errors
  }
  
  // format
  let errors = case constraints.format {
    Some(format) -> validate_format(s, format, errors)
    None -> errors
  }
  
  case errors {
    [] -> Ok(value)
    _ -> Error(list.reverse(errors))
  }
}

fn validate_format(s: String, format: String, errors: List(ValidationError)) -> List(ValidationError) {
  case format {
    "email" -> {
      case string.contains(s, "@") && string.contains(s, ".") {
        True -> errors
        False -> [PatternMismatch(field: "email", pattern: "email format"), ..errors]
      }
    }
    "uri" -> {
      case string.starts_with(s, "http://") || string.starts_with(s, "https://") {
        True -> errors
        False -> [PatternMismatch(field: "uri", pattern: "URI format"), ..errors]
      }
    }
    "date" -> {
      case matches_pattern(s, "^\\d{4}-\\d{2}-\\d{2}$") {
        True -> errors
        False -> [PatternMismatch(field: "date", pattern: "YYYY-MM-DD"), ..errors]
      }
    }
    _ -> errors  // 未知格式，跳过验证
  }
}
```

### 数组验证

```gleam
fn validate_array(
  constraints: ArrayConstraints,
  items: List(JsonValue),
  value: JsonValue,
) -> Result(JsonValue, List(ValidationError)) {
  let errors = []
  let len = list.length(items)
  
  // minItems
  let errors = case constraints.min_items {
    Some(min) if len < min -> [ArrayTooShort(field: "array", minimum: min), ..errors]
    _ -> errors
  }
  
  // maxItems
  let errors = case constraints.max_items {
    Some(max) if len > max -> [ArrayTooLong(field: "array", maximum: max), ..errors]
    _ -> errors
  }
  
  // uniqueItems
  let errors = case constraints.unique_items {
    True -> {
      case has_duplicates(items) {
        True -> [DuplicateItems(field: "array"), ..errors]
        False -> errors
      }
    }
    False -> errors
  }
  
  // items schema
  let errors = case constraints.items {
    Some(schema) -> {
      let item_errors = validate_array_items(schema, items)
      list.append(errors, item_errors)
    }
    None -> errors
  }
  
  case errors {
    [] -> Ok(value)
    _ -> Error(list.reverse(errors))
  }
}

fn validate_array_items(schema: Schema, items: List(JsonValue)) -> List(ValidationError) {
  items
  |> list.index_map(fn(item, index) {
    case validate(schema, item) {
      Ok(_) -> []
      Error(errors) -> errors
    }
  })
  |> list.flatten()
}
```

### 对象验证

```gleam
fn validate_object(
  constraints: ObjectConstraints,
  props: Dict(String, JsonValue),
  value: JsonValue,
) -> Result(JsonValue, List(ValidationError)) {
  let errors = []
  let len = dict.size(props)
  
  // minProperties
  let errors = case constraints.min_properties {
    Some(min) if len < min -> [ArrayTooShort(field: "object", minimum: min), ..errors]
    _ -> errors
  }
  
  // maxProperties
  let errors = case constraints.max_properties {
    Some(max) if len > max -> [ArrayTooLong(field: "object", maximum: max), ..errors]
    _ -> errors
  }
  
  // required
  let errors = constraints.required
    |> list.fold(errors, fn(errors, field) {
      case dict.has_key(props, field) {
        True -> errors
        False -> [MissingRequired(field: field), ..errors]
      }
    })
  
  // properties
  let errors = constraints.properties
    |> dict.fold(errors, fn(errors, key, schema) {
      case dict.get(props, key) {
        Some(value) -> {
          case validate(schema, value) {
            Ok(_) -> errors
            Error(e) -> list.append(errors, e)
          }
        }
        None -> errors
      }
    })
  
  // additionalProperties
  let errors = case constraints.additional_properties {
    Some(schema) -> {
      let extra_keys = props
        |> dict.keys()
        |> list.filter(fn(key) { !dict.has_key(constraints.properties, key) })
      
      extra_keys
        |> list.fold(errors, fn(errors, key) {
          case dict.get(props, key) {
            Some(value) -> {
              case validate(schema, value) {
                Ok(_) -> errors
                Error(e) -> list.append(errors, e)
              }
            }
            None -> errors
          }
        })
    }
    None -> {
      // 不允许额外属性
      let extra_keys = props
        |> dict.keys()
        |> list.filter(fn(key) { !dict.has_key(constraints.properties, key) })
      
      extra_keys
        |> list.fold(errors, fn(errors, key) {
          [AdditionalProperty(field: key), ..errors]
        })
    }
  }
  
  case errors {
    [] -> Ok(value)
    _ -> Error(list.reverse(errors))
  }
}
```

## Schema 构建器

```gleam
// src/traenupi_core/schema_builder.gleam
pub fn null() -> Schema {
  NullSchema
}

pub fn boolean() -> Schema {
  BooleanSchema
}

pub fn number() -> Schema {
  NumberSchema(NumberConstraints(
    minimum: None,
    maximum: None,
    exclusive_minimum: None,
    exclusive_maximum: None,
    multiple_of: None,
  ))
}

pub fn string() -> Schema {
  StringSchema(StringConstraints(
    min_length: None,
    max_length: None,
    pattern: None,
    format: None,
  ))
}

pub fn array() -> Schema {
  ArraySchema(ArrayConstraints(
    items: None,
    min_items: None,
    max_items: None,
    unique_items: False,
  ))
}

pub fn object() -> Schema {
  ObjectSchema(ObjectConstraints(
    properties: dict.new(),
    required: [],
    additional_properties: None,
    min_properties: None,
    max_properties: None,
  ))
}

// 修饰器
pub fn with_minimum(schema: Schema, min: Float) -> Schema {
  case schema {
    NumberSchema(constraints) -> NumberSchema(NumberConstraints(..constraints, minimum: Some(min)))
    _ -> schema
  }
}

pub fn with_maximum(schema: Schema, max: Float) -> Schema {
  case schema {
    NumberSchema(constraints) -> NumberSchema(NumberConstraints(..constraints, maximum: Some(max)))
    _ -> schema
  }
}

pub fn with_min_length(schema: Schema, min: Int) -> Schema {
  case schema {
    StringSchema(constraints) -> StringSchema(StringConstraints(..constraints, min_length: Some(min)))
    _ -> schema
  }
}

pub fn with_max_length(schema: Schema, max: Int) -> Schema {
  case schema {
    StringSchema(constraints) -> StringSchema(StringConstraints(..constraints, max_length: Some(max)))
    _ -> schema
  }
}

pub fn with_pattern(schema: Schema, pattern: String) -> Schema {
  case schema {
    StringSchema(constraints) -> StringSchema(StringConstraints(..constraints, pattern: Some(pattern)))
    _ -> schema
  }
}

pub fn with_items(schema: Schema, items: Schema) -> Schema {
  case schema {
    ArraySchema(constraints) -> ArraySchema(ArrayConstraints(..constraints, items: Some(items)))
    _ -> schema
  }
}

pub fn with_property(schema: Schema, name: String, prop_schema: Schema) -> Schema {
  case schema {
    ObjectSchema(constraints) -> {
      let properties = dict.insert(constraints.properties, name, prop_schema)
      ObjectSchema(ObjectConstraints(..constraints, properties: properties))
    }
    _ -> schema
  }
}

pub fn with_required(schema: Schema, fields: List(String)) -> Schema {
  case schema {
    ObjectSchema(constraints) -> ObjectSchema(ObjectConstraints(..constraints, required: fields))
    _ -> schema
  }
}
```

## 使用示例

```gleam
pub fn user_schema() -> Schema {
  object()
  |> with_property("id", number() |> with_minimum(1.0))
  |> with_property("name", string() |> with_min_length(1) |> with_max_length(100))
  |> with_property("email", string() |> with_pattern("^[^@]+@[^@]+\\.[^@]+$"))
  |> with_property("age", number() |> with_minimum(0.0) |> with_maximum(150.0))
  |> with_required(["id", "name", "email"])
}

pub fn validate_user_test() {
  let schema = user_schema()
  
  let valid_user = JsonObject(dict.from_list([
    #("id", JsonNumber(1.0)),
    #("name", JsonString("Alice")),
    #("email", JsonString("alice@example.com")),
    #("age", JsonNumber(30.0)),
  ]))
  
  case validate(schema, valid_user) {
    Ok(_) -> io.println("验证通过")
    Error(errors) -> io.println("验证失败")
  }
}
```

## 小结

在本章中，我们实现了：

1. **Schema 类型** - 完整的 JSON Schema 类型系统
2. **验证函数** - 类型验证、约束验证
3. **错误处理** - 详细的验证错误信息
4. **Schema 构建器** - 流畅的 API 构建复杂 Schema

下一章，我们将实现 JSON Path 查询语言。
