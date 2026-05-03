# 第十章：异步编程

## Promise 基础

Gleam 的 JavaScript 目标使用 Promise 处理异步操作。

### 基本使用

```gleam
// src/traenupi_core/async.gleam
import gleam/javascript/promise.{type Promise, await, resolve, map, try_await}

pub fn example() -> Promise(String) {
  resolve("Hello")
  |> map(fn(s) { s <> ", World!" })
}

pub fn async_operation() -> Promise(Int) {
  use result <- try_await(fetch_data())
  
  case result {
    Ok(data) -> resolve(process(data))
    Error(_) -> resolve(0)
  }
}
```

### Promise 组合子

```gleam
pub fn all(promises: List(Promise(a))) -> Promise(List(a)) {
  promise.all(promises)
}

pub fn race(promises: List(Promise(a))) -> Promise(a) {
  promise.race(promises)
}

pub fn first_successful(promises: List(Promise(a))) -> Promise(a) {
  promise.any(promises)
}
```

## 并发控制

### 并行执行

```gleam
pub fn parallel_map(items: List(a), f: fn(a) -> Promise(b)) -> Promise(List(b)) {
  items
  |> list.map(f)
  |> promise.all
}

pub fn parallel_filter(items: List(a), predicate: fn(a) -> Promise(Bool)) -> Promise(List(a)) {
  use results <- promise.try_await(
    items
    |> list.map(fn(item) {
      use is_valid <- promise.try_await(predicate(item))
      resolve(#(item, is_valid))
    })
    |> promise.all
  )
  
  resolve(
    results
    |> list.filter(fn(pair) {
      let #(_, is_valid) = pair
      is_valid
    })
    |> list.map(fn(pair) {
      let #(item, _) = pair
      item
    })
  )
}
```

### 限制并发

```gleam
pub type ConcurrencyLimiter {
  ConcurrencyLimiter(max_concurrent: Int, current: Int, queue: List(fn() -> Promise(a)))
}

pub fn limit_concurrency(
  items: List(a),
  max_concurrent: Int,
  f: fn(a) -> Promise(b),
) -> Promise(List(b)) {
  do_limit_concurrency(items, max_concurrent, f, [], [])
}

fn do_limit_concurrency(
  items: List(a),
  max_concurrent: Int,
  f: fn(a) -> Promise(b),
  running: List(Promise(#(Int, b))),
  results: List(b),
) -> Promise(List(b)) {
  case items {
    [] -> {
      case running {
        [] -> resolve(list.reverse(results))
        _ -> {
          use completed <- try_await(promise.race(running))
          let #(index, result) = completed
          let remaining = remove_at(running, index)
          do_limit_concurrency([], max_concurrent, f, remaining, [result, ..results])
        }
      }
    }
    
    [item, ..rest] if list.length(running) < max_concurrent -> {
      let promise = 
        f(item)
        |> map(fn(result) { #(list.length(running), result) })
      
      do_limit_concurrency(rest, max_concurrent, f, [promise, ..running], results)
    }
    
    _ -> {
      use completed <- try_await(promise.race(running))
      let #(index, result) = completed
      let remaining = remove_at(running, index)
      
      let new_promise = 
        f(list.first(items))
        |> map(fn(result) { #(list.length(remaining), result) })
      
      do_limit_concurrency(list.drop(items, 1), max_concurrent, f, [new_promise, ..remaining], [result, ..results])
    }
  }
}
```

## 超时处理

### Promise 超时

```gleam
pub type TimeoutError {
  Timeout(ms: Int)
}

pub fn with_timeout(promise: Promise(a), timeout_ms: Int) -> Promise(Result(a, TimeoutError)) {
  let timeout = 
    sleep(timeout_ms)
    |> map(fn(_) { Error(Timeout(timeout_ms)) })
  
  let success = promise |> map(fn(value) { Ok(value) })
  
  promise.race([timeout, success])
}

@external(javascript, "./async_ffi.mjs", "sleep")
pub fn sleep(ms: Int) -> Promise(Nil)
```

```javascript
// async_ffi.mjs
export function sleep(ms) {
  return new Promise((resolve) => {
    setTimeout(() => resolve(null), ms);
  });
}
```

