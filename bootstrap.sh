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
if [[ ! -d "$CLAUDE_CONFIG_DIR" ]]; then
    # Check for Claude Desktop app on macOS
    if [[ -d "/Applications/Claude.app" ]]; then
        # Claude Desktop is installed but config dir doesn't exist yet
        mkdir -p "$CLAUDE_CONFIG_DIR"
        info "Claude Desktop detected. Creating configuration directory..."
    elif command -v claude &> /dev/null; then
        # Claude Code CLI is installed
        mkdir -p "$CLAUDE_CONFIG_DIR"
        info "Claude Code CLI detected. Creating configuration directory..."
    else
        error "Neither Claude Desktop nor Claude Code CLI found. Please install Claude Desktop or Claude Code first."
    fi
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

# Function to setup environment variables
setup_env_vars() {
    local env_file="$HOME/.claude_env"
    
    info "Setting up environment variables..."
    
    # Check if variables are already set
    local need_anthropic=true
    local need_openrouter=true
    
    if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
        need_anthropic=false
        success "✓ ANTHROPIC_API_KEY already set"
    fi
    
    if [[ -n "${OPENROUTER_API_KEY:-}" ]]; then
        need_openrouter=false
        success "✓ OPENROUTER_API_KEY already set"
    fi
    
    # Create env file if needed
    if [[ "$need_anthropic" == true ]] || [[ "$need_openrouter" == true ]]; then
        cat > "$env_file" << 'EOF'
# Claude Environment Variables
# Add your API keys here and source this file in your shell profile

EOF
        
        if [[ "$need_anthropic" == true ]]; then
            echo "export ANTHROPIC_API_KEY=your-key-here" >> "$env_file"
        fi
        
        if [[ "$need_openrouter" == true ]]; then
            echo "export OPENROUTER_API_KEY=your-key-here" >> "$env_file"
            echo "export OPENROUTER_DEFAULT_MODEL=gpt-4" >> "$env_file"
        fi
        
        warn "⚠️  Please edit $env_file and add your API keys"
        
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
    echo "1. Check Node.js installation"
    echo "2. Backup existing Claude config"
    echo "3. Setup MCP servers configuration"
    echo "4. Configure environment variables"
    echo "5. Install APM components:"
    echo "   - APM commands and prompts"
    echo "   - Agent prompts and core scripts"
    echo "   - Codex integration"
    echo "   - Agent examples"
    echo "   - MCP default configuration"
    echo "6. Create CLAUDE.md template"
    echo
    
    read -p "Continue with installation? [Y/n] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ -n $REPLY ]]; then
        info "Installation cancelled."
        exit 0
    fi
    
    echo
    
    # Step 1: Check Node.js
    if ! check_node; then
        warn "⚠️  Continuing without Node.js - MCP servers will not work"
    fi
    
    # Step 2: Backup existing config
    backup_config
    
    # Step 3: Setup MCP config
    merge_mcp_config
    
    # Step 4: Setup environment variables
    setup_env_vars
    
    # Step 5: Setup APM and agent files
    setup_apm_commands
    setup_agent_prompts
    setup_apm_prompts
    setup_agent_core
    setup_codex
    setup_agent_examples
    setup_mcp_defaults
    
    # Step 6: Optionally create CLAUDE.md
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
    info "1. Add your API keys to: $HOME/.claude_env"
    info "2. Restart your terminal or run: source $HOME/.claude_env"
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