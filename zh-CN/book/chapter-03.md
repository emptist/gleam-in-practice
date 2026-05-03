# 第三章：处理 JSON

## JSON 在 Gleam 中的重要性

在现代 Web 开发中，JSON 是数据交换的标准格式。Gleam 提供了强大的工具来处理 JSON 数据。

## 动态 JSON 类型

Gleam 的 `gleam/dynamic` 模块提供了处理动态数据的能力：

```gleam
import gleam/dynamic.{type Dynamic}
import gleam/json

// JSON 值类型
pub type JsonValue {
  JsonNull
  JsonBool(Bool)
  JsonNumber(Float)
  JsonString(String)
  JsonArray(List(JsonValue))
  JsonObject(Dict(String, JsonValue))
}
```

## JSON 解码

### 基本解码

```gleam
import gleam/dynamic
import gleam/json

pub fn decode_string(data: String) -> Result(JsonValue, String) {
  json.decode(data)
}

// 示例
pub fn example() {
  let data = "{\"name\": \"Alice\", \"age\": 30}"
  
  case json.decode(data) {
    Ok(value) -> {
      // 处理解码后的值
      io.debug(value)
    }
    Error(_) -> {
      io.println("JSON 解码失败")
    }
  }
}
```

### 解码为自定义类型

```gleam
import gleam/dynamic

pub type User {
  User(id: Int, name: String, email: String)
}

pub fn decode_user(data: Dynamic) -> Result(User, List(dynamic.DecodeError)) {
  use id <- dynamic.field("id", dynamic.int)
  use name <- dynamic.field("name", dynamic.string)
  use email <- dynamic.field("email", dynamic.string)
  
  Ok(User(id: id, name: name, email: email))
}

// 使用解码器
pub fn parse_user(json_string: String) -> Result(User, String) {
  case json.decode(json_string) {
    Ok(dynamic_data) -> {
      case decode_user(dynamic_data) {
        Ok(user) -> Ok(user)
        Error(errors) -> Error("解码失败")
      }
    }
    Error(_) -> Error("JSON 解析失败")
  }
}
```

### 解码器组合

```gleam
import gleam/dynamic

// 可选字段
pub fn decode_user_with_optional(data: Dynamic) -> Result(User, List(dynamic.DecodeError)) {
  use id <- dynamic.field("id", dynamic.int)
  use name <- dynamic.field("name", dynamic.string)
  use email <- dynamic.optional_field("email", dynamic.string)
  
  Ok(User(
    id: id,
    name: name,
    email: option.unwrap(email, ""),
  ))
}

// 嵌套对象
pub type Address {
  Address(city: String, country: String)
}

pub type Person {
  Person(name: String, address: Address)
}

pub fn decode_address(data: Dynamic) -> Result(Address, List(dynamic.DecodeError)) {
  use city <- dynamic.field("city", dynamic.string)
  use country <- dynamic.field("country", dynamic.string)
  
  Ok(Address(city: city, country: country))
}

pub fn decode_person(data: Dynamic) -> Result(Person, List(dynamic.DecodeError)) {
  use name <- dynamic.field("name", dynamic.string)
  use address <- dynamic.field("address", decode_address)
  
  Ok(Person(name: name, address: address))
}

// 列表解码
pub fn decode_users(data: Dynamic) -> Result(List(User), List(dynamic.DecodeError)) {
  dynamic.list(decode_user)(data)
}
```

## JSON 编码

### 基本编码

```gleam
import gleam/json.{type Json}

// 编码基本类型
pub fn encode_int(n: Int) -> String {
  json.int(n) |> json.to_string
}

pub fn encode_string(s: String) -> String {
  json.string(s) |> json.to_string
}

pub fn encode_bool(b: Bool) -> String {
  json.bool(b) |> json.to_string
}

pub fn encode_float(f: Float) -> String {
  json.float(f) |> json.to_string
}
```

### 编码对象

```gleam
// 编码自定义类型
pub fn encode_user(user: User) -> String {
  json.object([
    #("id", json.int(user.id)),
    #("name", json.string(user.name)),
    #("email", json.string(user.email)),
  ])
  |> json.to_string
}

// 编码嵌套对象
pub fn encode_address(address: Address) -> Json {
  json.object([
    #("city", json.string(address.city)),
    #("country", json.string(address.country)),
  ])
}

pub fn encode_person(person: Person) -> String {
  json.object([
    #("name", json.string(person.name)),
    #("address", encode_address(person.address)),
  ])
  |> json.to_string
}

// 编码列表
pub fn encode_users(users: List(User)) -> String {
  json.array(users, fn(user) {
    json.object([
      #("id", json.int(user.id)),
      #("name", json.string(user.name)),
      #("email", json.string(user.email)),
    ])
  })
  |> json.to_string
}
```