### 重试机制

```gleam
pub type RetryConfig {
  RetryConfig(
    max_retries: Int,
    initial_delay_ms: Int,
    max_delay_ms: Int,
    multiplier: Float,
  )
}

pub fn with_retry(
  operation: fn() -> Promise(Result(a, e)),
  config: RetryConfig,
) -> Promise(Result(a, e)) {
  do_retry(operation, config, 0, config.initial_delay_ms)
}

fn do_retry(
  operation: fn() -> Promise(Result(a, e)),
  config: RetryConfig,
  attempt: Int,
  delay_ms: Int,
) -> Promise(Result(a, e)) {
  use result <- try_await(operation())
  
  case result {
    Ok(value) -> resolve(Ok(value))
    Error(error) -> {
      case attempt < config.max_retries {
        True -> {
          use _ <- try_await(sleep(delay_ms))
          let new_delay = min(delay_ms * config.multiplier, config.max_delay_ms)
          do_retry(operation, config, attempt + 1, new_delay)
        }
        False -> resolve(Error(error))
      }
    }
  }
}
```

## 错误处理

### 错误边界

```gleam
pub fn catch_error(promise: Promise(a)) -> Promise(Result(a, String)) {
  promise
  |> map(fn(value) { Ok(value) })
  |> promise_rescue(fn(error) { Error(error) })
}

@external(javascript, "./async_ffi.mjs", "rescue")
fn promise_rescue(promise: Promise(a), handler: fn(String) -> a) -> Promise(a)
```

```javascript
// async_ffi.mjs
export function rescue(promise, handler) {
  return promise.catch((error) => {
    return handler(error.message || String(error));
  });
}
```

### 错误恢复

```gleam
pub fn recover(
  promise: Promise(a),
  fallback: fn() -> Promise(a),
) -> Promise(a) {
  use result <- try_await(catch_error(promise))
  
  case result {
    Ok(value) -> resolve(value)
    Error(_) -> fallback()
  }
}
```

## 实战案例

### 并发数据获取

```gleam
pub fn fetch_user_data(user_ids: List(Int)) -> Promise(Result(List(UserData), String)) {
  use results <- try_await(
    user_ids
    |> parallel_map(fn(id) {
      use user <- try_await(fetch_user(id))
      use posts <- try_await(fetch_user_posts(id))
      resolve(Ok(UserData(user: user, posts: posts)))
    })
    |> promise.all
  )
  
  resolve(result.all(results))
}

pub fn fetch_user_data_limited(
  user_ids: List(Int),
  max_concurrent: Int,
) -> Promise(Result(List(UserData), String)) {
  use results <- try_await(
    limit_concurrency(user_ids, max_concurrent, fn(id) {
      use user <- try_await(fetch_user(id))
      use posts <- try_await(fetch_user_posts(id))
      resolve(Ok(UserData(user: user, posts: posts)))
    })
  )
  
  resolve(result.all(results))
}
```

### 批处理

```gleam
pub type BatchConfig {
  BatchConfig(batch_size: Int, delay_ms: Int)
}

pub fn process_batch(
  items: List(a),
  config: BatchConfig,
  processor: fn(List(a)) -> Promise(Result(List(b), e)),
) -> Promise(Result(List(b), e)) {
  let batches = chunk(items, config.batch_size)
  
  use results <- try_await(
    batches
    |> list.index_map(fn(batch, index) {
      use _ <- try_await(sleep(index * config.delay_ms))
      processor(batch)
    })
    |> promise.all
  )
  
  resolve(
    results
    |> result.all()
    |> result.map(list.flatten)
  )
}

fn chunk(list: List(a), size: Int) -> List(List(a)) {
  case list {
    [] -> []
    _ -> {
      let #(first, rest) = list.split(list, size)
      [first, ..chunk(rest, size)]
    }
  }
}
```

## 小结

在本章中，我们学习了：

1. **Promise 基础** - 创建和组合 Promise
2. **并发控制** - 并行执行和限制并发
3. **超时处理** - 超时和重试机制
4. **错误处理** - 错误边界和恢复
5. **实战案例** - 并发数据获取和批处理

下一章，我们将学习测试策略。
