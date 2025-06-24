# APM Memory Bank Management

## Memory Bank Operations:
1. **Initialize**: Create new Memory Bank structure
2. **Update**: Add new log entries
3. **Query**: Search and retrieve information
4. **Archive**: Move old entries to archive

## Log Entry Format:
```
[TIMESTAMP] [AGENT_TYPE] [TASK_ID]
Action: [What was done]
Result: [Outcome/Status]
Notes: [Additional context]
---
```

## Commands:
- To add entry: Append to MEMORY_BANK.md following the format
- To search: Use keyword search across all entries
- To summarize: Create executive summary of recent activities

## MCP Memory Integration:
The Memory Bank is synchronized with the MCP memory server.
Use the memory server API to store and retrieve persistent data.

Maintain chronological order and ensure all significant actions are logged.