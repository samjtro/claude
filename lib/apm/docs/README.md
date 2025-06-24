# Agentic Project Management (APM) Framework

## Overview
APM is a structured framework for managing complex AI-assisted projects using multiple specialized agents. It provides clear workflows, role definitions, and communication protocols integrated with Claude Code and MCP servers.

## Core Components

### 1. Manager Agent
- Creates and maintains Implementation Plans
- Assigns tasks to Implementation Agents
- Reviews completed work
- Manages the Memory Bank
- Coordinates agent handovers

### 2. Implementation Agents
- Execute specific tasks from the Implementation Plan
- Follow coding standards and project conventions
- Report progress and blockers
- Create logs for Memory Bank updates

### 3. Memory Bank
- Centralized log of all agent activities
- Integrated with MCP memory server for persistence
- Searchable knowledge base
- Preserves context across agent instances
- Critical for handovers and reviews

### 4. Implementation Plan
- Detailed breakdown of project phases and tasks
- Task dependencies and priorities
- Resource allocation and timelines
- Progress tracking

## Workflow

1. **Manager Setup**: Initialize Manager Agent with project context
2. **Planning**: Manager creates Implementation Plan
3. **Task Assignment**: Manager prepares task prompts
4. **Execution**: Implementation Agents work on tasks
5. **Reporting**: Agents log work in Memory Bank format
6. **Review**: Manager reviews and updates plan
7. **Iteration**: Repeat until project completion

## Commands

- `/apm-manager` - Initialize Manager Agent
- `/apm-implement` - Create Implementation Agent
- `/apm-task` - Generate task assignment
- `/apm-memory` - Manage Memory Bank
- `/apm-handover` - Execute handover protocol
- `/apm-plan` - Manage Implementation Plan
- `/apm-review` - Review completed work

## MCP Integration

APM is deeply integrated with MCP servers:
- **Memory Server**: Persistent storage for Memory Bank
- **Sequential Thinking**: Complex problem-solving for agents
- **Context7**: Enhanced conversation memory
- **OpenRouter AI**: Access to multiple models for specialized tasks

## Best Practices

1. **Clear Communication**: Use structured formats for all exchanges
2. **Regular Updates**: Keep Memory Bank current
3. **Context Preservation**: Document decisions and rationale
4. **Quality Focus**: Ensure production-ready implementations
5. **Proactive Handovers**: Plan for context limits

## Getting Started

1. Use `/apm-manager` to initialize the Manager Agent
2. Let Manager create initial Implementation Plan
3. Use `/apm-implement` when starting implementation work
4. Follow the structured workflow for best results

## Advanced Features

### Project Configuration
Create `.claudebox/project.json` for custom settings:
```json
{
  "apm": {
    "enabled": true,
    "auto_memory_sync": true,
    "task_prefix": "PROJ"
  }
}
```

### Memory Bank Queries
Use MCP memory server API to query project history:
- Search by task ID
- Filter by agent type
- Generate progress reports

For detailed information about each component, refer to the individual command documentation.