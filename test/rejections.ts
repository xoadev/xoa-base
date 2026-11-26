// Exercise the installed checker against broken output, restoring each file before the next case.
const root = "build/bilingual";
// The SEO check alone, over the built site: the test site's SITE.
const seo = [
  "run",
  "--config",
  "website/deno.json",
  "-A",
  "website/seo.ts",
  `${root}/_site`,
  "https://example.xoa.dev",
];
const cases: [string, string, (text: string) => string, string][] = [
  [
    "404 indexable",
    "404.html",
    (s) => s.replace('content="noindex"', 'content="index"'),
    "custom 404 must be noindex",
  ],
  [
    "404 without home link",
    "404.html",
    (s) => s.replace('href="/">Volver', 'href="#">Volver'),
    "custom 404 needs a home link",
  ],
  [
    "404 in sitemap",
    "sitemap.xml",
    (s) =>
      s.replace(
        "</urlset>",
        "<url><loc>https://example.xoa.dev/404.html</loc></url></urlset>",
      ),
    "custom 404 must not be in sitemap",
  ],
  [
    "JSON-LD absent",
    "index.html",
    (s) =>
      s.replace(/<script type="application\/ld\+json">[\s\S]*?<\/script>/g, ""),
    "no JSON-LD",
  ],
  [
    "CSP absent",
    "index.html",
    (s) => s.replace(/<meta http-equiv="Content-Security-Policy"[^>]*>/g, ""),
    "CSP default-src",
  ],
  [
    "CSP unsafe",
    "index.html",
    (s) => s.replace("script-src 'self'", "script-src 'self' 'unsafe-inline'"),
    "CSP script-src",
  ],
  [
    "origin prefix",
    "sitemap.xml",
    (s) =>
      s.replace(
        "</urlset>",
        "<url><loc>https://example.xoa.dev.evil.test/</loc></url></urlset>",
      ),
    "is not under",
  ],
  [
    "social origin",
    "index.html",
    (s) =>
      s.replace(
        'content="https://example.xoa.dev/assets/og.png"',
        'content="https://example.xoa.dev.evil.test/assets/og.png"',
      ),
    "og:image",
  ],
  [
    "alternates absent",
    "index.html",
    (s) => s.replace(/<link[^>]*hreflang[^>]*>/g, ""),
    "missing hreflang",
  ],
  [
    "broken link",
    "index.html",
    (s) => s.replace('href="/styles.css"', 'href="/missing.css"'),
    "/missing.css does not exist",
  ],
  [
    "manifest icons absent",
    "site.webmanifest",
    () => '{"icons":[]}',
    "no 512x512 icon",
  ],
];
for (const [name, file, mutate, expected] of cases) {
  const path = `${root}/_site/${file}`;
  const original = await Deno.readTextFile(path);
  const changed = mutate(original);
  if (changed === original) {
    throw new Error(`${name}: mutation did not change the fixture`);
  }
  try {
    await Deno.writeTextFile(path, changed);
    const result = await new Deno.Command(Deno.execPath(), {
      args: seo,
      stdout: "piped",
      stderr: "piped",
    }).output();
    const output = new TextDecoder().decode(result.stderr);
    if (result.success || !output.includes(expected)) {
      throw new Error(`${name}: expected ${expected}, got ${output}`);
    }
    console.log(`rejection: ${name} OK`);
  } finally {
    await Deno.writeTextFile(path, original);
  }
}
for (const file of ["favicon-96.png", "404.html"]) {
  const icon = `${root}/_site/${file}`;
  await Deno.rename(icon, `${icon}.saved`);
  try {
    const result = await new Deno.Command(Deno.execPath(), {
      args: seo,
      stdout: "piped",
      stderr: "piped",
    }).output();
    if (
      result.success ||
      !new TextDecoder().decode(result.stderr).includes(
        `/${file}: missing`,
      )
    ) {
      throw new Error(`missing ${file} was not rejected`);
    }
    console.log(`rejection: missing ${file} OK`);
  } finally {
    await Deno.rename(`${icon}.saved`, icon);
  }
}
const markdown = `${root}/rejected.md`;
await Deno.writeTextFile(markdown, "Some <b>bold</b> text.\n");
try {
  const result = await new Deno.Command(Deno.execPath(), {
    args: ["task", "build"],
    cwd: root,
    stdout: "piped",
  }).output();
  if (
    result.success ||
    !new TextDecoder().decode(result.stderr).includes("HTML in Markdown")
  ) {
    throw new Error("HTML in Markdown was not rejected");
  }
  console.log("rejection: HTML in Markdown OK");
} finally {
  await Deno.remove(markdown);
}
