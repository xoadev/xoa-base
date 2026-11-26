# xoa-base

The checks and workflows shared by XOA Desarrollo's projects, for anyone to use: they need no
credentials.

| Folder       | For                                                                       |
| ------------ | ------------------------------------------------------------------------- |
| `website/`   | A static Lume site; what it checks, in `website/mod.ts` and `a11y.ts`     |
| `container/` | A container image; what it checks, in `container/image.mk` and `image.sh` |

## Using it in a project

A project names one commit of this repository and never edits what it takes from it: a change goes
here, and the project moves to the new commit.

The commit is a release's, named in the project's workflows as `@<sha> # vX.Y.Z`: Dependabot's
`github-actions` ecosystem moves it there, with the same week's cooldown as everything else. The
`Makefile` reads it from those workflows, and the site's plugin fails its build when its `deno.json`
is left at another commit, saying where to move it.

**`container/`** is fetched by `make` into `.xoa-base/`, which the project's `.gitignore` lists. The
project's `Makefile` sets the variables `image.mk` lists, wires its targets into its own, and then
fetches and includes it:

```make
IMAGE := myapp:local
# What a real request does, inside the image, under a deployment's restrictions ($$IMAGE_RUN).
IMAGE_CHECK = $$IMAGE_RUN "$$IMAGE" check /data
lint: image-lint
test: image-check
```

<!-- fetch -->

```make
# xoadev/xoa-base at the commit the project's workflows call, which Dependabot moves: make reads it
# from them, fetches it into .xoa-base/ when it is missing or at another commit, and git checks it.
XOA_BASE := $(sort $(shell sed -n 's|.*xoadev/xoa-base/\.github/workflows/[^@]*@\([0-9a-f]\{40\}\).*|\1|p' .github/workflows/*.y*ml))
$(if $(filter 1,$(words $(XOA_BASE))),,$(error the workflows call xoa-base at "$(XOA_BASE)": one commit, in every uses: line))
include .xoa-base/$(XOA_BASE)/container/image.mk
.xoa-base/$(XOA_BASE)/%: .xoa-base/$(XOA_BASE)/.fetched ;
.xoa-base/$(XOA_BASE)/.fetched:
	@rm -rf .xoa-base && git init -q $(@D)
	@git -C $(@D) fetch -q --depth 1 https://github.com/xoadev/xoa-base $(XOA_BASE)
	@git -C $(@D) checkout -q FETCH_HEAD && touch $@
```

**`website/`** is a Lume plugin the site imports by the same commit, with nothing fetched by `make`:
how, and the format of the site's prose it reads, in [`website/README.md`](website/README.md).

**The CI** calls the reusable workflow by the same commit, in `.github/workflows/image.yml`:

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
    uses: xoadev/xoa-base/.github/workflows/image.yml@<sha>
```

**Releases** are this repository's own workflows too. `release-draft.yml` rewrites, on every push to
`main`, the draft of the next version that convco reads in the Conventional Commits; `release.yml`,
run by hand, publishes it and makes its tag. A project calls them the same way, the draft from a
push to `main` and the publication from a `workflow_dispatch`, with `contents: write`; one that
builds binaries or images publishes them in a workflow of its own.

An image compiled in stages that cannot cross-compile builds each architecture on its own runner
rather than under emulation: two jobs, one with `platforms: linux/arm64` and
`runs-on: '"ubuntu-24.04-arm"'`.

The workflow runs on GitHub's runners unless the calling repository is private and its organization
(or the repository) sets the Actions variable `SELF_HOSTED_RUNNER` to its own runners' labels as
JSON, such as `["xoa-selfhosted","x64"]`; the image's check, which needs Docker, takes
`SELF_HOSTED_DOCKER_RUNNER` first. A public repository never runs on them, since its pull requests
come from anyone. The `runs-on` input overrides all of this.

## Development

`make help` lists the targets and what each checks; `make check` is what CI runs. Beyond Deno,
`make test-image` needs Docker with buildx and QEMU, and `make test-fetch` needs this commit on
GitHub (`XOA_BASE_TEST=<sha>` for another).
