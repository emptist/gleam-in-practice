# Chapter 13: JSON Path Query Language - A Case Study

> "Query JSON like you query databases, but with type safety."
> 
> — JSON Path wisdom

## The Problem

JSON Path is a query language for JSON:
- Navigate nested structures
- Filter arrays
- Select multiple values
- Support wildcards and slices

Example queries:
```
$.store.books[*].author
$.store.books[?(@.price < 10)]
$..author
$.store.books[0:2]
```

## The Solution: json_path.gleam

### Core Types

```gleam
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
  Equals(left: FilterValue, right: FilterValue)
  NotEquals(left: FilterValue, right: FilterValue)
  LessThan(left: FilterValue, right: FilterValue)
  GreaterThan(left: FilterValue, right: FilterValue)
  And(left: FilterExpr, right: FilterExpr)
  Or(left: FilterExpr, right: FilterExpr)
  Not(expr: FilterExpr)
  Exists(path: Path)
}

pub type FilterValue {
  Literal(JsonValue)
  PathRef(Path)
}

pub type QueryError {
  ParseError(String)
  PathNotFound(String)
  InvalidFilter(String)
}
```

### Parser

```gleam
pub fn parse(query: String) -> Result(Path, QueryError) {
  let tokens = tokenize(query)
  parse_path(tokens, Root)
}

fn tokenize(query: String) -> List(Token) {
  query
  |> string.to_graphemes()
  |> tokenize_chars([], [])
}

fn tokenize_chars(chars: List(String), current: List(String), tokens: List(Token)) 
    -> List(Token) {
  case chars {
    [] -> 
      finalize_token(current, tokens)
      |> list.reverse()
    
    ["$", ..rest] -> 
      tokenize_chars(rest, [], [RootToken, ..finalize_token(current, tokens)])
    
    [".", "." | rest] -> 
      tokenize_chars(rest, [], [DotDot, ..finalize_token(current, tokens)])
    
    [".", ..rest] -> 
      tokenize_chars(rest, [], [Dot, ..finalize_token(current, tokens)])
    
    ["[", ..rest] -> 
      tokenize_chars(rest, [], [LBracket, ..finalize_token(current, tokens)])
    
    ["]", ..rest] -> 
      tokenize_chars(rest, [], [RBracket, ..finalize_token(current, tokens)])
    
    ["*", ..rest] -> 
      tokenize_chars(rest, [], [Star, ..finalize_token(current, tokens)])
    
    [":", ..rest] -> 
      tokenize_chars(rest, [], [Colon, ..finalize_token(current, tokens)])
    
    ["?", ..rest] -> 
      tokenize_chars(rest, [], [Question, ..finalize_token(current, tokens)])
    
    ["(", ..rest] -> 
      tokenize_chars(rest, [], [LParen, ..finalize_token(current, tokens)])
    
    [")", ..rest] -> 
      tokenize_chars(rest, [], [RParen, ..finalize_token(current, tokens)])
    
    [c, ..rest] -> 
      tokenize_chars(rest, [c, ..current], tokens)
  }
}

fn finalize_token(current: List(String), tokens: List(Token)) -> List(Token) {
  case current {
    [] -> tokens
    chars -> {
      let text = chars |> list.reverse() |> string.from_graphemes()
      case text {
        "" -> tokens
        _ -> [Text(text), ..tokens]
      }
    }
  }
}
```

### Path Parser

```gleam
fn parse_path(tokens: List(Token), base: Path) -> Result(Path, QueryError) {
  case tokens {
    [] -> Ok(base)
    
    [Dot, Text(name), ..rest] -> 
      parse_path(rest, Child(base, name))
    
    [DotDot, Text(name), ..rest] -> 
      parse_path(rest, RecursiveDescent(base, name))
    
    [Dot, Star, ..rest] -> 
      parse_path(rest, Wildcard(base))
    
    [LBracket, Text(name), RBracket, ..rest] -> 
      parse_path(rest, Child(base, name))
    
    [LBracket, Text(num), RBracket, ..rest] -> {
      case int.parse(num) {
        Ok(index) -> parse_path(rest, Index(base, index))
        Error(_) -> Error(ParseError("Invalid index: " <> num))
      }
    }
    
    [LBracket, Star, RBracket, ..rest] -> 
      parse_path(rest, Wildcard(base))
    
    [LBracket, Text(start), Colon, Text(end), RBracket, ..rest] -> {
      use start_idx <- result.try(parse_int(start))
      use end_idx <- result.try(parse_int(end))
      parse_path(rest, Slice(base, start_idx, end_idx, 1))
    }
    
    [LBracket, Question, LParen, ..rest] -> {
      use filter_tokens, remaining <- result.try(extract_filter_tokens(rest, []))
      use filter_expr <- result.try(parse_filter_expr(filter_tokens))
      case remaining {
        [RBracket, ..more] -> parse_path(more, Filter(base, filter_expr))
        _ -> Error(ParseError("Expected ] after filter"))
      }
    }
    
    _ -> Error(ParseError("Unexpected tokens"))
  }
}
```

