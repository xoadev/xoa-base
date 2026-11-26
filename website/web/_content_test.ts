// From github.com/xoadev/xoa-base (website/web/_content_test.ts), fetched by the project's Makefile: change it there.
// The tests of _content.ts (`deno task content`): on pages and collections written here, in a folder of their own.
import { content, page, sections, type Tree, validate } from "./_content.ts";
const DEFAULT_LANGUAGE = "es";

async function folder(files: Record<string, string>): Promise<URL> {
  const root = await Deno.makeTempDir();
  for (const [path, text] of Object.entries(files)) {
    await Deno.mkdir(`${root}/${path}`.replace(/\/[^/]+$/, ""), { recursive: true });
    await Deno.writeTextFile(`${root}/${path}`, text);
  }
  return new URL(`file://${root}/`);
}

// An error that does not say `expected`, a missing file say, is thrown again: a test cannot pass because something
// else broke.
async function rejects(run: () => unknown, expected: string): Promise<void> {
  let error: unknown;
  try {
    await run();
  } catch (thrown) {
    error = thrown;
  }
  if (error === undefined) throw new Error(`accepted; expected an error saying «${expected}»`);
  if (!String((error as Error).message).includes(expected)) throw error;
}

Deno.test("a page's body is cut into sections and items, but not inside code", async () => {
  const found = sections("# hero\n\nThe lead.\n\n# steps\n\n## One {#one}\n\n```sh\n# not a section\n```\n");
  const expected = {
    hero: { body: "The lead.", items: [] },
    steps: { body: "", items: [{ id: "one", title: "One", body: "```sh\n# not a section\n```" }] },
  };
  if (JSON.stringify(found) !== JSON.stringify(expected)) throw new Error(JSON.stringify(found));
  await rejects(() => sections("Prose with no section.\n"), "prose before the first");
  await rejects(() => sections("# hero\n\nA.\n\n# hero\n\nB.\n"), "two sections «# hero»");
});

Deno.test("an item's data follow its id, wherever the item is moved", async () => {
  const items = "topics:\n  items:\n    data: { anchor: datos }\n    languages: { anchor: lenguas }\n";
  const root = await folder({
    "moved.md": `---\n${items}---\n\n# topics\n\n## Languages {#languages}\n\nB.\n\n## Data {#data}\n\nA.\n`,
    "orphan.md": `---\n${items}---\n\n# topics\n\n## Data {#data}\n\nA.\n`,
    "unnamed.md": "---\n---\n\n# topics\n\n## Data\n\nA.\n",
    "twice.md": "---\n---\n\n# topics\n\n## Data {#data}\n\nA.\n\n## More data {#data}\n\nB.\n",
  });
  const moved = ((await page(new URL("moved.md", root))).topics as { items: Tree[] }).items;
  if (moved.map((item) => `${item.title}:${item.anchor}`).join(" ") !== "Languages:lenguas Data:datos") {
    throw new Error(JSON.stringify(moved));
  }
  await rejects(() => page(new URL("orphan.md", root)), "has languages with no «## … {#id}»");
  await rejects(() => page(new URL("unnamed.md", root)), "«## Data» in topics needs an id");
  await rejects(() => page(new URL("twice.md", root)), "two items with the id data");
});

Deno.test("a page's front matter holds its title, its description and one object per section", async () => {
  const root = await folder({ "loose.md": "---\ntitle: Home\nfoo: abc\n---\n\n# intro\n\nHello.\n" });
  await rejects(() => page(new URL("loose.md", root)), "«foo» is neither title, description nor a section's data");
});

Deno.test("a collection is one file per item, its id the file's name, in its data's order", async () => {
  const root = await folder({
    "home.md": "---\ntitle: Home\n---\n\n# intro\n\nHello.\n",
    "projects/limen.md": "---\norder: 2\n---\n\nAn MCP server.\n",
    "projects/ruas.md": "---\norder: 1\n---\n\nA geocoder.\n",
  });
  const tree = await content(root);
  const projects = tree.projects as Tree[];
  if (projects.map((item) => `${item.id}:${item.body}`).join(" ") !== "ruas:A geocoder. limen:An MCP server.") {
    throw new Error(JSON.stringify(projects));
  }
  if ((tree.home as Tree & { page: Tree }).page.title !== "Home") throw new Error(JSON.stringify(tree.home));
});

Deno.test("languages are compared with the default by key and by id, not by position", async () => {
  const tree = async (files: Record<string, string>) => await content(await folder(files));
  const home = (heading: string, one: string, two: string) =>
    `---\nhero: { title: Hola }\n---\n\n# ${heading}\n\n## Uno {#${one}}\n\nA.\n\n## Dos {#${two}}\n\nB.\n`;
  const reference = await tree({ "home.md": home("hero", "one", "two"), "projects/ruas.md": "---\n---\n\nA.\n" });
  const reordered = await tree({ "home.md": home("hero", "two", "one"), "projects/ruas.md": "---\n---\n\nB.\n" });
  validate({ [DEFAULT_LANGUAGE]: reference, other: reordered }, DEFAULT_LANGUAGE);
  const renamed = await tree({ "home.md": home("hero", "uno", "two"), "projects/ruas.md": "---\n---\n\nB.\n" });
  await rejects(() => validate({ [DEFAULT_LANGUAGE]: reference, other: renamed }, DEFAULT_LANGUAGE), "missing .home.hero.items.#one");
  const translated = await tree({ "home.md": home("inicio", "one", "two"), "projects/ruas.md": "---\n---\n\nB.\n" });
  await rejects(() => validate({ [DEFAULT_LANGUAGE]: reference, other: translated }, DEFAULT_LANGUAGE), "extra .home.inicio");
  const lacking = await tree({ "home.md": home("hero", "one", "two") });
  await rejects(() => validate({ [DEFAULT_LANGUAGE]: reference, other: lacking }, DEFAULT_LANGUAGE), "missing .projects.#ruas");
});

Deno.test("what is declared in some languages only exists in exactly those", async () => {
  const tree = async (files: Record<string, string>) => await content(await folder(files));
  const intro = "---\n---\n\n# intro\n\nHello.\n";
  const withVideos = await tree({ "home.md": `${intro}\n# videos\n\nVídeos.\n`, "press/one.md": "---\n---\n\nA.\n" });
  const without = await tree({ "home.md": intro });
  const only = { "home.videos": [DEFAULT_LANGUAGE], press: [DEFAULT_LANGUAGE] };
  validate({ [DEFAULT_LANGUAGE]: withVideos, other: without }, DEFAULT_LANGUAGE, "_content", only);
  await rejects(
    () => validate({ [DEFAULT_LANGUAGE]: withVideos, other: withVideos }, DEFAULT_LANGUAGE, "_content", only),
    `home.videos is declared only in ${DEFAULT_LANGUAGE}`,
  );
  await rejects(
    () => validate({ [DEFAULT_LANGUAGE]: without, other: without }, DEFAULT_LANGUAGE, "_content", only),
    `home.videos is declared in ${DEFAULT_LANGUAGE} and is not there`,
  );
  await rejects(() => validate({ [DEFAULT_LANGUAGE]: withVideos, other: without }, DEFAULT_LANGUAGE), "missing .home.videos");
});
