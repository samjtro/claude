#!/usr/bin/env bash

# Step 3: Development Lifecycle Workflow
# Manages multi-agent development with Opus orchestrating Sonnet instances

set -euo pipefail

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

SESSION_DIR="$1"
PLAN_PATH="${SESSION_DIR}/PLAN.md"
DEVELOPMENT_DIR="${SESSION_DIR}/development"

# Create development directory structure
mkdir -p "${DEVELOPMENT_DIR}/phases"
mkdir -p "${DEVELOPMENT_DIR}/tasks"
mkdir -p "${DEVELOPMENT_DIR}/tests"
mkdir -p "${DEVELOPMENT_DIR}/reviews"

# Extract phases from plan
extract_phases() {
    echo -e "${BLUE}Extracting phases from plan...${NC}"
    
    # Create phase extraction prompt
    cat > "${SESSION_DIR}/extract_phases_prompt.txt" <<'EOF'
You are analyzing a refactor plan to extract distinct development phases.

INSTRUCTIONS:
1. Read the plan from PLAN.md
2. Identify all distinct phases mentioned in the plan
3. For each phase, extract:
   - Phase number and name
   - Objectives
   - Task list
   - Dependencies
4. Save phase information to development/phases/phases.json

OUTPUT FORMAT (JSON):
{
  "phases": [
    {
      "number": 1,
      "name": "Phase Name",
      "objectives": ["objective1", "objective2"],
      "tasks": ["task1", "task2"],
      "dependencies": [],
      "status": "pending"
    }
  ]
}

Extract phases from PLAN.md now.
EOF

    cd "$SESSION_DIR"
    npx claude-code \
        --model opus \
        --max-turns 3 \
        --prompt "$(cat extract_phases_prompt.txt)" \
        --non-interactive \
        > "${DEVELOPMENT_DIR}/phase_extraction.log" 2>&1
    
    if [[ -f "${DEVELOPMENT_DIR}/phases/phases.json" ]]; then
        echo -e "${GREEN}✓ Phases extracted successfully${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to extract phases${NC}"
        return 1
    fi
}

# Create task manager prompt for a phase
create_task_manager_prompt() {
    local phase_num="$1"
    local phase_name="$2"
    
    cat > "${DEVELOPMENT_DIR}/phases/phase_${phase_num}_prompt.txt" <<EOF
You are an expert Project Manager orchestrating development tasks for Phase ${phase_num}: ${phase_name}.

INSTRUCTIONS:
1. Ultrathink to establish a complete set of tasks for this phase
2. Review PLAN.md, GUIDE.md, and QUESTIONS.md to understand context
3. Break down the phase into granular, actionable tasks
4. For each task, prepare:
   - Clear objective
   - Technical specifications
   - Implementation approach
   - Success criteria
5. Save tasks to development/tasks/TASKS_PHASE${phase_num}_$(date +%s).md

IMPORTANT: After creating the task list, you will spawn individual Sonnet instances for each task. Prepare comprehensive briefs for each.

TASK STRUCTURE:
# Phase ${phase_num}: ${phase_name} Tasks

## Task 1: [Task Name]
**Objective**: Clear description
**Technical Specs**: Detailed requirements
**Implementation**: Step-by-step approach
**Success Criteria**: Measurable outcomes

[Continue for all tasks...]

Read all context files and create the comprehensive task list.
EOF
}

