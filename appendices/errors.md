# Appendix C: Common Error Messages and Solutions

## Type Errors

### "The module `X` does not have a `Y` value"

**Problem:**
```gleam
list.at([1, 2, 3], 0)
// Error: The module `gleam/list` does not have a `at` value
```

**Solution:**
```gleam
// Use a different function or implement your own
list.first([1, 2, 3])  // Ok(1)

// Or implement custom function
fn at(list: List(a), index: Int) -> Option(a) {
  case list {
    [] -> None
    [first, ..rest] if index == 0 -> Some(first)
    [_, ..rest] -> at(rest, index - 1)
  }
}
```

### "I was not expecting this"

**Problem:**
```gleam
let #(a, b) = tuple
// Error: I was not expecting this
```

**Solution:**
```gleam
// Check syntax - tuple access uses #()
case tuple {
  #(a, b) -> a + b
}

// Or destructure in function parameter
fn handle(#(a, b)) { a + b }
```

### "Unknown type `Promise`"

**Problem:**
```gleam
pub fn fetch() -> Promise(String) { ... }
// Error: Unknown type `Promise`
```

**Solution:**
```gleam
// Import the type
import gleam/javascript/promise.{type Promise}

pub fn fetch() -> Promise(String) { ... }
```

### "This imported type is never used"

**Problem:**
```gleam
import gleam/javascript/promise.{type Promise}
// Warning: This imported type is never used
```

**Solution:**
```gleam
// Either use it or remove it
import gleam/javascript/promise.{type Promise, await, resolve}

// Or just remove the unused import
```

## Pattern Matching Errors

### "Invalid label name"

**Problem:**
```gleam
case user {
  User(userName: n, ..) -> n
}
// Error: Invalid label name
```

**Solution:**
```gleam
// Use snake_case for labels (matching field names)
case user {
  User(user_name: n, ..) -> n
}

// Or use positional matching
case user {
  User(n, _, _) -> n
}
```

### "No case clauses"

**Problem:**
```gleam
case value {
}
// Error: No case clauses
```

**Solution:**
```gleam
// Add at least one case
case value {
  _ -> "default"
}
```

### "Non exhaustive patterns"

**Problem:**
```gleam
case status {
  Pending -> "waiting"
  Running -> "in progress"
  // Error: Non exhaustive patterns
}
```

**Solution:**
```gleam
// Handle all cases or use wildcard
case status {
  Pending -> "waiting"
  Running -> "in progress"
  Completed -> "done"
  Failed -> "error"
}

// Or use wildcard for remaining
case status {
  Pending -> "waiting"
  _ -> "other"
}
```

## FFI Errors

### "External function not found"

**Problem:**
```gleam
@external(javascript, "./ffi.mjs", "myFunc")
pub fn myFunc() -> Int
```
```javascript
// ffi.mjs
export function my_func() { return 42; }  // Wrong name!
```

**Solution:**
```gleam
// Match the JavaScript export name exactly
@external(javascript, "./ffi.mjs", "my_func")
pub fn myFunc() -> Int
```

### "Type mismatch in FFI"

**Problem:**
```gleam
@external(javascript, "./ffi.mjs", "getValue")
pub fn getValue() -> String
```
```javascript
export function getValue() { return 42; }  // Returns number!
```

**Solution:**
```gleam
// Match the return type
@external(javascript, "./ffi.mjs", "getValue")
pub fn getValue() -> Int

// Or convert in JavaScript
export function getValue() { return "42"; }
```

## Float vs Int Errors

### "The *. operator expects arguments of this type: Float"

**Problem:**
```gleam
let x = 10
let y = x * 2.5
// Error: The *. operator expects arguments of this type: Float
```

**Solution:**
```gleam
// Convert to float first
let x = 10.0
let y = x *. 2.5

// Or use int operations
let x = 10
let y = x * 2  // Both must be int
```

### "The <. operator expects arguments of this type: Float"

**Problem:**
```gleam
let x = 3.14
let y = 2
let result = x < y
// Error: The <. operator expects arguments of this type: Float
```

**Solution:**
```gleam
// Use float comparison
let x = 3.14
let y = 2.0
let result = x <. y

// Or convert
let result = x <. int.to_float(y)
```

## List Errors

### "The module `gleam/list` does not have a `range` value"

**Problem:**
```gleam
list.range(0, 10)
// Error: The module `gleam/list` does not have a `range` value
```

**Solution:**
```gleam
// Implement custom range
fn range(start: Int, stop: Int) -> List(Int) {
  case start > stop {
    True -> []
    False -> [start, ..range(start + 1, stop)]
  }
}
```

### "The module `gleam/list` does not have a `index_map` value"

**Problem:**
```gleam
list.index_map([1, 2, 3], fn(x, i) { x + i })
// Error: Unknown function
```

**Solution:**
```gleam
// Use list.map with enumerate pattern
[1, 2, 3]
|> list.map(fn(x) { x })  // Standard map

// Or implement custom
fn index_map(list: List(a), f: fn(a, Int) -> b) -> List(b) {
  do_index_map(list, f, 0)
}

fn do_index_map(list: List(a), f: fn(a, Int) -> b, index: Int) -> List(b) {
  case list {
    [] -> []
    [first, ..rest] -> [f(first, index), ..do_index_map(rest, f, index + 1)]
  }
}
```

## Syntax Errors

### "Gleam doesn't have if expressions"

**Problem:**
```gleam
if x > 0 {
  "positive"
} else {
  "negative"
}
// Error: Gleam doesn't have if expressions
```

**Solution:**
```gleam
// Use case expression
case x > 0 {
  True -> "positive"
  False -> "negative"
}
```

### "Expected a pattern"

**Problem:**
```gleam
case value {
  Some(x) if x > 0 -> x  // Guards are OK
  Some(x) && x < 10 -> x  // Error: Expected a pattern
}
```

**Solution:**
```gleam
// Use proper guard syntax
case value {
  Some(x) if x > 0 && x < 10 -> x
  _ -> 0
}
```

## Common Warnings

### "Unused variable"

**Problem:**
```gleam
let result = do_something()
// Warning: Unused variable `result`
```

**Solution:**
```gleam
// Use the variable
let result = do_something()
io.debug(result)

// Or ignore with underscore
let _ = do_something()
```

### "Unused imported module"

**Problem:**
```gleam
import gleam/list
// Warning: Unused imported module
```

**Solution:**
```gleam
// Either use it
import gleam/list

let items = list.map([1, 2, 3], fn(x) { x * 2 })

// Or remove it
```

## Quick Reference

| Error | Cause | Solution |
|-------|-------|----------|
| "does not have a `X` value" | Function doesn't exist | Check docs, implement custom |
| "I was not expecting this" | Syntax error | Check syntax carefully |
| "Unknown type" | Missing import | Add import statement |
| "Invalid label name" | Wrong case | Use snake_case |
| "Non exhaustive patterns" | Missing cases | Add all cases or wildcard |
| "expects Float" | Int/Float mismatch | Convert or use correct operator |
| "doesn't have if expressions" | Using if | Use case expression |
| "Unused variable" | Not using result | Use it or prefix with _ |
