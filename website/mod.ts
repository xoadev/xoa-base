// From github.com/xoadev/xoa-base (website/mod.ts): change it there.
// The Lume plugin of a XOA site. Its _config.ts runs `site.use(xoa())`, and every build checks what it built: the
// pages with html-validate (its accessibility rules too), the stylesheets with Stylelint, the prose for HTML inside
// Markdown, and the SEO of seo.ts. A failure fails `deno task build`; while serving, it is printed and the site stays
// up. The accessibility check needs a browser, so it runs apart: `a11y()`, from a11y.ts.
import type Site from "lume/core/site.ts";
import { markdownIt } from "lume/deps/markdown_it.ts";
import { HtmlValidate } from "npm:html-validate@11.16.1";
import stylelint from "npm:stylelint@17.16.0";
import recommended from "npm:stylelint-config-recommended@18.0.0";
import standard from "npm:stylelint-config-standard@40.0.0";
import { checkSeo } from "./seo.ts";

export { loadContent } from "./content.ts";
export { a11y, installBrowser } from "./a11y.ts";

const html = new HtmlValidate({
  extends: ["html-validate:recommended", "html-validate:a11y"],
  rules: {
    "attribute-empty-style": "off",
    "no-trailing-whitespace": "off",
    // Lume writes a boolean attribute empty (required=""), so that is the style a page is held to.
    "attribute-boolean-style": ["error", { style: "empty" }],
  },
});
// stylelint-config-standard extends stylelint-config-recommended by name, which Deno cannot resolve: both, flattened.
const css = { rules: { ...recommended.rules, ...standard.rules } };
// A line that needs HTML Markdown cannot say carries this comment with its reason, as markdownlint has it.
const HTML_ALLOWED = "markdownlint-disable-line MD033";

async function* files(dir: string, skip: string[], extension: string): AsyncGenerator<string> {
  for await (const entry of Deno.readDir(dir)) {
    const path = `${dir}/${entry.name}`;
    if (skip.includes(path) || entry.name.startsWith(".") || entry.name === "node_modules") continue;
    if (entry.isDirectory) yield* files(path, skip, extension);
    else if (entry.name.endsWith(extension)) yield path;
  }
}

async function pagesFailures(dest: string): Promise<string[]> {
  const failures: string[] = [];
  for await (const file of files(dest, [], ".html")) {
    const where = file.slice(dest.length);
    // Lume logs a page it could not render and leaves it empty, and still ends well.
    if (!(await Deno.readTextFile(file)).trim()) failures.push(`${where}: empty, it did not render`);
    const report = await html.validateFile(file);
    for (const { messages } of report.results) {
      for (const { line, ruleId, message } of messages) failures.push(`${where}:${line}: ${message} (${ruleId})`);
    }
  }
  return failures;
}

async function stylesFailures(src: string, dest: string): Promise<string[]> {
  const sheets = await Array.fromAsync(files(src, [dest], ".css"));
  if (!sheets.length) return [];
  // Stylelint reads the site's .stylelintignore (deno task runs in the site's folder): a library's stylesheet goes there.
  const { results } = await stylelint.lint({ files: sheets, config: css });
  return results.flatMap(({ source, warnings }) =>
    warnings.map(({ line, text }) => `${source?.slice(src.length)}:${line}: ${text}`)
  );
}

async function proseFailures(src: string, dest: string): Promise<string[]> {
  const failures: string[] = [];
  const parser = markdownIt({ html: true });
  for await (const file of files(src, [dest], ".md")) {
    const lines = (await Deno.readTextFile(file)).split("\n");
    // Front matter is YAML, not Markdown: the body starts after it.
    const start = lines[0] === "---" ? lines.indexOf("---", 1) + 1 : 0;
    const body = lines.slice(start);
    const tokens = parser.parse(body.join("\n"), {});
    for (const token of tokens) {
      const html = token.type === "html_block" ||
        token.children?.some((child: { type: string }) => child.type === "html_inline");
      const line = token.map?.[0] ?? 0;
      if (html && !body[line]?.includes(HTML_ALLOWED)) {
        failures.push(`${file.slice(src.length)}:${start + line + 1}: HTML in Markdown`);
      }
    }
  }
  return failures;
}

// This module's own commit, when the site imports it from GitHub (raw.githubusercontent.com/xoadev/xoa-base/<sha>/).
const OWN_COMMIT = /\/xoadev\/xoa-base\/([0-9a-f]{40})\//.exec(import.meta.url)?.[1];
const CALLED = /xoadev\/xoa-base\/\.github\/[^@\s]+@([0-9a-f]{40})/g;

// The commit the site imports this from is the one its repository's workflows call, which Dependabot moves: a deno.json
// left behind fails here, saying where to move it.
async function commitFailures(src: string): Promise<string[]> {
  if (!OWN_COMMIT) return [];
  let root = src;
  while (!(await exists(`${root}/.git`))) {
    const parent = root.replace(/\/[^/]+$/, "");
    if (!parent || parent === root) return [];
    root = parent;
  }
  const called = new Set<string>();
  const workflows = `${root}/.github/workflows`;
  if (await exists(workflows)) {
    for await (const entry of Deno.readDir(workflows)) {
      if (!/\.ya?ml$/.test(entry.name)) continue;
      for (const [, commit] of (await Deno.readTextFile(`${workflows}/${entry.name}`)).matchAll(CALLED)) {
        called.add(commit);
      }
    }
  }
  if (!called.size) {
    return [
      `.github/workflows: no workflow calls xoa-base, whose commit the site's xoa-web/ must follow: add the one ` +
      `website/README.md shows, calling web.yml@${OWN_COMMIT}`,
    ];
  }
  if (called.size === 1 && called.has(OWN_COMMIT)) return [];
  return [
    `deno.json: xoa-web/ is at xoa-base ${OWN_COMMIT}, but the workflows call ${
      [...called].join(", ")
    }: move xoa-web/ ` +
    `to the workflows' commit (Dependabot moves only theirs)`,
  ];
}

async function exists(path: string): Promise<boolean> {
  try {
    await Deno.stat(path);
    return true;
  } catch (error) {
    if (error instanceof Deno.errors.NotFound) return false;
    throw error;
  }
}

export interface Options {
  // Sources a directive of the Content Security Policy allows beyond 'self' and exact HTTPS origins, which the check
  // refuses otherwise: each one written in the site's _config.ts with the reason it cannot be avoided
  // (`{ "img-src": ["data:"] }` for the blank tiles a map library writes).
  csp?: Record<string, string[]>;
}

export default function xoa(options: Options = {}) {
  return (site: Site) => {
    // A value as JSON inside a page: a `<` could close the script block.
    site.filter("json", (value: unknown) => JSON.stringify(value).replaceAll("<", "\\u003c"));

    site.addEventListener("afterBuild", async () => {
      // Both without a trailing slash, so the built site is found and skipped among the sources.
      const src = site.src().replace(/\/$/, "");
      const dest = site.dest().replace(/\/$/, "");
      const seo = await checkSeo(dest, site.options.location.href, options.csp);
      const failures = [
        ...(await commitFailures(src)),
        ...(await pagesFailures(dest)),
        ...(await stylesFailures(src, dest)),
        ...(await proseFailures(src, dest)),
        ...seo.failures,
      ];
      if (!failures.length) {
        console.log(`xoa: ${seo.pages} indexable pages checked, no failures`);
        return;
      }
      console.error(`xoa: the built site fails its checks\n${failures.join("\n")}`);
      if (!Deno.args.includes("-s") && !Deno.args.includes("--serve")) Deno.exit(1);
    });
  };
}
