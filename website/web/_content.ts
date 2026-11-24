// Copied from github.com/xoadev/xoa-base (website/web/_content.ts): change it there, not in a project's copy.
// The site's prose, read as the website skill writes it ("Languages"): `_content/<lang>/<page>.md`, one file per page
// and language, and `_content/<lang>/<collection>/<id>.md`, one file per item of a collection. `_data.ts` calls
// `loadContent()` and hands each language's tree to the pages as `c`.
import { extract } from "lume/deps/front_matter.ts";
import { markdownIt, markdownItAttrs } from "lume/deps/markdown_it.ts";
import { DEFAULT_LANGUAGE, LANGUAGES } from "./_languages.ts";

export type Tree = { [key: string]: unknown };
type Item = { id?: string; title: string; body: string };
type Section = { body: string; items: Item[] };
// What is read of markdown-it's tokens.
type Token = {
  type: string;
  tag: string;
  level: number;
  map: [number, number] | null;
  content: string;
  children: Token[] | null;
  attrGet(name: string): string | null;
};

const markdown = markdownIt().use(markdownItAttrs);

// A page's body: its prose, cut into sections by its `# <section>` headings and each section's items by its
// `## <title> {#id}` headings. Markdown-it finds the headings, so one inside a code block or written underlined is read
// as Markdown reads it.
export function sections(body: string): Record<string, Section> {
  const lines = body.split("\n");
  const tokens: Token[] = markdown.parse(body, {});
  const headings = tokens.flatMap((token: Token, n: number) =>
    token.type === "heading_open" && (token.tag === "h1" || token.tag === "h2") && token.map
      ? [{
        level: token.tag,
        start: token.map[0],
        end: token.map[1],
        id: token.attrGet("id") ?? undefined,
        title: (tokens[n + 1].children ?? []).filter((child) => child.type === "text" || child.type === "code_inline")
          .map((child) => child.content).join("").trim(),
      }]
      : []
  );
  const first = headings.find((heading) => heading.level === "h1")?.start ?? lines.length;
  if (tokens.some((token) => token.map && token.level === 0 && token.map[0] < first)) {
    throw new Error(`prose before the first «# <section>»: ${lines.slice(0, first).join(" ").trim().slice(0, 80)}`);
  }
  const found: Record<string, Section> = {};
  let section: Section | undefined;
  headings.forEach((heading, n) => {
    const text = lines.slice(heading.end, headings[n + 1]?.start ?? lines.length).join("\n").trim();
    if (heading.level === "h1") {
      if (heading.title in found) throw new Error(`two sections «# ${heading.title}»`);
      found[heading.title] = section = { body: text, items: [] };
    } else section!.items.push({ ...(heading.id ? { id: heading.id } : {}), title: heading.title, body: text });
  });
  return found;
}

// `_content/<lang>/<page>.md` is `c.<page>`: its title and description are `c.<page>.page`; every other key of its
// front matter is a section's data and labels, `c.<page>.<section>`, to which the body adds the section's prose
// (`body`, Markdown) and its items (`items`, each its `id`, `title` and `body`). The `# <section>` lines are keys, the
// same in every language. Every item is written `## <title> {#id}`, with the same id in every language, and the data of
// one that has any go in the front matter's `<section>.items.<id>`: by id, not by position, so reordering one side
// cannot pair an item with another's data, and an id on one side without its pair fails the build.
export async function page(file: URL): Promise<Tree> {
  const { attrs, body } = extract<Tree>(await Deno.readTextFile(file));
  const { title, description, ...data } = attrs;
  const result: Tree = title || description ? { page: { title, description } } : {};
  for (const [name, value] of Object.entries(data)) {
    if (value === null || typeof value !== "object" || Array.isArray(value)) {
      throw new Error(`${file.pathname}: «${name}» is neither title, description nor a section's data ({ … })`);
    }
    result[name] = { ...(value as Tree) };
  }
  for (const [name, prose] of Object.entries(sections(body))) {
    const section = (result[name] ?? {}) as Tree;
    const extra = (section.items ?? {}) as Record<string, Tree>;
    if (Array.isArray(extra)) {
      throw new Error(`${file.pathname}: ${name}.items goes by id ({ <id>: {…} }), not as a list`);
    }
    if (prose.body) section.body = prose.body;
    const missing = prose.items.find((item) => !item.id);
    if (missing) {
      throw new Error(`${file.pathname}: «## ${missing.title}» in ${name} needs an id: «## ${missing.title} {#id}»`);
    }
    const ids = prose.items.map((item) => item.id!);
    const repeated = ids.find((id, n) => ids.indexOf(id) !== n);
    if (repeated) throw new Error(`${file.pathname}: ${name} has two items with the id ${repeated}`);
    const orphans = Object.keys(extra).filter((id) => !ids.includes(id));
    if (orphans.length) {
      throw new Error(`${file.pathname}: ${name}.items has ${orphans.join(", ")} with no «## … {#id}»`);
    }
    if (prose.items.length) section.items = prose.items.map((item) => ({ ...extra[item.id!], ...item }));
    else delete section.items;
    result[name] = section;
  }
  return result;
}

