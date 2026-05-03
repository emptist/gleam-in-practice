# Chapter 9: Caching

> "Cache invalidation is one of the hardest problems in computer science. But with immutable data, it becomes much simpler."
> 
> — Functional programming wisdom

## TTL-Based Cache

### The TypeScript Approach

```typescript
// TypeScript - mutable cache with expiration
class TTLCache<T> {
  private cache = new Map<string, { value: T; expires: number }>();
  
  get(key: string): T | undefined {
    const entry = this.cache.get(key);
    if (!entry) return undefined;
    
    if (Date.now() > entry.expires) {
      this.cache.delete(key);
      return undefined;
    }
    
    return entry.value;
  }
  
  set(key: string, value: T, ttlMs: number): void {
    this.cache.set(key, {
      value,
      expires: Date.now() + ttlMs,
    });
  }
  
  clear(): void {
    this.cache.clear();
  }
}
```

### The Gleam Approach

```gleam
pub type CacheEntry(a) {
  CacheEntry(value: a, expires_at: Int)
}

pub type TTLCache(a) {
  TTLCache(
    entries: Dict(String, CacheEntry(a)),
    default_ttl_ms: Int,
  )
}

pub fn new(default_ttl_ms: Int) -> TTLCache(a) {
  TTLCache(entries: dict.new(), default_ttl_ms: default_ttl_ms)
}

pub fn get(cache: TTLCache(a), key: String, now: Int) -> Option(#(a, TTLCache(a))) {
  case dict.get(cache.entries, key) {
    Ok(entry) -> {
      case now < entry.expires_at {
        True -> Some(#(entry.value, cache))
        False -> {
          let new_entries = dict.delete(cache.entries, key)
          None
        }
      }
    }
    Error(_) -> None
  }
}

pub fn set(cache: TTLCache(a), key: String, value: a, now: Int) -> TTLCache(a) {
  let entry = CacheEntry(
    value: value,
    expires_at: now + cache.default_ttl_ms,
  )
  TTLCache(..cache, entries: dict.insert(cache.entries, key, entry))
}

pub fn set_with_ttl(
  cache: TTLCache(a),
  key: String,
  value: a,
  ttl_ms: Int,
  now: Int,
) -> TTLCache(a) {
  let entry = CacheEntry(
    value: value,
    expires_at: now + ttl_ms,
  )
  TTLCache(..cache, entries: dict.insert(cache.entries, key, entry))
}

pub fn remove(cache: TTLCache(a), key: String) -> TTLCache(a) {
  TTLCache(..cache, entries: dict.delete(cache.entries, key))
}

pub fn clear(cache: TTLCache(a)) -> TTLCache(a) {
  TTLCache(..cache, entries: dict.new())
}

pub fn cleanup(cache: TTLCache(a), now: Int) -> TTLCache(a) {
  let valid_entries = 
    dict.to_list(cache.entries)
    |> list.filter(fn(pair) {
      let #(_, entry) = pair
      now < entry.expires_at
    })
  
  TTLCache(..cache, entries: dict.from_list(valid_entries))
}
```

---

## LRU Cache

### Least Recently Used Eviction

