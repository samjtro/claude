# my claude code config

## Bootstrap

```bash
curl https://raw.githubusercontent.com/samjtro/claude/refs/heads/main/bootstrap.sh > bootstrap.sh && chmod +x bootstrap.sh && ./bootstrap.sh
```

## What Gets Installed

### 1. MCP Servers Configuration
Located in `~/Library/Application Support/Claude/claude_desktop_config.json`:
- **memory**: Persistent memory across sessions
- **sequential-thinking**: Enhanced reasoning capabilities
- **context7**: Advanced context management
- **openrouterai**: Access to additional LLM models

### 2. APM Commands
Installed to `~/.claude/commands/`:
- `/apm-manager` - Initialize project management
- `/apm-implement` - Create task-specific agents
- `/apm-agents` - Launch multi-agent development team
- `/apm-memory` - Manage persistent knowledge base
- `/apm-handover` - Manage context window transitions
- `/apm-plan` - Manage implementation plans
- `/apm-review` - Review work progress
- `/apm-task` - Generate task assignments

### 3. Agent Prompts
Installed to `~/.claude/prompts/`:
- Developer agent prompt
- Planner agent prompt
- Reviewer agent prompt
- Tester agent prompt

### 4. Environment Configuration
Creates `~/.claude_env` with required environment variables:
- `ANTHROPIC_API_KEY` - Your Anthropic API key
- `OPENROUTER_API_KEY` - OpenRouter API key (optional)
- `OPENROUTER_DEFAULT_MODEL` - Default model for OpenRouter
- `GITHUB_TOKEN` - GitHub personal access token (optional)

## Manual Setup

### 1. Environment Variables
```bash
# Run the environment setup script
./scripts/setup-env.sh

# Or manually add to ~/.claude_env:
export ANTHROPIC_API_KEY=your-key-here
export OPENROUTER_API_KEY=your-key-here
export OPENROUTER_DEFAULT_MODEL=gpt-4
```

### 2. Extended MCP Configuration
For additional MCP servers (GitHub, filesystem), use the extended config:
```bash
cp configs/claude_desktop_config_extended.json ~/Library/Application\ Support/Claude/claude_desktop_config.json
```

### 3. Project-Specific Configuration
Create a `CLAUDE.md` file in your project root:
```bash
# In your project directory
../path/to/claude/bootstrap.sh
# Choose "y" when prompted to create CLAUDE.md
```

## Directory Structure

```
claude/
├── bootstrap.sh              # Main installation script
├── configs/                  # Configuration templates
│   ├── claude_desktop_config.json
│   └── claude_desktop_config_extended.json
├── scripts/                  # Utility scripts
│   └── setup-env.sh         # Environment setup helper
├── docs/                    # Documentation and commands
│   ├── apm/commands/        # APM command files
│   └── agents/prompts/      # Agent prompt templates
└── README.md                # This file
```

## Requirements

- macOS or Linux
- Claude Desktop installed
- Node.js (for MCP servers)
- jq (optional, for config merging)

## Troubleshooting

### MCP Servers Not Working
1. Ensure Node.js is installed: `node --version`
2. Check Claude Desktop logs for errors
3. Verify environment variables are set: `echo $ANTHROPIC_API_KEY`

### Commands Not Available
1. Restart Claude Desktop after installation
2. Check files exist in `~/.claude/commands/`
3. Ensure proper permissions on command files

### Environment Variables Not Loading
1. Source your shell profile: `source ~/.zshrc` or `source ~/.bashrc`
2. Verify `.claude_env` exists and contains your keys
3. Check that your shell profile sources `.claude_env`

## Advanced Usage

### Custom MCP Servers
Add custom MCP servers to your config:
```json
{
  "mcpServers": {
    "your-server": {
      "command": "npx",
      "args": ["-y", "@your-org/your-mcp-server"],
      "env": {
        "YOUR_API_KEY": "${YOUR_API_KEY}"
      }
    }
  }
}
```

### Project Templates
The CLAUDE.md file supports project-specific configurations:
- Custom commands and scripts
- Project structure documentation
- Development guidelines
- Build and test commands

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project extracts and simplifies features from [claudebox](https://github.com/samjtro/claudebox).

## Acknowledgments

Based on the excellent work in [claudebox](https://github.com/samjtro/claudebox) by @samjtro.
