# 第六章：构建命令行工具

## CLI 设计原则

好的命令行工具应该：

1. **直观** - 命令和参数易于理解
2. **一致** - 遵循 Unix 哲学
3. **友好** - 提供有用的帮助信息
4. **健壮** - 正确处理错误

## 参数解析

### 基本类型

```gleam
// src/traenupi_core/cli.gleam
pub type CliArg {
  Flag(name: String, description: String, short: Option(String))
  Option(name: String, description: String, short: Option(String), default: Option(String))
  Positional(name: String, description: String, required: Bool)
}

pub type CliConfig {
  CliConfig(
    name: String,
    version: String,
    description: String,
    args: List(CliArg),
  )
}

pub type ParsedArg {
  PresentFlag(name: String)
  PresentOption(name: String, value: String)
  PresentPositional(name: String, value: String)
}

pub type ParseResult {
  ParseResult(args: Dict(String, ParsedArg), remaining: List(String))
}

pub type ParseError {
  UnknownFlag(name: String)
  MissingValue(name: String)
  MissingRequired(name: String)
  InvalidValue(name: String, value: String)
}
```

### 解析器实现

```gleam
pub fn parse(config: CliConfig, argv: List(String)) -> Result(ParsedArgs, ParseError) {
  let args = dict.new()
  let remaining = []
  
  do_parse(config, argv, args, remaining)
}

fn do_parse(
  config: CliConfig,
  argv: List(String),
  args: Dict(String, ParsedArg),
  remaining: List(String),
) -> Result(ParsedArgs, ParseError) {
  case argv {
    [] -> {
      // 检查必需参数
      case check_required(config, args) {
        Ok(_) -> Ok(ParsedArgs(args: args, remaining: list.reverse(remaining)))
        Error(e) -> Error(e)
      }
    }
    
    ["--help", .._] -> Error(ShowHelp(config: config))
    ["-h", .._] -> Error(ShowHelp(config: config))
    ["--version", .._] -> Error(ShowVersion(version: config.version))
    ["-v", .._] -> Error(ShowVersion(version: config.version))
    
    [arg, ..rest] if string.starts_with(arg, "--") -> {
      let name = string.drop_left(arg, 2)
      parse_long_option(config, name, rest, args, remaining)
    }
    
    [arg, ..rest] if string.starts_with(arg, "-") -> {
      let name = string.drop_left(arg, 1)
      parse_short_option(config, name, rest, args, remaining)
    }
    
    [value, ..rest] -> {
      do_parse(config, rest, args, [value, ..remaining])
    }
  }
}

fn parse_long_option(
  config: CliConfig,
  name: String,
  rest: List(String),
  args: Dict(String, ParsedArg),
  remaining: List(String),
) -> Result(ParsedArgs, ParseError) {
  case find_arg(config, name) {
    Some(Flag(name:, ..)) -> {
      let args = dict.insert(args, name, PresentFlag(name))
      do_parse(config, rest, args, remaining)
    }
    
    Some(Option(name:, ..)) -> {
      case rest {
        [value, ..rest2] -> {
          let args = dict.insert(args, name, PresentOption(name: name, value: value))
          do_parse(config, rest2, args, remaining)
        }
        [] -> Error(MissingValue(name: name))
      }
    }
    
    None -> Error(UnknownFlag(name: name))
  }
}

fn parse_short_option(
  config: CliConfig,
  short: String,
  rest: List(String),
  args: Dict(String, ParsedArg),
  remaining: List(String),
) -> Result(ParsedArgs, ParseError) {
  case find_arg_by_short(config, short) {
    Some(Flag(name:, ..)) -> {
      let args = dict.insert(args, name, PresentFlag(name))
      do_parse(config, rest, args, remaining)
    }
    
    Some(Option(name:, ..)) -> {
      case rest {
        [value, ..rest2] -> {
          let args = dict.insert(args, name, PresentOption(name: name, value: value))
          do_parse(config, rest2, args, remaining)
        }
        [] -> Error(MissingValue(name: name))
      }
    }
    
    None -> Error(UnknownFlag(name: short))
  }
}
```

## 帮助信息生成

```gleam
pub fn generate_help(config: CliConfig) -> String {
  let usage = "用法: " <> config.name <> " [选项] [参数]"
  
  let options_help = config.args
    |> list.map(arg_help)
    |> string.join("\n")
  
  usage <> "\n\n" <> config.description <> "\n\n选项:\n" <> options_help
}

fn arg_help(arg: CliArg) -> String {
  case arg {
    Flag(name, description, short) -> {
      let short_str = case short {
        Some(s) -> "  -" <> s <> ", "
        None -> "      "
      }
      short_str <> "--" <> name <> "    " <> description
    }
    
    Option(name, description, short, default) -> {
      let short_str = case short {
        Some(s) -> "  -" <> s <> ", "
        None -> "      "
      }
      let default_str = case default {
        Some(d) -> " (默认: " <> d <> ")"
        None -> ""
      }
      short_str <> "--" <> name <> " <值>    " <> description <> default_str
    }
    
    Positional(name, description, required) -> {
      let req_str = case required {
        True -> " (必需)"
        False -> " (可选)"
      }
      "  <" <> name <> ">    " <> description <> req_str
    }
  }
}
```

## 实战：TraeNuPI CLI

