# 第十三章：案例研究 - JSON Path 查询语言

## 项目背景

JSON Path 是一种用于查询 JSON 文档的表达式语言，类似于 XPath 用于 XML。本章我们将实现一个完整的 JSON Path 解析器和求值器。

## 核心类型

### Path 类型

```gleam
// src/traenupi_core/json_path.gleam
pub type Path {
  Root
  Child(parent: Path, key: String)
  Index(parent: Path, index: Int)
  Slice(parent: Path, start: Int, end: Int, step: Int)
  Wildcard(parent: Path)
  RecursiveDescent(parent: Path, key: String)
  Filter(parent: Path, expression: FilterExpr)
  Union(parent: Path, paths: List(Path))
}

pub type FilterExpr {
  Exists(path: Path)
  Equals(path: Path, value: JsonValue)
  NotEquals(path: Path, value: JsonValue)
  LessThan(path: Path, value: JsonValue)
  GreaterThan(path: Path, value: JsonValue)
  And(left: FilterExpr, right: FilterExpr)
  Or(left: FilterExpr, right: FilterExpr)
  Not(expression: FilterExpr)
}

pub type QueryError {
  ParseError(message: String, position: Int)
  InvalidPath(message: String)
  TypeMismatch(expected: String, actual: String)
}
```

## 解析器

### 词法分析

