# Agent Skills

A personal collection of reusable agent skills.

- [codebase-health](skills/codebase-health/SKILL.md): Review a repository's structural health and maintainability, with a front-end focus, then deliver approved fixes as pull requests.
- [commit](skills/commit/SKILL.md): Create focused commits with Conventional Commits messages.
- [github-pr](skills/github-pr/SKILL.md): Create and update concise, well-structured GitHub pull requests with consistent conventions and verified base branches.

## Installation

Install skills with [skills.sh](https://skills.sh/docs):

```bash
npx skills add arklanq/agent-skills
```

## Requirements

- Node.js and npm for installation.
- Bash and Git for the context scripts.
- Authenticated GitHub CLI (`gh`) for `github-pr` and `codebase-health` pull requests.
- Optional: ripgrep (`rg`) for detecting ticket-provider references.
