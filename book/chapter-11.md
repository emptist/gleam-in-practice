# Chapter 11: Testing Strategies

> "Pure functions are the easiest to test. Gleam code is mostly pure functions."
> 
> — Testing wisdom

## Unit Testing Basics

### The TypeScript Approach

```typescript
// TypeScript - Jest/Vitest testing
import { describe, it, expect, beforeEach } from 'vitest';

describe('Task', () => {
  let task: Task;

  beforeEach(() => {
    task = new Task('Test task');
  });

  it('should start with pending status', () => {
    expect(task.status).toBe('pending');
  });

  it('should transition to running', () => {
    task.start();
    expect(task.status).toBe('running');
  });

  it('should throw if starting completed task', () => {
    task.complete('done');
    expect(() => task.start()).toThrow();
  });
});
```

### The Gleam Approach

```gleam
// task_test.gleam
import gleeunit
import traenupi_core/task.{new_task, start, complete, is_pending}

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn new_task_is_pending_test() {
  let task = new_task("Test task", 0)
  task.status |> should.equal(Pending)
}

pub fn start_task_becomes_running_test() {
  let task = new_task("Test task", 0)
  let result = start(task)
  
  case result {
    Ok(started) -> started.status |> should.equal(Running)
    Error(_) -> should.fail("Expected task to start")
  }
}

pub fn start_completed_task_fails_test() {
  let task = 
    new_task("Test task", 0)
    |> complete("done")
  
  let result = start(task)
  
  case result {
    Ok(_) -> should.fail("Expected error")
    Error(InvalidStatus(_)) -> Nil
    Error(_) -> should.fail("Expected InvalidStatus error")
  }
}
```

---

## Test Organization

### File Structure

```
traenupi_core/
├── src/
│   └── traenupi_core/
│       ├── task.gleam
│       ├── meeting.gleam
│       └── ...
└── test/
    └── traenupi_core_test.gleam
```

### Test Module Pattern

```gleam
// traenupi_core_test.gleam
import gleeunit
import gleeunit/should

// Task tests
pub fn task_new_test() { ... }
pub fn task_start_test() { ... }
pub fn task_complete_test() { ... }

// Meeting tests
pub fn meeting_new_test() { ... }
pub fn meeting_consensus_test() { ... }

pub fn main() -> Nil {
  gleeunit.main()
}
```

---

## Property-Based Testing

### QuickCheck-Style Testing

```gleam
import gleam/list
import gleam/int
import gleam/string

pub fn list_reverse_is_idempotent_test() {
  let property = fn(lst: List(Int)) {
    lst
    |> list.reverse()
    |> list.reverse()
    |> should.equal(lst)
  }
  
  let test_cases = [
    [],
    [1],
    [1, 2],
    [1, 2, 3],
    [1, 2, 3, 4, 5],
  ]
  
  test_cases
  |> list.each(property)
}

pub fn string_append_length_test() {
  let property = fn(a: String, b: String) {
    let combined = a <> b
    let expected = string.length(a) + string.length(b)
    string.length(combined) |> should.equal(expected)
  }
  
  let test_cases = [
    #("", ""),
    #("a", ""),
    #("", "b"),
    #("hello", " world"),
  ]
  
  test_cases
  |> list.each(fn(pair) {
    let #(a, b) = pair
    property(a, b)
  })
}
```

### Real Example: property.gleam

From TraeNuPI's implementation (135 lines):

```gleam
// property.gleam
import gleam/list
import gleam/int
import gleam/string
import gleam/float

pub type Generator(a) {
  Generator(generate: fn(Int) -> a)
}

pub fn int_generator(min: Int, max: Int) -> Generator(Int) {
  Generator(fn(seed) {
    let range = max - min
    min + (seed % range)
  })
}

pub fn string_generator(min_len: Int, max_len: Int) -> Generator(String) {
  Generator(fn(seed) {
    let len = min_len + (seed % (max_len - min_len + 1))
    int.to_string(seed)
    |> string.repeat(len / string.length(int.to_string(seed)) + 1)
    |> string.slice(0, len)
  })
}

pub fn list_generator(item_gen: Generator(a), min_len: Int, max_len: Int) 
    -> Generator(List(a)) {
  Generator(fn(seed) {
    let len = min_len + (seed % (max_len - min_len + 1))
    list.range(0, len - 1)
    |> list.map(fn(i) { item_gen.generate(seed + i * 17) })
  })
}

pub fn for_all(
  generator: Generator(a),
  property: fn(a) -> Bool,
  num_tests: Int,
) -> Result(Nil, a) {
  do_for_all(generator, property, num_tests, 1)
}

fn do_for_all(
  generator: Generator(a),
  property: fn(a) -> Bool,
  remaining: Int,
  seed: Int,
) -> Result(Nil, a) {
  case remaining {
    0 -> Ok(Nil)
    n -> {
      let value = generator.generate(seed)
      case property(value) {
        True -> do_for_all(generator, property, n - 1, seed + 1)
        False -> Error(value)
      }
    }
  }
}

pub fn shrink_int(value: Int, min: Int) -> List(Int) {
  case value {
    v if v <= min -> []
    v -> [
      min,
      min + (v - min) / 2,
      v - 1,
    ]
  }
}

pub fn shrink_string(value: String) -> List(String) {
  let len = string.length(value)
  case len {
    0 -> []
    1 -> [""]
    _ -> [
      string.slice(value, 0, len / 2),
      string.slice(value, 1, len - 1),
    ]
  }
}
```

