import gleam/io
import gleam/http.{Get, Post}
import gleam/http/request
import gleam/httpc
import gleam/int
import gleam/string

pub fn test_http() {
  io.println("\n=== Testing HTTP Libraries ===\n")
  
  // Test 1: GET request
  test_get_request()
  
  // Test 2: POST request
  test_post_request()
  
  // Test 3: Custom headers
  test_custom_headers()
  
  io.println("\n✅ All HTTP tests completed!")
}

fn test_get_request() {
  io.println("Test 1: GET Request")
  
  let assert Ok(base_req) = request.to("https://httpbin.org/get")
  let req = request.set_method(base_req, Get)
  
  case httpc.send(req) {
    Ok(response) -> {
      io.println("✓ GET request successful")
      io.println("  Status: " <> int.to_string(response.status))
      case response.status == 200 {
        True -> io.println("  ✓ Status is 200")
        False -> {
          io.println("  ✗ Expected status 200")
          panic
        }
      }
      io.println("  Body length: " <> int.to_string(string.length(response.body)) <> " chars")
    }
    Error(error) -> {
      io.println("✗ GET request failed")
      panic
    }
  }
}

fn test_post_request() {
  io.println("\nTest 2: POST Request")
  
  let body = "{\"name\": \"Alice\", \"age\": 30}"
  let assert Ok(base_req) = request.to("https://httpbin.org/post")
  let req = 
    base_req
    |> request.set_method(Post)
    |> request.set_body(body)
    |> request.prepend_header("content-type", "application/json")
  
  case httpc.send(req) {
    Ok(response) -> {
      io.println("✓ POST request successful")
      io.println("  Status: " <> int.to_string(response.status))
      case response.status == 200 {
        True -> io.println("  ✓ Status is 200")
        False -> {
          io.println("  ✗ Expected status 200")
          panic
        }
      }
      io.println("  Body length: " <> int.to_string(string.length(response.body)) <> " chars")
    }
    Error(error) -> {
      io.println("✗ POST request failed")
      panic
    }
  }
}

fn test_custom_headers() {
  io.println("\nTest 3: Custom Headers")
  
  let assert Ok(base_req) = request.to("https://httpbin.org/headers")
  let req = 
    base_req
    |> request.set_method(Get)
    |> request.prepend_header("x-custom-header", "test-value")
    |> request.prepend_header("user-agent", "Gleam-HTTP-Test/1.0")
  
  case httpc.send(req) {
    Ok(response) -> {
      io.println("✓ Request with custom headers successful")
      io.println("  Status: " <> int.to_string(response.status))
      case response.status == 200 {
        True -> io.println("  ✓ Status is 200")
        False -> {
          io.println("  ✗ Expected status 200")
          panic
        }
      }
      // Check if our custom header is echoed back
      case string.contains(response.body, "X-Custom-Header") {
        True -> io.println("  ✓ Custom header found in response")
        False -> io.println("  ⚠ Custom header not found in response (may be case-sensitive)")
      }
    }
    Error(error) -> {
      io.println("✗ Request failed")
      panic
    }
  }
}
