# xoa-base

The checks and workflows shared by XOA Desarrollo's projects, for anyone to use: they need no
credentials.

| Folder       | What it checks                                                                                  |
| ------------ | ----------------------------------------------------------------------------------------------- |
| `website/`   | A static Lume site: lints, content by language, SEO, accessibility at two widths and two themes |
| `container/` | A container image: digests, distroless, non-root, secrets, both architectures, a clean stop     |

## Using it in a project

A project names one commit of this repository and never edits what it takes from it: a change goes
here, and the project moves to the new commit.

**`container/`** is fetched by `make` into `.xoa-base/`, which the project's `.gitignore` lists. In
the project's `Makefile`, with the `IMAGE_*` variables `image.mk` lists set above it:

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

**`website/`** is still copied: `website/web.mk` to the project root and `website/web/` into the
site's folder, recording the commit. Its checks run inside the site's own Deno configuration, which
the project extends.

**The CI** calls the reusable workflow by the same commit:

```yaml
jobs:
  image:
    uses: xoadev/xoa-base/.github/workflows/image.yml@<sha> # vX.Y.Z
```

The workflow runs on GitHub's runners unless the calling repository is private and its organization
(or the repository) sets the Actions variable `SELF_HOSTED_RUNNER` to its own runners' labels as
JSON, such as `["xoa-selfhosted","x64"]`; the image's check, which needs Docker, takes
`SELF_HOSTED_DOCKER_RUNNER` first. A public repository never runs on them, since its pull requests
come from anyone. The `runs-on` input overrides all of this.

## Development

- `make check`: the Markdown's layout, the website's checks over the test site in `test/site`,
  monolingual and bilingual, with the cases that must fail, the image policy over `test/image` and
  the Dockerfiles in `test/image/rejected`, and the shared head of `AGENTS.md`.
- `make test-fetch`: a scratch project fetches `container/` with the snippet above, at this commit
  (`XOA_BASE=<sha>` for another), and its policy runs. It needs the commit on GitHub.
- `make test-image`: the image's lint and check over the test image, for amd64 and arm64. It needs
  Docker with buildx and QEMU.
- `make web-serve`: the test site at <http://localhost:3000> (after `make test`).
- `make web-browser`: the Chromium of the accessibility check, once per machine.
