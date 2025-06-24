#!/bin/bash
# Main agent loop for claudebox multi-agent framework

set -euo pipefail

# Configuration
ITERATION=0
MEGATHINK_INTERVAL=4
LOG_DIR="$HOME/.claudebox/logs"
MEMORY_DIR="$HOME/.claudebox/memory"

# Ensure directories exist
mkdir -p "$LOG_DIR" "$MEMORY_DIR"

# Agent prompt files - relative to script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLANNER_PROMPT="$SCRIPT_DIR/../prompts/planner.md"
DEVELOPER_PROMPT="$SCRIPT_DIR/../prompts/developer.md"
REVIEWER_PROMPT="$SCRIPT_DIR/../prompts/reviewer.md"
TESTER_PROMPT="$SCRIPT_DIR/../prompts/tester.md"

# Logging functions
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_DIR/agent_loop.log"
}

log_agent() {
    local agent=$1
    shift
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [$agent] $*" | tee -a "$LOG_DIR/${agent}.log"
}

# Agent execution functions
run_planner() {
    log_agent "PLANNER" "Analyzing project and selecting next task..."
    
    # Create planner context
    cat <<EOF > "$LOG_DIR/planner_context.md"
# Planner Context

## Current Iteration: $ITERATION

## Instructions
$(cat "$PLANNER_PROMPT")

## Current Project State
- Working Directory: $(pwd)
- Git Status: $(git status --short 2>/dev/null || echo "Not a git repository")

Please analyze the project and select the next task to work on.
EOF

    # Execute planner via Claude
    if command -v claude >/dev/null 2>&1; then
        claude -c "$LOG_DIR/planner_context.md" "Select the next task following the planner agent guidelines" > "$LOG_DIR/planner_output.md"
    else
        log_agent "PLANNER" "Claude CLI not found. Please ensure Claude is properly installed."
        return 1
    fi
    
    log_agent "PLANNER" "Task selection complete"
}

run_developer() {
    log_agent "DEVELOPER" "Implementing selected task..."
    
    # Get task from planner output
    local task=$(grep -A1 "SELECTED_TASK:" "$LOG_DIR/planner_output.md" 2>/dev/null | tail -1 || echo "No task selected")
    
    # Create developer context
    cat <<EOF > "$LOG_DIR/developer_context.md"
# Developer Context

## Task to Implement
$task

## Instructions
$(cat "$DEVELOPER_PROMPT")

## Planner Output
$(cat "$LOG_DIR/planner_output.md")

Please implement the selected task following the developer agent guidelines.
EOF

    # Execute developer via Claude
    if command -v claude >/dev/null 2>&1; then
        claude -c "$LOG_DIR/developer_context.md" "Implement the task following the developer agent guidelines" > "$LOG_DIR/developer_output.md"
    else
        log_agent "DEVELOPER" "Claude CLI not found"
        return 1
    fi
    
    log_agent "DEVELOPER" "Implementation complete"
}

run_reviewer() {
    log_agent "REVIEWER" "Reviewing code changes..."
    
    # Create reviewer context
    cat <<EOF > "$LOG_DIR/reviewer_context.md"
# Reviewer Context

## Instructions
$(cat "$REVIEWER_PROMPT")

## Developer Output
$(cat "$LOG_DIR/developer_output.md")

## Changed Files
$(git diff --name-only 2>/dev/null || echo "Unable to determine changed files")

Please review the implementation following the reviewer agent guidelines.
EOF

    # Execute reviewer via Claude
    if command -v claude >/dev/null 2>&1; then
        claude -c "$LOG_DIR/reviewer_context.md" "Review the changes following the reviewer agent guidelines" > "$LOG_DIR/reviewer_output.md"
    else
        log_agent "REVIEWER" "Claude CLI not found"
        return 1
    fi
    
    log_agent "REVIEWER" "Review complete"
}

