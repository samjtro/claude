#!/bin/bash
# Interactive agent loop with granular control per iteration

set -euo pipefail

# Configuration
LOG_DIR="${AGENT_LOG_DIR:-$HOME/.claudebox/logs}"
MEMORY_DIR="${MEMORY_DIR:-$HOME/.claudebox/memory}"
QUESTIONS_FILE="$LOG_DIR/iteration_questions.md"
ANSWERS_FILE="$LOG_DIR/iteration_answers.md"
OPUS_MODEL="claude-3-opus-20240229"

# Ensure directories exist
mkdir -p "$LOG_DIR" "$MEMORY_DIR"

# Agent prompt files - relative to script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLANNER_PROMPT="$SCRIPT_DIR/../prompts/planner.md"
DEVELOPER_PROMPT="$SCRIPT_DIR/../prompts/developer.md"
REVIEWER_PROMPT="$SCRIPT_DIR/../prompts/reviewer.md"
TESTER_PROMPT="$SCRIPT_DIR/../prompts/tester.md"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*" | tee -a "$LOG_DIR/interactive_loop.log"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $*" | tee -a "$LOG_DIR/interactive_loop.log" >&2
}

log_success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS:${NC} $*" | tee -a "$LOG_DIR/interactive_loop.log"
}

# Generate questions from plan using Opus
generate_questions() {
    local plan_file=$1
    
    if [[ ! -f "$plan_file" ]]; then
        log_error "Plan file not found: $plan_file"
        return 1
    fi
    
    log "Generating questions from plan using Opus..."
    
    # Create question generation prompt
    cat > "$LOG_DIR/question_prompt.md" <<EOF
# Question Generation for Development Iteration

## Plan Content
$(cat "$plan_file")

## Task
You are preparing for a development iteration. Based on the plan above, generate 3-5 specific questions that will help guide the development team. These questions should:

1. Clarify any ambiguous requirements
2. Identify potential technical challenges
3. Determine implementation priorities
4. Understand success criteria
5. Identify any dependencies or blockers

Format the questions as a markdown list that can be edited by the user.

## Output Format
Generate questions in this format:

### Development Questions

1. **[Category]**: [Specific question]?
   - [ ] [User will fill this in]

2. **[Category]**: [Specific question]?
   - [ ] [User will fill this in]

(etc.)

Categories can be: Requirements, Technical, Priority, Testing, Dependencies, etc.
EOF

    # Use Claude Opus to generate questions
    if command -v claude >/dev/null 2>&1; then
        claude --model "$OPUS_MODEL" -c "$LOG_DIR/question_prompt.md" \
            "Generate specific development questions based on this plan" > "$QUESTIONS_FILE" 2>/dev/null || {
            # Fallback to default model if Opus not available
            claude -c "$LOG_DIR/question_prompt.md" \
                "Generate specific development questions based on this plan" > "$QUESTIONS_FILE"
        }
        
        log_success "Questions generated"
        return 0
    else
        log_error "Claude CLI not found"
        return 1
    fi
}

# Open vim for user to answer questions
get_user_answers() {
    log "Opening vim for you to answer the questions..."
    
    # Prepare the answers file with questions
    cat > "$ANSWERS_FILE" <<EOF
# Development Iteration Questions

Please answer the questions below to guide this development iteration.
Save and exit when done (:wq in vim).

---

$(cat "$QUESTIONS_FILE")

---

## Your Answers

Please fill in your answers above by replacing the [ ] checkboxes with your responses.
EOF

    # Open vim for editing
    if command -v vim >/dev/null 2>&1; then
        vim "$ANSWERS_FILE"
    elif command -v vi >/dev/null 2>&1; then
        vi "$ANSWERS_FILE"
    elif command -v nano >/dev/null 2>&1; then
        nano "$ANSWERS_FILE"
    else
        log_error "No text editor found (tried vim, vi, nano)"
        return 1
    fi
    
    log_success "Answers saved"
    return 0
}

