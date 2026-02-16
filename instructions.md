# Claude Code Docker Container

## Authentication
Either:
- **Host credentials (recommended):** Run `claude /login` on the host — credentials are mounted automatically
- **API key:** Set `ANTHROPIC_API_KEY` in your project's `.env` file

## Optional `.env` vars (in project root)
- `ANTHROPIC_API_KEY` — Claude API key (not needed if using host credentials)
- `GH_API_KEY` — GitHub personal access token
- `GIT_USER_NAME` — git commit author name (default: "Claude Code Agent")
- `GIT_USER_EMAIL` — git commit author email (default: claude-agent@noreply.github.com)
- `SKIP_PERMISSIONS` — set to `1` to skip Claude permission prompts
- `CONTAINER_PORT` — expose a port from the container (e.g., `8000`)

## Setup
1. Run `claude /login` on the host, or add `ANTHROPIC_API_KEY` to your project's `.env`
2. Optionally create `agent.deps` in project root (one apt package per line)

## Usage
```bash
.claude/run.sh                          # interactive session
.claude/run.sh "fix the login bug"      # session with initial prompt
.claude/run.sh -p "list all TODOs"      # headless (print and exit)
.claude/run.sh --skip-perms "do it all" # skip permission prompts
.claude/run.sh /handle-issue 42         # run a slash command
```

## Host access
Services on your machine are reachable inside the container at `host.docker.internal:<port>`.
