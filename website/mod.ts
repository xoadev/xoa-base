// From github.com/xoadev/xoa-base (website/mod.ts): change it there.
// The Lume plugin of a XOA site. Its _config.ts runs `site.use(xoa())`, and every build checks what it built: the
// pages with html-validate (its accessibility rules too), the stylesheets with Stylelint, the prose for HTML inside
// Markdown, and the SEO of seo.ts. A failure fails `deno task build`; while serving, it is printed and the site stays
// up. The accessibility check needs a browser, so it is a script of its own, a11y.ts.
import type Site from "lume/core/site.ts";
import { markdownIt } from "lume/deps/markdown_it.ts";
import { HtmlValidate } from "npm:html-validate@11.16.1";
import stylelint from "npm:stylelint@17.16.0";
import recommended from "npm:stylelint-config-recommended@18.0.0";
import standard from "npm:stylelint-config-standard@40.0.0";
import { checkSeo } from "./seo.ts";

export { loadContent } from "./content.ts";

const html = new HtmlValidate({
  extends: ["html-validate:recommended", "html-validate:a11y"],
  rules: { "attribute-empty-style": "off", "no-trailing-whitespace": "off" },
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

export default function xoa() {
  return (site: Site) => {
    // A value as JSON inside a page: a `<` could close the script block.
    site.filter("json", (value: unknown) => JSON.stringify(value).replaceAll("<", "\\u003c"));

    site.addEventListener("afterBuild", async () => {
      // Both without a trailing slash, so the built site is found and skipped among the sources.
      const src = site.src().replace(/\/$/, "");
      const dest = site.dest().replace(/\/$/, "");
      const seo = await checkSeo(dest, site.options.location.href);
      const failures = [
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
