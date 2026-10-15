# Agent Skills

A personal collection of reusable agent skills.

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
- Authenticated GitHub CLI (`gh`) for `github-pr`.
- Optional: ripgrep (`rg`) for detecting ticket-provider references.
