# Chapter 10: Async Programming

> "Async in Gleam is explicit, composable, and type-safe. No more callback hell."
> 
> — Gleam async wisdom

## Promise Basics

### The TypeScript Approach

```typescript
// TypeScript - Promise-based async
async function fetchUser(id: string): Promise<User> {
  const response = await fetch(`/api/users/${id}`);
  if (!response.ok) {
    throw new Error(`Failed to fetch user: ${response.statusText}`);
  }
  return response.json();
}

async function fetchUserPosts(userId: string): Promise<Post[]> {
  const response = await fetch(`/api/users/${userId}/posts`);
  if (!response.ok) {
    throw new Error(`Failed to fetch posts`);
  }
  return response.json();
}

// Chaining
async function getUserWithPosts(id: string): Promise<{ user: User; posts: Post[] }> {
  const user = await fetchUser(id);
  const posts = await fetchUserPosts(user.id);
  return { user, posts };
}
```

### The Gleam Approach

```gleam
import gleam/javascript/promise.{type Promise, await, resolve}

pub fn fetch_user(id: String) -> Promise(Result(User, HttpError)) {
  use response <- await(http_get("/api/users/" <> id))
  
  case response {
    Ok(body) -> {
      case json_decode_user(body) {
        Ok(user) -> resolve(Ok(user))
        Error(e) -> resolve(Error(ParseError(e)))
      }
    }
    Error(e) -> resolve(Error(HttpError(e)))
  }
}

pub fn fetch_user_posts(user_id: String) -> Promise(Result(List(Post), HttpError)) {
  use response <- await(http_get("/api/users/" <> user_id <> "/posts"))
  
  case response {
    Ok(body) -> {
      case json_decode_posts(body) {
        Ok(posts) -> resolve(Ok(posts))
        Error(e) -> resolve(Error(ParseError(e)))
      }
    }
    Error(e) -> resolve(Error(HttpError(e)))
  }
}

pub fn get_user_with_posts(id: String) -> Promise(Result(UserWithPosts, HttpError)) {
  use user <- await(fetch_user(id))
  
  case user {
    Ok(u) -> {
      use posts <- await(fetch_user_posts(u.id))
      
      case posts {
        Ok(p) -> resolve(Ok(UserWithPosts(user: u, posts: p)))
        Error(e) -> resolve(Error(e))
      }
    }
    Error(e) -> resolve(Error(e))
  }
}
```

---

## Promise Combinators

### Parallel Execution

```gleam
pub fn parallel_all(promises: List(Promise(a))) -> Promise(List(a)) {
  promise.all(promises)
}

pub fn parallel_any(promises: List(Promise(a))) -> Promise(a) {
  promise.any(promises)
}

pub fn parallel_race(promises: List(Promise(a))) -> Promise(a) {
  promise.race(promises)
}
```

### Real Example: async.gleam

From TraeNuPI's implementation (225 lines):

```gleam
// async.gleam
import gleam/javascript/promise.{type Promise, await, resolve}
import gleam/list
import gleam/option.{type Option, None, Some}

pub fn map(promise: Promise(a), f: fn(a) -> b) -> Promise(b) {
  use value <- await(promise)
  resolve(f(value))
}

pub fn map_result(
  promise: Promise(Result(a, e)),
  f: fn(a) -> b,
) -> Promise(Result(b, e)) {
  use result <- await(promise)
  case result {
    Ok(value) -> resolve(Ok(f(value)))
    Error(e) -> resolve(Error(e))
  }
}

pub fn flat_map(promise: Promise(a), f: fn(a) -> Promise(b)) -> Promise(b) {
  use value <- await(promise)
  f(value)
}

pub fn sequence(promises: List(Promise(a))) -> Promise(List(a)) {
  promise.all(promises)
}

pub fn traverse(list: List(a), f: fn(a) -> Promise(b)) -> Promise(List(b)) {
  list
  |> list.map(f)
  |> promise.all
}

pub fn traverse_result(
  list: List(a),
  f: fn(a) -> Promise(Result(b, e)),
) -> Promise(Result(List(b), e)) {
  use results <- await(
    list
    |> list.map(f)
    |> promise.all
  )
  
  let accumulated = 
    results
    |> list.fold(Ok([]), fn(acc, result) {
      case acc, result {
        Ok(acc_list), Ok(value) -> Ok([value, ..acc_list])
        Error(e), _ -> Error(e)
        _, Error(e) -> Error(e)
      }
    })
  
  resolve(accumulated)
}

pub fn retry(
  action: fn() -> Promise(Result(a, e)),
  max_attempts: Int,
  delay_ms: Int,
) -> Promise(Result(a, e)) {
  do_retry(action, max_attempts, delay_ms, 0)
}

fn do_retry(
  action: fn() -> Promise(Result(a, e)),
  max_attempts: Int,
  delay_ms: Int,
  attempt: Int,
) -> Promise(Result(a, e)) {
  use result <- await(action())
  
  case result {
    Ok(value) -> resolve(Ok(value))
    Error(e) -> {
      case attempt < max_attempts - 1 {
        True -> {
          use _ <- await(sleep(delay_ms))
          do_retry(action, max_attempts, delay_ms, attempt + 1)
        }
        False -> resolve(Error(e))
      }
    }
  }
}

pub fn timeout(
  promise: Promise(a),
  ms: Int,
  default: a,
) -> Promise(a) {
  use _ <- await(promise.race([promise, sleep_then(ms, default)]))
  resolve(default)
}

fn sleep_then(ms: Int, value: a) -> Promise(a) {
  use _ <- await(sleep(ms))
  resolve(value)
}

@external(javascript, "./async_ffi.mjs", "sleep")
pub fn sleep(ms: Int) -> Promise(Nil)
```