```gleam
// src/traenupi_core/cli.gleam
pub fn main() -> Nil {
  let config = CliConfig(
    name: "traenupi",
    version: "1.0.0",
    description: "TraeNuPI - AI 伴侣系统命令行工具",
    args: [
      Flag(name: "verbose", description: "显示详细输出", short: Some("v")),
      Flag(name: "quiet", description: "静默模式", short: Some("q")),
      Option(name: "config", description: "配置文件路径", short: Some("c"), default: Some("~/.traenupi/config.json")),
      Option(name: "db", description: "数据库连接字符串", short: Some("d"), default: None),
      Positional(name: "command", description: "要执行的命令", required: True),
      Positional(name: "args", description: "命令参数", required: False),
    ],
  )
  
  let argv = get_argv()  // 从系统获取参数
  
  case parse(config, argv) {
    Ok(parsed) -> execute_command(parsed)
    Error(ShowHelp(config:)) -> {
      io.println(generate_help(config))
    }
    Error(ShowVersion(version:)) -> {
      io.println(config.name <> " v" <> version)
    }
    Error(error) -> {
      io.println(error_message(error))
      io.println("\n使用 --help 查看帮助信息")
    }
  }
}

fn error_message(error: ParseError) -> String {
  case error {
    UnknownFlag(name) -> "未知选项: " <> name
    MissingValue(name) -> "选项缺少值: " <> name
    MissingRequired(name) -> "缺少必需参数: " <> name
    InvalidValue(name, value) -> "无效值: " <> name <> " = " <> value
  }
}
```

## 命令分发

```gleam
pub type Command {
  Start
  Stop
  Status
  Config(action: ConfigAction)
  Task(action: TaskAction)
  Help
}

pub type ConfigAction {
  Show
  Set(key: String, value: String)
  Get(key: String)
}

pub type TaskAction {
  List
  Add(title: String, priority: Int)
  Complete(id: String)
  Remove(id: String)
}

pub fn execute_command(parsed: ParsedArgs) -> Nil {
  let command = parsed.args
    |> dict.get("command")
    |> option.unwrap("help")
  
  case command {
    "start" -> execute_start(parsed)
    "stop" -> execute_stop(parsed)
    "status" -> execute_status(parsed)
    "config" -> execute_config(parsed)
    "task" -> execute_task(parsed)
    "help" -> execute_help(parsed)
    _ -> {
      io.println("未知命令: " <> command)
      io.println("使用 --help 查看帮助信息")
    }
  }
}

fn execute_start(parsed: ParsedArgs) -> Nil {
  let verbose = dict.has_key(parsed.args, "verbose")
  
  if verbose {
    io.println("正在启动 TraeNuPI...")
  }
  
  // 启动逻辑
  case start_daemon() {
    Ok(_) -> {
      io.println("TraeNuPI 已启动")
    }
    Error(error) -> {
      io.println("启动失败: " <> error)
    }
  }
}

fn execute_task(parsed: ParsedArgs) -> Nil {
  let action = parsed.args
    |> dict.get("args")
    |> option.unwrap("list")
  
  case action {
    "list" -> list_tasks()
    "add" -> add_task(parsed)
    "complete" -> complete_task(parsed)
    _ -> io.println("未知任务操作: " <> action)
  }
}

fn list_tasks() -> Nil {
  case get_tasks() {
    Ok(tasks) -> {
      io.println("任务列表:")
      tasks
        |> list.each(fn(task) {
          io.println("  [" <> task.id <> "] " <> task.title <> " (" <> status_to_string(task.status) <> ")")
        })
    }
    Error(error) -> {
      io.println("获取任务失败: " <> error)
    }
  }
}

fn add_task(parsed: ParsedArgs) -> Nil {
  let title = parsed.args
    |> dict.get("title")
    |> option.unwrap("新任务")
  
  let priority = parsed.args
    |> dict.get("priority")
    |> option.map(fn(p) {
      case p {
        PresentOption(value:) -> int.parse(value) |> option.unwrap(1)
        _ -> 1
      }
    })
    |> option.unwrap(1)
  
  case create_task(title, priority) {
    Ok(task) -> {
      io.println("任务已创建: " <> task.id)
    }
    Error(error) -> {
      io.println("创建任务失败: " <> error)
    }
  }
}
```

## 进度显示

```gleam
pub type Progress {
  Progress(current: Int, total: Int, message: String)
}

pub fn show_progress(progress: Progress) -> Nil {
  let percent = progress.current * 100 / progress.total
  let bar = progress_bar(percent)
  
  io.print("\r" <> bar <> " " <> int.to_string(percent) <> "% - " <> progress.message)
}

fn progress_bar(percent: Int) -> String {
  let filled = percent / 5
  let empty = 20 - filled
  
  let filled_str = string.repeat("█", filled)
  let empty_str = string.repeat("░", empty)
  
  "[" <> filled_str <> empty_str <> "]"
}

pub fn complete_progress(message: String) -> Nil {
  io.println("\r" <> message <> "                    ")
}
```

## 小结

在本章中，我们学习了：

1. **参数解析** - 解析命令行参数和选项
2. **帮助信息** - 自动生成帮助文档
3. **命令分发** - 根据命令执行不同操作
4. **进度显示** - 显示操作进度

下一章，我们将学习状态管理。
