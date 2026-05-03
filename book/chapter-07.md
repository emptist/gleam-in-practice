# Chapter 7: State Management

> "Immutability is not a constraint, it's a superpower."
> 
> — Functional programming wisdom

## Immutable State Patterns

### The TypeScript Problem

```typescript
// TypeScript - mutable state
interface AppState {
  user: User | null;
  tasks: Task[];
  loading: boolean;
  error: string | null;
}

let state: AppState = {
  user: null,
  tasks: [],
  loading: false,
  error: null,
};

// Mutation is easy but dangerous
function addTask(task: Task) {
  state.tasks.push(task); // Mutates in place!
}

// Hard to track changes
function updateTask(id: string, updates: Partial<Task>) {
  const index = state.tasks.findIndex(t => t.id === id);
  if (index !== -1) {
    state.tasks[index] = { ...state.tasks[index], ...updates }; // Mutation!
  }
}
```

### The Gleam Solution

```gleam
pub type AppState {
  AppState(
    user: Option(User),
    tasks: List(Task),
    loading: Bool,
    error: Option(String),
  )
}

pub fn init() -> AppState {
  AppState(
    user: None,
    tasks: [],
    loading: False,
    error: None,
  )
}

// Every "mutation" returns a new state
pub fn add_task(state: AppState, task: Task) -> AppState {
  AppState(..state, tasks: [task, ..state.tasks])
}

pub fn update_task(state: AppState, id: String, updates: TaskUpdates) -> AppState {
  let tasks = 
    state.tasks
    |> list.map(fn(t) {
      case t.id == id {
        True -> apply_updates(t, updates)
        False -> t
      }
    })
  AppState(..state, tasks: tasks)
}
```

---

## State Machines in Gleam

### Defining States

```gleam
pub type TaskState {
  Pending
  Running(progress: Int)
  Completed(result: String)
  Failed(error: String)
}

pub type TaskEvent {
  Start
  UpdateProgress(Int)
  Complete(String)
  Fail(String)
}

pub fn transition(state: TaskState, event: TaskEvent) -> TaskState {
  case state, event {
    Pending, Start -> Running(progress: 0)
    Running(_), UpdateProgress(p) -> Running(progress: p)
    Running(_), Complete(r) -> Completed(result: r)
    Running(_), Fail(e) -> Failed(error: e)
    Failed(_), Start -> Running(progress: 0) // Retry
    _, _ -> state // Invalid transition, stay in current state
  }
}
```

### Valid Transitions

```gleam
pub fn can_transition(state: TaskState, event: TaskEvent) -> Bool {
  case state, event {
    Pending, Start -> True
    Running(_), UpdateProgress(_) -> True
    Running(_), Complete(_) -> True
    Running(_), Fail(_) -> True
    Failed(_), Start -> True
    _, _ -> False
  }
}

pub fn safe_transition(state: TaskState, event: TaskEvent) 
    -> Result(TaskState, String) {
  case can_transition(state, event) {
    True -> Ok(transition(state, event))
    False -> Error("Invalid transition from " <> state_name(state))
  }
}
```

---

## Real Example: state.gleam

From TraeNuPI's implementation (216 lines):

```gleam
// state.gleam
import gleam/option.{type Option, None, Some}
import gleam/dict.{type Dict}

pub type State {
  State(
    session_id: String,
    status: Status,
    context: Dict(String, String),
    history: List(HistoryEntry),
    created_at: Int,
    updated_at: Int,
  )
}

pub type Status {
  Idle
  Thinking
  Waiting
  Completed
  Error(String)
}

pub type HistoryEntry {
  HistoryEntry(
    role: Role,
    content: String,
    timestamp: Int,
  )
}

pub type Role {
  User
  Assistant
  System
}

pub fn new(session_id: String) -> State {
  State(
    session_id: session_id,
    status: Idle,
    context: dict.new(),
    history: [],
    created_at: now(),
    updated_at: now(),
  )
}

pub fn set_status(state: State, status: Status) -> State {
  State(..state, status: status, updated_at: now())
}

pub fn add_context(state: State, key: String, value: String) -> State {
  State(..state, context: dict.insert(state.context, key, value), updated_at: now())
}

pub fn add_message(state: State, role: Role, content: String) -> State {
  let entry = HistoryEntry(role: role, content: content, timestamp: now())
  State(..state, history: [entry, ..state.history], updated_at: now())
}

pub fn get_context(state: State, key: String) -> Option(String) {
  dict.get(state.context, key)
}

pub fn get_recent_history(state: State, limit: Int) -> List(HistoryEntry) {
  state.history
  |> list.take(limit)
}

pub fn is_idle(state: State) -> Bool {
  state.status == Idle
}

pub fn is_thinking(state: State) -> Bool {
  case state.status {
    Thinking -> True
    _ -> False
  }
}

pub fn is_completed(state: State) -> Bool {
  state.status == Completed
}

pub fn has_error(state: State) -> Bool {
  case state.status {
    Error(_) -> True
    _ -> False
  }
}

pub fn clear_history(state: State) -> State {
  State(..state, history: [], updated_at: now())
}

pub fn merge_context(state: State, other: Dict(String, String)) -> State {
  let merged = 
    dict.to_list(other)
    |> list.fold(state.context, fn(acc, pair) {
      let #(key, value) = pair
      dict.insert(acc, key, value)
    })
  State(..state, context: merged, updated_at: now())
}
```

