# Onit QuickEdit - Claude Code Instructions

## Project Overview

Onit QuickEdit is a macOS app that rewrites, fixes or transforms selected text
in any application via LLM, in place. This tree (branch `feat/quickedit-only`)
is the QuickEdit-only strip of onit-beacon, headed to its own private repo
`synth-inc/onit-quickedit`.

## Git Workflow

- **Always use pull requests** for changes - do not commit directly to `main`
- Create a feature branch before making changes (e.g., `feat/feature-name`, `fix/bug-name`)
- Push the branch and open a PR for review
- Use descriptive PR titles and include a summary of changes

## Project Structure

- `macos/` - The macOS app (Swift/SwiftUI). Xcode project `OnitQuickEdit.xcodeproj`,
  scheme `OnitQuickEdit`, sources under `macos/OnitQuickEdit/`, tests under `macos/OnitTests/`
- No submodules.

## Worktree Setup (IMPORTANT)

**After creating a new worktree or switching to a new branch, always run:**

```bash
# Install git hooks (cleans SPM cache)
./.githooks/install.sh
```

## File Locations

### Documentation
- `macos/OnitQuickEdit/PERMISSIONS.md` - Permissions model (Accessibility, Screen Recording)
