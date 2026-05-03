# Chapter 6: Building a CLI

> "A good CLI is like a good conversation: clear, helpful, and predictable."
> 
> — CLI design wisdom

## Argument Parsing

### The TypeScript Approach

```typescript
// TypeScript - often uses libraries like commander or yargs
import { Command } from 'commander';

const program = new Command();
program
  .name('traenupi')
  .description('AI companion CLI')
  .version('1.0.0');

program
  .command('tellme')
  .description('Ask the baby AI a question')
  .argument('<question>', 'The question to ask')
  .option('-q, --quick', 'Quick response mode')
  .action((question, options) => {
    console.log(askAi(question, options.quick));
  });

program.parse();
```

### The Gleam Approach

```gleam
// cli.gleam
pub type Command {
  Tellme(question: String, quick: Bool)
  Start
  Status
  Help
  Version
}

pub type ParseError {
  UnknownCommand(String)
  MissingArgument(String)
  InvalidOption(String)
}

pub fn parse_args(args: List(String)) -> Result(Command, ParseError) {
  case args {
    ["tellme", question, "-q"] -> Ok(Tellme(question, True))
    ["tellme", question] -> Ok(Tellme(question, False))
    ["tellme"] -> Error(MissingArgument("question"))
    ["start"] -> Ok(Start)
    ["status"] -> Ok(Status)
    ["help"] -> Ok(Help)
    ["--version"] -> Ok(Version)
    ["-v"] -> Ok(Version)
    [cmd, ..] -> Error(UnknownCommand(cmd))
    [] -> Ok(Help)
  }
}
```

---

## Command Dispatch

### Pattern Matching for Commands

```gleam
pub fn execute(command: Command) -> Nil {
  case command {
    Tellme(question, quick) -> {
      let response = ask_ai(question, quick)
      io.println(response)
    }
    Start -> {
      io.println("Starting TraeNuPI...")
      start_daemon()
    }
    Status -> {
      let status = get_status()
      io.println(status)
    }
    Help -> {
      io.println(generate_help())
    }
    Version -> {
      io.println("TraeNuPI v1.0.0")
    }
  }
}
```

### With Error Handling

```gleam
pub fn run(args: List(String)) -> Nil {
  case parse_args(args) {
    Ok(command) -> {
      case execute(command) {
        Ok(_) -> Nil
        Error(e) -> io.println(error_message(e))
      }
    }
    Error(e) -> io.println(parse_error_message(e))
  }
}

fn parse_error_message(error: ParseError) -> String {
  case error {
    UnknownCommand(cmd) -> "Unknown command: " <> cmd
    MissingArgument(arg) -> "Missing argument: " <> arg
    InvalidOption(opt) -> "Invalid option: " <> opt
  }
}
```

---

## Help Generation

### Automatic Help

```gleam
pub fn generate_help() -> String {
  "
TraeNuPI - AI Companion CLI

Usage:
  traenupi <command> [options]

Commands:
  tellme <question>  Ask the baby AI a question
    Options:
      -q, --quick    Quick response mode
  
  start              Start the TraeNuPI daemon
  status             Show current status
  help               Show this help message
  version            Show version

Examples:
  traenupi tellme \"What should I work on?\"
  traenupi tellme \"Quick question\" -q
  traenupi start
  traenupi status
"
}
```

### Dynamic Help from Command Types

```gleam
pub type CommandInfo {
  CommandInfo(
    name: String,
    description: String,
    usage: String,
    examples: List(String),
  )
}

pub fn get_command_info(command: Command) -> CommandInfo {
  case command {
    Tellme(_, _) -> CommandInfo(
      name: "tellme",
      description: "Ask the baby AI a question",
      usage: "traenupi tellme <question> [-q]",
      examples: [
        "traenupi tellme \"What should I work on?\"",
        "traenupi tellme \"Quick question\" -q",
      ],
    )
    Start -> CommandInfo(
      name: "start",
      description: "Start the TraeNuPI daemon",
      usage: "traenupi start",
      examples: ["traenupi start"],
    )
    Status -> CommandInfo(
      name: "status",
      description: "Show current status",
      usage: "traenupi status",
      examples: ["traenupi status"],
    )
    Help -> CommandInfo(
      name: "help",
      description: "Show help message",
      usage: "traenupi help",
      examples: ["traenupi help"],
    )
    Version -> CommandInfo(
      name: "version",
      description: "Show version",
      usage: "traenupi version",
      examples: ["traenupi --version"],
    )
  }
}
```

