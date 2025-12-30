# Contributing to Mousecape

感谢你对 Mousecape 的关注！本文档说明如何参与贡献。

Thanks for your interest in Mousecape! This document explains how to contribute.

---

## Branch Strategy / 分支策略

| Branch | Purpose | 用途 |
|--------|---------|------|
| `master` | Production releases only | 仅用于生产发布 |
| `develop` | Bug fixes and stabilization | 修复和稳定性改进 |
| `feature` | New feature development | 新功能开发 |

### Merge Flow / 合并流程
```
feature → develop → master
   ↓         ↓         ↓
 新功能    修复/集成    发布
```

**For new features:** Submit PRs to `feature` branch.

**For bug fixes:** Submit PRs to `develop` branch.

**新功能：** 请将 PR 提交到 `feature` 分支。

**Bug 修复：** 请将 PR 提交到 `develop` 分支。

---

## How to Contribute / 如何贡献

### 1. Fork & Clone
```bash
git clone https://github.com/YOUR_USERNAME/Mousecape.git
cd Mousecape
```

### 2. Create Feature Branch
```bash
git checkout -b your-feature-name origin/feature
```

### 3. Make Changes & Commit
```bash
git add .
git commit -m "Add: description of your changes"
```

### 4. Push & Create PR
```bash
git push origin your-feature-name
```
Then create a Pull Request to the `feature` branch on GitHub.

---

## PR Review Process / PR 审核流程

### For Contributors / 贡献者须知

1. Ensure CI build passes / 确保 CI 构建通过
2. Describe your changes clearly / 清晰描述你的更改
3. Link related issues if any / 关联相关 Issue
4. Be responsive to review comments / 及时响应审核意见

### For Maintainers / 维护者审核清单

#### GitHub Web Review
1. Open PR → "Files changed" tab
2. Check CI build status (GitHub Actions)
3. Review code line by line, add inline comments
4. Submit Review: Approve / Request changes / Comment

#### Local Testing (Recommended)
```bash
# Method 1: GitHub CLI
gh pr checkout <PR_NUMBER>

# Method 2: Manual fetch
git fetch origin pull/<PR_NUMBER>/head:pr-<PR_NUMBER>
git checkout pr-<PR_NUMBER>

# Build and test
xcodebuild -project Mousecape/Mousecape.xcodeproj -scheme Mousecape build
```

#### Review Checklist
- [ ] Code style follows project conventions
- [ ] No breaking changes to existing features
- [ ] Private API changes documented (CGSInternal/)
- [ ] Related documentation updated
- [ ] CI build passes
- [ ] Tested on macOS Tahoe

---

## Code Style / 代码风格

- Follow existing Objective-C / Swift conventions
- Use ARC where possible (check file compiler flags in project.pbxproj)
- Document any private API usage
- Keep commits atomic and well-described

---

## Version Strategy / 版本策略

| Version | Type | Content |
|---------|------|---------|
| v1.0.x | Patch | Bug fixes only |
| v1.x.0 | Minor | New features from community |
| vX.0.0 | Major | Breaking changes |

### Release Flow
```
feature → develop (integration) → master (release)
              ↓
         v1.1.0-beta → v1.1.0
```

---

## Questions? / 有问题？

- Open an [Issue](https://github.com/sdmj76/Mousecape/issues)
- Check existing discussions

---

## License

By contributing, you agree that your contributions will be licensed under the same license as the project.
