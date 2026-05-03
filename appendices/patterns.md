# Appendix B: Common Patterns

## 1. Builder Pattern

Build complex objects step by step:

```gleam
pub type QueryBuilder {
  QueryBuilder(
    table: String,
    columns: List(String),
    where_clause: Option(String),
    order_by: Option(String),
    limit: Option(Int),
  )
}

pub fn new(table: String) -> QueryBuilder {
  QueryBuilder(
    table: table,
    columns: [],
    where_clause: None,
    order_by: None,
    limit: None,
  )
}

pub fn select(builder: QueryBuilder, columns: List(String)) -> QueryBuilder {
  QueryBuilder(..builder, columns: columns)
}

pub fn where_(builder: QueryBuilder, clause: String) -> QueryBuilder {
  QueryBuilder(..builder, where_clause: Some(clause))
}

pub fn order_by(builder: QueryBuilder, column: String) -> QueryBuilder {
  QueryBuilder(..builder, order_by: Some(column))
}

pub fn limit(builder: QueryBuilder, n: Int) -> QueryBuilder {
  QueryBuilder(..builder, limit: Some(n))
}

pub fn build(builder: QueryBuilder) -> String {
  let cols = case builder.columns {
    [] -> "*"
    c -> string.join(c, ", ")
  }
  
  let base = "SELECT " <> cols <> " FROM " <> builder.table
  
  let with_where = case builder.where_clause {
    Some(clause) -> base <> " WHERE " <> clause
    None -> base
  }
  
  let with_order = case builder.order_by {
    Some(col) -> with_where <> " ORDER BY " <> col
    None -> with_where
  }
  
  case builder.limit {
    Some(n) -> with_order <> " LIMIT " <> int.to_string(n)
    None -> with_order
  }
}

// Usage
let query = 
  new("users")
  |> select(["id", "name", "email"])
  |> where_("active = true")
  |> order_by("created_at")
  |> limit(10)
  |> build()
// "SELECT id, name, email FROM users WHERE active = true ORDER BY created_at LIMIT 10"
```

## 2. State Machine

Model complex state transitions:

```gleam
pub type OrderState {
  Created
  Paid(payment_id: String)
  Shipped(tracking: String)
  Delivered
  Cancelled(reason: String)
}

pub type OrderEvent {
  Pay(String)
  Ship(String)
  Deliver
  Cancel(String)
}

pub fn transition(state: OrderState, event: OrderEvent) -> Result(OrderState, String) {
  case state, event {
    Created, Pay(id) -> Ok(Paid(id))
    Paid(_), Ship(tracking) -> Ok(Shipped(tracking))
    Shipped(_), Deliver -> Ok(Delivered)
    Created, Cancel(r) -> Ok(Cancelled(r))
    Paid(_), Cancel(r) -> Ok(Cancelled(r))
    _, _ -> Error("Invalid transition")
  }
}

pub fn can_transition(state: OrderState, event: OrderEvent) -> Bool {
  case state, event {
    Created, Pay(_) -> True
    Paid(_), Ship(_) -> True
    Shipped(_), Deliver -> True
    Created, Cancel(_) -> True
    Paid(_), Cancel(_) -> True
    _, _ -> False
  }
}
```

## 3. Result Composition

Chain operations that can fail:

```gleam
pub fn process_order(order: Order) -> Result(Receipt, OrderError) {
  use validated <- result.try(validate_order(order))
  use inventory <- result.try(check_inventory(validated))
  use payment <- result.try(process_payment(validated))
  use shipment <- result.try(create_shipment(inventory, payment))
  Ok(create_receipt(shipment))
}

// With error context
pub fn with_context(
  result: Result(a, e),
  context: fn(e) -> String,
) -> Result(a, String) {
  case result {
    Ok(value) -> Ok(value)
    Error(e) -> Error(context(e))
  }
}
```

## 4. Option Composition

Chain operations that might return nothing:

```gleam
pub fn find_user_email(db: Db, user_id: String) -> Option(String) {
  use user <- option.try(get_user(db, user_id))
  use profile <- option.try(get_profile(db, user.profile_id))
  profile.email
}

// With default
pub fn get_email_with_default(db: Db, user_id: String) -> String {
  find_user_email(db, user_id)
  |> option.unwrap("no-email@example.com")
}
```