---

## Error Handling in Async

### Result-Based Error Handling

```gleam
pub type AsyncError {
  NetworkError(String)
  TimeoutError
  ParseError(String)
  ValidationError(String)
}

pub fn safe_fetch(url: String) -> Promise(Result(String, AsyncError)) {
  use response <- await(http_get(url))
  
  case response {
    Ok(body) -> resolve(Ok(body))
    Error(e) -> resolve(Error(NetworkError(e)))
  }
}

pub fn with_timeout(
  promise: Promise(Result(a, e)),
  ms: Int,
) -> Promise(Result(a, AsyncError)) {
  use result <- await(promise.race([
    map_result(promise, fn(r) { r }),
    sleep_then(ms, Error(TimeoutError)),
  ]))
  
  resolve(result)
}
```

### Error Recovery

```gleam
pub fn with_fallback(
  primary: Promise(Result(a, e)),
  fallback: fn() -> Promise(Result(a, e)),
) -> Promise(Result(a, e)) {
  use result <- await(primary)
  
  case result {
    Ok(value) -> resolve(Ok(value))
    Error(_) -> fallback()
  }
}

pub fn with_default(
  promise: Promise(Result(a, e)),
  default: a,
) -> Promise(a) {
  use result <- await(promise)
  
  case result {
    Ok(value) -> resolve(value)
    Error(_) -> resolve(default)
  }
}
```

---

## Real-World Patterns

### Batch Processing

```gleam
pub fn batch_process(
  items: List(a),
  process: fn(a) -> Promise(Result(b, e)),
  batch_size: Int,
) -> Promise(Result(List(b), e)) {
  items
  |> list.chunk(batch_size)
  |> traverse(fn(batch) {
    batch
    |> list.map(process)
    |> promise.all
    |> map(fn(results) {
      results
      |> list.fold(Ok([]), fn(acc, result) {
        case acc, result {
          Ok(acc_list), Ok(value) -> Ok([value, ..acc_list])
          Error(e), _ -> Error(e)
          _, Error(e) -> Error(e)
        }
      })
    })
  })
  |> map(fn(batch_results) {
    batch_results
    |> list.fold(Ok([]), fn(acc, batch_result) {
      case acc, batch_result {
        Ok(acc_list), Ok(batch) -> Ok(acc_list ++ batch)
        Error(e), _ -> Error(e)
        _, Error(e) -> Error(e)
      }
    })
  })
}
```

### Rate Limiting

```gleam
pub type RateLimiter {
  RateLimiter(
    max_concurrent: Int,
    current: Int,
    queue: List(fn() -> Promise(a)),
  )
}

pub fn with_rate_limit(
  limiter: RateLimiter,
  action: fn() -> Promise(a),
) -> Promise(#(a, RateLimiter)) {
  case limiter.current < limiter.max_concurrent {
    True -> {
      use result <- await(action())
      resolve(#(result, RateLimiter(
        max_concurrent: limiter.max_concurrent,
        current: limiter.current - 1,
        queue: limiter.queue,
      )))
    }
    False -> {
      let new_limiter = RateLimiter(
        max_concurrent: limiter.max_concurrent,
        current: limiter.current,
        queue: [action, ..limiter.queue],
      )
      resolve(#(promise.await(action(), fn(a) { a }), new_limiter))
    }
  }
}
```

---

## Integration with TypeScript

### Async Bridge

```typescript
// async-bridge.ts
import * as async from './gleam/traenupi_core/build/dev/javascript/traenupi_core/traenupi_core/async.mjs';

export class AsyncUtils {
  static async map<T, R>(
    promise: Promise<T>,
    f: (value: T) => R
  ): Promise<R> {
    return async.map(promise, f);
  }

  static async sequence<T>(promises: Promise<T>[]): Promise<T[]> {
    return async.sequence(promises);
  }

  static async traverse<T, R>(
    items: T[],
    f: (item: T) => Promise<R>
  ): Promise<R[]> {
    return async.traverse(items, f);
  }

  static async retry<T, E>(
    action: () => Promise<T>,
    maxAttempts: number,
    delayMs: number
  ): Promise<T> {
    return async.retry(action, maxAttempts, delayMs);
  }

  static async withTimeout<T>(
    promise: Promise<T>,
    ms: number,
    defaultValue: T
  ): Promise<T> {
    return async.timeout(promise, ms, defaultValue);
  }

  static sleep(ms: number): Promise<void> {
    return async.sleep(ms);
  }
}
```

---

## Summary

| Aspect | TypeScript | Gleam |
|--------|------------|-------|
| Error handling | Try/catch | Result type |
| Composition | .then() chains | await expressions |
| Parallel | Promise.all() | promise.all() |
| Retry | Manual | Built-in combinator |
| Timeout | Promise.race() | Built-in combinator |

## Key Takeaways

1. **Result type for errors** - No exceptions
2. **Combinators are reusable** - retry, timeout, fallback
3. **Type-safe async** - Compiler catches mistakes
4. **Parallel is easy** - promise.all() works naturally
5. **Testing is simple** - Mock promises, not time

## Next Steps

In **Chapter 11**, we'll explore:
- Unit testing strategies
- Property-based testing
- Test organization

---

*Continue to [Chapter 11: Testing Strategies](./chapter-11.md)*
