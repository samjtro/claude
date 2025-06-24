#!/usr/bin/env bash

# Test script for the refactor workflow system
# This script validates the refactor system installation and basic functionality

set -euo pipefail

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test results
TESTS_PASSED=0
TESTS_FAILED=0

# Test function
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo -e "${BLUE}Running test: ${test_name}${NC}"
    
    if eval "$test_command"; then
        echo -e "${GREEN}✓ PASSED${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAILED${NC}"
        ((TESTS_FAILED++))
    fi
    echo
}

# Test 1: Check if refactor command exists
test_refactor_command() {
    [[ -f "$HOME/.claude/commands/apm-refactor.md" ]]
}

# Test 2: Check if refactor script is executable
test_refactor_script() {
    [[ -x "$HOME/.claude/lib/refactor/commands/refactor.sh" ]]
}

# Test 3: Check if workflow scripts exist
test_workflow_scripts() {
    local workflows=(
        "orchestrator.sh"
        "step1_questions.sh"
        "step2_plan.sh"
        "step3_development.sh"
        "step4_review.sh"
    )
    
    for script in "${workflows[@]}"; do
        if [[ ! -f "$HOME/.claude/lib/refactor/workflows/$script" ]]; then
            return 1
        fi
    done
    return 0
}

# Test 4: Check if sessions directory exists
test_sessions_directory() {
    [[ -d "$HOME/.claude/refactor/sessions" ]]
}

# Test 5: Check NPX availability
test_npx_available() {
    command -v npx &> /dev/null
}

# Test 6: Check Claude Code CLI
test_claude_cli() {
    command -v claude &> /dev/null || command -v npx &> /dev/null
}

# Test 7: Create test guide and validate argument parsing
test_argument_parsing() {
    local test_guide="/tmp/test_refactor_guide.md"
    cat > "$test_guide" <<EOF
# Test Refactor Guide

This is a test guide for validating the refactor system.

## Objectives
- Test the refactor workflow
- Validate argument parsing
- Ensure proper error handling
EOF
    
    # Test with valid argument (dry run - just check parsing)
    if bash "$HOME/.claude/lib/refactor/commands/refactor.sh" "$test_guide" 2>&1 | grep -q "Session initialized"; then
        rm -f "$test_guide"
        return 0
    else
        rm -f "$test_guide"
        return 1
    fi
}

# Main test execution
main() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}                    REFACTOR SYSTEM TEST SUITE                      ${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
    echo
    
    # Run all tests
    run_test "Refactor command exists" test_refactor_command
    run_test "Refactor script is executable" test_refactor_script
    run_test "All workflow scripts exist" test_workflow_scripts
    run_test "Sessions directory exists" test_sessions_directory
    run_test "NPX is available" test_npx_available
    run_test "Claude CLI is available" test_claude_cli
    
    # Summary
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}                           TEST SUMMARY                             ${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
    echo
    echo -e "Tests passed: ${GREEN}${TESTS_PASSED}${NC}"
    echo -e "Tests failed: ${RED}${TESTS_FAILED}${NC}"
    echo
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}All tests passed! The refactor system is properly installed.${NC}"
        return 0
    else
        echo -e "${RED}Some tests failed. Please check the installation.${NC}"
        return 1
    fi
}

# Execute main
main