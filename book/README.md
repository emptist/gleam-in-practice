# Gleam Programming in Practice

## Table of Contents

### Part I: Foundations

1. [Introduction for TypeScript Developers](./chapter-01.md)
   - Why Gleam? The TypeScript pain points
   - Setting up your environment
   - Your first Gleam module
   - The mental model shift

2. [Types and Pattern Matching](./chapter-02.md)
   - Custom types vs TypeScript interfaces
   - Pattern matching: the superpower
   - Result type: errors done right
   - Option type: no more null checks

3. [Working with JSON](./chapter-03.md)
   - Building a JSON parser from scratch
   - Type-safe JSON handling
   - JSON Schema validation
   - Real example: jsonx.gleam (601 lines)

4. [FFI - JavaScript Integration](./chapter-04.md)
   - Calling JavaScript from Gleam
   - Calling Gleam from TypeScript
   - Building a bridge module
   - Real example: gleam-bridge.ts

### Part II: Real-World Development

5. [Database Operations](./chapter-05.md)
   - Type-safe SQL queries
   - Connection pooling
   - Transaction handling
   - Real example: db.gleam

6. [Building a CLI](./chapter-06.md)
   - Argument parsing
   - Command dispatch
   - Help generation
   - Real example: cli.gleam

7. [State Management](./chapter-07.md)
   - Immutable state patterns
   - State machines in Gleam
   - Real example: state.gleam

8. [Validation](./chapter-08.md)
   - Building a validation library
   - Composable validators
   - Error accumulation
   - Real example: validation.gleam

### Part III: Advanced Patterns

9. [Caching](./chapter-09.md)
   - TTL cache implementation
   - LRU cache implementation
   - Thread safety considerations
   - Real example: cache.gleam

10. [Async Programming](./chapter-10.md)
    - Promise handling in Gleam
    - Async combinators
    - Error handling patterns
    - Real example: async.gleam

11. [Testing Strategies](./chapter-11.md)
    - Unit testing with gleeunit
    - Property-based testing
    - Integration testing
    - Real example: 343 tests

### Part IV: Case Studies

12. [JSON Schema Validation](./chapter-12.md)
    - 841 lines of production code
    - How we built it
    - Lessons learned

13. [JSON Path Query Language](./chapter-13.md)
    - Parser combinators in Gleam
    - Query execution engine
    - 442 lines of focused code

14. [Absorbing Nezha into TraeNuPI](./chapter-14.md)
    - From 2500-line TypeScript to 300-line Gleam modules
    - Migration strategy
    - Benefits realized

### Appendices

- [A: Gleam vs TypeScript Cheat Sheet](../appendices/cheat-sheet.md)
- [B: Common Patterns Reference](../appendices/patterns.md)
- [C: Error Messages Explained](../appendices/errors.md)
- [D: Project Structure Guide](../appendices/structure.md)

---

## Reading Guide

### For TypeScript Developers

Start with **Chapter 1** - it explains the mental model shift needed. Then work through Part I before jumping to specific topics.

### For Experienced Gleam Users

Jump to **Part III** for advanced patterns, or **Part IV** for case studies of real production code.

### For AI Agents

This book is written to be AI-friendly:
- Clear examples
- Explicit types
- Self-contained chapters
- Real code references

---

## Progress

| Part | Chapters | Status |
|------|----------|--------|
| I: Foundations | 1-4 | 🚧 In Progress |
| II: Real-World | 5-8 | 📝 Planned |
| III: Advanced | 9-11 | 📝 Planned |
| IV: Case Studies | 12-14 | 📝 Planned |

---

*Last updated: 2026-05-03*