## 实战：JSON 解析器实现

让我们实现一个完整的 JSON 解析器：

```gleam
pub type JsonValue {
  JsonNull
  JsonBool(Bool)
  JsonNumber(Float)
  JsonString(String)
  JsonArray(List(JsonValue))
  JsonObject(List(#(String, JsonValue)))
}

pub type JsonError {
  InvalidJson(message: String)
  UnexpectedEnd
  UnexpectedCharacter(char: String, position: Int)
}

pub fn parse(input: String) -> Result(JsonValue, JsonError) {
  let parser = Parser(input: input, position: 0)
  parse_value(parser)
}

type Parser {
  Parser(input: String, position: Int)
}

fn parse_value(parser: Parser) -> Result(#(JsonValue, Parser), JsonError) {
  let parser = skip_whitespace(parser)
  
  case peek_char(parser) {
    Some('n') -> parse_null(parser)
    Some('t') -> parse_true(parser)
    Some('f') -> parse_false(parser)
    Some('"') -> parse_string(parser)
    Some(c) if c == '-' || is_digit(c) -> parse_number(parser)
    Some('[') -> parse_array(parser)
    Some('{') -> parse_object(parser)
    Some(c) -> Error(UnexpectedCharacter(char: string.from_char(c), position: parser.position))
    None -> Error(UnexpectedEnd)
  }
}

fn parse_null(parser: Parser) -> Result(#(JsonValue, Parser), JsonError) {
  case string.slice(parser.input, parser.position, 4) {
    "null" -> Ok(#(JsonNull, Parser(..parser, position: parser.position + 4)))
    _ -> Error(InvalidJson(message: "Expected 'null'"))
  }
}

fn parse_true(parser: Parser) -> Result(#(JsonValue, Parser), JsonError) {
  case string.slice(parser.input, parser.position, 4) {
    "true" -> Ok(#(JsonBool(True), Parser(..parser, position: parser.position + 4)))
    _ -> Error(InvalidJson(message: "Expected 'true'"))
  }
}

fn parse_false(parser: Parser) -> Result(#(JsonValue, Parser), JsonError) {
  case string.slice(parser.input, parser.position, 5) {
    "false" -> Ok(#(JsonBool(False), Parser(..parser, position: parser.position + 5)))
    _ -> Error(InvalidJson(message: "Expected 'false'"))
  }
}

fn parse_string(parser: Parser) -> Result(#(JsonValue, Parser), JsonError) {
  let parser = advance(parser) // 跳过开头的 "
  
  parse_string_content(parser, "")
}

fn parse_string_content(parser: Parser, acc: String) -> Result(#(JsonValue, Parser), JsonError) {
  case peek_char(parser) {
    Some('"') -> {
      let parser = advance(parser)
      Ok(#(JsonString(acc), parser))
    }
    Some('\\') -> {
      let parser = advance(parser)
      case peek_char(parser) {
        Some('n') -> parse_string_content(advance(parser), acc <> "\n")
        Some('t') -> parse_string_content(advance(parser), acc <> "\t")
        Some('r') -> parse_string_content(advance(parser), acc <> "\r")
        Some('\\') -> parse_string_content(advance(parser), acc <> "\\")
        Some('"') -> parse_string_content(advance(parser), acc <> "\"")
        Some(c) -> parse_string_content(advance(parser), acc <> string.from_char(c))
        None -> Error(UnexpectedEnd)
      }
    }
    Some(c) -> parse_string_content(advance(parser), acc <> string.from_char(c))
    None -> Error(UnexpectedEnd)
  }
}

fn parse_number(parser: Parser) -> Result(#(JsonValue, Parser), JsonError) {
  let parser = skip_whitespace(parser)
  
  // 收集数字字符
  parse_number_chars(parser, "")
}

fn parse_number_chars(parser: Parser, acc: String) -> Result(#(JsonValue, Parser), JsonError) {
  case peek_char(parser) {
    Some(c) if is_digit(c) || c == '-' || c == '.' || c == 'e' || c == 'E' || c == '+' -> {
      parse_number_chars(advance(parser), acc <> string.from_char(c))
    }
    _ -> {
      case float.parse(acc) {
        Ok(n) -> Ok(#(JsonNumber(n), parser))
        Error(_) -> Error(InvalidJson(message: "Invalid number: " <> acc))
      }
    }
  }
}

fn parse_array(parser: Parser) -> Result(#(JsonValue, Parser), JsonError) {
  let parser = advance(parser) // 跳过 [
  let parser = skip_whitespace(parser)
  
  case peek_char(parser) {
    Some(']') -> Ok(#(JsonArray([]), advance(parser)))
    _ -> parse_array_items(parser, [])
  }
}

fn parse_array_items(parser: Parser, items: List(JsonValue)) -> Result(#(JsonValue, Parser), JsonError) {
  use value <- result.try(parse_value(parser))
  let parser = skip_whitespace(parser)
  
  case peek_char(parser) {
    Some(',') -> {
      let parser = advance(parser)
      parse_array_items(parser, [value, ..items])
    }
    Some(']') -> Ok(#(JsonArray(list.reverse([value, ..items])), advance(parser)))
    _ -> Error(InvalidJson(message: "Expected ',' or ']' in array"))
  }
}

fn parse_object(parser: Parser) -> Result(#(JsonValue, Parser), JsonError) {
  let parser = advance(parser) // 跳过 {
  let parser = skip_whitespace(parser)
  
  case peek_char(parser) {
    Some('}') -> Ok(#(JsonObject([]), advance(parser)))
    _ -> parse_object_items(parser, [])
  }
}

fn parse_object_items(parser: Parser, items: List(#(String, JsonValue))) -> Result(#(JsonValue, Parser), JsonError) {
  // 解析键
  use key <- result.try(parse_object_key(parser))
  let parser = skip_whitespace(parser)
  
  // 期望冒号
  case peek_char(parser) {
    Some(':') -> {
      let parser = advance(parser)
      let parser = skip_whitespace(parser)
      
      // 解析值
      use value <- result.try(parse_value(parser))
      let parser = skip_whitespace(parser)
      
      case peek_char(parser) {
        Some(',') -> {
          let parser = advance(parser)
          parse_object_items(parser, [#(key, value), ..items])
        }
        Some('}') -> Ok(#(JsonObject(list.reverse([#(key, value), ..items])), advance(parser)))
        _ -> Error(InvalidJson(message: "Expected ',' or '}' in object"))
      }
    }
    _ -> Error(InvalidJson(message: "Expected ':' after key"))
  }
}

fn parse_object_key(parser: Parser) -> Result(#(String, Parser), JsonError) {
  case parse_string(parser) {
    Ok(#(JsonString(key), parser)) -> Ok(#(key, parser))
    _ -> Error(InvalidJson(message: "Expected string key in object"))
  }
}

// 辅助函数
fn peek_char(parser: Parser) -> Option(Char) {
  string.at(parser.input, parser.position)
}

fn advance(parser: Parser) -> Parser {
  Parser(..parser, position: parser.position + 1)
}

fn skip_whitespace(parser: Parser) -> Parser {
  case peek_char(parser) {
    Some(c) if c == ' ' || c == '\n' || c == '\r' || c == '\t' -> {
      skip_whitespace(advance(parser))
    }
    _ -> parser
  }
}

fn is_digit(char: Char) -> Bool {
  char >= '0' && char <= '9'
}
```