---

## Testing Patterns

### Testing Result Types

```gleam
pub fn result_ok_test() {
  let result = Ok(42)
  
  case result {
    Ok(value) -> value |> should.equal(42)
    Error(_) -> should.fail("Expected Ok")
  }
}

pub fn result_error_test() {
  let result: Result(Int, String) = Error("failed")
  
  case result {
    Ok(_) -> should.fail("Expected Error")
    Error(e) -> e |> should.equal("failed")
  }
}

pub fn result_map_test() {
  let result = Ok(10)
  let mapped = result.map(result, fn(x) { x * 2 })
  
  case mapped {
    Ok(value) -> value |> should.equal(20)
    Error(_) -> should.fail("Expected Ok")
  }
}
```

### Testing Option Types

```gleam
pub fn option_some_test() {
  let opt = Some(42)
  
  case opt {
    Some(value) -> value |> should.equal(42)
    None -> should.fail("Expected Some")
  }
}

pub fn option_none_test() {
  let opt: Option(Int) = None
  opt |> should.equal(None)
}

pub fn option_unwrap_or_test() {
  let opt: Option(Int) = None
  option.unwrap(opt, 0) |> should.equal(0)
  
  let opt = Some(42)
  option.unwrap(opt, 0) |> should.equal(42)
}
```

### Testing State Transitions

```gleam
pub fn state_machine_test() {
  let initial = new_state()
  
  initial.status |> should.equal(Idle)
  
  let thinking = set_status(initial, Thinking)
  thinking.status |> should.equal(Thinking)
  
  let completed = set_status(thinking, Completed)
  completed.status |> should.equal(Completed)
  
  let history = get_recent_history(completed, 10)
  list.length(history) |> should.equal(0)
}
```

---

## Test Coverage

### Running Tests

```bash
# Run all tests
gleam test

# Run with verbose output
gleam test -- --verbose

# Run specific test file
gleam test test/task_test.gleam
```

### Test Statistics

From TraeNuPI's test output:

```
Running traenupi_core_test.main
...............................................................................
...............................................................................
...............................................................................
...............................................................................
...............................................................................
...............................................................................
...............................................................................
343 passed, no failures
```

---

## Integration Testing

### Testing FFI

```gleam
pub fn ffi_generate_id_test() {
  let id1 = generate_id()
  let id2 = generate_id()
  
  id1 |> should.not_equal(id2)
  string.length(id1) |> should.equal(36)
}

pub fn ffi_now_test() {
  let t1 = now()
  let t2 = now()
  
  t2 >=. t1 |> should.be_true()
}
```

### Testing Database Operations

```gleam
pub fn db_insert_test() {
  let config = DbConfig(
    host: "localhost",
    port: 5432,
    database: "test_db",
    user: "test",
    password: None,
    max_connections: 5,
    idle_timeout_ms: 30000,
    connection_timeout_ms: 5000,
  )
  
  use conn <- await(connect(config))
  
  case conn {
    Ok(c) -> {
      use result <- await(insert(c, "users", ["name"], ["test"]))
      case result {
        Ok(id) -> id |> should.be_int()
        Error(_) -> should.fail("Insert failed")
      }
    }
    Error(_) -> should.fail("Connection failed")
  }
}
```

---

## Summary

| Aspect | TypeScript | Gleam |
|--------|------------|-------|
| Test framework | Jest/Vitest | gleeunit |
| Assertions | expect() | should.equal() |
| Mocking | Often needed | Rarely needed |
| Property testing | Libraries | Built-in patterns |
| Pure functions | Hard to test | Easy to test |

## Key Takeaways

1. **Pure functions are easy to test** - No mocking needed
2. **Result/Option are explicit** - No null surprises
3. **Property testing is natural** - Generate inputs, check properties
4. **State transitions are testable** - Each step returns new state
5. **FFI testing is straightforward** - Test the interface

## Next Steps

In **Chapter 12**, we'll explore:
- JSON Schema validation case study
- 841 lines of real-world code
- Design decisions and trade-offs

---

*Continue to [Chapter 12: JSON Schema Validation Case Study](./chapter-12.md)*