## 5. Validation Pattern

Accumulate multiple validation errors:

```gleam
pub type ValidationResult(a, e) {
  Valid(a)
  Invalid(List(e))
}

pub fn validate_user(input: UserInput) -> ValidationResult(User, ValidationError) {
  let name_result = validate_name(input.name)
  let email_result = validate_email(input.email)
  let age_result = validate_age(input.age)
  
  let errors = 
    errors_from(name_result) ++ 
    errors_from(email_result) ++ 
    errors_from(age_result)
  
  case errors {
    [] -> Valid(User(name: input.name, email: input.email, age: input.age))
    _ -> Invalid(errors)
  }
}

fn errors_from(result: ValidationResult(a, e)) -> List(e) {
  case result {
    Valid(_) -> []
    Invalid(errors) -> errors
  }
}
```

## 6. Repository Pattern

Abstract data access:

```gleam
pub type Repository(a, e) {
  Repository(
    get: fn(String) -> Promise(Result(a, e)),
    list: fn() -> Promise(Result(List(a), e)),
    save: fn(a) -> Promise(Result(a, e)),
    delete: fn(String) -> Promise(Result(Nil, e)),
  )
}

pub fn new_task_repository(db: Connection) -> Repository(Task, DbError) {
  Repository(
    get: fn(id) { get_task(db, id) },
    list: fn() { list_tasks(db) },
    save: fn(task) { save_task(db, task) },
    delete: fn(id) { delete_task(db, id) },
  )
}
```

## 7. Cache Pattern

Memoize expensive operations:

```gleam
pub type Cache(k, v) {
  Cache(
    data: Dict(k, #(v, Int)),
    ttl_ms: Int,
  )
}

pub fn cached(
  cache: Cache(k, v),
  key: k,
  fetch: fn(k) -> Promise(v),
  now: Int,
) -> Promise(#(v, Cache(k, v))) {
  case dict.get(cache.data, key) {
    Ok(#(value, expires_at)) if now < expires_at -> {
      promise.resolve(#(value, cache))
    }
    _ -> {
      use value <- promise.await(fetch(key))
      let new_cache = Cache(
        data: dict.insert(cache.data, key, #(value, now + cache.ttl_ms)),
        ttl_ms: cache.ttl_ms,
      )
      promise.resolve(#(value, new_cache))
    }
  }
}
```

## 8. Observer Pattern

Notify subscribers of changes:

```gleam
pub type Observer(a) {
  Observer(notify: fn(a) -> Nil)
}

pub type Observable(a) {
  Observable(
    value: a,
    observers: List(Observer(a)),
  )
}

pub fn subscribe(observable: Observable(a), observer: Observer(a)) -> Observable(a) {
  Observable(..observable, observers: [observer, ..observable.observers])
}

pub fn update(observable: Observable(a), f: fn(a) -> a) -> Observable(a) {
  let new_value = f(observable.value)
  
  observable.observers
  |> list.each(fn(obs) { obs.notify(new_value) })
  
  Observable(..observable, value: new_value)
}
```

## 9. Decorator Pattern

Add behavior without modifying:

```gleam
pub type Logger(a) {
  Logger(log: fn(String, a) -> a)
}

pub fn with_logging(
  logger: Logger(a),
  name: String,
  f: fn() -> a,
) -> a {
  let result = f()
  logger.log(name, result)
  result
}

pub fn timed(f: fn() -> a) -> #(a, Int) {
  let start = now()
  let result = f()
  let elapsed = now() - start
  #(result, elapsed)
}
```

## 10. Strategy Pattern

Swap algorithms at runtime:

```gleam
pub type SortStrategy(a) {
  SortStrategy(sort: fn(List(a)) -> List(a))
}

pub fn bubble_sort() -> SortStrategy(a) {
  SortStrategy(fn(list) { 
    // bubble sort implementation
    list 
  })
}

pub fn quick_sort(compare: fn(a, a) -> Order) -> SortStrategy(a) {
  SortStrategy(fn(list) { 
    // quick sort implementation
    list 
  })
}

pub fn sort(list: List(a), strategy: SortStrategy(a)) -> List(a) {
  strategy.sort(list)
}
```
