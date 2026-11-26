# The website's checks

A XOA site imports this folder as Deno modules, by one commit of this repository. The site's
`deno.json` maps them, and its `deno.lock` holds their hashes, all of them after one build, since
the plugin imports every module:

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
  what it made (what, in `mod.ts`) and fails on any failure; while serving, it prints them. The
  plugin also gives the pages the `json` filter for their JSON-LD.
- Its `_data.ts` reads the prose with `loadContent({ root, languages, defaultLanguage })` from
  `xoa-web/mod.ts`.
- `deno task a11y` checks the built site in a browser, which `deno task browser` installs once.
- The modules share the site's `lume/`, so the site's Lume is theirs too.

The project's `Makefile` runs them through the two targets the CI's workflow calls: `web-check`
(`cd <site> && deno fmt --check && deno lint && deno task build && deno task a11y`) and
`web-browser` (`cd <site> && deno task browser`).

## The site's prose

`loadContent()` reads the prose of a site in this format, and the build fails where it is not
followed.

- **One Markdown file per page and language**, `_content/<code>/<page>.md`, so a person edits and
  translates a whole page as one text. Data and short labels (titles, button texts, table cells,
  URLs, dates) go in the front matter, under the key of their section; prose goes in the body, cut
  into sections by a `# <section>` line, and a section's repeated items (cards, steps) each under a
  `## <title> {#id}` line. Prose before the first section fails.
- **`<section>` and `id` are keys, not text**: the same in every language, never translated, in a
  lowercase slug (`# benefits`, `## Pide una clave {#key}`). A section's visible title is a label in
  its front matter; an item's title is the text of its `##`. Every item carries its id.
- **An item with no data, or one or two short fields** (a link target, an anchor, an eyebrow), stays
  in the page's body, its fields in the front matter under its id, `<section>.items.<id>`, never as
  a list matched by position. An id on one side without its pair, a repeated id or an item without
  one fails.
- **An item with more data than that** (projects with their links and tags, team members, notes)
  goes to a collection, one file per item and language, `_content/<code>/<collection>/<id>.md`: its
  front matter holds the data, its body the prose, and the items come in the order of their `order`
  field. A collection's files are named the same in every language.
- **The languages are compared with the default one**, by front matter key, by section, by item id
  and by collection file: what one language lacks or adds fails. What exists in some languages only,
  a page, a section or a collection, is declared to
  `loadContent({ only: { "home.videos": ["es"] } })` and must exist in exactly those.
- **Headings are read as Markdown reads them** (through Lume's markdown-it), so a `#` inside fenced
  code is not a section. A page has several `#` headings by design: a project that runs markdownlint
  over the site turns MD025 off for `_content/`.
- **No HTML in Markdown**: the build fails on it. HTML for a case nothing else covers goes on its
  own line with `markdownlint-disable-line MD033` and its reason, which the check reads too.

The pages receive each language's tree as `c`: `c.<page>.<section>.body` and `.items`, and
`c.<collection>` as a list.
