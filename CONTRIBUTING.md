# Contributing to Claude Ship Command

Thank you for your interest in contributing! This document provides guidelines for contributions.

## How to Contribute

### Reporting Issues

1. Check if the issue already exists in [GitHub Issues](https://github.com/YOUR_USERNAME/claude-ship-command/issues)
2. Create a new issue with:
   - Clear, descriptive title
   - Steps to reproduce (if bug)
   - Expected vs actual behavior
   - Your OS and Claude Code version

### Suggesting Features

1. Open a [GitHub Issue](https://github.com/YOUR_USERNAME/claude-ship-command/issues/new) with the "enhancement" label
2. Describe the feature and its use case
3. Explain why it would benefit other users

### Pull Requests

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Make your changes
4. Test your changes thoroughly
5. Commit with conventional commits: `feat: add X` or `fix: resolve Y`
6. Push and create a Pull Request

## Code Guidelines

### Skill File (ship.md)

- Keep the skill file self-contained
- Use clear, step-by-step instructions
- Handle errors gracefully with actionable messages
- Support cross-platform commands where possible
- Document any new configuration options

### Installers

- Test on the target platform before submitting
- Preserve existing user configurations
- Provide clear feedback during installation
- Handle missing dependencies gracefully

### Documentation

- Keep README.md up to date with new features
- Add examples for new configuration options
- Use consistent formatting

## Testing Your Changes

### Test the Skill

1. Copy your modified `ship.md` to `~/.claude/skills/`
2. Open Claude Code in a test project
3. Run `/ship` with various scenarios:
   - Clean working tree
   - Uncommitted changes
   - Custom commit message
   - `--no-deploy` flag
   - `--no-build` flag

### Test Installers

**Mac/Linux:**
```bash
# Test in a clean environment
rm -rf ~/.claude/skills/ship.md ~/.claude/ship.config.json
./install.sh
```

**Windows:**
```powershell
# Test in a clean environment
Remove-Item -Path "$env:USERPROFILE\.claude\skills\ship.md" -ErrorAction SilentlyContinue
Remove-Item -Path "$env:USERPROFILE\.claude\ship.config.json" -ErrorAction SilentlyContinue
.\install.ps1
```

## Commit Message Format

Use [Conventional Commits](https://www.conventionalcommits.org/):

- `feat: add new feature`
- `fix: resolve bug in X`
- `docs: update README`
- `refactor: improve code structure`
- `test: add test for X`
- `chore: update dependencies`

## Questions?

Open an issue with the "question" label or reach out to the maintainers.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
