---
slug: apm-agents
name: APM Multi-Agent Framework
command: /apm-agents
cwd: .
group: apm
description: Coordinate multiple specialized agents for development
---

# APM Multi-Agent Framework

Execute the multi-agent development framework with specialized agents working together.

## Agent Team

- **Planner**: Analyzes and selects tasks
- **Developer**: Implements code changes  
- **Reviewer**: Validates code quality
- **Tester**: Ensures functionality

## Commands

### Run Interactive Iteration
```bash
/apm-agents iterate <plan-file> [iteration-number]
```
Runs an interactive development iteration:
1. Generates questions about your plan using Opus
2. Opens vim for you to answer questions
3. Executes agents based on your answers

Example:
```bash
/apm-agents iterate project-plan.md      # First iteration
/apm-agents iterate project-plan.md 2    # Second iteration
```

### Check Status
```bash
/apm-agents status
```
Shows current agent states and progress.

### Enable Codex
```bash
export CODEX_ENABLED=true
export OPENAI_API_KEY=your-key
/apm-agents start
```
Enhances code review with GPT-4 analysis.

## Workflow

1. Create a plan.md file describing your project
2. Run `/apm-agents iterate plan.md`
3. Opus generates specific questions about your plan
4. Answer questions in vim to guide development
5. Agents execute based on your context:
   - Planner selects tasks aligned with your answers
   - Developer implements with your priorities in mind
   - Reviewer focuses on your concerns
   - Tester validates based on success criteria
6. Review results and run next iteration

## Configuration

- `MEGATHINK_INTERVAL=4` - Architectural review frequency
- `CODEX_ENABLED=true` - Enable enhanced reviews
- `AGENT_LOG_DIR` - Log file location

## Integration

Works seamlessly with:
- APM Manager for task assignment
- Memory Bank for persistence
- Todo system for task tracking