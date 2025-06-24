---
slug: apm-refactor
name: APM Refactor Workflow
command: /refactor
cwd: .
group: apm
description: Initiate a comprehensive refactor workflow with multi-agent orchestration
---

# APM Refactor Workflow

This command initiates a comprehensive refactor workflow that orchestrates multiple Claude Code instances to manage complex codebase changes.

## Usage

```
/refactor <PATH_TO_GUIDE.md>
```

## What This Command Does

When you run this command, it will:

1. **Create a timestamped session** for your refactor in `~/.claude/refactor/sessions/`
2. **Launch the Questions Phase** - An Opus instance will analyze your guide and generate comprehensive questions
3. **Open an editor** for you to answer the questions
4. **Generate a Plan** - Based on your guide and answers, create a detailed implementation plan
5. **Allow plan iteration** - You can review and modify the plan until satisfied
6. **Execute Development** - Multi-agent development with Opus orchestrating Sonnet instances
7. **Review Implementation** - Comprehensive review of all work completed

## Workflow Implementation

When you run this command with a path to a refactor guide markdown file, execute the following:

```bash
# The refactor workflow script path
REFACTOR_SCRIPT="$HOME/.claude/lib/refactor/commands/refactor.sh"

# Check if the refactor script exists
if [[ -f "$REFACTOR_SCRIPT" ]]; then
    # Execute the refactor workflow with the provided guide
    bash "$REFACTOR_SCRIPT" "$1"
else
    echo "Error: Refactor workflow not properly installed."
    echo "Please run the bootstrap script from: https://github.com/samjtro/claude"
    exit 1
fi
```

## Requirements

- A markdown file describing your refactor goals and requirements
- Claude Code with Opus and Sonnet model access
- Sufficient time for the multi-phase workflow (can be resumed)

## Session Management

All refactor sessions are saved with timestamps, allowing you to:
- Review past refactors
- Resume interrupted sessions
- Track implementation history

## Example Guide Structure

Your refactor guide should include:
- Clear objectives
- Technical requirements
- Constraints or limitations
- Success criteria
- Any specific implementation preferences