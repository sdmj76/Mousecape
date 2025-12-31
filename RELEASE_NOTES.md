**[English](#english) | [中文](#中文)**

<a id="english"></a>

## English

### v1.0.1 - Native Windows Cursor Conversion

**Major Update: Windows cursor conversion rewritten from Python to native Swift**

- Replaced external Python script with pure Swift implementation
- No longer requires bundled Python runtime
- Significantly reduced app size (from ~50MB to ~5MB)
- Faster conversion speed with optimized performance
- Improved parsing reliability for .cur and .ani formats

**Bug Fixes:**

- Fixed memory alignment crash when parsing certain cursor files
- Fixed cape rename error when saving imported cursors

---

<a id="中文"></a>

## 中文

### v1.0.1 - 原生 Windows 光标转换

**重大更新：Windows 光标转换从 Python 重写为原生 Swift**

- 使用纯 Swift 实现替代外挂 Python 脚本
- 不再需要内置 Python 运行时
- 大幅减小应用体积（从约 50MB 降至约 5MB）
- 优化性能，转换速度更快
- 提升 .cur 和 .ani 格式的解析可靠性

**Bug 修复：**

- 修复解析某些光标文件时的内存对齐崩溃问题
- 修复导入光标保存时的 cape 重命名错误

---

## Credits | 致谢

- **Original Author | 原作者:** Alex Zielenski (2013-2025)
- **SwiftUI Redesign | SwiftUI 重构:** sdmj76 (2025)
- **Coding Assistant | 编程协助:** Claude Code (Opus)
