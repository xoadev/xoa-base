// The versions the modules name in full are deno.jsonc's, which Dependabot moves: after its pull request, this fails
// until the code says the same version.
import { parse } from "jsr:@std/jsonc@1.0.3";

const imports = (parse(await Deno.readTextFile(new URL("deno.jsonc", import.meta.url))) as {
  imports: Record<string, string>;
}).imports;
const pinned = new Map(
  Object.values(imports).flatMap((target) => {
    const match = /^(npm|jsr):(@?[^@]+)@([^/]+)/.exec(target);
    return match ? [[`${match[1]}:${match[2]}`, match[3]]] : [];
  }),
);

Deno.test("the modules name their dependencies at deno.jsonc's versions", async () => {
  const wrong: string[] = [];
  for await (const entry of Deno.readDir(new URL(".", import.meta.url))) {
    if (!entry.name.endsWith(".ts")) continue;
    const code = await Deno.readTextFile(new URL(entry.name, import.meta.url));
    for (const [, kind, name, version] of code.matchAll(/["'](npm|jsr):(@?[^@"']+)@([^/"']+)/g)) {
      const expected = pinned.get(`${kind}:${name}`);
      if (expected === undefined) wrong.push(`${entry.name}: ${kind}:${name} is not in deno.jsonc's imports`);
      else if (expected !== version) {
        wrong.push(`${entry.name}: ${kind}:${name}@${version}, but deno.jsonc pins ${expected}: write ${expected}`);
      }
    }
  }
  if (wrong.length) throw new Error(wrong.join("\n"));
});
