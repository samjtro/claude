#!/usr/bin/env bash

# Claude Code Refactor Command
# Initiates a comprehensive refactor workflow with multi-agent orchestration

set -euo pipefail

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
REFACTOR_BASE_DIR="${HOME}/.claude/refactor/sessions"
WORKFLOWS_DIR="$(dirname "$0")/../workflows"
INSTANCES_DIR="$(dirname "$0")/../instances"

# Ensure base directories exist
mkdir -p "$REFACTOR_BASE_DIR"

# Function to display usage
usage() {
    echo -e "${CYAN}Claude Code Refactor System${NC}"
    echo -e "${GREEN}Usage:${NC} /refactor <PATH_TO_GUIDE.md>"
    echo ""
    echo "Initiates a comprehensive refactor workflow with:"
    echo "  - Question generation phase"
    echo "  - Plan creation and iteration"
    echo "  - Multi-agent development lifecycle"
    echo "  - Automated review and validation"
    echo ""
    echo -e "${YELLOW}Arguments:${NC}"
    echo "  PATH_TO_GUIDE.md    Path to your refactor guide markdown file"
    echo ""
    echo -e "${BLUE}Example:${NC}"
    echo "  /refactor ./docs/api-refactor-guide.md"
    exit 1
}

# Function to create timestamped session directory
create_session_directory() {
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local session_name="refactor_${timestamp}"
    local session_dir="${REFACTOR_BASE_DIR}/${session_name}"
    
    mkdir -p "$session_dir"
    echo "$session_dir"
}

# Function to validate guide file
validate_guide_file() {
    local guide_path="$1"
    
    if [[ ! -f "$guide_path" ]]; then
        echo -e "${RED}Error:${NC} Guide file not found: $guide_path"
        exit 1
    fi
    
    if [[ ! "$guide_path" =~ \.md$ ]]; then
        echo -e "${YELLOW}Warning:${NC} Guide file should be a markdown (.md) file"
    fi
    
    # Make absolute path
    echo "$(cd "$(dirname "$guide_path")" && pwd)/$(basename "$guide_path")"
}

# Function to initialize session
initialize_session() {
    local session_dir="$1"
    local guide_path="$2"
    
    # Copy guide to session directory
    cp "$guide_path" "$session_dir/GUIDE.md"
    
    # Create session metadata
    cat > "$session_dir/session.json" <<EOF
{
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "guide_path": "$guide_path",
  "status": "initialized",
  "current_phase": "questions",
  "phases": {
    "questions": {"status": "pending", "started_at": null, "completed_at": null},
    "plan": {"status": "pending", "started_at": null, "completed_at": null},
    "development": {"status": "pending", "started_at": null, "completed_at": null},
    "review": {"status": "pending", "started_at": null, "completed_at": null}
  }
}
EOF
    
    echo -e "${GREEN}✓${NC} Session initialized at: ${CYAN}$session_dir${NC}"
}

# Function to start refactor workflow
start_refactor_workflow() {
    local session_dir="$1"
    
    echo -e "${MAGENTA}Starting Refactor Workflow${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Execute the main workflow orchestrator
    bash "${WORKFLOWS_DIR}/orchestrator.sh" "$session_dir"
}

# Main execution
main() {
    # Check arguments
    if [[ $# -lt 1 ]]; then
        usage
    fi
    
    local guide_path="$1"
    
    # Validate guide file
    guide_path=$(validate_guide_file "$guide_path")
    
    # Create session directory
    local session_dir=$(create_session_directory)
    
    # Initialize session
    initialize_session "$session_dir" "$guide_path"
    
    # Start the refactor workflow
    start_refactor_workflow "$session_dir"
}

# Execute main function
main "$@"