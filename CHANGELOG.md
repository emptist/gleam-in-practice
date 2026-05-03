# Changelog

All notable changes to this book will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [1.1.0-zh] - 2026-05-03

### Added
- Complete Chinese translation of the book
- zh-CN/book/ - All 14 chapters translated
  - 第一章：TypeScript 开发者入门
  - 第二章：类型与模式匹配
  - 第三章：处理 JSON
  - 第四章：FFI - JavaScript 集成
  - 第五章：数据库操作
  - 第六章：构建 CLI
  - 第七章：状态管理
  - 第八章：验证
  - 第九章：缓存
  - 第十章：异步编程
  - 第十一章：测试策略
  - 第十二章：JSON Schema 验证
  - 第十三章：JSON Path 查询语言
  - 第十四章：将 Nezha 整合到 TraeNuPI
- zh-CN/appendices/ - All appendices translated
  - 速查表
  - 常见模式
  - 错误及解决方案
  - 项目结构指南
- zh-CN/book/gleam-in-practice-zh.pdf - Chinese PDF version

## [1.0.0] - 2026-05-03

### Added
- Complete book with 14 chapters
- Part I: Foundations (Chapters 1-4)
  - Introduction for TypeScript Developers
  - Types and Pattern Matching
  - Working with JSON
  - FFI - JavaScript Integration
- Part II: Real-World Development (Chapters 5-8)
  - Database Operations
  - Building a CLI
  - State Management
  - Validation
- Part III: Advanced Patterns (Chapters 9-11)
  - Caching
  - Async Programming
  - Testing Strategies
- Part IV: Case Studies (Chapters 12-14)
  - JSON Schema Validation (841 lines)
  - JSON Path Query Language (442 lines)
  - Absorbing Nezha into TraeNuPI
- Appendices
  - Cheat Sheet for TypeScript Developers
  - Common Patterns
  - Error Messages and Solutions
  - Project Structure

### TraeNuPI Implementation
- 23 Gleam modules (7,000+ lines)
- 343 passing tests
- Full TypeScript integration
- PostgreSQL database layer
- New modules: task.gleam, meeting.gleam, db.gleam

## [0.4.0] - 2026-05-03

### Added
- Chapter 6: Building a CLI
- Chapter 7: State Management
- Chapter 8: Validation
- task.gleam module (200 lines) - Task management
- meeting.gleam module (260 lines) - Meeting consensus

### Changed
- Updated README with 8 completed chapters
- Updated module statistics (23 modules, 7,000+ lines)

## [0.3.0] - 2026-05-03

### Added
- Chapter 4: FFI - JavaScript Integration
- Chapter 5: Database Operations
- db.gleam module (294 lines) - Type-safe database operations
- db_ffi.mjs - JavaScript FFI bridge for database

## [0.2.0] - 2026-05-03

### Added
- Chapter 2: Types and Pattern Matching
- Chapter 3: Working with JSON
- Comprehensive JSON parsing and encoding examples
- Decoder combinator patterns

## [0.1.0] - 2026-05-03

### Added
- Book project initialized
- Part I: Foundations structure planned
- Part II: Real-World Development structure planned
- Part III: Advanced Patterns structure planned
- Part IV: Case Studies structure planned
- Appendices structure planned
- Chapter 1: Introduction for TypeScript Developers
- Project README with statistics from TraeNuPI

---

## Version History

| Version | Date       | Description                                     |
| ------- | ---------- | ----------------------------------------------- |
| 1.0.0   | 2026-05-03 | Complete book with 14 chapters and 4 appendices |
| 0.4.0   | 2026-05-03 | Chapters 6-8, task & meeting modules            |
| 0.3.0   | 2026-05-03 | Chapters 4-5, database module                   |
| 0.2.0   | 2026-05-03 | Chapters 2-3, JSON patterns                     |
| 0.1.0   | 2026-05-03 | Initial structure and Chapter 1                 |

## Statistics

| Metric            | Value  |
| ----------------- | ------ |
| Chapters          | 14     |
| Appendices        | 4      |
| Gleam modules     | 23     |
| Total Gleam lines | 7,000+ |
| Tests passing     | 343    |
| FFI files         | 6      |
