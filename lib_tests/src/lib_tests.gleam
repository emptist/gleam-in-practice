import gleam/io
import gleam/list
import simplifile
import filepath
import lib_tests/http_test
import lib_tests/json_test

pub fn main() {
  io.println("Testing pure Gleam libraries...")
  
  // Test 1: File operations
  test_write_read()
  test_directory_operations()
  test_file_copy()
  test_file_deletion()
  test_path_operations()
  
  // Test 2: HTTP operations
  http_test.test_http()
  
  // Test 3: JSON operations
  json_test.test_json()
  
  io.println("\n✅ All tests completed successfully!")
}

fn test_write_read() {
  io.println("\n=== Test: Write and Read ===")
  
  let content = "Hello, Gleam! This is a test file.\nLine 2\nLine 3"
  let filename = "test_data/test_file.txt"
  
  // Ensure directory exists
  let _ = simplifile.create_directory("test_data")
  
  // Write file
  case simplifile.write(filename, content) {
    Ok(_) -> io.println("✓ File written successfully")
    Error(error) -> {
      io.println("✗ Write failed: " <> simplifile.describe_error(error))
      panic
    }
  }
  
  // Read file
  case simplifile.read(filename) {
    Ok(read_content) -> {
      case read_content == content {
        True -> {
          io.println("✓ File read successfully")
          io.println("  Content: " <> read_content)
        }
        False -> {
          io.println("✗ Content mismatch")
          panic
        }
      }
    }
    Error(error) -> {
      io.println("✗ Read failed: " <> simplifile.describe_error(error))
      panic
    }
  }
  
  // Read non-existent file
  case simplifile.read("non_existent_file.txt") {
    Ok(_) -> {
      io.println("✗ Should have failed reading non-existent file")
      panic
    }
    Error(_) -> io.println("✓ Correctly failed reading non-existent file")
  }
}

fn test_directory_operations() {
  io.println("\n=== Test: Directory Operations ===")
  
  let dir_name = "test_data/subdir/nested"
  
  // Create nested directory
  case simplifile.create_directory_all(dir_name) {
    Ok(_) -> io.println("✓ Nested directory created")
    Error(error) -> {
      io.println("✗ Directory creation failed: " <> simplifile.describe_error(error))
      panic
    }
  }
  
  // List files in directory
  case simplifile.get_files("test_data") {
    Ok(files) -> {
      io.println("✓ Files listed successfully")
      io.println("  Files:")
      files |> list.each(fn(file) { io.println("    - " <> file) })
      case files == [] {
        True -> {
          io.println("✗ Directory should have files")
          panic
        }
        False -> Nil
      }
    }
    Error(error) -> {
      io.println("✗ List files failed: " <> simplifile.describe_error(error))
      panic
    }
  }
  
  // Check if directory exists
  case simplifile.is_directory("test_data") {
    Ok(True) -> io.println("✓ Directory exists check passed")
    Ok(False) -> {
      io.println("✗ Directory should exist")
      panic
    }
    Error(error) -> {
      io.println("✗ Directory check failed: " <> simplifile.describe_error(error))
      panic
    }
  }
}

fn test_file_copy() {
  io.println("\n=== Test: File Copy ===")
  
  let source = "test_data/test_file.txt"
  let destination = "test_data/copied_file.txt"
  
  // Copy file
  case simplifile.copy_file(source, destination) {
    Ok(_) -> io.println("✓ File copied successfully")
    Error(error) -> {
      io.println("✗ Copy failed: " <> simplifile.describe_error(error))
      panic
    }
  }
  
  // Verify copy
  case simplifile.read(destination) {
    Ok(content) -> {
      case simplifile.read(source) {
        Ok(source_content) -> {
          case content == source_content {
            True -> io.println("✓ Copied content matches source")
            False -> {
              io.println("✗ Content mismatch")
              panic
            }
          }
        }
        Error(_) -> panic
      }
    }
    Error(_) -> panic
  }
}

fn test_file_deletion() {
  io.println("\n=== Test: File Deletion ===")
  
  let filename = "test_data/to_delete.txt"
  
  // Create a file to delete
  let _ = simplifile.write(filename, "Delete me")
  
  // Delete file
  case simplifile.delete(filename) {
    Ok(_) -> io.println("✓ File deleted successfully")
    Error(error) -> {
      io.println("✗ Delete failed: " <> simplifile.describe_error(error))
      panic
    }
  }
  
  // Verify deletion
  case simplifile.read(filename) {
    Ok(_) -> {
      io.println("✗ File should have been deleted")
      panic
    }
    Error(_) -> io.println("✓ File correctly deleted")
  }
}

fn test_path_operations() {
  io.println("\n=== Test: Path Operations ===")
  
  // Test filepath operations
  let path = filepath.join("home", "user")
  case path == "home/user" {
    True -> io.println("✓ Path join: " <> path)
    False -> {
      io.println("✗ Path join failed")
      panic
    }
  }
  
  let ext = filepath.extension("document.pdf")
  case ext {
    Ok(e) -> {
      case e == "pdf" {
        True -> io.println("✓ Extension extracted: " <> e)
        False -> {
          io.println("✗ Extension mismatch")
          panic
        }
      }
    }
    Error(_) -> panic
  }
  
  let base = filepath.base_name("/home/user/document.pdf")
  case base == "document.pdf" {
    True -> io.println("✓ Base name: " <> base)
    False -> {
      io.println("✗ Base name mismatch")
      panic
    }
  }
  
  let dir = filepath.directory_name("/home/user/document.pdf")
  case dir == "/home/user" {
    True -> io.println("✓ Directory name: " <> dir)
    False -> {
      io.println("✗ Directory name mismatch")
      panic
    }
  }
  
  // Test simplifile path operations
  case simplifile.is_file("test_data/test_file.txt") {
    Ok(True) -> io.println("✓ File exists check passed")
    _ -> {
      io.println("✗ File should exist")
      panic
    }
  }
}