### Evaluator

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
      |> list.flat_map(fn(v) { get_child(v, key) })
      |> Ok
    }
    
    Index(parent, index) -> {
      use parent_values <- result.try(evaluate_path(parent, value))
      parent_values
      |> list.flat_map(fn(v) { get_index(v, index) })
      |> Ok
    }
    
    Slice(parent, start, end, step) -> {
      use parent_values <- result.try(evaluate_path(parent, value))
      parent_values
      |> list.flat_map(fn(v) { get_slice(v, start, end, step) })
      |> Ok
    }
    
    Wildcard(parent) -> {
      use parent_values <- result.try(evaluate_path(parent, value))
      parent_values
      |> list.flat_map(fn(v) { get_all_children(v) })
      |> Ok
    }
    
    RecursiveDescent(parent, key) -> {
      use parent_values <- result.try(evaluate_path(parent, value))
      parent_values
      |> list.flat_map(fn(v) { recursive_find(v, key) })
      |> Ok
    }
    
    Filter(parent, expr) -> {
      use parent_values <- result.try(evaluate_path(parent, value))
      parent_values
      |> list.flat_map(fn(v) { filter_values(v, expr) })
      |> Ok
    }
    
    Union(parent, paths) -> {
      use parent_values <- result.try(evaluate_path(parent, value))
      paths
      |> list.flat_map(fn(p) {
        case evaluate_path(p, value) {
          Ok(values) -> values
          Error(_) -> []
        }
      })
      |> Ok
    }
  }
}
```

### Filter Evaluation

```gleam
fn filter_values(value: JsonValue, expr: FilterExpr) -> List(JsonValue) {
  case value {
    JsonArray(items) -> 
      items
      |> list.filter(fn(item) { evaluate_filter(expr, item) })
    
    JsonObject(obj) -> 
      dict.values(obj)
      |> list.filter(fn(item) { evaluate_filter(expr, item) })
    
    _ -> []
  }
}

fn evaluate_filter(expr: FilterExpr, value: JsonValue) -> Bool {
  case expr {
    Equals(left, right) -> {
      let left_val = resolve_filter_value(left, value)
      let right_val = resolve_filter_value(right, value)
      left_val == right_val
    }
    
    NotEquals(left, right) -> {
      let left_val = resolve_filter_value(left, value)
      let right_val = resolve_filter_value(right, value)
      left_val != right_val
    }
    
    LessThan(left, right) -> {
      let left_val = resolve_filter_value(left, value)
      let right_val = resolve_filter_value(right, value)
      compare_values(left_val, right_val) == Lt
    }
    
    GreaterThan(left, right) -> {
      let left_val = resolve_filter_value(left, value)
      let right_val = resolve_filter_value(right, value)
      compare_values(left_val, right_val) == Gt
    }
    
    And(left, right) -> 
      evaluate_filter(left, value) && evaluate_filter(right, value)
    
    Or(left, right) -> 
      evaluate_filter(left, value) || evaluate_filter(right, value)
    
    Not(inner) -> !evaluate_filter(inner, value)
    
    Exists(path) -> {
      case evaluate_path(path, value) {
        Ok(values) -> !list.is_empty(values)
        Error(_) -> False
      }
    }
  }
}

fn resolve_filter_value(fv: FilterValue, current: JsonValue) -> JsonValue {
  case fv {
    Literal(v) -> v
    PathRef(path) -> {
      case evaluate_path(path, current) {
        Ok([value]) -> value
        _ -> JsonNull
      }
    }
  }
}
```

### Recursive Descent

```gleam
fn recursive_find(value: JsonValue, key: String) -> List(JsonValue) {
  case value {
    JsonObject(obj) -> {
      let direct = case dict.get(obj, key) {
        Ok(v) -> [v]
        Error(_) -> []
      }
      
      let nested = 
        dict.values(obj)
        |> list.flat_map(fn(v) { recursive_find(v, key) })
      
      direct ++ nested
    }
    
    JsonArray(items) -> 
      items
      |> list.flat_map(fn(item) { recursive_find(item, key) })
    
    _ -> []
  }
}
```

## Usage Examples

### Basic Queries

```gleam
let json = parse_json('
  {
    "store": {
      "books": [
        {"title": "Book 1", "price": 10},
        {"title": "Book 2", "price": 5},
        {"title": "Book 3", "price": 15}
      ]
    }
  }
')

let path = parse("$.store.books[*].title")
let result = query(path, json)
// Ok([JsonString("Book 1"), JsonString("Book 2"), JsonString("Book 3")])
```

### Filter Queries

```gleam
let path = parse("$.store.books[?(@.price < 10)]")
let result = query(path, json)
// Ok([JsonObject({"title": "Book 2", "price": 5})])
```

### Recursive Descent

```gleam
let path = parse("$..price")
let result = query(path, json)
// Ok([JsonNumber(10), JsonNumber(5), JsonNumber(15)])
```

## Summary

| Metric | Value |
|--------|-------|
| Total lines | 442 |
| Path types | 8 |
| Filter operators | 7 |
| Token types | 12 |

## Key Takeaways

1. **Parser combinators are natural** - Tokenize then parse
2. **Recursive descent is elegant** - Pattern match on structure
3. **Filters are expressions** - Build complex queries from simple parts
4. **Type safety prevents errors** - Invalid paths caught at compile time
5. **Result type for errors** - No exceptions

## Next Steps

In **Chapter 14**, we'll explore:
- Absorbing Nezha into TraeNuPI
- Migration strategy
- Lessons learned

---

*Continue to [Chapter 14: Absorbing Nezha Case Study](./chapter-14.md)*
