# Gleam Programming in Practice

> A Practical Guide for TypeScript Developers
> 
> Written while building TraeNuPI - a real-world AI companion system

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Gleam](https://img.shields.io/badge/Gleam-1.14+-pink.svg)](https://gleam.run)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.0+-blue.svg)](https://www.typescriptlang.org/)
[![Book Status](https://img.shields.io/badge/Book-Complete-brightgreen.svg)]()

## What Is This Book?

This book teaches Gleam through **real-world examples** from the TraeNuPI project - a production AI companion system with:

- **23 Gleam modules** (7,000+ lines)
- **343 passing tests**
- **Full TypeScript integration**
- **PostgreSQL database layer**

### Why This Book?

| Problem | TypeScript | Gleam Solution |
|---------|------------|----------------|
| File size | 2,500+ lines | Max 841 lines |
| Null safety | Runtime errors | Compile-time |
| Pattern matching | Switch/if chains | Pattern matching |
| Error handling | Try/catch | Result type |
| Refactoring | Risky | Safe with types |

## Quick Start

```bash
# Clone the repository
git clone https://github.com/nezha/gleam-in-practice
cd gleam-in-practice

# Read the book
cd book
# Start with chapter-01.md

# Run examples
cd ../examples/chapter-01
gleam run
```

## Chapters

### Part I: Foundations

| Chapter | Title | Status |
|---------|-------|--------|
| [01](./book/chapter-01.md) | Introduction for TypeScript Developers | ✅ |
| [02](./book/chapter-02.md) | Types and Pattern Matching | ✅ |
| [03](./book/chapter-03.md) | Working with JSON | ✅ |
| [04](./book/chapter-04.md) | FFI - JavaScript Integration | ✅ |

### Part II: Real-World Development

| Chapter | Title | Status |
|---------|-------|--------|
| [05](./book/chapter-05.md) | Database Operations | ✅ |
| [06](./book/chapter-06.md) | Building a CLI | ✅ |
| [07](./book/chapter-07.md) | State Management | ✅ |
| [08](./book/chapter-08.md) | Validation | ✅ |

### Part III: Advanced Patterns

| Chapter | Title | Status |
|---------|-------|--------|
| [09](./book/chapter-09.md) | Caching | ✅ |
| [10](./book/chapter-10.md) | Async Programming | ✅ |
| [11](./book/chapter-11.md) | Testing Strategies | ✅ |

### Part IV: Case Studies

| Chapter | Title | Status |
|---------|-------|--------|
| [12](./book/chapter-12.md) | JSON Schema Validation (841 lines) | ✅ |
| [13](./book/chapter-13.md) | JSON Path Query Language (442 lines) | ✅ |
| [14](./book/chapter-14.md) | Absorbing Nezha into TraeNuPI | ✅ |
| [15](./book/chapter-15.md) | Building an AI Agent with Gleam | ✅ |

## Appendices

| Appendix | Title |
|----------|-------|
| [A](./appendices/cheat-sheet.md) | Cheat Sheet for TypeScript Developers |
| [B](./appendices/patterns.md) | Common Patterns |
| [C](./appendices/errors.md) | Error Messages and Solutions |
| [D](./appendices/structure.md) | Project Structure |

## Statistics

### Code Comparison

| Metric | TypeScript | Gleam |
|--------|------------|-------|
| Largest file | 2,540 lines | 841 lines |
| Average file | ~500 lines | ~250 lines |
| Test count | ~50 tests | 395 tests |
| Type errors caught | Runtime | Compile-time |

### Module Sizes from TraeNuPI

| Module | Lines | Purpose |
|--------|-------|---------|
| schema.gleam | 841 | JSON Schema validation |
| jsonx.gleam | 601 | JSON encoding/decoding |
| datetime.gleam | 528 | Date/time handling |
| json_path.gleam | 442 | JSON Path queries |
| db.gleam | 294 | Database operations |
| validation.gleam | 302 | Input validation |
| config.gleam | 320 | Config parsing |
| str.gleam | 376 | String utilities |
| fs.gleam | 284 | File system |
| resultx.gleam | 305 | Result combinators |
| schema_builder.gleam | 299 | Schema to JSON |
| task.gleam | 200 | Task management |
| meeting.gleam | 260 | Meeting consensus |
| cli.gleam | 219 | CLI parsing |
| cache.gleam | 214 | TTL & LRU cache |
| collection.gleam | 225 | Queue, Stack, Deque |
| async.gleam | 225 | Promise utilities |
| state.gleam | 216 | State management |
| http.gleam | 200 | HTTP client |
| logger.gleam | 192 | Structured logging |
| utils.gleam | 126 | General utilities |
| property.gleam | 135 | Property testing |
| json.gleam | 153 | JSON encoding |

## Project Structure

```
gleam-in-practice/
├── README.md              # This file
├── CHANGELOG.md           # Version history
├── LICENSE                # MIT License
├── book/
│   ├── chapter-01.md      # Introduction
│   ├── chapter-02.md      # Types and Patterns
│   ├── chapter-03.md      # JSON
│   ├── chapter-04.md      # FFI
│   ├── chapter-05.md      # Database
│   ├── chapter-06.md      # CLI
│   ├── chapter-07.md      # State
│   ├── chapter-08.md      # Validation
│   ├── chapter-09.md      # Caching
│   ├── chapter-10.md      # Async
│   ├── chapter-11.md      # Testing
│   ├── chapter-12.md      # Case Study: Schema
│   ├── chapter-13.md      # Case Study: JSON Path
│   ├── chapter-14.md      # Case Study: Nezha
│   └── chapter-15.md      # Case Study: AI Agent
├── appendices/
│   ├── cheat-sheet.md     # Quick reference
│   ├── patterns.md        # Common patterns
│   ├── errors.md          # Error solutions
│   └── structure.md       # Project structure
└── examples/              # Example code
```

## Key Takeaways

1. **Type Safety** - Catch bugs at compile time, not runtime
2. **Pattern Matching** - Eliminate complex if/else chains
3. **Immutability** - No race conditions, easy testing
4. **Result Type** - Explicit error handling, no exceptions
5. **FFI** - Seamless JavaScript integration

## Related Projects

- [TraeNuPI](https://github.com/nezha/traenupi) - The project this book is based on
- [Gleam](https://gleam.run) - Official Gleam website
- [Gleam Docs](https://gleam.run/documentation/) - Official documentation

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

MIT License - See [LICENSE](./LICENSE) for details.

## Author

Written by the TraeNuPI project contributors.

---

*Version 1.1.0 - Complete book with 15 chapters and 4 appendices*
*Last updated: 2026-05-04*