```gleam
pub type LRUCache(a) {
  LRUCache(
    data: Dict(String, #(a, Int)),
    access_order: List(String),
    max_size: Int,
    current_time: Int,
  )
}

pub fn new_lru(max_size: Int) -> LRUCache(a) {
  LRUCache(
    data: dict.new(),
    access_order: [],
    max_size: max_size,
    current_time: 0,
  )
}

pub fn get_lru(cache: LRUCache(a), key: String) -> Option(#(a, LRUCache(a))) {
  case dict.get(cache.data, key) {
    Ok(#(value, _)) -> {
      let new_order = 
        cache.access_order
        |> list.filter(fn(k) { k != key })
        |> list.prepend([key])
      
      let new_data = dict.insert(cache.data, key, #(value, cache.current_time + 1))
      
      let new_cache = LRUCache(
        data: new_data,
        access_order: new_order,
        max_size: cache.max_size,
        current_time: cache.current_time + 1,
      )
      
      Some(#(value, new_cache))
    }
    Error(_) -> None
  }
}

pub fn set_lru(cache: LRUCache(a), key: String, value: a) -> LRUCache(a) {
  let cache = case dict.has_key(cache.data, key) {
    True -> cache
    False -> evict_if_needed(cache)
  }
  
  let new_order = 
    cache.access_order
    |> list.filter(fn(k) { k != key })
    |> list.prepend([key])
  
  let new_data = dict.insert(cache.data, key, #(value, cache.current_time + 1))
  
  LRUCache(
    data: new_data,
    access_order: new_order,
    max_size: cache.max_size,
    current_time: cache.current_time + 1,
  )
}

fn evict_if_needed(cache: LRUCache(a)) -> LRUCache(a) {
  case dict.size(cache.data) >= cache.max_size {
    True -> {
      case list.reverse(cache.access_order) {
        [oldest, ..rest] -> {
          LRUCache(
            data: dict.delete(cache.data, oldest),
            access_order: list.reverse(rest),
            max_size: cache.max_size,
            current_time: cache.current_time,
          )
        }
        _ -> cache
      }
    }
    False -> cache
  }
}
```

---

## Real Example: cache.gleam

From TraeNuPI's implementation (214 lines):

```gleam
// cache.gleam
import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/int

pub type CacheEntry(a) {
  CacheEntry(value: a, expires_at: Int)
}

pub type TTLCache(a) {
  TTLCache(
    entries: Dict(String, CacheEntry(a)),
    default_ttl_ms: Int,
    stats: CacheStats,
  )
}

pub type CacheStats {
  CacheStats(hits: Int, misses: Int, evictions: Int)
}

pub fn new(default_ttl_ms: Int) -> TTLCache(a) {
  TTLCache(
    entries: dict.new(),
    default_ttl_ms: default_ttl_ms,
    stats: CacheStats(hits: 0, misses: 0, evictions: 0),
  )
}

pub fn get(cache: TTLCache(a), key: String, now: Int) 
    -> Option(#(a, TTLCache(a))) {
  case dict.get(cache.entries, key) {
    Ok(entry) -> {
      case now < entry.expires_at {
        True -> {
          let new_stats = CacheStats(
            hits: cache.stats.hits + 1,
            misses: cache.stats.misses,
            evictions: cache.stats.evictions,
          )
          Some(#(entry.value, TTLCache(..cache, stats: new_stats)))
        }
        False -> {
          let new_entries = dict.delete(cache.entries, key)
          let new_stats = CacheStats(
            hits: cache.stats.hits,
            misses: cache.stats.misses + 1,
            evictions: cache.stats.evictions + 1,
          )
          None
        }
      }
    }
    Error(_) -> {
      let new_stats = CacheStats(
        hits: cache.stats.hits,
        misses: cache.stats.misses + 1,
        evictions: cache.stats.evictions,
      )
      None
    }
  }
}

pub fn get_or_compute(
  cache: TTLCache(a),
  key: String,
  compute: fn() -> a,
  now: Int,
) -> #(a, TTLCache(a)) {
  case get(cache, key, now) {
    Some(#(value, new_cache)) -> #(value, new_cache)
    None -> {
      let value = compute()
      let new_cache = set(cache, key, value, now)
      #(value, new_cache)
    }
  }
}

pub fn stats(cache: TTLCache(a)) -> CacheStats {
  cache.stats
}

pub fn hit_rate(cache: TTLCache(a)) -> Float {
  let total = cache.stats.hits + cache.stats.misses
  case total {
    0 -> 0.0
    _ -> int.to_float(cache.stats.hits) /. int.to_float(total)
  }
}
```

---

## Cache Patterns

### Memoization