// `_content/<lang>/<collection>/<id>.md` is one item of `c.<collection>`: its front matter is its data, its body its
// prose (`body`), its file name its `id`, the same in every language. The items go in the order of their `order` field,
// or of their ids when they have none.
async function collection(folder: URL): Promise<Tree[]> {
  const items: Tree[] = [];
  for await (const entry of Deno.readDir(folder)) {
    if (!entry.name.endsWith(".md")) continue;
    const { attrs, body } = extract<Tree>(await Deno.readTextFile(new URL(entry.name, folder)));
    items.push({ ...attrs, id: entry.name.replace(/\.md$/, ""), body: body.trim() });
  }
  const rank = (item: Tree) => typeof item.order === "number" ? item.order : Infinity;
  return items.sort((a, b) => rank(a) - rank(b) || String(a.id).localeCompare(String(b.id)));
}

// One language's prose: its pages and its collections.
export async function content(folder: URL): Promise<Tree> {
  const tree: Tree = {};
  for await (const entry of Deno.readDir(folder)) {
    const name = entry.name.replace(/\.md$/, "");
    if (name in tree) throw new Error(`${folder.pathname}: ${name} is both a page and a collection`);
    if (entry.isDirectory) tree[name] = await collection(new URL(`${entry.name}/`, folder));
    else if (entry.name.endsWith(".md")) tree[name] = await page(new URL(entry.name, folder));
  }
  return tree;
}

// Every key of a tree, to compare one language with the default: a list of items by their ids, so a language with the
// same items in another order still matches, and one with an item missing, extra or renamed does not.
function keys(value: unknown, prefix = ""): string[] {
  if (value === null || typeof value !== "object") return [`${prefix}:${typeof value}`];
  const entries = Array.isArray(value) && value.every((item) => (item as Item)?.id)
    ? value.map((item) => [`#${(item as Item).id}`, item])
    : Object.entries(value);
  return entries.flatMap(([key, item]) => keys(item, `${prefix}.${key}`));
}

// What exists in some languages only, declared: `{ "home.videos": ["es"] }` is a section of the home only in
// Spanish; a key with no dot is a whole page or collection. It is left out of the comparison with the default, and
// must exist in exactly those languages.
export type Only = Record<string, string[]>;

function at(tree: Tree, path: string): unknown {
  return path.split(".").reduce<unknown>((node, key) => (node as Tree | undefined)?.[key], tree);
}

// Each language against the default: a key, a section or an item one has and the other lacks fails the build, but
// for what `only` declares.
export function validate(trees: Record<string, Tree>, where = "_content", only: Only = {}): void {
  const declared = (key: string) =>
    Object.keys(only).some((path) => key.startsWith(`.${path}.`) || key.startsWith(`.${path}:`));
  const shared = (tree: Tree) => keys(tree).filter((key) => !declared(key)).sort();
  const expected = shared(trees[DEFAULT_LANGUAGE]);
  for (const [code, tree] of Object.entries(trees)) {
    const found = shared(tree);
    const missing = expected.filter((key) => !found.includes(key));
    const extra = found.filter((key) => !expected.includes(key));
    if (missing.length || extra.length) {
      throw new Error(
        `${where}/${code}/ differs from ${DEFAULT_LANGUAGE}: missing ${missing.join(", ") || "nothing"}; ` +
          `extra ${extra.join(", ") || "nothing"}`,
      );
    }
    for (const [path, languages] of Object.entries(only)) {
      const present = at(tree, path) !== undefined;
      if (languages.includes(code) && !present) {
        throw new Error(`${where}/${code}/: ${path} is declared in ${code} and is not there`);
      }
      if (!languages.includes(code) && present) {
        throw new Error(`${where}/${code}/: ${path} is declared only in ${languages.join(", ")}`);
      }
    }
  }
}

// The prose of every language of the site, `_content/<lang>/` next to this file, checked against the default one;
// `only` declares what exists in some languages only (see `validate`).
export async function loadContent(
  { root = new URL("./_content/", import.meta.url), only = {} }: { root?: URL; only?: Only } = {},
): Promise<Record<string, Tree>> {
  const trees: Record<string, Tree> = {};
  for (const code of Object.keys(LANGUAGES)) trees[code] = await content(new URL(`${code}/`, root));
  validate(trees, root.pathname.replace(/\/$/, ""), only);
  return trees;
}
