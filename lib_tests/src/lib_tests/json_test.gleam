import gleam/io
import gleam/json
import gleam/dynamic/decode
import gleam/int
import gleam/bool
import gleam/string

pub type User {
  User(name: String, age: Int, email: String, active: Bool)
}

pub fn test_json() {
  io.println("\n=== Testing JSON Library ===\n")
  
  // Test 1: JSON encoding
  test_encoding()
  
  // Test 2: JSON decoding
  test_decoding()
  
  // Test 3: Complex JSON
  test_complex_json()
  
  io.println("\n✅ All JSON tests completed!")
}

fn test_encoding() {
  io.println("Test 1: JSON Encoding")
  
  let user = User(name: "Alice", age: 30, email: "alice@example.com", active: True)
  let json_string = encode_user(user)
  
  io.println("✓ User encoded successfully")
  io.println("  JSON: " <> json_string)
  
  case json_string == "{\"name\":\"Alice\",\"age\":30,\"email\":\"alice@example.com\",\"active\":true}" {
    True -> io.println("  ✓ JSON format is correct")
    False -> {
      io.println("  ✗ JSON format mismatch")
      panic
    }
  }
}

fn test_decoding() {
  io.println("\nTest 2: JSON Decoding")
  
  let json_string = "{\"name\":\"Bob\",\"age\":25,\"email\":\"bob@example.com\",\"active\":false}"
  
  case decode_user(json_string) {
    Ok(user) -> {
      io.println("✓ User decoded successfully")
      io.println("  Name: " <> user.name)
      io.println("  Age: " <> int.to_string(user.age))
      io.println("  Email: " <> user.email)
      io.println("  Active: " <> bool.to_string(user.active))
      
      case user.name == "Bob" && user.age == 25 {
        True -> io.println("  ✓ Decoded values are correct")
        False -> {
          io.println("  ✗ Decoded values mismatch")
          panic
        }
      }
    }
    Error(_error) -> {
      io.println("✗ Decoding failed")
      panic
    }
  }
  
  // Test invalid JSON
  case decode_user("invalid json") {
    Ok(_) -> {
      io.println("✗ Should have failed decoding invalid JSON")
      panic
    }
    Error(_) -> io.println("✓ Correctly failed decoding invalid JSON")
  }
}

fn test_complex_json() {
  io.println("\nTest 3: Complex JSON")
  
  // Test nested JSON
  let complex_json = json.object([
    #("user", json.object([
      #("name", json.string("Charlie")),
      #("age", json.int(35)),
    ])),
    #("tags", json.array(from: ["developer", "gleam", "functional"], of: json.string)),
    #("metadata", json.object([
      #("created", json.string("2025-01-01")),
      #("updated", json.string("2025-05-05")),
    ])),
  ])
  
  let json_string = json.to_string(complex_json)
  io.println("✓ Complex JSON encoded successfully")
  io.println("  JSON: " <> json_string)
  
  // Test array encoding
  let array_json = json.array(from: [1, 2, 3], of: json.int)
  let array_string = json.to_string(array_json)
  
  case array_string == "[1,2,3]" {
    True -> io.println("✓ Array JSON is correct: " <> array_string)
    False -> {
      io.println("✗ Array JSON mismatch")
      panic
    }
  }
  
  // Test list decoding
  let list_json = "[\"a\",\"b\",\"c\"]"
  case json.parse(from: list_json, using: decode.list(of: decode.string)) {
    Ok(items) -> {
      io.println("✓ List decoded successfully")
      io.println("  Items: " <> string.join(items, with: ", "))
      case items == ["a", "b", "c"] {
        True -> io.println("  ✓ List values are correct")
        False -> {
          io.println("  ✗ List values mismatch")
          panic
        }
      }
    }
    Error(_) -> {
      io.println("✗ List decoding failed")
      panic
    }
  }
}

// Helper functions for encoding/decoding
fn encode_user(user: User) -> String {
  json.object([
    #("name", json.string(user.name)),
    #("age", json.int(user.age)),
    #("email", json.string(user.email)),
    #("active", json.bool(user.active)),
  ])
  |> json.to_string
}

fn decode_user(json_string: String) -> Result(User, json.DecodeError) {
  let user_decoder = {
    use name <- decode.field("name", decode.string)
    use age <- decode.field("age", decode.int)
    use email <- decode.field("email", decode.string)
    use active <- decode.field("active", decode.bool)
    decode.success(User(name:, age:, email:, active:))
  }
  
  json.parse(from: json_string, using: user_decoder)
}
