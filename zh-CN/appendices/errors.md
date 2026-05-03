# 附录 C：常见错误及解决方案

## 编译错误

### 1. 类型不匹配

**错误：**
```
The function `length` expects arguments of this type: String
But it was given arguments of this type: Int
```

**原因：** 函数参数类型与期望不符。

**解决方案：**
```gleam
// 错误
string.length(42)

// 正确
string.length("hello")
```

### 2. 未找到模块

**错误：**
```
Unknown module `gleam/json`
```

**原因：** 模块不存在或未安装。

**解决方案：**
```bash
# 添加依赖
gleam add gleam_json
```

### 3. 未找到值

**错误：**
```
The module `gleam/list` does not have a `at` value
```

**原因：** 函数名拼写错误或不存在。

**解决方案：**
```gleam
// 错误
list.at([1, 2, 3], 0)

// 正确
list.first([1, 2, 3])
```

### 4. 未使用的变量

**错误：**
```
Unused variable: x
```

**原因：** 定义了变量但未使用。

**解决方案：**
```gleam
// 错误
let x = 10
let y = 20

// 正确：使用 _ 前缀
let _x = 10
let y = 20
```

### 5. 无效的模式匹配

**错误：**
```
This pattern does not match the type
```

**原因：** 模式匹配与类型不符。

**解决方案：**
```gleam
// 错误
case option {
  Some(x) -> x
  None -> 0
  Other -> 1  // Option 没有 Other 变体
}

// 正确
case option {
  Some(x) -> x
  None -> 0
}
```

## 运行时错误

### 6. 空列表访问

**错误：**
```
Empty list error
```

**原因：** 尝试访问空列表的元素。

**解决方案：**
```gleam
// 危险
let first = list.first([])  // 返回 None

// 安全
case list.first(items) {
  Some(first) -> process(first)
  None -> handle_empty()
}
```

### 7. 字典键不存在

**错误：**
```
Key not found
```

**原因：** 访问不存在的键。

**解决方案：**
```gleam
// 安全
case dict.get(my_dict, "key") {
  Some(value) -> value
  None -> default_value
}

// 或使用默认值
let value = dict.get(my_dict, "key") |> option.unwrap(default_value)
```

### 8. 整数溢出

**错误：**
```
Integer overflow
```

**原因：** 整数运算超出范围。

**解决方案：**
```gleam
// 使用 Float 处理大数
let big_number = 1.0e10

// 或检查范围
fn safe_add(a: Int, b: Int) -> Result(Int, String) {
  let result = a + b
  case result < a {
    True -> Error("溢出")
    False -> Ok(result)
  }
}
```

## FFI 错误

### 9. JavaScript 类型错误

**错误：**
```
TypeError: x is not a function
```

**原因：** FFI 函数签名不匹配。

**解决方案：**
```gleam
// Gleam 声明
@external(javascript, "./ffi.mjs", "process")
pub fn process(input: String) -> String

// JavaScript 实现
// ffi.mjs
export function process(input) {
  if (typeof input !== "string") {
    throw new Error("Expected string");
  }
  return input.toUpperCase();
}
```

### 10. 异步函数错误

**错误：**
```
Promise returned but expected synchronous value
```

**原因：** 同步函数调用了异步代码。

**解决方案：**
```gleam
// 错误
@external(javascript, "./ffi.mjs", "fetch")
pub fn fetch(url: String) -> String

// 正确：返回 Promise
@external(javascript, "./ffi.mjs", "fetch")
pub fn fetch(url: String) -> Promise(String)
```

## 测试错误

### 11. 断言失败

**错误：**
```
Expected: 2
Got: 1
```

**原因：** 测试断言不匹配。

**解决方案：**
```gleam
pub fn addition_test() {
  // 检查实际逻辑
  let result = 1 + 1
  result |> should.equal(2)
}
```

### 12. 测试未运行

**错误：**
```
No tests found
```

**原因：** 测试函数命名不正确。

**解决方案：**
```gleam
// 错误：函数名没有 _test 后缀
pub fn addition() {
  1 + 1 |> should.equal(2)
}

// 正确
pub fn addition_test() {
  1 + 1 |> should.equal(2)
}
```

## 常见陷阱

### 13. 可变状态

**问题：**
```gleam
let state = State(count: 0)
update_state(state)  // state 没有被修改！
```

**解决方案：**
```gleam
let state = State(count: 0)
let state = update_state(state)  // 接收返回值
```

### 14. 字符串比较

**问题：**
```gleam
case a == b {  // 可能不工作
  True -> ...
}
```

**解决方案：**
```gleam
case string.compare(a, b) {
  order.Eq -> ...
  order.Lt -> ...
  order.Gt -> ...
}
```

### 15. 浮点数精度

**问题：**
```gleam
0.1 + 0.2 == 0.3  // False!
```

**解决方案：**
```gleam
fn nearly_equal(a: Float, b: Float, epsilon: Float) -> Bool {
  let diff = float.absolute_value(a -. b)
  diff <. epsilon
}

nearly_equal(0.1 +. 0.2, 0.3, 0.0001)  // True
```

## 调试技巧

### 使用 io.debug

```gleam
let value = complex_calculation()
io.debug(value)  // 打印到控制台
```

### 使用 should.be_ok 和 should.be_error

```gleam
let result = risky_operation()
result |> should.be_ok()  // 确保是 Ok
```

### 分步调试

```gleam
let step1 = step_one(input)
io.debug(step1)

let step2 = step_two(step1)
io.debug(step2)

let step3 = step_three(step2)
io.debug(step3)
```

### 类型检查

```bash
# 只做类型检查，不生成代码
gleam check
```
