# Claude Code Refactor System

A comprehensive multi-agent orchestration system for managing complex codebase refactors using Claude Code.

## Overview

The Refactor System provides a structured workflow for planning and executing significant codebase changes. It orchestrates multiple Claude Code instances through distinct phases:

1. **Questions Generation** - Analyzes your refactor guide to generate clarifying questions
2. **Plan Creation** - Develops a comprehensive implementation plan based on your requirements
3. **Development Execution** - Manages multi-agent development with task distribution
4. **Review & Validation** - Ensures quality and completeness of the implementation

## Installation

The refactor system is automatically installed when you run the main bootstrap script:

```bash
bash bootstrap.sh
```

This will:
- Install the `/refactor` command
- Set up the refactor workflow scripts
- Create session management directories
- Configure all necessary permissions

## Usage

### Basic Command

```bash
/refactor <PATH_TO_GUIDE.md>
```

### Creating a Refactor Guide

Your refactor guide should be a markdown file containing:

- **Overview**: High-level description of the refactor
- **Current State**: Existing implementation details
- **Target Architecture**: Desired end state
- **Technical Requirements**: Specific implementation needs
- **Constraints**: Limitations and boundaries
- **Success Criteria**: Measurable outcomes

See `examples/example-refactor-guide.md` for a complete template.

### Workflow Phases

#### Phase 1: Questions
- Claude analyzes your guide
- Generates comprehensive questions
- Opens editor for you to provide answers
- Saves context for subsequent phases

#### Phase 2: Planning
- Creates detailed implementation plan
- Organizes work into logical phases
- Allows iterative refinement
- Produces final `PLAN.md`

#### Phase 3: Development
- Breaks down phases into tasks
- Spawns Sonnet instances for implementation
- Manages task dependencies
- Runs tests for each phase

#### Phase 4: Review
- Comprehensive validation
- Checks against original requirements
- Produces review report
- Creates deliverables summary

## Directory Structure

```
~/.claude/
├── commands/
│   └── apm-refactor.md         # Command definition
├── lib/
│   └── refactor/
│       ├── commands/           # Entry point scripts
│       ├── workflows/          # Phase orchestration
│       ├── instances/          # Instance management
│       └── sessions/           # Runtime data
└── refactor/
    └── sessions/               # Saved refactor sessions
        └── refactor_YYYYMMDD_HHMMSS/
            ├── GUIDE.md        # Original guide
            ├── QUESTIONS.md    # Q&A document
            ├── PLAN.md         # Implementation plan
            ├── development/    # Development artifacts
            ├── final_review/   # Review results
            └── session.json    # Session metadata
```

## Session Management

All refactor sessions are saved with timestamps, allowing you to:
- Review past refactors
- Resume interrupted sessions
- Track implementation history
- Audit changes over time

Sessions are stored in: `~/.claude/refactor/sessions/`

## Testing

Run the test suite to verify installation:

```bash
bash ~/.claude/lib/refactor/test/test_refactor.sh
```

## Advanced Features

### Model Selection
- Questions and Planning: Opus for comprehensive analysis
- Development Tasks: Sonnet for efficient implementation
- Reviews: Opus for thorough validation

### Editor Integration
- Supports vim/nvim for editing questions and plans
- Defaults to `$EDITOR` environment variable
- Interactive editing with save detection

### Error Handling
- Graceful failure with descriptive messages
- Session state preservation
- Ability to resume from any phase

## Troubleshooting

### Common Issues

1. **"NPX not found"**
   - Install Node.js: https://nodejs.org/
   - Or use: `brew install node`

2. **"Claude command not found"**
   - Install Claude Code: `npm install -g @anthropic-ai/claude-code`
   - Ensure npm bin is in PATH

3. **"Permission denied"**
   - Run: `chmod +x ~/.claude/lib/refactor/**/*.sh`
   - Check directory permissions

### Debug Mode

Enable verbose logging:
```bash
DEBUG=1 /refactor guide.md
```

## Contributing

The refactor system is part of the Claude setup repository:
https://github.com/samjtro/claude

## License

This system is provided as part of the Claude Code ecosystem and follows the same licensing terms.