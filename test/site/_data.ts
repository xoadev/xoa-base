import { parse } from "lume/deps/yaml.ts";

// Where the site is published: the canonical, social and sitemap URLs are built from it.
export const SITE = "https://example.xoa.dev";

// The site's language: every page's, unless a page is translated (`lang: [es, en]` in its front matter). Its texts,
// _texts/<code>.yml, are the reference of any translation.
import { DEFAULT_LANGUAGE, LANGUAGES } from "./_languages.ts";

// The color of the browser's bar, the --ink of styles.css.
const theme = "#0a0a0a";

// Who publishes the site, as schema.org says it: the JSON-LD of every page.
const organization = {
  "@type": "Organization",
  name: "XOA Desarrollo, S.L.",
  url: "https://xoa.dev",
  email: "hello@xoa.dev",
};

type Texts = { [key: string]: Texts | Texts[] | string };

// Every key of a text file, as a path: a translation that lacks one or adds one fails the build.
function paths(value: unknown, prefix = ""): string[] {
  if (typeof value === "string") return [prefix];
  if (Array.isArray(value)) return value.flatMap((item, n) => paths(item, `${prefix}[${n}]`));
  return Object.entries(value as Texts).flatMap(([key, item]) => paths(item, `${prefix}.${key}`));
}

// Load each registered language; a missing catalog fails the build.
const dir = new URL("./_texts/", import.meta.url);
const texts: Record<string, Texts> = {};
for (const code of Object.keys(LANGUAGES)) {
  texts[code] = parse(Deno.readTextFileSync(new URL(`${code}.yml`, dir))) as Texts;
}
if (!texts[DEFAULT_LANGUAGE]) throw new Error(`_texts/${DEFAULT_LANGUAGE}.yml is missing: it is DEFAULT_LANGUAGE`);

const expected = new Set(paths(texts[DEFAULT_LANGUAGE]));
for (const [code, own] of Object.entries(texts)) {
  const found = new Set(paths(own));
  const missing = [...expected].filter((path) => !found.has(path));
  const extra = [...found].filter((path) => !expected.has(path));
  if (missing.length || extra.length) {
    throw new Error(`_texts/${code}.yml differs from ${DEFAULT_LANGUAGE}.yml: missing ${missing}, extra ${extra}`);
  }
}

export default {
  theme,
  organization,
  lang: DEFAULT_LANGUAGE,
  languages: LANGUAGES,
  // `t` is the default language's texts; the multilanguage plugin replaces it on a translated page with its own.
  t: texts[DEFAULT_LANGUAGE],
  ...Object.fromEntries(Object.keys(LANGUAGES).map((code) => [code, { t: texts[code] }])),
};
