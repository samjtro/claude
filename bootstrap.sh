#!/usr/bin/env bash
set -euo pipefail

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Utility functions
cecho() { echo -e "${2:-$NC}$1${NC}"; }
error() { cecho "$1" "$RED" >&2; exit "${2:-1}"; }
warn() { cecho "$1" "$YELLOW"; }
info() { cecho "$1" "$BLUE"; }
success() { cecho "$1" "$GREEN"; }

# Configuration
readonly CLAUDE_CONFIG_DIR="$HOME/Library/Application Support/Claude"
readonly REPO_URL="https://github.com/samjtro/claude.git"
readonly TEMP_DIR="/tmp/claude-bootstrap-$$"

# Clone the repository to get source files
info "🚀 Claude Bootstrap - Cloning repository..."
git clone "$REPO_URL" "$TEMP_DIR" || error "Failed to clone repository"
cd "$TEMP_DIR"
readonly SCRIPT_DIR="$TEMP_DIR"

info "🚀 Claude Bootstrap - Setting up Claude Desktop/Code with QoL features"
echo

# Check if Claude Desktop or Claude Code is installed
claude_found=false

# Check for Claude Desktop app on macOS
if [[ -d "/Applications/Claude.app" ]]; then
    claude_found=true
    info "Claude Desktop detected at /Applications/Claude.app"
    # Ensure config directory exists
    if [[ ! -d "$CLAUDE_CONFIG_DIR" ]]; then
        mkdir -p "$CLAUDE_CONFIG_DIR"
        info "Creating configuration directory..."
    fi
elif command -v claude &> /dev/null; then
    # Claude Code CLI is installed
    claude_found=true
    info "Claude Code CLI detected"
    # Ensure config directory exists
    if [[ ! -d "$CLAUDE_CONFIG_DIR" ]]; then
        mkdir -p "$CLAUDE_CONFIG_DIR"
        info "Creating configuration directory..."
    fi
elif [[ -d "$CLAUDE_CONFIG_DIR" ]]; then
    # Config directory exists, assume Claude is installed
    claude_found=true
    info "Claude configuration directory found"
else
    error "Neither Claude Desktop nor Claude Code CLI found. Please install Claude Desktop or Claude Code first."
fi

# Function to backup existing config
backup_config() {
    local config_file="$CLAUDE_CONFIG_DIR/claude_desktop_config.json"
    if [[ -f "$config_file" ]]; then
        local backup_file="${config_file}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$config_file" "$backup_file"
        success "✓ Backed up existing config to: $backup_file"
    fi
}

# Function to merge MCP servers into existing config
merge_mcp_config() {
    local config_file="$CLAUDE_CONFIG_DIR/claude_desktop_config.json"
    local new_config="$SCRIPT_DIR/configs/claude_desktop_config.json"
    
    if [[ ! -f "$config_file" ]]; then
        # No existing config, copy new one
        cp "$new_config" "$config_file"
        success "✓ Created new Claude config with MCP servers"
    else
        # Merge configurations using jq
        if command -v jq &> /dev/null; then
            # Create merged config
            jq -s '.[0] * .[1]' "$config_file" "$new_config" > "$config_file.tmp"
            mv "$config_file.tmp" "$config_file"
            success "✓ Merged MCP servers into existing config"
        else
            warn "⚠️  jq not found. Installing jq is recommended for config merging."
            warn "   Run: brew install jq (macOS) or apt-get install jq (Linux)"
            warn "   Alternatively, manually merge configs from: $new_config"
        fi
    fi
}

# Function to detect authentication method
detect_auth_method() {
    local auth_method="none"
    local auth_details=""
    local auth_pref_file="$HOME/.claude/auth_preferences.json"
    
    info "🔍 Detecting existing authentication method..."
    
    # First check for saved authentication preferences
    if [[ -f "$auth_pref_file" ]] && command -v jq &> /dev/null; then
        local saved_method=$(jq -r '.authMethod // "none"' "$auth_pref_file" 2>/dev/null)
        if [[ "$saved_method" != "none" ]]; then
            info "Found saved authentication preference: $saved_method"
        fi
    fi
    
    # Check for API key authentication
    if [[ -n "${ANTHROPIC_API_KEY:-}" ]] || [[ -f "$HOME/.claude_env" ]] && grep -q "ANTHROPIC_API_KEY" "$HOME/.claude_env" 2>/dev/null; then
        auth_method="api_key"
        auth_details="Environment variable (ANTHROPIC_API_KEY)"
    fi
    
    # Check if Claude Code CLI is authenticated via /login
    # Since Claude Code uses ephemeral session auth, we check if the CLI is installed
    # and try to detect if user has active session by checking claude CLI status
    if command -v claude &> /dev/null; then
        # Try to run a simple claude command to check if authenticated
        if claude --version &> /dev/null; then
            # If we already detected API key, this might be dual auth
            if [[ "$auth_method" == "api_key" ]]; then
                auth_method="dual"
                auth_details="Both API key and Claude Code session"
            else
                auth_method="session"
                auth_details="Claude Code /login session"
            fi
        fi
    fi
    
    echo "$auth_method|$auth_details"
}

