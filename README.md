Collection of Claude commands, tools, etc

Intended to be used as the .claude folder of a project, preferably as a submodule for easy config sharing across projects.

In your project directory:

```
git submodule add git@github.com:bgould96/claude-config.git .claude
```

With this + a CLAUDE.md in the project repo itself, Claude Code can be trivially deployed anywhere.

Some commands require use of the GitHub CLI. To set this up, create a fine grained personal access token with the following permissions:

- Contents: R
- Issues: R/W
- Pull Requests: R/W

ONLY give this PAT access to repos you want Claude Code to be able to read

To update `.claude`,

```
git pull --recurse-submodules
```
