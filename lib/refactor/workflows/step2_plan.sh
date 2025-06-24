#!/usr/bin/env bash

# Step 2: Plan Generation and Iteration Workflow
# Generates and iterates on a comprehensive refactor plan

set -euo pipefail

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

SESSION_DIR="$1"
GUIDE_PATH="${SESSION_DIR}/GUIDE.md"
QUESTIONS_PATH="${SESSION_DIR}/QUESTIONS.md"
PLAN_PATH="${SESSION_DIR}/PLAN.md"
UPDATED_PLAN_PATH="${SESSION_DIR}/UPDATED_PLAN.md"

# Create plan generation prompt
create_plan_prompt() {
    local iteration="$1"
    
    if [[ "$iteration" == "initial" ]]; then
        cat > "${SESSION_DIR}/plan_prompt.txt" <<'EOF'
You are an expert Project Manager creating a comprehensive refactor plan. Your task is to synthesize the refactor guide and Q&A to create a detailed, phased implementation plan.

INSTRUCTIONS:
1. Ultrathink as an expert PM to examine the refactor guide (GUIDE.md) and answered questions (QUESTIONS.md)
2. Create a comprehensive plan divided into logical phases
3. Each phase should contain:
   - Clear objectives
   - Detailed TODO lists with granular tasks
   - Success criteria
   - Dependencies and prerequisites
   - Risk mitigation strategies
4. Include high-level guidance for maintaining system coherence
5. Save the plan to PLAN.md

PLAN STRUCTURE:
- Executive Summary
- Phase Overview
- Detailed Phase Breakdowns
  - Phase objectives
  - Task lists (granular, actionable items)
  - Technical specifications
  - Integration points
  - Testing requirements
  - Rollback procedures
- Timeline and Dependencies
- Success Metrics

Read GUIDE.md and QUESTIONS.md, then generate the comprehensive plan.
EOF
    else
        cat > "${SESSION_DIR}/plan_update_prompt.txt" <<'EOF'
You are an expert Project Manager updating a refactor plan based on user feedback. 

INSTRUCTIONS:
1. Ultrathink to examine the differences between PLAN.md and UPDATED_PLAN.md
2. Understand the user's requested changes and their implications
3. Generate a new, improved plan that incorporates all user feedback
4. Maintain the overall structure while implementing the requested updates
5. Ensure all changes are coherent with the overall refactor goals
6. Save the updated plan to PLAN.md

Focus on:
- Understanding why the user made specific changes
- Ensuring the updates improve the plan's effectiveness
- Maintaining consistency across all phases
- Adjusting dependencies if needed

Read PLAN.md, UPDATED_PLAN.md, GUIDE.md, and QUESTIONS.md, then generate the improved plan.
EOF
    fi
}

# Execute Claude Code instance for plan generation
run_plan_instance() {
    local iteration="$1"
    local prompt_file="plan_prompt.txt"
    
    if [[ "$iteration" != "initial" ]]; then
        prompt_file="plan_update_prompt.txt"
        echo -e "${BLUE}Updating plan based on user feedback...${NC}"
    else
        echo -e "${BLUE}Generating initial plan...${NC}"
    fi
    
    # Create the appropriate prompt
    create_plan_prompt "$iteration"
    
    # Run Claude Code with the plan prompt
    cd "$SESSION_DIR"
    
    npx claude-code \
        --model opus \
        --max-turns 5 \
        --prompt "$(cat $prompt_file)" \
        --non-interactive \
        > "plan_generation_${iteration}.log" 2>&1
    
    # Check if PLAN.md was created/updated
    if [[ -f "$PLAN_PATH" ]]; then
        echo -e "${GREEN}✓ Plan ${iteration} completed successfully${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to generate plan${NC}"
        return 1
    fi
}

# Check if files differ
files_differ() {
    if ! cmp -s "$1" "$2"; then
        return 0  # Files differ
    else
        return 1  # Files are the same
    fi
}

# Open plan in editor for user review
edit_plan() {
    local editor="${EDITOR:-nvim}"
    
    # Check for nvim preference
    if command -v nvim &> /dev/null; then
        editor="nvim"
    elif command -v vim &> /dev/null; then
        editor="vim"
    fi
    
    # Copy current plan to updated plan
    cp "$PLAN_PATH" "$UPDATED_PLAN_PATH"
    
    echo ""
    echo -e "${YELLOW}Opening plan in ${editor} for review...${NC}"
    echo -e "${CYAN}Edit the plan if changes are needed.${NC}"
    echo -e "${CYAN}Save and exit when complete (no changes = plan accepted).${NC}"
    echo ""
    
    # Open in editor
    $editor "$UPDATED_PLAN_PATH"
}

# Main plan generation loop
main() {
    echo -e "${BLUE}Starting Plan Generation Phase...${NC}"
    
    # Generate initial plan
    if ! run_plan_instance "initial"; then
        echo -e "${RED}Initial plan generation failed${NC}"
        return 1
    fi
    
    # Plan iteration loop
    local iteration=1
    while true; do
        echo ""
        echo -e "${MAGENTA}Plan Review Round ${iteration}${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        # Let user edit the plan
        edit_plan
        
        # Check if plan was modified
        if files_differ "$PLAN_PATH" "$UPDATED_PLAN_PATH"; then
            echo -e "${YELLOW}Plan modifications detected. Updating...${NC}"
            
            # Run update instance
            if run_plan_instance "iteration_${iteration}"; then
                ((iteration++))
            else
                echo -e "${RED}Plan update failed${NC}"
                return 1
            fi
        else
            echo -e "${GREEN}✓ Plan accepted without modifications${NC}"
            break
        fi
        
        # Safety check to prevent infinite loops
        if [[ $iteration -gt 10 ]]; then
            echo -e "${YELLOW}Maximum iterations reached. Proceeding with current plan.${NC}"
            break
        fi
    done
    
    # Clean up temporary files
    rm -f "$UPDATED_PLAN_PATH"
    
    # Save completion timestamp
    date -u +"%Y-%m-%dT%H:%M:%SZ" > "${SESSION_DIR}/.plan_completed"
    
    echo -e "${GREEN}Plan phase completed successfully${NC}"
    return 0
}

# Execute main
main