---

## Real Example: cli.gleam

From TraeNuPI's implementation (219 lines):

```gleam
// cli.gleam
import gleam/io
import gleam/list
import gleam/string
import gleam/option.{type Option, None, Some}

pub type Command {
  Tellme(question: String, quick: Bool, session: Bool)
  Start
  Status
  History(limit: Int)
  Remember(content: String, category: String)
  Forget(id: String)
  Help
  Version
}

pub type ParseError {
  UnknownCommand(String)
  MissingArgument(String)
  InvalidOption(String)
  InvalidValue(String)
}

pub fn parse(args: List(String)) -> Result(Command, ParseError) {
  let args = list.filter(args, fn(a) { a != "" })
  
  case args {
    ["tellme", rest..] -> parse_tellme(rest)
    ["start"] -> Ok(Start)
    ["status"] -> Ok(Status)
    ["history"] -> Ok(History(limit: 10))
    ["history", n] -> parse_history_limit(n)
    ["remember", content, category] -> Ok(Remember(content, category))
    ["remember", content] -> Ok(Remember(content, "general"))
    ["remember"] -> Error(MissingArgument("content"))
    ["forget", id] -> Ok(Forget(id))
    ["forget"] -> Error(MissingArgument("id"))
    ["help"] -> Ok(Help)
    ["--help"] -> Ok(Help)
    ["-h"] -> Ok(Help)
    ["--version"] -> Ok(Version)
    ["-v"] -> Ok(Version)
    [cmd, ..] -> Error(UnknownCommand(cmd))
    [] -> Ok(Help)
  }
}

fn parse_tellme(args: List(String)) -> Result(Command, ParseError) {
  case args {
    ["-q", "-s", question] -> Ok(Tellme(question, True, True))
    ["-s", "-q", question] -> Ok(Tellme(question, True, True))
    ["-q", question] -> Ok(Tellme(question, True, False))
    ["-s", question] -> Ok(Tellme(question, False, True))
    [question, "-q"] -> Ok(Tellme(question, True, False))
    [question, "-s"] -> Ok(Tellme(question, False, True))
    [question] -> Ok(Tellme(question, False, False))
    [] -> Error(MissingArgument("question"))
    _ -> Error(InvalidOption("Invalid options for tellme"))
  }
}

fn parse_history_limit(n: String) -> Result(Command, ParseError) {
  case int.parse(n) {
    Ok(limit) if limit > 0 -> Ok(History(limit: limit))
    Ok(_) -> Error(InvalidValue("Limit must be positive"))
    Error(_) -> Error(InvalidValue("Invalid number: " <> n))
  }
}

pub fn help() -> String {
  "
TraeNuPI - AI Companion CLI

Usage:
  traenupi <command> [options]

Commands:
  tellme <question>    Ask the baby AI a question
    Options:
      -q              Quick response mode
      -s              Use session context
  
  start                Start the TraeNuPI daemon
  status               Show current status
  
  history [limit]      Show conversation history
    Default limit: 10
  
  remember <content> [category]
                       Store knowledge for future sessions
    Default category: general
  
  forget <id>          Remove a stored knowledge item
  
  help                 Show this help message
  version              Show version

Examples:
  traenupi tellme \"What should I work on?\"
  traenupi tellme \"Quick question\" -q
  traenupi start
  traenupi status
  traenupi history 20
  traenupi remember \"Important fact\" work
  traenupi forget abc123
"
}
```