```gleam
pub fn memoize(
  cache: TTLCache(a),
  key: String,
  compute: fn() -> a,
  ttl_ms: Int,
  now: Int,
) -> #(a, TTLCache(a)) {
  case get(cache, key, now) {
    Some(#(value, new_cache)) -> #(value, new_cache)
    None -> {
      let value = compute()
      let new_cache = set_with_ttl(cache, key, value, ttl_ms, now)
      #(value, new_cache)
    }
  }
}
```

### Cache-Aside Pattern

```gleam
pub fn cache_aside(
  cache: TTLCache(a),
  key: String,
  fetch: fn() -> Promise(Result(a, e)),
  ttl_ms: Int,
  now: Int,
) -> Promise(Result(a, e)) {
  case get(cache, key, now) {
    Some(#(value, _)) -> promise.resolve(Ok(value))
    None -> {
      use result <- promise.await(fetch())
      case result {
        Ok(value) -> {
          let _ = set_with_ttl(cache, key, value, ttl_ms, now)
          promise.resolve(Ok(value))
        }
        Error(e) -> promise.resolve(Error(e))
      }
    }
  }
}
```

### Write-Through Pattern

```gleam
pub fn write_through(
  cache: TTLCache(a),
  key: String,
  value: a,
  write: fn(String, a) -> Promise(Result(Nil, e)),
  ttl_ms: Int,
  now: Int,
) -> Promise(Result(TTLCache(a), e)) {
  use result <- promise.await(write(key, value))
  case result {
    Ok(_) -> {
      let new_cache = set_with_ttl(cache, key, value, ttl_ms, now)
      promise.resolve(Ok(new_cache))
    }
    Error(e) -> promise.resolve(Error(e))
  }
}
```

---

## Integration with TypeScript

### Cache Bridge

```typescript
// cache-bridge.ts
import * as cache from './gleam/traenupi_core/build/dev/javascript/traenupi_core/traenupi_core/cache.mjs';

export class CacheManager<T> {
  private cache: any;

  constructor(defaultTtlMs: number = 60000) {
    this.cache = cache.new(defaultTtlMs);
  }

  get(key: string): T | undefined {
    const now = Date.now();
    const result = cache.get(this.cache, key, now);
    
    if (result && result.type === 'Some') {
      const [value, newCache] = result.value;
      this.cache = newCache;
      return value;
    }
    
    return undefined;
  }

  set(key: string, value: T, ttlMs?: number): void {
    const now = Date.now();
    if (ttlMs) {
      this.cache = cache.set_with_ttl(this.cache, key, value, ttlMs, now);
    } else {
      this.cache = cache.set(this.cache, key, value, now);
    }
  }

  getOrCompute(key: string, compute: () => T): T {
    const now = Date.now();
    const [value, newCache] = cache.get_or_compute(
      this.cache,
      key,
      compute,
      now
    );
    this.cache = newCache;
    return value;
  }

  stats(): { hits: number; misses: number; evictions: number } {
    return cache.stats(this.cache);
  }

  hitRate(): number {
    return cache.hit_rate(this.cache);
  }
}
```

---

## Summary

| Aspect | TypeScript | Gleam |
|--------|------------|-------|
| Mutability | In-place updates | Returns new cache |
| Thread safety | Needs locks | Naturally safe |
| Testing | Mock time | Pass time as param |
| Stats tracking | Manual | Built-in |
| Eviction | Side effects | Pure functions |

## Key Takeaways

1. **Immutable caches are thread-safe** - No race conditions
2. **Time is a parameter** - Easy to test
3. **Stats come for free** - Track hits/misses in type
4. **Eviction is explicit** - No hidden side effects
5. **Composition is natural** - Combine caches easily

## Next Steps

In **Chapter 10**, we'll explore:
- Promise combinators
- Async patterns
- Error handling in async code

---

*Continue to [Chapter 10: Async Programming](./chapter-10.md)*
