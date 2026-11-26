# AGENTS.md

XOA's shared rules come with its agent plugin (`XOA_RULES` is `oss` in `.claude/settings.json`);
what follows is this repository's own and prevails where it narrows them.

## This repository

The checks and workflows XOA Desarrollo's projects share: what enforces the guidelines in each
project, in its `make` and its CI. It is public so that open source projects, and whoever
contributes to them, use it without credentials. Nothing here depends on anything private. **Stage:
in testing**, no project depends on a release yet: anything may break.

- **Each folder is an area** (`website/`, `container/`): what a project copies from it, as it is.
  What belongs to a project goes in its own files (the variables of its `Makefile`, its pages),
  never in an edited copy; what is missing is added here.
- **The reusable workflows** (`.github/workflows/web.yml`, `image.yml`) are called by a project by
  SHA, and Dependabot moves it. `check.yml` calls them over the test site and image, so what is
  tested here is what runs in a project.
- **Checks are tested as a project would use them**: `make test` copies `website/web` over the test
  site in `test/site` (and its bilingual version, with `test/site-en.yml`) and runs `web.mk`'s
  targets on it; those of `container/` run over the image in `test/image`, and each `Dockerfile` in
  `test/image/rejected` breaks one rule the policy must refuse. The test site and image exist only
  for that.
- **GitHub's runners only**: a public repository's pull requests come from anyone, and a self-hosted
  runner would run their code.