---

## Advanced Patterns

### Subcommands

```gleam
pub type TaskCommand {
  TaskList(status: Option(String))
  TaskCreate(title: String, priority: Int)
  TaskShow(id: String)
  TaskComplete(id: String)
}

pub type Command {
  Task(TaskCommand)
  Meeting(MeetingCommand)
  Knowledge(KnowledgeCommand)
  // ...
}

pub fn parse(args: List(String)) -> Result(Command, ParseError) {
  case args {
    ["task", rest..] -> parse_task(rest)
    ["meeting", rest..] -> parse_meeting(rest)
    // ...
  }
}

fn parse_task(args: List(String)) -> Result(Command, ParseError) {
  case args {
    ["list"] -> Ok(Task(TaskList(None)))
    ["list", "--status", status] -> Ok(Task(TaskList(Some(status))))
    ["create", title, "--priority", p] -> {
      case int.parse(p) {
        Ok(priority) -> Ok(Task(TaskCreate(title, priority)))
        Error(_) -> Error(InvalidValue("Invalid priority"))
      }
    }
    ["show", id] -> Ok(Task(TaskShow(id)))
    ["complete", id] -> Ok(Task(TaskComplete(id)))
    _ -> Error(UnknownCommand("task " <> string.join(args, " ")))
  }
}
```

### Flag Parsing

```gleam
pub type Flag {
  Flag(name: String, value: String)
  BoolFlag(name: String, value: Bool)
}

pub fn parse_flags(args: List(String)) -> #(List(String), List(Flag)) {
  let flags = []
  let positional = []
  
  args
  |> list.fold(#(positional, flags), fn(acc, arg) {
    let #(pos, flags) = acc
    case string.starts_with(arg, "--") {
      True -> {
        let parts = string.split(string.drop_start(arg, 2), "=")
        case parts {
          [name, value] -> #(pos, [Flag(name, value), ..flags])
          [name] -> #(pos, [BoolFlag(name, True), ..flags])
          _ -> #(pos, flags)
        }
      }
      False -> #([arg, ..pos], flags)
    }
  })
}
```

---

## Integration with TypeScript

### Calling Gleam CLI from TypeScript

```typescript
// index.ts
import { parse, help, type Command } from './gleam/traenupi_core/build/dev/javascript/traenupi_core/traenupi_core/cli.mjs';

const args = process.argv.slice(2);

const result = parse(args);

if (result.type === 'Ok') {
  const command = result.value;
  await executeCommand(command);
} else {
  console.error(`Error: ${result.value}`);
  console.log(help());
  process.exit(1);
}

async function executeCommand(command: Command) {
  switch (command.type) {
    case 'Tellme':
      const response = await askAi(command.question, command.quick);
      console.log(response);
      break;
    case 'Start':
      await startDaemon();
      break;
    case 'Status':
      console.log(await getStatus());
      break;
    case 'Help':
      console.log(help());
      break;
    case 'Version':
      console.log('TraeNuPI v1.0.0');
      break;
  }
}
```

---

## Summary

| Aspect | TypeScript | Gleam |
|--------|------------|-------|
| Parsing | Libraries (commander) | Pattern matching |
| Type safety | Runtime | Compile-time |
| Error handling | Try/catch | Result type |
| Help generation | Manual | Pattern matching |
| Subcommands | Nested objects | Nested types |

## Key Takeaways

1. **Pattern matching eliminates if/else chains** - Each command is one case
2. **Type-safe parsing** - Invalid commands are caught at compile time
3. **Result type for errors** - No exceptions
4. **Help is data** - Generate from command types
5. **Easy integration** - Call Gleam from TypeScript

## Next Steps

In **Chapter 7**, we'll explore:
- Immutable state patterns
- State machines in Gleam
- Real example: state.gleam

---

*Continue to [Chapter 7: State Management](./chapter-07.md)*