run_tester() {
    log_agent "TESTER" "Running tests and validation..."
    
    # Create tester context
    cat <<EOF > "$LOG_DIR/tester_context.md"
# Tester Context

## Instructions
$(cat "$TESTER_PROMPT")

## Developer Output
$(cat "$LOG_DIR/developer_output.md")

## Reviewer Feedback
$(cat "$LOG_DIR/reviewer_output.md")

Please test the implementation following the tester agent guidelines.
EOF

    # Execute tester via Claude
    if command -v claude >/dev/null 2>&1; then
        claude -c "$LOG_DIR/tester_context.md" "Test the implementation following the tester agent guidelines" > "$LOG_DIR/tester_output.md"
    else
        log_agent "TESTER" "Claude CLI not found"
        return 1
    fi
    
    log_agent "TESTER" "Testing complete"
}

run_megathink() {
    log "Running megathink mode for architectural review..."
    
    cat <<EOF > "$LOG_DIR/megathink_context.md"
# Megathink Architectural Review

## Iteration: $ITERATION

## Recent Work Summary
- Last 4 iterations of work
- Current project state
- Technical debt assessment
- Architecture considerations

## Questions to Consider
1. Is the project architecture still sound?
2. Are we accumulating technical debt?
3. Should we refactor any components?
4. Are there emerging patterns we should standardize?
5. What are the next major milestones?

Please provide a high-level architectural review and recommendations.
EOF

    # Use opus model for megathink if available
    if command -v claude >/dev/null 2>&1; then
        claude --model claude-3-opus-20240229 -c "$LOG_DIR/megathink_context.md" "Perform architectural review" > "$LOG_DIR/megathink_output.md" 2>/dev/null || \
        claude -c "$LOG_DIR/megathink_context.md" "Perform architectural review" > "$LOG_DIR/megathink_output.md"
    fi
    
    log "Megathink complete"
}

# Main loop
main() {
    log "Starting claudebox agent loop"
    
    # Check for required tools
    if ! command -v claude >/dev/null 2>&1; then
        log "ERROR: Claude CLI not found. Please ensure Claude is installed and in PATH"
        exit 1
    fi
    
    # Main development loop
    while true; do
        ITERATION=$((ITERATION + 1))
        log "=== Starting iteration $ITERATION ==="
        
        # Run planner
        if ! run_planner; then
            log "Planner failed, retrying in 30 seconds..."
            sleep 30
            continue
        fi
        
        # Check if planner found tasks
        if grep -q "NO_TASKS_AVAILABLE\|ALL_COMPLETE" "$LOG_DIR/planner_output.md" 2>/dev/null; then
            log "No tasks available or all tasks complete. Exiting loop."
            break
        fi
        
        # Run developer
        if ! run_developer; then
            log "Developer failed, retrying iteration..."
            continue
        fi
        
        # Run reviewer
        if ! run_reviewer; then
            log "Reviewer failed, continuing..."
        fi
        
        # Check review status
        if grep -q "REVIEW_STATUS: REJECTED" "$LOG_DIR/reviewer_output.md" 2>/dev/null; then
            log "Changes rejected by reviewer, returning to planner..."
            continue
        fi
        
        # Run tester
        if ! run_tester; then
            log "Tester failed, continuing..."
        fi
        
        # Check test status
        if grep -q "TEST_STATUS: FAILED" "$LOG_DIR/tester_output.md" 2>/dev/null; then
            log "Tests failed, returning to planner..."
            continue
        fi
        
        # Megathink mode every N iterations
        if [ $((ITERATION % MEGATHINK_INTERVAL)) -eq 0 ]; then
            run_megathink
        fi
        
        # Save iteration summary to memory
        cat <<EOF > "$MEMORY_DIR/iteration_${ITERATION}.md"
# Iteration $ITERATION Summary

## Planner Output
$(cat "$LOG_DIR/planner_output.md")

## Developer Output
$(cat "$LOG_DIR/developer_output.md")

## Reviewer Output
$(cat "$LOG_DIR/reviewer_output.md")

## Tester Output
$(cat "$LOG_DIR/tester_output.md")
EOF
        
        log "Iteration $ITERATION complete"
        
        # Optional: Add delay between iterations
        sleep 5
    done
    
    log "Agent loop completed after $ITERATION iterations"
}

# Handle interrupts gracefully
trap 'log "Interrupted, saving state..."; exit 0' INT TERM

# Run main loop
main "$@"