## JSON 编码器实现

```gleam
pub fn encode(value: JsonValue) -> String {
  case value {
    JsonNull -> "null"
    JsonBool(True) -> "true"
    JsonBool(False) -> "false"
    JsonNumber(n) -> float.to_string(n)
    JsonString(s) -> encode_string_value(s)
    JsonArray(items) -> encode_array(items)
    JsonObject(items) -> encode_object(items)
  }
}

fn encode_string_value(s: String) -> String {
  "\"" <> escape_string(s) <> "\""
}

fn escape_string(s: String) -> String {
  s
  |> string.replace("\\", "\\\\")
  |> string.replace("\"", "\\\"")
  |> string.replace("\n", "\\n")
  |> string.replace("\t", "\\t")
  |> string.replace("\r", "\\r")
}

fn encode_array(items: List(JsonValue)) -> String {
  let encoded = items
    |> list.map(encode)
    |> string.join(",")
  
  "[" <> encoded <> "]"
}

fn encode_object(items: List(#(String, JsonValue))) -> String {
  let encoded = items
    |> list.map(fn(pair) {
      let #(key, value) = pair
      encode_string_value(key) <> ":" <> encode(value)
    })
    |> string.join(",")
  
  "{" <> encoded <> "}"
}
```

## 小结

在本章中，我们学习了：

1. **JSON 解码** - 使用 dynamic 模块解码 JSON
2. **JSON 编码** - 将 Gleam 类型编码为 JSON
3. **解码器组合** - 组合解码器处理复杂结构
4. **自定义解析器** - 实现完整的 JSON 解析器
5. **自定义编码器** - 实现完整的 JSON 编码器

下一章，我们将学习如何使用 FFI 与 JavaScript 交互。
