# APM Handover Protocol

## Handover Checklist:
1. **Current State Summary**: Document what has been completed
2. **Pending Tasks**: List unfinished work with current progress
3. **Key Decisions**: Important choices made and their rationale
4. **Known Issues**: Any blockers or problems encountered
5. **Next Steps**: Clear guidance for the next agent

## Handover Artifact Format:
```
HANDOVER ARTIFACT
Generated: [TIMESTAMP]
From: [Current Agent ID]
To: [Next Agent ID]

## Completed Work:
[List of completed tasks/features]

## Current Task Progress:
[Status of in-progress work]

## Critical Context:
[Essential information for continuity]

## Recommended Actions:
[Specific next steps]
```

## MCP Integration:
Store handover artifacts in the MCP memory server for persistence.
This ensures continuity across Claude sessions.

Execute handover when approaching context limits or role transition.