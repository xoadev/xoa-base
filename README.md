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
include .xoa-base/$(XOA_BASE)/container/image.mk
.xoa-base/$(XOA_BASE)/%: .xoa-base/$(XOA_BASE)/.fetched ;
.xoa-base/$(XOA_BASE)/.fetched:
	@rm -rf .xoa-base && git init -q $(@D)
	@git -C $(@D) fetch -q --depth 1 https://github.com/xoadev/xoa-base $(XOA_BASE)
	@git -C $(@D) checkout -q FETCH_HEAD && touch $@
```

**`website/`** is a Lume plugin and a script that the site imports as Deno modules, by the same
commit, with nothing fetched by `make`. The site's `deno.json` maps them, and its `deno.lock` holds
their hashes, all of them after one build, since the plugin imports every module:

```json
{
  "imports": { "xoa-web/": "https://raw.githubusercontent.com/xoadev/xoa-base/<sha>/website/" },
  "tasks": {
    "a11y": "echo \"import { a11y } from 'xoa-web/mod.ts'; await a11y()\" | deno run -A -",
    "browser": "echo \"import { installBrowser } from 'xoa-web/mod.ts'; await installBrowser()\" | deno run -A -"
  }
}
```

- Its `_config.ts` runs `site.use(xoa())`, imported from `xoa-web/mod.ts`. Every build then checks
  what it made (what, in `website/mod.ts`) and fails on any failure; while serving, it prints them.
  The plugin also gives the pages the `json` filter for their JSON-LD.
- Its `_data.ts` reads the prose with `loadContent({ root, languages, defaultLanguage })` from
  `xoa-web/mod.ts`.
- `deno task a11y` checks the built site in a browser, which `deno task browser` installs once.
- The modules share the site's `lume/`, so the site's Lume is theirs too.

The project's `Makefile` runs them through the two targets the CI's workflow calls: `web-check`
(`cd <site> && deno fmt --check && deno lint && deno task build && deno task a11y`) and
`web-browser` (`cd <site> && deno task browser`).

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
