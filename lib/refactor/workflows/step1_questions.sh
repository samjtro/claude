#!/usr/bin/env bash

# Step 1: Questions Generation Workflow
# Generates comprehensive questions using Claude Code Opus instance

set -euo pipefail

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SESSION_DIR="$1"
GUIDE_PATH="${SESSION_DIR}/GUIDE.md"
QUESTIONS_PATH="${SESSION_DIR}/QUESTIONS.md"
INSTANCES_DIR="$(dirname "$0")/../instances"

# Create questions generation prompt
create_questions_prompt() {
    cat > "${SESSION_DIR}/questions_prompt.txt" <<'EOF'
You are an expert Project Manager conducting a comprehensive analysis of a refactor guide. Your task is to generate insightful questions that will ensure the refactor is successful.

INSTRUCTIONS:
1. Ultrathink as an expert PM to examine the provided refactor guide multiple times
2. Create a comprehensive list of questions organized by refactor phases
3. Focus on both high-level architectural concerns and granular implementation details
4. Ensure questions cover all aspects that could impact the refactor's success
5. Save the questions to QUESTIONS.md in a clear, organized format

QUESTION CATEGORIES TO CONSIDER:
- Architecture & Design
- Technical Implementation
- Integration Points
- Testing Strategy
- Performance Considerations
- Security Implications
- Migration Path
- Rollback Strategy
- Documentation Needs
- Team & Resource Requirements

Read the refactor guide at GUIDE.md and generate your questions.
EOF
}

# Execute Claude Code instance for questions
run_questions_instance() {
    echo -e "${BLUE}Generating questions based on refactor guide...${NC}"
    
    # Create the prompt
    create_questions_prompt
    
    # Run Claude Code with the questions prompt
    cd "$SESSION_DIR"
    
    # Use Claude Code SDK to run the questions generation
    npx claude-code \
        --model opus \
        --max-turns 5 \
        --prompt "$(cat questions_prompt.txt)" \
        --non-interactive \
        > questions_generation.log 2>&1
    
    # Check if QUESTIONS.md was created
    if [[ -f "$QUESTIONS_PATH" ]]; then
        echo -e "${GREEN}✓ Questions generated successfully${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to generate questions${NC}"
        return 1
    fi
}

# Open questions in editor for user to answer
edit_questions() {
    local editor="${EDITOR:-nvim}"
    
    # Check for nvim preference
    if command -v nvim &> /dev/null; then
        editor="nvim"
    elif command -v vim &> /dev/null; then
        editor="vim"
    fi
    
    echo ""
    echo -e "${YELLOW}Opening questions in ${editor}...${NC}"
    echo -e "${CYAN}Please answer the questions to provide context for the refactor.${NC}"
    echo -e "${CYAN}Save and exit when complete.${NC}"
    echo ""
    
    # Add instructions to the questions file
    {
        echo "# REFACTOR QUESTIONS"
        echo ""
        echo "Please answer the following questions to provide context for the refactor."
        echo "Your answers will guide the creation of a comprehensive refactor plan."
        echo ""
        echo "---"
        echo ""
        cat "$QUESTIONS_PATH"
    } > "${QUESTIONS_PATH}.tmp"
    mv "${QUESTIONS_PATH}.tmp" "$QUESTIONS_PATH"
    
    # Open in editor
    $editor "$QUESTIONS_PATH"
    
    echo -e "${GREEN}✓ Questions answered${NC}"
}

# Main execution
main() {
    echo -e "${BLUE}Starting Questions Generation Phase...${NC}"
    
    # Run questions instance
    if run_questions_instance; then
        # Open for user editing
        edit_questions
        
        # Save completion timestamp
        date -u +"%Y-%m-%dT%H:%M:%SZ" > "${SESSION_DIR}/.questions_completed"
        
        echo -e "${GREEN}Questions phase completed successfully${NC}"
        return 0
    else
        echo -e "${RED}Questions phase failed${NC}"
        return 1
    fi
}

# Execute main
main