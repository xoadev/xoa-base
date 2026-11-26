# xoa-base

The checks and workflows shared by XOA Desarrollo's projects, for anyone to use: they need no
credentials.

| Folder       | For                                                                       |
| ------------ | ------------------------------------------------------------------------- |
| `website/`   | A static Lume site; what it checks, in `website/web.mk`                   |
| `container/` | A container image; what it checks, in `container/image.mk` and `image.sh` |

## Using it in a project

A project names one commit of this repository and never edits what it takes from it: a change goes
here, and the project moves to the new commit.

Until there are releases, the commit is one of `main`.

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
# xoadev/xoa-base at this commit, the one the workflows call too. make fetches it into .xoa-base/
# when it is missing or at another commit, and git checks it against the commit's hash.
XOA_BASE := <sha>
# The areas the project uses.
include .xoa-base/$(XOA_BASE)/container/image.mk
include .xoa-base/$(XOA_BASE)/website/web.mk
.xoa-base/$(XOA_BASE)/%: .xoa-base/$(XOA_BASE)/.fetched ;
.xoa-base/$(XOA_BASE)/.fetched:
	@rm -rf .xoa-base && git init -q $(@D)
	@git -C $(@D) fetch -q --depth 1 https://github.com/xoadev/xoa-base $(XOA_BASE)
	@git -C $(@D) checkout -q FETCH_HEAD && touch $@
```

**`website/`** is fetched the same way. The checks run with this repository's `deno.json` and frozen
lock, so the site's own `deno.json` holds only what it builds with: its `build` and `serve` tasks
and its dependencies. It also maps `xoa-web/` to the fetched reader of `_content/`, through the link
`make` keeps at `.xoa-base/current`, so the commit is written once:

```json
{ "imports": { "xoa-web/": "../.xoa-base/current/website/web/" } }
```

The site's `_data.ts` reads its prose with
`loadContent({ root: new URL("./_content/", import.meta.url), languages, defaultLanguage })` from
`xoa-web/_content.ts`, and `SITE`, the origin the checks expect, is exported there too. The
project's `Makefile` sets `WEB` to the site's folder and wires `web-lint` into `lint` and
`web-seo web-a11y` into `test`.

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

Moving to another commit is one pull request that changes `XOA_BASE` and the workflow's SHA
together; nothing checks that they match.

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
