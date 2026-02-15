# Contributing to iFocus

Thank you for your interest in contributing to iFocus! This repository follows standard open-source contribution practices. All contributions must go through **fork → branch → pull request → review → merge**.

## 📌 Contribution Categories

This project supports the following types of contributions:

1. **Good First Issue** - Small UI or logic fixes, simple bug fixes, minor refactors
2. **Documentation** - Improve README clarity, add setup steps, add feature descriptions, add screenshots
3. **Code/Test** - Add unit tests, improve focus timer logic, add validations, fix feature bugs

Each Pull Request must clearly belong to **one of these categories**.

## 🛠️ Workflow

1. Fork the repository.
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/ifocus.git`
3. Add upstream: `git remote add upstream https://github.com/nikodemo-bukwimba/ifocus.git`
4. Create a new branch: `git checkout -b feature/short-description`
5. Make your changes and test locally.
6. Stage changes: `git add .`
7. Commit using conventional commits: `git commit -m "feat: add focus session validation"`
8. Rebase before pushing: `git pull upstream main --rebase`
9. Push your branch: `git push origin feature/short-description`
10. Open a Pull Request to main on the original repository.

## 📝 Commit Message Convention

Use one of the following prefixes: `feat:` (new feature), `fix:` (bug fix), `docs:` (documentation), `test:` (tests), `refactor:` (code improvement). Example: `git commit -m "fix: correct timer reset bug"`

## 📋 Pull Request Rules

Each PR must: reference an issue (e.g., Closes #5), describe what was changed and why, include screenshots or test output if applicable, contain only one logical change. PRs without linked issues may be rejected.

## 🚫 Forbidden Actions

Do NOT push directly to main. Do NOT merge your own PR. Do NOT submit trivial changes (e.g., single typo only). Do NOT copy code without attribution.

## 🤝 Code of Conduct

By contributing, you agree to follow the project's Code of Conduct.
