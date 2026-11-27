# xoa-base

The checks and workflows shared by XOA Desarrollo's projects, for anyone to use: they need no
credentials.

| Folder       | For                                                                       |
| ------------ | ------------------------------------------------------------------------- |
| `website/`   | A static Lume site; what it checks, in `website/mod.ts` and `a11y.ts`     |
| `container/` | A container image; what it checks, in `container/image.mk` and `image.sh` |
| `lint/`      | The linters any repository may need, one `.mk` each                       |

## Using it in a project

A project names one commit of this repository and never edits what it takes from it: a change goes
here, and the project moves to the new commit. Until this repository's first release that commit is
one of `main`; from then on it is a release's.

**The CI names the commit**, in the `uses:` lines of the workflows that call this repository's, with
its version beside it, which Dependabot's `github-actions` ecosystem moves, with the same week's
cooldown as everything else. For an image, `.github/workflows/image.yml`:

```yaml
name: image
on:
  pull_request:
    paths: [Dockerfile, Makefile, src/**, .github/workflows/image.yml]
  push:
    branches: [main]
permissions:
  contents: read
jobs:
  image:
    uses: xoadev/xoa-base/.github/workflows/image.yml@<sha> # vX.Y.Z
```

**The `Makefile` reads that commit** from the workflows, fetches this repository at it into
`.xoa-base/`, which the project's `.gitignore` lists, and includes the areas it uses:

<!-- fetch -->

```make
# xoadev/xoa-base at the commit the project's workflows call, which Dependabot moves: make reads it
# from them, fetches it into .xoa-base/ when it is missing or at another commit, and git checks it.
XOA_BASE := $(sort $(shell sed -n 's|.*xoadev/xoa-base/\.github/workflows/[^@]*@\([0-9a-f]\{40\}\).*|\1|p' .github/workflows/*.y*ml))
$(if $(XOA_BASE),,$(error no workflow calls xoa-base yet: add the one its README shows first))
$(if $(filter 1,$(words $(XOA_BASE))),,$(error the workflows call xoa-base at $(XOA_BASE): one commit, in every uses: line))
include .xoa-base/$(XOA_BASE)/container/image.mk
.xoa-base/$(XOA_BASE)/%: .xoa-base/$(XOA_BASE)/.fetched ;
.xoa-base/$(XOA_BASE)/.fetched:
	@rm -rf .xoa-base && git init -q $(@D)
	@git -C $(@D) fetch -q --depth 1 https://github.com/xoadev/xoa-base $(XOA_BASE)
	@git -C $(@D) checkout -q FETCH_HEAD && touch $@
```

**`container/`**: above the `include`, the project sets the variables `image.mk` lists and wires its
targets into its own:

```make
IMAGE := myapp:local
# What a real request does, inside the image, under a deployment's restrictions ($$IMAGE_RUN).
IMAGE_CHECK = $$IMAGE_RUN "$$IMAGE" check /data
lint: image-lint
test: image-check
```

An image compiled in stages that cannot cross-compile builds each architecture on its own runner
rather than under emulation: two jobs, one with `platforms: linux/arm64` and
`runs-on: '"ubuntu-24.04-arm"'`.

**`lint/`**: the project includes the linters it needs the same way
(`include .xoa-base/$(XOA_BASE)/lint/markdown.mk`, and so on) and puts their targets in its `lint`.
Each says in its first lines what it checks and how. The tools come with the machine, never with
`make`: they belong in the images of XOA's runners and agent (by-fros/cloud), anywhere else they are
installed by hand, and a `.mk` fails saying which one is missing or too old.

**`website/`** is a Lume plugin the site imports by the same commit, and `website/web.mk` its
targets, included like the others: how, and the format of the site's prose it reads, in
[`website/README.md`](website/README.md).

**Releases** are this repository's own workflows too. `release-draft.yml` rewrites, on every push to
`main`, the draft of the next version that convco reads in the Conventional Commits; `release.yml`,
run by hand, publishes it and makes its tag. A project calls them the same way, the draft from a
push to `main` and the publication from a `workflow_dispatch`, with `contents: write`; one that
builds an image publishes it with `image-release.yml`, whose first lines show how to call it.

**Runners**: the workflows run on GitHub's unless the calling repository is private and its
organization (or the repository) sets the Actions variable `SELF_HOSTED_RUNNER` to its own runners'
labels as JSON, such as `["xoa-selfhosted","x64"]`; those that need Docker take
`SELF_HOSTED_DOCKER_RUNNER` first. A public repository never runs on them, since its pull requests
come from anyone. The `runs-on` input overrides all of this.

## Development

`make help` lists the targets and what each checks; CI runs `make check` across its jobs, plus
`test-fetch` and `test-image`. Beyond Deno, `make test-image` needs Docker with buildx and QEMU, and
`make test-fetch` needs this commit on GitHub (`XOA_BASE_TEST=<sha>` for another).
