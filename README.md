# xoa-base

The checks and workflows shared by XOA Desarrollo's projects, for anyone to use: they need no
credentials.

| Folder       | What it checks                                                                                  |
| ------------ | ----------------------------------------------------------------------------------------------- |
| `website/`   | A static Lume site: lints, content by language, SEO, accessibility at two widths and two themes |
| `container/` | A container image: digests, distroless, non-root, secrets, both architectures, a clean stop     |

## Using it in a project

1. Copy the area's files from a commit of this repository, as they are, and record that commit:
   - `website/web.mk` to the project root and `website/web/` into the site's folder;
   - `container/image.mk` to the project root and `container/tools/image.sh` to `tools/`.
2. `include web.mk` or `include image.mk` in the project's `Makefile`, with its variables set above
   (each `.mk` lists them).
3. Call the reusable workflow from the project's CI, by the SHA of the same commit:

   ```yaml
   jobs:
     image:
       uses: xoadev/xoa-base/.github/workflows/image.yml@<sha> # vX.Y.Z
   ```

The workflow runs on GitHub's runners when the calling repository is public, whose pull requests
come from anyone, and on XOA's own when it is private; its `runs-on` input overrides that.

The copies are never edited in the project: a change goes here, and the project copies the new
commit.

## Development

- `make check`: the Markdown's layout, the website's checks over the test site in `test/site`,
  monolingual and bilingual, with the cases that must fail, the image policy over `test/image` and
  the Dockerfiles in `test/image/rejected`, and the shared head of `AGENTS.md`.
- `make test-image`: the image's lint and check over the test image, for amd64 and arm64. It needs
  Docker with buildx and QEMU.
- `make web-serve`: the test site at <http://localhost:3000> (after `make test`).
- `make web-browser`: the Chromium of the accessibility check, once per machine.
