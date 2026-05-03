# Chapter 1: Introduction for TypeScript Developers

> "The best code is no code. The second best is code that's easy to delete."
> 
> Gleam makes both possible.

## Why Gleam? The TypeScript Pain Points

After years of TypeScript development, I discovered Gleam and it changed how I think about code. Here's why:

### Pain Point 1: File Size Explosion

**TypeScript Reality:**
```
src/index.ts: 2,540 lines
src/services/InterReviewService.ts: 1,200+ lines
src/services/MeetingHandler.ts: 800+ lines
```

**Gleam Reality:**
```
schema.gleam: 841 lines (largest)
jsonx.gleam: 601 lines
json_path.gleam: 442 lines
Average: ~250 lines
```

**Why?** Gleam's module system and pattern matching naturally encourage small, focused modules. TypeScript's object-oriented patterns often lead to monolithic classes.

### Pain Point 2: Null/Undefined Hell

**TypeScript:**
```typescript
function getUser(id: string): User | undefined {
  // Did I handle undefined? Maybe?
}

const user = getUser("123");
console.log(user.name); // Error: Object is possibly 'undefined'
console.log(user!.name); // I know better! (famous last words)
```

**Gleam:**
```gleam
pub fn get_user(id: String) -> Result(User, UserError) {
  // Must handle both cases!
}

case get_user("123") {
  Ok(user) -> io.debug(user.name)
  Error(NotFound) -> io.debug("User not found")
  Error(DatabaseError(msg)) -> io.debug("DB error: " <> msg)
}
```

**Why?** Gleam has no null. You must handle errors explicitly. The compiler forces you.

### Pain Point 3: Nested Conditionals

**TypeScript:**
```typescript
function processCommand(cmd: string, args: string[]): Result {
  if (cmd === "create") {
    if (args.length > 0) {
      if (isValidName(args[0])) {
        if (hasPermission(user)) {
          // ... 4 levels deep
        } else {
          return { error: "No permission" };
        }
      } else {
        return { error: "Invalid name" };
      }
    } else {
      return { error: "Missing argument" };
    }
  } else if (cmd === "delete") {
    // ... more nesting
  }
  // ... 100 more lines
}
```

**Gleam:**
```gleam
pub fn process_command(cmd: String, args: List(String)) -> Result(Nil, Error) {
  case cmd, args {
    "create", [name, ..] if is_valid_name(name) -> create_item(name)
    "create", _ -> Error(InvalidName)
    "delete", [id, ..] -> delete_item(id)
    "delete", [] -> Error(MissingArgument)
    _, _ -> Error(UnknownCommand)
  }
}
```

**Why?** Pattern matching flattens conditionals. Each case is one line.

### Pain Point 4: Implicit Any

**TypeScript:**
```typescript
const data = JSON.parse(input); // any
const result = processData(data); // No type checking!
```

**Gleam:**
```gleam
let result = json_decode(input)
case result {
  Ok(data) -> process_data(data) // Type-safe!
  Error(err) -> Error(ParseError(err))
}
```

**Why?** Gleam has no any type. Everything must be typed.

### Pain Point 5: Refactoring Fear

**TypeScript:**
```typescript
// Change User interface
interface User {
  id: string;
  name: string;
  email: string; // Added this
}

// Did I update all usages?
// Did I handle undefined?
// Will runtime catch it?
```

**Gleam:**
```gleam
// Change User type
pub type User {
  User(id: String, name: String, email: String) // Added email
}

// Compiler: "You forgot to update these 12 places"
// Fix all 12, and it works. Guaranteed.
```

**Why?** Gleam's compiler catches every usage. No runtime surprises.

---

## Setting Up Your Environment

### Install Gleam

```bash
# macOS
brew install gleam

# Linux
curl -fsSL https://gleam.run/install.sh | sh

# Verify
gleam --version
# gleam 1.14+
```

### Install Erlang (Required)

```bash
# macOS
brew install erlang

# Linux
apt install erlang
```

### Create Your First Project

```bash
gleam new my_project
cd my_project
gleam run
```

Output:
```
  Compiling my_project
   Built in 0.15s
    Running my_project.main
Hello, from my_project!
```

### Project Structure

```
my_project/
├── gleam.toml          # Project config
├── manifest.toml       # Dependencies lock
├── src/
│   └── my_project.gleam # Main module
└── test/
    └── my_project_test.gleam # Tests
```

### For TypeScript Projects

Add to your TypeScript project:

```bash
cd my-typescript-project
mkdir -p gleam/my_gleam_core
cd gleam/my_gleam_core
gleam new my_gleam_core --target javascript
```

