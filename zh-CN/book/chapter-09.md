# 第九章：缓存

## 为什么需要缓存？

缓存可以显著提高应用程序性能：

- **减少数据库查询** - 缓存频繁访问的数据
- **降低延迟** - 快速响应重复请求
- **节省资源** - 减少计算和网络开销

## TTL 缓存

### 基本实现

```gleam
// src/traenupi_core/cache.gleam
pub type CacheEntry(a) {
  CacheEntry(
    value: a,
    created_at: Int,
    ttl_ms: Int,
  )
}

pub type Cache(a) {
  Cache(
    entries: Dict(String, CacheEntry(a)),
    default_ttl: Int,
  )
}

pub fn new(default_ttl: Int) -> Cache(a) {
  Cache(
    entries: dict.new(),
    default_ttl: default_ttl,
  )
}

pub fn get(cache: Cache(a), key: String) -> Option(a) {
  case dict.get(cache.entries, key) {
    Some(entry) -> {
      case is_expired(entry) {
        True -> None
        False -> Some(entry.value)
      }
    }
    None -> None
  }
}

pub fn set(cache: Cache(a), key: String, value: a) -> Cache(a) {
  set_with_ttl(cache, key, value, cache.default_ttl)
}

pub fn set_with_ttl(cache: Cache(a), key: String, value: a, ttl_ms: Int) -> Cache(a) {
  let entry = CacheEntry(
    value: value,
    created_at: now(),
    ttl_ms: ttl_ms,
  )
  
  Cache(..cache, entries: dict.insert(cache.entries, key, entry))
}

pub fn delete(cache: Cache(a), key: String) -> Cache(a) {
  Cache(..cache, entries: dict.delete(cache.entries, key))
}

pub fn clear(cache: Cache(a)) -> Cache(a) {
  Cache(..cache, entries: dict.new())
}

pub fn cleanup(cache: Cache(a)) -> Cache(a) {
  let entries = cache.entries
    |> dict.filter(fn(_, entry) { !is_expired(entry) })
  
  Cache(..cache, entries: entries)
}

fn is_expired(entry: CacheEntry(a)) -> Bool {
  let current_time = now()
  let expires_at = entry.created_at + entry.ttl_ms
  
  current_time > expires_at
}
```

### 使用示例

```gleam
pub fn example() {
  // 创建缓存，默认 TTL 5 分钟
  let cache = cache.new(5 * 60 * 1000)
  
  // 设置值
  let cache = cache.set(cache, "user:1", User(id: 1, name: "Alice"))
  
  // 获取值
  case cache.get(cache, "user:1") {
    Some(user) -> io.println("找到用户: " <> user.name)
    None -> io.println("用户不存在或已过期")
  }
  
  // 自定义 TTL
  let cache = cache.set_with_ttl(cache, "session:abc", session, 30 * 60 * 1000)
  
  // 清理过期条目
  let cache = cache.cleanup(cache)
}
```

## LRU 缓存

### 基本实现

```gleam
pub type LRUCache(a) {
  LRUCache(
    entries: Dict(String, #(a, Int)),  // value 和最后访问时间
    max_size: Int,
    current_time: Int,
  )
}

pub fn lru_new(max_size: Int) -> LRUCache(a) {
  LRUCache(
    entries: dict.new(),
    max_size: max_size,
    current_time: 0,
  )
}

pub fn lru_get(cache: LRUCache(a), key: String) -> #(Option(a), LRUCache(a)) {
  case dict.get(cache.entries, key) {
    Some(#(value, _)) -> {
      // 更新访问时间
      let new_time = cache.current_time + 1
      let entries = dict.insert(cache.entries, key, #(value, new_time))
      
      #(Some(value), LRUCache(..cache, entries: entries, current_time: new_time))
    }
    None -> #(None, cache)
  }
}

pub fn lru_set(cache: LRUCache(a), key: String, value: a) -> LRUCache(a) {
  let new_time = cache.current_time + 1
  
  // 检查是否需要淘汰
  let entries = case dict.size(cache.entries) >= cache.max_size {
    True -> {
      // 找到最久未使用的条目
      let lru_key = find_lru_key(cache.entries)
      
      case lru_key {
        Some(k) -> dict.delete(cache.entries, k)
        None -> cache.entries
      }
    }
    False -> cache.entries
  }
  
  let entries = dict.insert(entries, key, #(value, new_time))
  
  LRUCache(..cache, entries: entries, current_time: new_time)
}

fn find_lru_key(entries: Dict(String, #(a, Int))) -> Option(String) {
  entries
    |> dict.to_list()
    |> list.sort(fn(a, b) {
      let #(_, #(_, time_a)) = a
      let #(_, #(_, time_b)) = b
      
      time_a > time_b
    })
    |> list.first()
    |> option.map(fn(pair) {
      let #(key, _) = pair
      key
    })
}
```

### 使用示例

```gleam
pub fn lru_example() {
  // 创建 LRU 缓存，最多 100 个条目
  let cache = lru_new(100)
  
  // 设置值
  let cache = lru_set(cache, "key1", "value1")
  let cache = lru_set(cache, "key2", "value2")
  
  // 获取值
  let #(value, cache) = lru_get(cache, "key1")
  
  case value {
    Some(v) -> io.println("找到: " <> v)
    None -> io.println("未找到")
  }
}
```

## 缓存策略

### 缓存穿透保护

```gleam
pub type CacheResult(a) {
  Hit(a)
  Miss
  Stale(a)
}

pub fn get_or_fetch(
  cache: Cache(a),
  key: String,
  fetch: fn() -> Promise(Result(a, String)),
) -> Promise(#(a, Cache(a))) {
  case cache.get(cache, key) {
    Some(value) -> promise.resolve(#(value, cache))
    None -> {
      use result <- promise.try_await(fetch())
      
      case result {
        Ok(value) -> {
          let cache = cache.set(cache, key, value)
          promise.resolve(#(value, cache))
        }
        Error(error) -> {
          // 缓存空值以防止缓存穿透
          let cache = cache.set_with_ttl(cache, key <> ":empty", Nil, 60 * 1000)
          promise.resolve(Error(error))
        }
      }
    }
  }
}
```

### 缓存预热

```gleam
pub fn warmup(
  cache: Cache(a),
  keys: List(String),
  fetch: fn(String) -> Promise(Result(a, String)),
) -> Promise(Cache(a)) {
  list.fold_async(keys, cache, fn(cache, key) {
    use result <- promise.try_await(fetch(key))
    
    case result {
      Ok(value) -> promise.resolve(cache.set(cache, key, value))
      Error(_) -> promise.resolve(cache)
    }
  })
}
```

### 缓存失效

```gleam
pub type InvalidationStrategy {
  TTL(ttl_ms: Int)
  OnChange(signal: String)
  Manual
}

pub fn invalidate_pattern(cache: Cache(a), pattern: String) -> Cache(a) {
  let entries = cache.entries
    |> dict.filter(fn(key, _) {
      !matches_pattern(key, pattern)
    })
  
  Cache(..cache, entries: entries)
}

pub fn invalidate_all(cache: Cache(a)) -> Cache(a) {
  Cache(..cache, entries: dict.new())
}
```

## 小结

在本章中，我们学习了：

1. **TTL 缓存** - 基于时间的缓存过期
2. **LRU 缓存** - 最近最少使用淘汰策略
3. **缓存策略** - 穿透保护、预热、失效

下一章，我们将学习异步编程。