---

## State Accumulator Pattern

### Building State Through Operations

```gleam
pub type Builder {
  Builder(
    items: List(Item),
    errors: List(String),
    warnings: List(String),
  )
}

pub fn new_builder() -> Builder {
  Builder(items: [], errors: [], warnings: [])
}

pub fn add_item(builder: Builder, item: Item) -> Builder {
  Builder(..builder, items: [item, ..builder.items])
}

pub fn add_error(builder: Builder, error: String) -> Builder {
  Builder(..builder, errors: [error, ..builder.errors])
}

pub fn add_warning(builder: Builder, warning: String) -> Builder {
  Builder(..builder, warnings: [warning, ..builder.warnings])
}

pub fn build(builder: Builder) -> Result(List(Item), List(String)) {
  case builder.errors {
    [] -> Ok(builder.items)
    errors -> Error(errors)
  }
}
```

### Chaining State Operations

```gleam
pub fn process_items(items: List(String)) -> Result(List(Item), List(String)) {
  new_builder()
  |> process_all(items)
  |> build()
}

fn process_all(builder: Builder, items: List(String)) -> Builder {
  items
  |> list.fold(builder, fn(b, item) {
    case parse_item(item) {
      Ok(parsed) -> add_item(b, parsed)
      Error(e) -> add_error(b, e)
    }
  })
}
```

---

## State and Concurrency

### No Race Conditions

```gleam
// In Gleam, immutability means no race conditions
pub fn concurrent_update(state: State, updates: List(String)) -> State {
  // Each update is independent
  updates
  |> list.fold(state, fn(s, update) {
    apply_update(s, update)
  })
}

// The result is deterministic regardless of execution order
// because each step produces a new state
```

### State Snapshots

```gleam
pub type StateStore {
  StateStore(
    current: State,
    history: List(State),
    max_history: Int,
  )
}

pub fn snapshot(store: StateStore) -> StateStore {
  StateStore(
    current: store.current,
    history: [store.current, ..store.history]
      |> list.take(store.max_history),
    max_history: store.max_history,
  )
}

pub fn rollback(store: StateStore) -> Result(StateStore, String) {
  case store.history {
    [previous, ..rest] -> Ok(StateStore(
      current: previous,
      history: rest,
      max_history: store.max_history,
    ))
    [] -> Error("No history to rollback to")
  }
}
```

---

## Integration with TypeScript

### State Bridge

```typescript
// state-bridge.ts
import * as state from './gleam/traenupi_core/build/dev/javascript/traenupi_core/traenupi_core/state.mjs';

export class StateManager {
  private state: any;

  constructor(sessionId: string) {
    this.state = state.new(sessionId);
  }

  setStatus(status: 'idle' | 'thinking' | 'waiting' | 'completed' | string): void {
    const gleamStatus = this.toGleamStatus(status);
    this.state = state.set_status(this.state, gleamStatus);
  }

  addContext(key: string, value: string): void {
    this.state = state.add_context(this.state, key, value);
  }

  addMessage(role: 'user' | 'assistant' | 'system', content: string): void {
    const gleamRole = this.toGleamRole(role);
    this.state = state.add_message(this.state, gleamRole, content);
  }

  getRecentHistory(limit: number): any[] {
    return state.get_recent_history(this.state, limit);
  }

  private toGleamStatus(status: string): any {
    switch (status) {
      case 'idle': return { type: 'Idle' };
      case 'thinking': return { type: 'Thinking' };
      case 'waiting': return { type: 'Waiting' };
      case 'completed': return { type: 'Completed' };
      default: return { type: 'Error', value: status };
    }
  }

  private toGleamRole(role: string): any {
    switch (role) {
      case 'user': return { type: 'User' };
      case 'assistant': return { type: 'Assistant' };
      case 'system': return { type: 'System' };
      default: return { type: 'User' };
    }
  }
}
```

---

## Summary

| Aspect | TypeScript | Gleam |
|--------|------------|-------|
| Mutability | Mutable by default | Immutable by default |
| State updates | In-place mutation | Returns new state |
| Race conditions | Possible | Impossible |
| History | Manual | Natural (keep old states) |
| State machines | Libraries needed | Pattern matching |

## Key Takeaways

1. **Immutability eliminates race conditions** - No shared mutable state
2. **State machines are natural** - Pattern matching defines transitions
3. **History is free** - Keep old states for undo/redo
4. **Updates are explicit** - Every change returns a new state
5. **Testing is easy** - Pure functions, no mocking needed

## Next Steps

In **Chapter 8**, we'll explore:
- Building a validation library
- Composable validators
- Error accumulation

---

*Continue to [Chapter 8: Validation](./chapter-08.md)*