# Run development for a single phase
run_phase_development() {
    local phase_num="$1"
    local phase_name="$2"
    local phase_dir="${DEVELOPMENT_DIR}/phases/phase_${phase_num}"
    
    mkdir -p "$phase_dir"
    
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  Developing Phase ${phase_num}: ${phase_name}${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
    
    # Step 1: Create tasks with Opus
    echo -e "${BLUE}Creating task list...${NC}"
    create_task_manager_prompt "$phase_num" "$phase_name"
    
    cd "$SESSION_DIR"
    npx claude-code \
        --model opus \
        --max-turns 5 \
        --prompt "$(cat ${DEVELOPMENT_DIR}/phases/phase_${phase_num}_prompt.txt)" \
        --non-interactive \
        > "${phase_dir}/task_creation.log" 2>&1
    
    # Find the created tasks file
    local tasks_file=$(find "${DEVELOPMENT_DIR}/tasks" -name "TASKS_PHASE${phase_num}_*.md" | head -1)
    
    if [[ ! -f "$tasks_file" ]]; then
        echo -e "${RED}✗ Failed to create tasks for phase ${phase_num}${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓ Tasks created for phase ${phase_num}${NC}"
    
    # Step 2: Execute tasks with Sonnet instances
    echo -e "${BLUE}Executing development tasks...${NC}"
    
    # Create task execution orchestrator prompt
    cat > "${phase_dir}/execute_tasks_prompt.txt" <<EOF
You are orchestrating the execution of development tasks for Phase ${phase_num}.

INSTRUCTIONS:
1. Read the task list from ${tasks_file}
2. For each task, create a comprehensive prompt for a Sonnet instance
3. Execute each task by spawning Sonnet instances with:
   - Detailed implementation instructions
   - All necessary context from GUIDE.md, QUESTIONS.md, and PLAN.md
   - Clear success criteria
4. Track task completion in development/phases/phase_${phase_num}/task_status.json
5. After all tasks complete, create a test suite

EXECUTION APPROACH:
- Use 'npx claude-code --model sonnet-3.5 --single-turn' for each task
- Provide ultrathink instructions for complex tasks
- Ensure each task builds on previous ones appropriately
- Save all outputs to development/phases/phase_${phase_num}/

Begin task execution now.
EOF

    npx claude-code \
        --model opus \
        --max-turns 10 \
        --prompt "$(cat ${phase_dir}/execute_tasks_prompt.txt)" \
        --non-interactive \
        > "${phase_dir}/task_execution.log" 2>&1
    
    # Step 3: Run tests
    echo -e "${BLUE}Running test suite...${NC}"
    
    cat > "${phase_dir}/run_tests_prompt.txt" <<EOF
Run the test suite created for Phase ${phase_num} and ensure all tests pass.

INSTRUCTIONS:
1. Locate the test suite in the phase directory
2. Execute all tests in an interactive environment
3. Fix any failing tests
4. Continue until all tests pass
5. Save test results to development/tests/phase_${phase_num}_results.json

Begin test execution.
EOF

    npx claude-code \
        --model sonnet-3.5 \
        --max-turns 15 \
        --prompt "$(cat ${phase_dir}/run_tests_prompt.txt)" \
        > "${phase_dir}/test_execution.log" 2>&1
    
    echo -e "${GREEN}✓ Phase ${phase_num} development completed${NC}"
    return 0
}

# Review phase implementation
review_phase() {
    local phase_num="$1"
    local phase_name="$2"
    
    echo -e "${BLUE}Reviewing Phase ${phase_num} implementation...${NC}"
    
    cat > "${DEVELOPMENT_DIR}/reviews/phase_${phase_num}_review_prompt.txt" <<EOF
You are reviewing the implementation of Phase ${phase_num}: ${phase_name}.

REVIEW CRITERIA:
1. Compare implementation against:
   - Original PLAN.md specifications
   - GUIDE.md requirements
   - QUESTIONS.md context
2. Check for:
   - Complete task implementation
   - Test coverage
   - Code quality
   - No hallucinations or incomplete work
3. Identify any:
   - Missing functionality
   - Unfinished tasks
   - Quality issues
   - Integration problems

REVIEW OUTPUT:
Create a review report at development/reviews/phase_${phase_num}_review.md with:
- Summary of implementation
- Compliance with requirements
- Issues found (if any)
- Recommendation (PASS/FAIL)

Perform comprehensive review now.
EOF

    cd "$SESSION_DIR"
    npx claude-code \
        --model opus \
        --max-turns 5 \
        --prompt "$(cat ${DEVELOPMENT_DIR}/reviews/phase_${phase_num}_review_prompt.txt)" \
        --non-interactive \
        > "${DEVELOPMENT_DIR}/reviews/phase_${phase_num}_review.log" 2>&1
    
    # Check review result
    if grep -q "PASS" "${DEVELOPMENT_DIR}/reviews/phase_${phase_num}_review.md" 2>/dev/null; then
        echo -e "${GREEN}✓ Phase ${phase_num} passed review${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ Phase ${phase_num} requires attention${NC}"
        return 1
    fi
}

# Main development lifecycle
main() {
    echo -e "${BLUE}Starting Development Lifecycle...${NC}"
    
    # Extract phases from plan
    if ! extract_phases; then
        echo -e "${RED}Failed to extract phases${NC}"
        return 1
    fi
    
    # Read phases (simple parsing without jq dependency)
    local phase_count=$(grep -c '"number"' "${DEVELOPMENT_DIR}/phases/phases.json" || echo "0")
    
    if [[ $phase_count -eq 0 ]]; then
        echo -e "${RED}No phases found in plan${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Found ${phase_count} development phases${NC}"
    
    # Process each phase
    for ((i=1; i<=phase_count; i++)); do
        # Extract phase name (basic parsing)
        local phase_name="Phase ${i}"
        
        # Run development for this phase
        if run_phase_development "$i" "$phase_name"; then
            # Review the phase
            if ! review_phase "$i" "$phase_name"; then
                echo -e "${YELLOW}Phase ${i} needs revision${NC}"
                # In a real implementation, we might loop here for fixes
            fi
        else
            echo -e "${RED}Phase ${i} development failed${NC}"
            return 1
        fi
    done
    
    # Save completion timestamp
    date -u +"%Y-%m-%dT%H:%M:%SZ" > "${SESSION_DIR}/.development_completed"
    
    echo -e "${GREEN}Development lifecycle completed successfully${NC}"
    return 0
}

# Execute main
main