```gleam
type Token {
  Dollar
  Dot
  LBracket
  RBracket
  Star
  Colon
  Comma
  Identifier(String)
  Number(Int)
  String_(String)
  At
  Question
  Equals
  NotEquals
  LessThan
  GreaterThan
  And
  Or
  LParen
  RParen
}

type Lexer {
  Lexer(input: String, position: Int, tokens: List(Token))
}

fn tokenize(input: String) -> Result(List(Token), QueryError) {
  let lexer = Lexer(input: input, position: 0, tokens: [])
  do_tokenize(lexer)
}

fn do_tokenize(lexer: Lexer) -> Result(List(Token), QueryError) {
  case string.at(lexer.input, lexer.position) {
    Some('$') -> {
      let lexer = Lexer(..lexer, position: lexer.position + 1, tokens: [Dollar, ..lexer.tokens])
      do_tokenize(lexer)
    }
    
    Some('.') -> {
      let lexer = Lexer(..lexer, position: lexer.position + 1, tokens: [Dot, ..lexer.tokens])
      do_tokenize(lexer)
    }
    
    Some('[') -> {
      let lexer = Lexer(..lexer, position: lexer.position + 1, tokens: [LBracket, ..lexer.tokens])
      do_tokenize(lexer)
    }
    
    Some(']') -> {
      let lexer = Lexer(..lexer, position: lexer.position + 1, tokens: [RBracket, ..lexer.tokens])
      do_tokenize(lexer)
    }
    
    Some('*') -> {
      let lexer = Lexer(..lexer, position: lexer.position + 1, tokens: [Star, ..lexer.tokens])
      do_tokenize(lexer)
    }
    
    Some(':') -> {
      let lexer = Lexer(..lexer, position: lexer.position + 1, tokens: [Colon, ..lexer.tokens])
      do_tokenize(lexer)
    }
    
    Some(',') -> {
      let lexer = Lexer(..lexer, position: lexer.position + 1, tokens: [Comma, ..lexer.tokens])
      do_tokenize(lexer)
    }
    
    Some('@') -> {
      let lexer = Lexer(..lexer, position: lexer.position + 1, tokens: [At, ..lexer.tokens])
      do_tokenize(lexer)
    }
    
    Some('?') -> {
      let lexer = Lexer(..lexer, position: lexer.position + 1, tokens: [Question, ..lexer.tokens])
      do_tokenize(lexer)
    }
    
    Some('=') -> {
      case string.at(lexer.input, lexer.position + 1) {
        Some('=') -> {
          let lexer = Lexer(..lexer, position: lexer.position + 2, tokens: [Equals, ..lexer.tokens])
          do_tokenize(lexer)
        }
        _ -> Error(ParseError(message: "Expected '='", position: lexer.position))
      }
    }
    
    Some('!') -> {
      case string.at(lexer.input, lexer.position + 1) {
        Some('=') -> {
          let lexer = Lexer(..lexer, position: lexer.position + 2, tokens: [NotEquals, ..lexer.tokens])
          do_tokenize(lexer)
        }
        _ -> Error(ParseError(message: "Expected '='", position: lexer.position))
      }
    }
    
    Some('<') -> {
      let lexer = Lexer(..lexer, position: lexer.position + 1, tokens: [LessThan, ..lexer.tokens])
      do_tokenize(lexer)
    }
    
    Some('>') -> {
      let lexer = Lexer(..lexer, position: lexer.position + 1, tokens: [GreaterThan, ..lexer.tokens])
      do_tokenize(lexer)
    }
    
    Some('&') -> {
      case string.at(lexer.input, lexer.position + 1) {
        Some('&') -> {
          let lexer = Lexer(..lexer, position: lexer.position + 2, tokens: [And, ..lexer.tokens])
          do_tokenize(lexer)
        }
        _ -> Error(ParseError(message: "Expected '&'", position: lexer.position))
      }
    }
    
    Some('|') -> {
      case string.at(lexer.input, lexer.position + 1) {
        Some('|') -> {
          let lexer = Lexer(..lexer, position: lexer.position + 2, tokens: [Or, ..lexer.tokens])
          do_tokenize(lexer)
        }
        _ -> Error(ParseError(message: "Expected '|'", position: lexer.position))
      }
    }
    
    Some('(') -> {
      let lexer = Lexer(..lexer, position: lexer.position + 1, tokens: [LParen, ..lexer.tokens])
      do_tokenize(lexer)
    }
    
    Some(')') -> {
      let lexer = Lexer(..lexer, position: lexer.position + 1, tokens: [RParen, ..lexer.tokens])
      do_tokenize(lexer)
    }
    
    Some('"') -> {
      let #(token, new_pos) = read_string(lexer.input, lexer.position)
      let lexer = Lexer(..lexer, position: new_pos, tokens: [token, ..lexer.tokens])
      do_tokenize(lexer)
    }
    
    Some(c) if is_digit(c) -> {
      let #(token, new_pos) = read_number(lexer.input, lexer.position)
      let lexer = Lexer(..lexer, position: new_pos, tokens: [token, ..lexer.tokens])
      do_tokenize(lexer)
    }
    
    Some(c) if is_identifier_start(c) -> {
      let #(token, new_pos) = read_identifier(lexer.input, lexer.position)
      let lexer = Lexer(..lexer, position: new_pos, tokens: [token, ..lexer.tokens])
      do_tokenize(lexer)
    }
    
    Some(c) if c == ' ' || c == '\n' || c == '\t' -> {
      let lexer = Lexer(..lexer, position: lexer.position + 1)
      do_tokenize(lexer)
    }
    
    None -> Ok(list.reverse(lexer.tokens))
    
    Some(c) -> Error(ParseError(message: "Unexpected character: " <> string.from_char(c), position: lexer.position))
  }
}
```

### 语法解析

