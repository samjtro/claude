#!/bin/bash
# Codex integration for enhanced code review capabilities

set -euo pipefail

# Configuration
CODEX_ENABLED=${CODEX_ENABLED:-false}
CODEX_API_KEY=${OPENAI_API_KEY:-}
CODEX_MODEL=${CODEX_MODEL:-"gpt-4"}
CODEX_LOG="$HOME/.claudebox/logs/codex.log"

# Ensure log directory exists
mkdir -p "$(dirname "$CODEX_LOG")"

# Logging function
log_codex() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [CODEX] $*" | tee -a "$CODEX_LOG"
}

# Check if Codex should be enabled
check_codex_availability() {
    if [ "$CODEX_ENABLED" != "true" ]; then
        log_codex "Codex integration disabled"
        return 1
    fi
    
    if [ -z "$CODEX_API_KEY" ]; then
        log_codex "OpenAI API key not set. Set OPENAI_API_KEY to enable Codex"
        return 1
    fi
    
    if ! command -v curl >/dev/null 2>&1; then
        log_codex "curl not found. Please install curl for Codex integration"
        return 1
    fi
    
    if ! command -v jq >/dev/null 2>&1; then
        log_codex "jq not found. Please install jq for Codex integration"
        return 1
    fi
    
    return 0
}

# Analyze code using Codex/GPT-4
analyze_code() {
    local file_path=$1
    local analysis_type=${2:-"review"}  # review, security, performance, etc.
    
    if [ ! -f "$file_path" ]; then
        log_codex "File not found: $file_path"
        return 1
    fi
    
    # Read file content
    local content=$(cat "$file_path" | head -1000)  # Limit to first 1000 lines
    
    # Create prompt based on analysis type
    local prompt
    case "$analysis_type" in
        "review")
            prompt="Review this code for quality, bugs, and best practices:\n\n$content"
            ;;
        "security")
            prompt="Analyze this code for security vulnerabilities:\n\n$content"
            ;;
        "performance")
            prompt="Analyze this code for performance issues:\n\n$content"
            ;;
        *)
            prompt="Analyze this code:\n\n$content"
            ;;
    esac
    
    # Call OpenAI API
    local response=$(curl -s -X POST "https://api.openai.com/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $CODEX_API_KEY" \
        -d @- <<EOF
{
    "model": "$CODEX_MODEL",
    "messages": [
        {
            "role": "system",
            "content": "You are an expert code reviewer. Provide concise, actionable feedback."
        },
        {
            "role": "user",
            "content": $(echo "$prompt" | jq -Rs .)
        }
    ],
    "temperature": 0.3,
    "max_tokens": 1000
}
EOF
    )
    
    # Extract and return the analysis
    echo "$response" | jq -r '.choices[0].message.content' 2>/dev/null || {
        log_codex "Failed to parse Codex response"
        echo "$response" >> "$CODEX_LOG"
        return 1
    }
}

# Batch analyze multiple files
batch_analyze() {
    local analysis_type=$1
    shift
    local files=("$@")
    
    log_codex "Starting batch analysis of ${#files[@]} files"
    
    local output_dir="$HOME/.claudebox/codex_analysis/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$output_dir"
    
    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            log_codex "Analyzing: $file"
            local analysis=$(analyze_code "$file" "$analysis_type")
            
            # Save analysis to file
            local output_file="$output_dir/$(basename "$file").analysis.md"
            cat > "$output_file" <<EOF
# Codex Analysis: $file
**Type**: $analysis_type
**Date**: $(date)

## Analysis Results
$analysis
EOF
            
            echo "Analysis saved to: $output_file"
        fi
    done
    
    log_codex "Batch analysis complete. Results in: $output_dir"
}

# Integrate with reviewer agent
enhance_review() {
    local changed_files=$1
    
    if ! check_codex_availability; then
        return 0  # Silently skip if not available
    fi
    
    log_codex "Enhancing review with Codex analysis"
    
    # Create temporary file for enhanced review
    local enhanced_review="$HOME/.claudebox/logs/enhanced_review.md"
    
    echo "# Enhanced Code Review (Codex)" > "$enhanced_review"
    echo "" >> "$enhanced_review"
    
    # Analyze each changed file
    while IFS= read -r file; do
        if [ -f "$file" ]; then
            echo "## File: $file" >> "$enhanced_review"
            echo "" >> "$enhanced_review"
            
            # Run different types of analysis
            for analysis_type in "review" "security" "performance"; do
                echo "### ${analysis_type^} Analysis" >> "$enhanced_review"
                analyze_code "$file" "$analysis_type" >> "$enhanced_review" 2>/dev/null || echo "Analysis failed" >> "$enhanced_review"
                echo "" >> "$enhanced_review"
            done
        fi
    done <<< "$changed_files"
    
    log_codex "Enhanced review complete"
    echo "$enhanced_review"
}

# Main function for standalone usage
main() {
    case "${1:-help}" in
        "analyze")
            shift
            if [ $# -lt 1 ]; then
                echo "Usage: $0 analyze <file> [analysis_type]"
                exit 1
            fi
            analyze_code "$@"
            ;;
        "batch")
            shift
            if [ $# -lt 2 ]; then
                echo "Usage: $0 batch <analysis_type> <file1> [file2...]"
                exit 1
            fi
            batch_analyze "$@"
            ;;
        "enhance-review")
            shift
            if [ $# -lt 1 ]; then
                echo "Usage: $0 enhance-review <changed_files>"
                exit 1
            fi
            enhance_review "$@"
            ;;
        "check")
            if check_codex_availability; then
                echo "Codex integration is available and configured"
            else
                echo "Codex integration is not available"
                exit 1
            fi
            ;;
        *)
            cat <<EOF
Codex Integration for claudebox

Usage:
  $0 analyze <file> [analysis_type]     Analyze a single file
  $0 batch <type> <files...>           Batch analyze multiple files
  $0 enhance-review <changed_files>    Enhance code review
  $0 check                             Check Codex availability

Analysis types: review, security, performance

Environment variables:
  CODEX_ENABLED     Enable Codex integration (true/false)
  OPENAI_API_KEY    OpenAI API key for Codex
  CODEX_MODEL       Model to use (default: gpt-4)
EOF
            ;;
    esac
}

# Run main if executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi