# Contributing to DevReclaim

Thanks for taking the time to contribute.

## Ways to Contribute

- **Bug reports** — open an issue with steps to reproduce, expected vs actual behavior, and your macOS version.
- **Feature requests** — open an issue describing the use case. New cleanup presets are especially welcome.
- **Pull requests** — see the workflow below.

## Development Setup

Requirements: macOS 14+, Xcode 15+, Swift 5.9+

```sh
git clone https://github.com/recepzgrmh/Mac-Developer-Cleaner.git
cd Mac-Developer-Cleaner
open Package.swift
```

Build and run with `Cmd + R` in Xcode.

## Pull Request Workflow

1. Fork the repo and create a branch from `main`.
2. Make your changes. Keep commits focused — one logical change per commit.
3. Test on a real macOS 14+ machine before opening a PR.
4. Open a PR against `main` and fill in the PR template.

## Code Style

- Follow existing SwiftUI patterns in `DevReclaim/UI/`.
- New cleanup targets go in `DevReclaim/Core/Executors/`.
- Scanner logic belongs in `DevReclaim/Core/Engine/`.
- Keep destructive operations behind the existing safety-check flow — never delete silently.

## Commit Messages

Use the imperative mood: `add Flutter cache scanner`, not `added` or `adds`.

## License

By contributing, you agree your contributions will be licensed under the MIT License.