```gleam
type Parser {
  Parser(tokens: List(Token), position: Int)
}

pub fn parse(path_string: String) -> Result(Path, QueryError) {
  use tokens <- result.try(tokenize(path_string))
  let parser = Parser(tokens: tokens, position: 0)
  parse_path(parser)
}

fn parse_path(parser: Parser) -> Result(Path, QueryError) {
  case current_token(parser) {
    Some(Dollar) -> {
      let parser = advance(parser)
      parse_path_continue(parser, Root)
    }
    _ -> Error(ParseError(message: "Expected '$'", position: parser.position))
  }
}

fn parse_path_continue(parser: Parser, path: Path) -> Result(Path, QueryError) {
  case current_token(parser) {
    Some(Dot) -> {
      let parser = advance(parser)
      parse_dot_access(parser, path)
    }
    
    Some(LBracket) -> {
      let parser = advance(parser)
      parse_bracket_access(parser, path)
    }
    
    _ -> Ok(path)
  }
}

fn parse_dot_access(parser: Parser, parent: Path) -> Result(Path, QueryError) {
  case current_token(parser) {
    Some(Star) -> {
      let parser = advance(parser)
      parse_path_continue(parser, Wildcard(parent: parent))
    }
    
    Some(Identifier(name)) -> {
      let parser = advance(parser)
      parse_path_continue(parser, Child(parent: parent, key: name))
    }
    
    _ -> Error(ParseError(message: "Expected identifier or '*'", position: parser.position))
  }
}

fn parse_bracket_access(parser: Parser, parent: Path) -> Result(Path, QueryError) {
  case current_token(parser) {
    Some(Star) -> {
      let parser = advance(parser)
      case current_token(parser) {
        Some(RBracket) -> {
          let parser = advance(parser)
          parse_path_continue(parser, Wildcard(parent: parent))
        }
        _ -> Error(ParseError(message: "Expected ']'", position: parser.position))
      }
    }
    
    Some(Number(index)) -> {
      let parser = advance(parser)
      case current_token(parser) {
        Some(RBracket) -> {
          let parser = advance(parser)
          parse_path_continue(parser, Index(parent: parent, index: index))
        }
        Some(Colon) -> {
          parse_slice(parser, parent, index)
        }
        _ -> Error(ParseError(message: "Expected ']' or ':'", position: parser.position))
      }
    }
    
    Some(String_(key)) -> {
      let parser = advance(parser)
      case current_token(parser) {
        Some(RBracket) -> {
          let parser = advance(parser)
          parse_path_continue(parser, Child(parent: parent, key: key))
        }
        _ -> Error(ParseError(message: "Expected ']'", position: parser.position))
      }
    }
    
    Some(Comma) -> {
      parse_union(parser, parent, [])
    }
    
    Some(Question) -> {
      parse_filter(parser, parent)
    }
    
    _ -> Error(ParseError(message: "Expected '*', number, string, or '?'", position: parser.position))
  }
}
```

## 求值器

### 主求值函数

```gleam
pub fn query(path: Path, value: JsonValue) -> Result(List(JsonValue), QueryError) {
  evaluate_path(path, value)
}

fn evaluate_path(path: Path, value: JsonValue) -> Result(List(JsonValue), QueryError) {
  case path {
    Root -> Ok([value])
    
    Child(parent, key) -> {
      use parent_values <- result.try(evaluate_path(parent, value))
      
      parent_values
      |> list.map(fn(parent_value) { get_child(parent_value, key) })
      |> list.filter_map(fn(result) { result })
      |> Ok
    }
    
    Index(parent, index) -> {
      use parent_values <- result.try(evaluate_path(parent, value))
      
      parent_values
      |> list.map(fn(parent_value) { get_index(parent_value, index) })
      |> list.filter_map(fn(result) { result })
      |> Ok
    }
    
    Slice(parent, start, end, step) -> {
      use parent_values <- result.try(evaluate_path(parent, value))
      
      parent_values
      |> list.map(fn(parent_value) { get_slice(parent_value, start, end, step) })
      |> list.map(list.flatten)
      |> list.flatten()
      |> Ok
    }
    
    Wildcard(parent) -> {
      use parent_values <- result.try(evaluate_path(parent, value))
      
      parent_values
      |> list.map(get_all_values)
      |> list.flatten()
      |> Ok
    }
    
    RecursiveDescent(parent, key) -> {
      use parent_values <- result.try(evaluate_path(parent, value))
      
      parent_values
      |> list.map(fn(parent_value) { recursive_find(parent_value, key) })
      |> list.flatten()
      |> Ok
    }
    
    Filter(parent, expression) -> {
      use parent_values <- result.try(evaluate_path(parent, value))
      
      parent_values
      |> list.filter(fn(item) {
        case evaluate_filter(expression, item) {
          Ok(True) -> True
          _ -> False
        }
      })
      |> Ok
    }
    
    Union(parent, paths) -> {
      use parent_values <- result.try(evaluate_path(parent, value))
      
      paths
      |> list.map(fn(p) {
        parent_values
        |> list.map(fn(parent_value) { evaluate_path(p, parent_value) })
        |> result.all()
      })
      |> result.all()
      |> result.map(list.flatten)
    }
  }
}
```

### 辅助函数