# Process iteration with user context
run_iteration_with_context() {
    local plan_file=$1
    local iteration_num=${2:-1}
    
    log "Starting iteration $iteration_num with context from: $plan_file"
    
    # Create iteration context combining plan and answers
    cat > "$LOG_DIR/iteration_context.md" <<EOF
# Iteration $iteration_num Context

## Original Plan
$(cat "$plan_file")

## Questions and Answers
$(cat "$ANSWERS_FILE")

## Iteration Goal
Execute one development cycle based on the plan and answers above. Focus on:
1. Implementing the highest priority items
2. Following the technical approach outlined in the answers
3. Addressing any concerns or dependencies mentioned
EOF

    # Run the agent loop with context
    source "$SCRIPT_DIR/agent_loop.sh"
    
    # Override the main loop to run just one iteration
    run_single_iteration() {
        log "Running agents with iteration context..."
        
        # Planner uses the context to select tasks
        run_planner_with_context "$LOG_DIR/iteration_context.md"
        
        # Continue with normal agent flow
        run_developer
        run_reviewer
        run_tester
        
        # Save iteration summary
        save_iteration_summary "$iteration_num"
    }
    
    run_single_iteration
}

# Modified planner that uses iteration context
run_planner_with_context() {
    local context_file=$1
    
    log_agent "PLANNER" "Analyzing iteration context and selecting tasks..."
    
    cat <<EOF > "$LOG_DIR/planner_context.md"
# Planner Context

## Iteration Context
$(cat "$context_file")

## Instructions
$(cat "$PLANNER_PROMPT")

Based on the plan, questions, and answers above, select the most appropriate tasks for this iteration.
EOF

    if command -v claude >/dev/null 2>&1; then
        claude -c "$LOG_DIR/planner_context.md" \
            "Select tasks for this iteration based on the context" > "$LOG_DIR/planner_output.md"
    fi
    
    log_agent "PLANNER" "Task selection complete"
}

# Save iteration summary
save_iteration_summary() {
    local iteration_num=$1
    local summary_file="$MEMORY_DIR/iteration_${iteration_num}_summary.md"
    
    cat > "$summary_file" <<EOF
# Iteration $iteration_num Summary
Date: $(date)

## Context
- Plan: $plan_file
- Questions Generated: $(wc -l < "$QUESTIONS_FILE") questions
- User Provided Answers: Yes

## Agent Outputs
### Planner
$(cat "$LOG_DIR/planner_output.md" 2>/dev/null || echo "No planner output")

### Developer
$(cat "$LOG_DIR/developer_output.md" 2>/dev/null || echo "No developer output")

### Reviewer
$(cat "$LOG_DIR/reviewer_output.md" 2>/dev/null || echo "No reviewer output")

### Tester
$(cat "$LOG_DIR/tester_output.md" 2>/dev/null || echo "No tester output")
EOF

    log_success "Iteration $iteration_num summary saved to: $summary_file"
}

# Main function for interactive iteration
main() {
    if [[ $# -lt 1 ]]; then
        echo "Usage: $0 <plan-file> [iteration-number]"
        echo ""
        echo "Run a single development iteration with interactive Q&A"
        echo ""
        echo "Arguments:"
        echo "  plan-file        Path to markdown file containing the development plan"
        echo "  iteration-number Optional iteration number (default: 1)"
        echo ""
        echo "Example:"
        echo "  $0 ./project-plan.md"
        echo "  $0 ./project-plan.md 5"
        exit 1
    fi
    
    local plan_file=$1
    local iteration_num=${2:-1}
    
    # Validate plan file
    if [[ ! -f "$plan_file" ]]; then
        log_error "Plan file not found: $plan_file"
        exit 1
    fi
    
    # Check for Claude CLI
    if ! command -v claude >/dev/null 2>&1; then
        log_error "Claude CLI not found. Please ensure Claude is installed."
        exit 1
    fi
    
    log "Starting interactive iteration process..."
    echo ""
    
    # Step 1: Generate questions
    if ! generate_questions "$plan_file"; then
        log_error "Failed to generate questions"
        exit 1
    fi
    
    # Step 2: Get user answers
    if ! get_user_answers; then
        log_error "Failed to get user answers"
        exit 1
    fi
    
    # Step 3: Run iteration with context
    run_iteration_with_context "$plan_file" "$iteration_num"
    
    log_success "Iteration $iteration_num complete!"
    echo ""
    echo "Results saved in:"
    echo "  - Logs: $LOG_DIR/"
    echo "  - Memory: $MEMORY_DIR/"
}

# Handle interrupts gracefully
trap 'log "Interrupted, saving state..."; exit 0' INT TERM

# Source required functions from agent_loop.sh
if [[ -f "$SCRIPT_DIR/agent_loop.sh" ]]; then
    # Source only the functions we need
    source <(grep -E '^(log_agent|run_developer|run_reviewer|run_tester)\(\)' "$SCRIPT_DIR/agent_loop.sh" -A 50 | sed '/^}/q')
fi

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" = "${0}" ]]; then
    main "$@"
fi