# Function to prompt for authentication method
prompt_auth_method() {
    local current_auth="$1"
    local current_details="$2"
    
    echo
    info "🔐 Authentication Configuration"
    echo
    
    if [[ "$current_auth" != "none" ]]; then
        success "Current authentication method: $current_auth"
        info "Details: $current_details"
        echo
        read -p "Keep current authentication method? [Y/n] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
            # Save current auth preference
            save_auth_preferences "$current_auth"
            return 0
        fi
    else
        warn "⚠️  No authentication method detected"
    fi
    
    echo
    info "Select authentication method:"
    echo "1) API Key (Environment variable)"
    echo "2) Claude Code /login (Session-based)"
    echo "3) Both (API key + Session)"
    echo "4) Skip authentication setup"
    echo
    read -p "Enter choice [1-4]: " -n 1 -r auth_choice
    echo
    
    case "$auth_choice" in
        1)
            setup_api_key_auth
            save_auth_preferences "api_key"
            ;;
        2)
            setup_session_auth
            save_auth_preferences "session"
            ;;
        3)
            setup_api_key_auth
            setup_session_auth
            save_auth_preferences "dual"
            ;;
        4)
            info "Skipping authentication setup"
            ;;
        *)
            warn "Invalid choice. Skipping authentication setup"
            ;;
    esac
}

# Function to setup API key authentication
setup_api_key_auth() {
    local env_file="$HOME/.claude_env"
    
    info "Setting up API key authentication..."
    
    # Check if API key is already set
    if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
        success "✓ ANTHROPIC_API_KEY already set in environment"
        return
    fi
    
    # Check if env file exists with API key
    if [[ -f "$env_file" ]] && grep -q "ANTHROPIC_API_KEY" "$env_file"; then
        local existing_key=$(grep "ANTHROPIC_API_KEY" "$env_file" | cut -d'=' -f2)
        if [[ "$existing_key" != "your-key-here" ]] && [[ -n "$existing_key" ]]; then
            success "✓ ANTHROPIC_API_KEY found in $env_file"
            return
        fi
    fi
    
    # Create or update env file
    if [[ ! -f "$env_file" ]]; then
        cat > "$env_file" << 'EOF'
# Claude Environment Variables
# Add your API keys here and source this file in your shell profile

EOF
    fi
    
    if ! grep -q "ANTHROPIC_API_KEY" "$env_file"; then
        echo "export ANTHROPIC_API_KEY=your-key-here" >> "$env_file"
    fi
    
    warn "⚠️  Please edit $env_file and add your Anthropic API key"
    info "   Get your API key from: https://console.anthropic.com/account/keys"
    
    # Add to shell profile
    local shell_profile=""
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
            info "Added source command to $shell_profile"
        fi
    fi
}

# Function to setup session authentication
setup_session_auth() {
    info "Setting up Claude Code session authentication..."
    
    # Check if Claude Code CLI is installed
    if ! command -v claude &> /dev/null; then
        warn "⚠️  Claude Code CLI not found"
        info "   Install Claude Code: npm install -g @anthropic-ai/claude-code"
        return
    fi
    
    success "✓ Claude Code CLI detected"
    echo
    info "To authenticate with Claude Code:"
    info "1. Run: claude login"
    info "2. Follow the browser authentication flow"
    info "3. Your session will be active for this terminal"
    echo
    info "Note: Claude Code uses ephemeral sessions."
    info "You'll need to run 'claude login' for each new terminal session."
}

# Function to save authentication preferences
save_auth_preferences() {
    local auth_method="$1"
    local claude_settings_dir="$HOME/.claude"
    local auth_config_file="$claude_settings_dir/auth_preferences.json"
    
    # Ensure directory exists
    mkdir -p "$claude_settings_dir"
    
    # Create auth preferences JSON
    cat > "$auth_config_file" << EOF
{
  "authMethod": "$auth_method",
  "configuredAt": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "configVersion": "1.0",
  "notes": {
    "api_key": "Uses ANTHROPIC_API_KEY from environment",
    "session": "Requires 'claude login' for each terminal session",
    "dual": "Supports both API key and session authentication"
  }
}
EOF
    
    success "✓ Saved authentication preferences to: $auth_config_file"
}

