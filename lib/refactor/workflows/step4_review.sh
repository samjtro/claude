#!/usr/bin/env bash

# Step 4: Final Review Workflow
# Comprehensive review of the entire refactor implementation

set -euo pipefail

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

SESSION_DIR="$1"
REVIEW_DIR="${SESSION_DIR}/final_review"

# Create review directory
mkdir -p "$REVIEW_DIR"

# Create comprehensive review prompt
create_final_review_prompt() {
    cat > "${REVIEW_DIR}/final_review_prompt.txt" <<'EOF'
You are conducting a comprehensive final review of the entire refactor implementation.

REVIEW SCOPE:
1. Original Requirements Review
   - Compare against GUIDE.md specifications
   - Verify all requirements are met
   - Check alignment with user's vision

2. Implementation Quality
   - Review all phase implementations
   - Check code quality and consistency
   - Verify integration between phases
   - Ensure no loose ends or incomplete work

3. Test Coverage
   - Verify all functionality is tested
   - Check test quality and coverage
   - Ensure tests are passing

4. Documentation Review
   - Check if implementation is well-documented
   - Verify all decisions are recorded
   - Ensure future maintainability

5. Deliverables Checklist
   - All planned features implemented
   - All tests passing
   - No critical issues remaining
   - Ready for production use

CREATE:
1. final_review/REVIEW_REPORT.md with:
   - Executive summary
   - Detailed findings by category
   - Issue list (if any)
   - Recommendations
   - Final verdict (APPROVED/NEEDS_WORK)

2. final_review/IMPLEMENTATION_SUMMARY.md with:
   - What was built
   - Key architectural decisions
   - Integration points
   - Future considerations

Conduct the comprehensive review now.
EOF
}

# Run final review
run_final_review() {
    echo -e "${BLUE}Conducting comprehensive final review...${NC}"
    
    create_final_review_prompt
    
    cd "$SESSION_DIR"
    npx claude-code \
        --model opus \
        --max-turns 8 \
        --prompt "$(cat ${REVIEW_DIR}/final_review_prompt.txt)" \
        --non-interactive \
        > "${REVIEW_DIR}/review_execution.log" 2>&1
    
    if [[ -f "${REVIEW_DIR}/REVIEW_REPORT.md" ]]; then
        echo -e "${GREEN}✓ Review completed${NC}"
        return 0
    else
        echo -e "${RED}✗ Review failed${NC}"
        return 1
    fi
}

# Generate final deliverables summary
generate_deliverables_summary() {
    echo -e "${BLUE}Generating deliverables summary...${NC}"
    
    cat > "${REVIEW_DIR}/deliverables_prompt.txt" <<EOF
Create a comprehensive deliverables package for the completed refactor.

INSTRUCTIONS:
1. Create final_review/DELIVERABLES.md listing:
   - All code changes made
   - New files created
   - Modified files
   - Test suites added
   - Documentation created

2. Create final_review/HANDOVER.md with:
   - Summary of what was accomplished
   - How to use the new implementation
   - Important notes for maintenance
   - Known limitations or future work

3. Organize all session artifacts for easy reference

Make this a complete package for project handover.
EOF

    cd "$SESSION_DIR"
    npx claude-code \
        --model sonnet-3.5 \
        --max-turns 3 \
        --prompt "$(cat ${REVIEW_DIR}/deliverables_prompt.txt)" \
        --non-interactive \
        > "${REVIEW_DIR}/deliverables.log" 2>&1
}

# Display review results
display_review_results() {
    echo ""
    echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║${NC} ${CYAN}FINAL REVIEW RESULTS${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Check review verdict
    if grep -q "APPROVED" "${REVIEW_DIR}/REVIEW_REPORT.md" 2>/dev/null; then
        echo -e "${GREEN}✓ REFACTOR APPROVED${NC}"
        echo -e "${GREEN}  The refactor has been successfully completed and reviewed.${NC}"
    else
        echo -e "${YELLOW}⚠ REFACTOR NEEDS ATTENTION${NC}"
        echo -e "${YELLOW}  Please review the report for required improvements.${NC}"
    fi
    
    echo ""
    echo -e "Review artifacts:"
    echo -e "  ${CYAN}${REVIEW_DIR}/REVIEW_REPORT.md${NC}"
    echo -e "  ${CYAN}${REVIEW_DIR}/IMPLEMENTATION_SUMMARY.md${NC}"
    echo -e "  ${CYAN}${REVIEW_DIR}/DELIVERABLES.md${NC}"
    echo -e "  ${CYAN}${REVIEW_DIR}/HANDOVER.md${NC}"
}

# Main review execution
main() {
    echo -e "${BLUE}Starting Final Review Phase...${NC}"
    
    # Run comprehensive review
    if ! run_final_review; then
        echo -e "${RED}Final review failed${NC}"
        return 1
    fi
    
    # Generate deliverables summary
    generate_deliverables_summary
    
    # Display results
    display_review_results
    
    # Save completion timestamp
    date -u +"%Y-%m-%dT%H:%M:%SZ" > "${SESSION_DIR}/.review_completed"
    
    echo -e "${GREEN}Review phase completed${NC}"
    return 0
}

# Execute main
main