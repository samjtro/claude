#!/usr/bin/env bash

# Claude Code Refactor Orchestrator
# Manages the complete refactor workflow lifecycle

set -euo pipefail

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Session directory passed as first argument
SESSION_DIR="$1"
WORKFLOWS_DIR="$(dirname "$0")"
INSTANCES_DIR="${WORKFLOWS_DIR}/../instances"

# Function to update session status
update_session_status() {
    local phase="$1"
    local status="$2"
    local session_file="${SESSION_DIR}/session.json"
    
    # Update using jq if available, otherwise use sed
    if command -v jq &> /dev/null; then
        local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        jq --arg phase "$phase" --arg status "$status" --arg ts "$timestamp" \
           '.phases[$phase].status = $status | 
            if $status == "started" then .phases[$phase].started_at = $ts
            elif $status == "completed" then .phases[$phase].completed_at = $ts
            else . end | 
            .current_phase = $phase' \
           "$session_file" > "${session_file}.tmp" && mv "${session_file}.tmp" "$session_file"
    fi
}

# Function to display phase header
display_phase_header() {
    local phase_name="$1"
    local phase_number="$2"
    
    echo ""
    echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║${NC} ${CYAN}Phase ${phase_number}: ${phase_name}${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Step 1: Questions Generation
run_questions_phase() {
    display_phase_header "Questions Generation" "1"
    update_session_status "questions" "started"
    
    echo -e "${BLUE}Launching Claude Code instance for question generation...${NC}"
    
    # Execute questions workflow
    bash "${WORKFLOWS_DIR}/step1_questions.sh" "$SESSION_DIR"
    
    if [[ $? -eq 0 ]]; then
        update_session_status "questions" "completed"
        echo -e "${GREEN}✓ Questions phase completed${NC}"
    else
        echo -e "${RED}✗ Questions phase failed${NC}"
        exit 1
    fi
}

# Step 2: Plan Generation and Iteration
run_plan_phase() {
    display_phase_header "Plan Generation" "2"
    update_session_status "plan" "started"
    
    echo -e "${BLUE}Launching Claude Code instance for plan generation...${NC}"
    
    # Execute plan workflow
    bash "${WORKFLOWS_DIR}/step2_plan.sh" "$SESSION_DIR"
    
    if [[ $? -eq 0 ]]; then
        update_session_status "plan" "completed"
        echo -e "${GREEN}✓ Plan phase completed${NC}"
    else
        echo -e "${RED}✗ Plan phase failed${NC}"
        exit 1
    fi
}

# Step 3: Development Lifecycle
run_development_phase() {
    display_phase_header "Development Lifecycle" "3"
    update_session_status "development" "started"
    
    echo -e "${BLUE}Launching multi-agent development lifecycle...${NC}"
    
    # Execute development workflow
    bash "${WORKFLOWS_DIR}/step3_development.sh" "$SESSION_DIR"
    
    if [[ $? -eq 0 ]]; then
        update_session_status "development" "completed"
        echo -e "${GREEN}✓ Development phase completed${NC}"
    else
        echo -e "${RED}✗ Development phase failed${NC}"
        exit 1
    fi
}

# Final Review
run_review_phase() {
    display_phase_header "Final Review" "4"
    update_session_status "review" "started"
    
    echo -e "${BLUE}Launching final review process...${NC}"
    
    # Execute review workflow
    bash "${WORKFLOWS_DIR}/step4_review.sh" "$SESSION_DIR"
    
    if [[ $? -eq 0 ]]; then
        update_session_status "review" "completed"
        echo -e "${GREEN}✓ Review phase completed${NC}"
    else
        echo -e "${RED}✗ Review phase failed${NC}"
        exit 1
    fi
}

# Main orchestration function
main() {
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}                    REFACTOR WORKFLOW ORCHESTRATOR                   ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "Session: ${YELLOW}$(basename "$SESSION_DIR")${NC}"
    echo ""
    
    # Run each phase in sequence
    run_questions_phase
    run_plan_phase
    run_development_phase
    run_review_phase
    
    # Display completion summary
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC} ${CYAN}REFACTOR WORKFLOW COMPLETED SUCCESSFULLY${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "Session artifacts available at:"
    echo -e "  ${YELLOW}${SESSION_DIR}${NC}"
    echo ""
    echo -e "Key files:"
    echo -e "  - ${CYAN}GUIDE.md${NC}        : Original refactor guide"
    echo -e "  - ${CYAN}QUESTIONS.md${NC}    : Generated questions and answers"
    echo -e "  - ${CYAN}PLAN.md${NC}         : Final refactor plan"
    echo -e "  - ${CYAN}TASKS_*.md${NC}      : Phase-specific task lists"
    echo -e "  - ${CYAN}session.json${NC}    : Session metadata"
}

# Execute main orchestration
main