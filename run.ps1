# Claude Code container launcher (Windows wrapper)
# Delegates to run.sh inside WSL

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent $ScriptDir

# Convert Windows path to WSL path
$WslProject = wsl wslpath -u ($ProjectDir -replace '\\', '/')

wsl --cd $WslProject -- bash .claude/run.sh @Args
