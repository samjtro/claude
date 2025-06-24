#!/usr/bin/env bash
set -euo pipefail

# Environment setup script for Claude
# This script helps set up required environment variables

echo "🔧 Claude Environment Setup"
echo

# Function to add variable to env file
add_to_env() {
    local var_name="$1"
    local var_desc="$2"
    local default_val="${3:-}"
    local env_file="$HOME/.claude_env"
    
    # Check if already set in environment
    if [[ -n "${!var_name:-}" ]]; then
        echo "✓ $var_name is already set"
        return
    fi
    
    # Check if in env file
    if [[ -f "$env_file" ]] && grep -q "^export $var_name=" "$env_file"; then
        echo "✓ $var_name exists in .claude_env"
        return
    fi
    
    # Prompt for value
    echo "📝 $var_desc"
    if [[ -n "$default_val" ]]; then
        read -p "Enter $var_name (default: $default_val): " value
        value="${value:-$default_val}"
    else
        read -p "Enter $var_name: " value
    fi
    
    # Add to env file
    if [[ -n "$value" ]]; then
        echo "export $var_name=$value" >> "$env_file"
        echo "✓ Added $var_name to .claude_env"
    else
        echo "⚠️  Skipped $var_name (no value provided)"
    fi
    echo
}

# Create env file if it doesn't exist
env_file="$HOME/.claude_env"
if [[ ! -f "$env_file" ]]; then
    cat > "$env_file" << 'EOF'
# Claude Environment Variables
# This file is sourced by your shell profile

EOF
fi

# Setup required variables
add_to_env "ANTHROPIC_API_KEY" "Your Anthropic API key (required for Claude)"
add_to_env "OPENROUTER_API_KEY" "Your OpenRouter API key (optional, for additional models)"
add_to_env "OPENROUTER_DEFAULT_MODEL" "Default OpenRouter model" "gpt-4"
add_to_env "GITHUB_TOKEN" "GitHub personal access token (optional, for GitHub MCP server)"

# Add to shell profile
shell_profile=""
if [[ -f "$HOME/.zshrc" ]]; then
    shell_profile="$HOME/.zshrc"
elif [[ -f "$HOME/.bashrc" ]]; then
    shell_profile="$HOME/.bashrc"
elif [[ -f "$HOME/.bash_profile" ]]; then
    shell_profile="$HOME/.bash_profile"
fi

if [[ -n "$shell_profile" ]]; then
    if ! grep -q "source.*\.claude_env" "$shell_profile"; then
        echo "" >> "$shell_profile"
        echo "# Claude environment variables" >> "$shell_profile"
        echo "[[ -f \"\$HOME/.claude_env\" ]] && source \"\$HOME/.claude_env\"" >> "$shell_profile"
        echo "✓ Added source command to $shell_profile"
    else
        echo "✓ .claude_env is already sourced in $shell_profile"
    fi
fi

echo
echo "🎉 Environment setup complete!"
echo
echo "Next steps:"
echo "1. Review and edit $env_file if needed"
echo "2. Restart your terminal or run: source $env_file"
echo