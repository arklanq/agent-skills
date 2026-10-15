# Agent Skills

Personal skills for Git and GitHub workflows.

- [commit](skills/commit/SKILL.md): Create focused commits with Conventional Commits messages.
- [github-pr](skills/github-pr/SKILL.md): Create and update GitHub pull requests.

## Installation

Install both skills with [skills.sh](https://skills.sh/docs):

```bash
npx skills add arklanq/agent-skills --skill commit github-pr
```

## Requirements

- Node.js and npm for installation.
- Bash and Git for the context scripts.
- Authenticated GitHub CLI (`gh`) for `github-pr`.
- Optional: ripgrep (`rg`) for detecting ticket-provider references.
