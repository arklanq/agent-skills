# Agent Skills

A personal collection of reusable agent skills.

- [codebase-health](skills/codebase-health/SKILL.md): Review a repository's structural health and maintainability, with a front-end focus, then deliver approved fixes as pull requests.
- [commit](skills/commit/SKILL.md): Create focused commits with Conventional Commits messages.
- [dashboard](skills/dashboard/SKILL.md): Open a live local dashboard of the agent's current work, kept up to date by a dashboard subagent.
- [github-pr](skills/github-pr/SKILL.md): Create and update concise, well-structured GitHub pull requests with consistent conventions and verified base branches.

## Installation

Install skills with [skills.sh](https://skills.sh/docs):

```bash
npx skills add arklanq/agent-skills
```

To pin a specific version, add its release tag after `#`, for example:

```bash
npx skills add arklanq/agent-skills#v1.0.0
```

See [Releases](https://github.com/arklanq/agent-skills/releases) for available versions and changes.

## Requirements

- Node.js and npm for installation.
- Bash and Git for the context scripts.
- Node.js 18+ on macOS or Linux for the `dashboard` runtime.
- Authenticated GitHub CLI (`gh`) for `github-pr` and `codebase-health` pull requests.
- Optional: ripgrep (`rg`) for detecting ticket-provider references.