# Function to setup environment variables (enhanced)
setup_env_vars() {
    local env_file="$HOME/.claude_env"
    
    info "Setting up additional environment variables..."
    
    # Check for OpenRouter API key
    local need_openrouter=true
    
    if [[ -n "${OPENROUTER_API_KEY:-}" ]]; then
        need_openrouter=false
        success "✓ OPENROUTER_API_KEY already set"
    fi
    
    # Create env file if needed for additional keys
    if [[ "$need_openrouter" == true ]]; then
        if [[ ! -f "$env_file" ]]; then
            cat > "$env_file" << 'EOF'
# Claude Environment Variables
# Add your API keys here and source this file in your shell profile

EOF
        fi
        
        if ! grep -q "OPENROUTER_API_KEY" "$env_file"; then
            echo "" >> "$env_file"
            echo "# Optional: OpenRouter for additional models" >> "$env_file"
            echo "export OPENROUTER_API_KEY=your-key-here" >> "$env_file"
            echo "export OPENROUTER_DEFAULT_MODEL=gpt-4" >> "$env_file"
        fi
        
        info "Optional: Add OPENROUTER_API_KEY to $env_file for additional models"
    fi
}

# Function to install Node.js if needed
check_node() {
    if ! command -v node &> /dev/null; then
        warn "⚠️  Node.js not found. MCP servers require Node.js."
        info "   Install Node.js from: https://nodejs.org/"
        info "   Or use: brew install node (macOS)"
        return 1
    else
        success "✓ Node.js found: $(node --version)"
        return 0
    fi
}

# Function to setup APM commands
setup_apm_commands() {
    local claude_commands_dir="$HOME/.claude/commands"
    mkdir -p "$claude_commands_dir"
    
    info "Setting up APM commands..."
    cp -r "$SCRIPT_DIR/lib/apm/commands/"* "$claude_commands_dir/"
    success "✓ APM commands installed to: $claude_commands_dir"
}

# Function to setup agent prompts
setup_agent_prompts() {
    local claude_prompts_dir="$HOME/.claude/prompts"
    mkdir -p "$claude_prompts_dir"
    
    info "Setting up agent prompts..."
    cp -r "$SCRIPT_DIR/lib/agents/prompts/"* "$claude_prompts_dir/"
    success "✓ Agent prompts installed to: $claude_prompts_dir"
}

# Function to setup APM prompts
setup_apm_prompts() {
    local claude_apm_dir="$HOME/.claude/apm"
    mkdir -p "$claude_apm_dir"
    
    info "Setting up APM prompts..."
    cp -r "$SCRIPT_DIR/lib/apm/prompts/"* "$claude_apm_dir/"
    success "✓ APM prompts installed to: $claude_apm_dir"
}

