# AGENTS.md

XOA's shared rules come with XOA's agent plugin, which XOA's people enable for themselves; this
repository only picks their variant (`XOA_RULES` is `oss` in `.claude/settings.json`). Whoever
contributes from outside works without them, with this file, the README and the checks. What this
repository is, how projects use it and how it is tested is in the [README](README.md); what follows
is only what working on it adds.

## This repository

**Stage: in testing**, no project depends on a release yet: anything may break.

- **Nothing here depends on anything private**: no private repository, secret or self-hosted runner.
  It is public, and its pull requests come from anyone, so its own CI runs on GitHub's runners only.
- **A change to a check comes with the case that proves it**: a Dockerfile in `test/image/accepted`
  or `test/image/rejected`, or a page of the test site, and the cases that must fail fail for that
  reason.
- **What a project needs is added here, never patched in the project**: the project's own part is
  its variables and its content, nothing it takes from this repository.