**Important:** Use `--target javascript` for TypeScript integration!

---

## Your First Gleam Module

### The TypeScript Way

```typescript
// utils.ts
export interface User {
  id: string;
  name: string;
  email?: string;
}

export function formatUser(user: User): string {
  return `${user.name} (${user.id})${user.email ? ` <${user.email}>` : ''}`;
}

export function validateEmail(email: string): boolean {
  return email.includes('@');
}
```

### The Gleam Way

```gleam
// utils.gleam
pub type User {
  User(id: String, name: String, email: Option(String))
}

pub fn format_user(user: User) -> String {
  case user.email {
    Some(email) -> user.name <> " (" <> user.id <> ") <" <> email <> ">"
    None -> user.name <> " (" <> user.id <> ")"
  }
}

pub fn validate_email(email: String) -> Bool {
  string.contains(email, "@")
}
```

### Key Differences

| Aspect | TypeScript | Gleam |
|--------|------------|-------|
| Optional fields | `email?: string` | `email: Option(String)` |
| String formatting | Template literals | Concatenation |
| Null handling | `if (email)` | Pattern matching |
| Return type | Implicit | Explicit `-> String` |

---

## The Mental Model Shift

### From OOP to Functional

**TypeScript (OOP):**
```typescript
class UserService {
  private db: Database;
  
  constructor(db: Database) {
    this.db = db;
  }
  
  async getUser(id: string): Promise<User | null> {
    return this.db.query('SELECT * FROM users WHERE id = $1', [id]);
  }
}
```

**Gleam (Functional):**
```gleam
pub fn get_user(db: Database, id: String) -> Promise(Result(User, DbError)) {
  query(db, "SELECT * FROM users WHERE id = $1", [id])
}
```

**Key insight:** No classes, no this, no implicit state. Functions take everything they need as arguments.

### From Mutation to Immutation

**TypeScript:**
```typescript
const user = { name: "Alice", score: 0 };
user.score += 10; // Mutation
```

**Gleam:**
```gleam
let user = User(name: "Alice", score: 0)
let user = User(..user, score: user.score + 10) // New value
```

**Key insight:** Every "mutation" creates a new value. Safer for concurrency, easier to reason about.

### From Exceptions to Results

**TypeScript:**
```typescript
try {
  const user = await getUser(id);
  return user;
} catch (e) {
  console.error(e);
  return null;
}
```

**Gleam:**
```gleam
case get_user(id) {
  Ok(user) -> Ok(user)
  Error(NotFound) -> Error(UserNotFound)
  Error(DbError(msg)) -> Error(DatabaseError(msg))
}
```

**Key insight:** Errors are values, not control flow. The compiler ensures you handle them.

---

## Practical Exercise

Convert this TypeScript code to Gleam:

```typescript
// TypeScript
interface Task {
  id: string;
  title: string;
  status: 'pending' | 'running' | 'done' | 'failed';
  priority: number;
}

function canStart(task: Task): boolean {
  return task.status === 'pending' && task.priority > 0;
}

function start(task: Task): Task {
  if (!canStart(task)) {
    throw new Error('Cannot start task');
  }
  return { ...task, status: 'running' };
}
```

**Solution:**

```gleam
// Gleam
pub type TaskStatus {
  Pending
  Running
  Done
  Failed
}

pub type Task {
  Task(id: String, title: String, status: TaskStatus, priority: Int)
}

pub type TaskError {
  CannotStartTask
}

pub fn can_start(task: Task) -> Bool {
  task.status == Pending && task.priority > 0
}

pub fn start(task: Task) -> Result(Task, TaskError) {
  case can_start(task) {
    True -> Ok(Task(..task, status: Running))
    False -> Error(CannotStartTask)
  }
}
```

**Improvements:**
1. Status is now a type, not a string
2. No exceptions - Result type
3. Pattern matching for status
4. Compiler catches invalid status values

---

## Summary

| TypeScript Problem | Gleam Solution |
|-------------------|----------------|
| 2500-line files | Natural 300-line modules |
| Null/undefined | No null, Option type |
| Nested if/else | Pattern matching |
| Implicit any | Explicit types |
| Runtime errors | Compile-time errors |
| Refactoring fear | Safe refactoring |
| Mutation bugs | Immutability |
| Exception handling | Result type |

## Next Steps

In **Chapter 2**, we'll dive deep into:
- Custom types vs TypeScript interfaces
- Pattern matching techniques
- Result and Option types
- Building real validation logic

---

*Continue to [Chapter 2: Types and Pattern Matching](./chapter-02.md)*