# Function to setup agent core scripts
setup_agent_core() {
    local claude_agent_core_dir="$HOME/.claude/agent-core"
    mkdir -p "$claude_agent_core_dir"
    
    info "Setting up agent core scripts..."
    cp -r "$SCRIPT_DIR/lib/agents/core/"* "$claude_agent_core_dir/"
    if [[ -f "$SCRIPT_DIR/lib/agents/claudebox-agents" ]]; then
        cp "$SCRIPT_DIR/lib/agents/claudebox-agents" "$claude_agent_core_dir/"
    fi
    chmod +x "$claude_agent_core_dir"/*.sh
    success "✓ Agent core scripts installed to: $claude_agent_core_dir"
}

# Function to setup Codex integration
setup_codex() {
    local claude_codex_dir="$HOME/.claude/codex"
    mkdir -p "$claude_codex_dir"
    
    info "Setting up Codex integration..."
    if [[ -d "$SCRIPT_DIR/lib/agents/codex" ]]; then
        cp -r "$SCRIPT_DIR/lib/agents/codex/"* "$claude_codex_dir/"
        chmod +x "$claude_codex_dir"/*.sh 2>/dev/null || true
        success "✓ Codex integration installed to: $claude_codex_dir"
    else
        warn "⚠️  Codex integration files not found"
    fi
}

# Function to setup agent examples
setup_agent_examples() {
    local claude_examples_dir="$HOME/.claude/examples"
    mkdir -p "$claude_examples_dir"
    
    info "Setting up agent examples..."
    if [[ -d "$SCRIPT_DIR/lib/agents/examples" ]]; then
        cp -r "$SCRIPT_DIR/lib/agents/examples/"* "$claude_examples_dir/"
        success "✓ Agent examples installed to: $claude_examples_dir"
    else
        warn "⚠️  Agent example files not found"
    fi
}

# Function to setup MCP default configuration
setup_mcp_defaults() {
    local claude_mcp_dir="$HOME/.claude/mcp"
    mkdir -p "$claude_mcp_dir"
    
    info "Setting up MCP default configuration..."
    if [[ -f "$SCRIPT_DIR/lib/mcp/default-config.json" ]]; then
        cp "$SCRIPT_DIR/lib/mcp/default-config.json" "$claude_mcp_dir/"
        success "✓ MCP default config installed to: $claude_mcp_dir"
    else
        warn "⚠️  MCP default configuration not found"
    fi
}

# Function to create CLAUDE.md
create_claude_md() {
    local project_dir="${1:-$(pwd)}"
    local claude_md="$project_dir/CLAUDE.md"
    
    if [[ -f "$claude_md" ]]; then
        warn "⚠️  CLAUDE.md already exists in $project_dir"
        return
    fi
    
    cat > "$claude_md" << 'EOF'
# Claude Project Configuration

This file provides context and configuration for Claude Desktop.

## Project Overview
[Describe your project here]

## Key Commands
- Lint: `npm run lint` or `[your lint command]`
- Test: `npm test` or `[your test command]`
- Build: `npm run build` or `[your build command]`

## Project Structure
```
src/
├── components/
├── utils/
└── ...
```

## Development Guidelines
- [Add your project-specific guidelines]

## APM Commands Available
- `/apm-manager` - Initialize project management
- `/apm-implement` - Create task-specific agents
- `/apm-agents` - Launch multi-agent development team
- `/apm-memory` - Manage persistent knowledge base
- `/apm-handover` - Manage context window transitions

## Notes
- [Add any additional notes or context]
EOF

    success "✓ Created CLAUDE.md template in: $project_dir"
}

# Main installation flow
main() {
    echo "📋 Installation Steps:"
    echo "1. Detect existing authentication method"
    echo "2. Configure authentication (confirm/change)"
    echo "3. Check Node.js installation"
    echo "4. Backup existing Claude config"
    echo "5. Setup MCP servers configuration"
    echo "6. Configure environment variables"
    echo "7. Install APM components:"
    echo "   - APM commands and prompts"
    echo "   - Agent prompts and core scripts"
    echo "   - Codex integration"
    echo "   - Agent examples"
    echo "   - MCP default configuration"
    echo "8. Create CLAUDE.md template"
    echo
    
    read -p "Continue with installation? [Y/n] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ -n $REPLY ]]; then
        info "Installation cancelled."
        exit 0
    fi
    
    echo
    
    # Step 1 & 2: Detect and configure authentication
    local auth_info=$(detect_auth_method)
    local current_auth=$(echo "$auth_info" | cut -d'|' -f1)
    local current_details=$(echo "$auth_info" | cut -d'|' -f2)
    prompt_auth_method "$current_auth" "$current_details"
    
    # Step 3: Check Node.js
    if ! check_node; then
        warn "⚠️  Continuing without Node.js - MCP servers will not work"
    fi
    
    # Step 4: Backup existing config
    backup_config
    
    # Step 5: Setup MCP config
    merge_mcp_config
    
    # Step 6: Setup additional environment variables
    setup_env_vars
    
    # Step 7: Setup APM and agent files
    setup_apm_commands
    setup_agent_prompts
    setup_apm_prompts
    setup_agent_core
    setup_codex
    setup_agent_examples
    setup_mcp_defaults
    
    # Step 8: Optionally create CLAUDE.md
    echo
    read -p "Create CLAUDE.md template in current directory? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        create_claude_md
    fi
    
    echo
    success "🎉 Claude Bootstrap completed successfully!"
    echo
    info "Next steps:"
    
    # Show relevant next steps based on authentication method
    local final_auth_info=$(detect_auth_method)
    local final_auth=$(echo "$final_auth_info" | cut -d'|' -f1)
    
    case "$final_auth" in
        "api_key")
            info "1. Ensure your API key is set in: $HOME/.claude_env"
            info "2. Restart your terminal or run: source $HOME/.claude_env"
            ;;
        "session")
            info "1. Run 'claude login' to authenticate with Claude Code"
            info "2. Authentication is required for each new terminal session"
            ;;
        "dual")
            info "1. API key configured in: $HOME/.claude_env"
            info "2. Use 'claude login' for session-based features"
            ;;
        *)
            warn "⚠️  No authentication configured"
            info "1. Set up API key in: $HOME/.claude_env"
            info "   OR"
            info "2. Run 'claude login' for session authentication"
            ;;
    esac
    
    info "3. Restart Claude Desktop (if using) to load new configuration"
    echo
    info "APM Commands are available in: $HOME/.claude/commands/"
    info "Agent Prompts are available in: $HOME/.claude/prompts/"
    info "APM Prompts are available in: $HOME/.claude/apm/"
    info "Agent Core Scripts are available in: $HOME/.claude/agent-core/"
    info "Codex Integration is available in: $HOME/.claude/codex/"
    info "Agent Examples are available in: $HOME/.claude/examples/"
    info "MCP Configuration is available in: $HOME/.claude/mcp/"
    echo
}

# Cleanup function
cleanup() {
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}

# Ensure cleanup on exit
trap cleanup EXIT

# Run main function
main "$@"