```gleam
fn get_child(value: JsonValue, key: String) -> Option(JsonValue) {
  case value {
    JsonObject(props) -> dict.get(props, key)
    _ -> None
  }
}

fn get_index(value: JsonValue, index: Int) -> Option(JsonValue) {
  case value {
    JsonArray(items) -> list_at(items, index)
    _ -> None
  }
}

fn get_slice(value: JsonValue, start: Int, end: Int, step: Int) -> List(JsonValue) {
  case value {
    JsonArray(items) -> {
      let len = list.length(items)
      let start = if start < 0 { len + start } else { start }
      let end = if end < 0 { len + end } else { end }
      
      items
      |> list_indexed()
      |> list.filter(fn(pair) {
        let #(i, _) = pair
        i >= start && i < end && (i - start) % step == 0
      })
      |> list.map(fn(pair) {
        let #(_, v) = pair
        v
      })
    }
    _ -> []
  }
}

fn get_all_values(value: JsonValue) -> List(JsonValue) {
  case value {
    JsonObject(props) -> dict.values(props)
    JsonArray(items) -> items
    _ -> []
  }
}

fn recursive_find(value: JsonValue, key: String) -> List(JsonValue) {
  case value {
    JsonObject(props) -> {
      let direct = case dict.get(props, key) {
        Some(v) -> [v]
        None -> []
      }
      
      let nested = props
        |> dict.values()
        |> list.map(fn(v) { recursive_find(v, key) })
        |> list.flatten()
      
      direct ++ nested
    }
    
    JsonArray(items) -> {
      items
      |> list.map(fn(item) { recursive_find(item, key) })
      |> list.flatten()
    }
    
    _ -> []
  }
}
```

## 使用示例

```gleam
pub fn example() {
  let data = JsonObject(dict.from_list([
    #("store", JsonObject(dict.from_list([
      #("book", JsonArray([
        JsonObject(dict.from_list([
          #("category", JsonString("reference")),
          #("author", JsonString("Nigel Rees")),
          #("title", JsonString("Sayings of the Century")),
          #("price", JsonNumber(8.95)),
        ])),
        JsonObject(dict.from_list([
          #("category", JsonString("fiction")),
          #("author", JsonString("Evelyn Waugh")),
          #("title", JsonString("Sword of Honour")),
          #("price", JsonNumber(12.99)),
        ])),
        JsonObject(dict.from_list([
          #("category", JsonString("fiction")),
          #("author", JsonString("Herman Melville")),
          #("title", JsonString("Moby Dick")),
          #("isbn", JsonString("0-553-21311-3")),
          #("price", JsonNumber(8.99)),
        ])),
      ])),
      #("bicycle", JsonObject(dict.from_list([
        #("color", JsonString("red")),
        #("price", JsonNumber(19.95)),
      ])),
    ])),
  ]))
  
  // $.store.book[0].title
  case parse("$.store.book[0].title") {
    Ok(path) -> {
      case query(path, data) {
        Ok(results) -> {
          results
          |> list.each(fn(result) {
            io.debug(result)  // JsonString("Sayings of the Century")
          })
        }
        Error(e) -> io.println("查询错误")
      }
    }
    Error(e) -> io.println("解析错误")
  }
  
  // $.store.book[*].author
  case parse("$.store.book[*].author") {
    Ok(path) -> {
      case query(path, data) {
        Ok(results) -> {
          // ["Nigel Rees", "Evelyn Waugh", "Herman Melville"]
        }
        Error(_) -> Nil
      }
    }
    Error(_) -> Nil
  }
  
  // $..book[?(@.price < 10)]
  case parse("$..book[?(@.price < 10)]") {
    Ok(path) -> {
      case query(path, data) {
        Ok(results) -> {
          // 价格低于 10 的书籍
        }
        Error(_) -> Nil
      }
    }
    Error(_) -> Nil
  }
}
```

## 小结

在本章中，我们实现了：

1. **词法分析** - 将 JSON Path 字符串转换为标记
2. **语法解析** - 将标记转换为 Path 类型
3. **求值器** - 对 JSON 数据执行查询
4. **过滤器** - 支持条件表达式

下一章，我们将讨论如何将 Nezha 功能整合到 TraeNuPI。
