// From github.com/xoadev/xoa-base (website/seo.ts): change it there.
// What search engines and shared links read, checked on the built site: every page in the sitemap and every
// indexable page built is there, each with a unique title and description, its own canonical URL, its language
// alternates and social image; the icons, the manifest and robots.txt are there; the JSON-LD parses, and no link or
// source inside the site points to a file that does not exist. The plugin (mod.ts) runs it after every build.
import { DOMParser } from "lume/deps/dom.ts";

// `root` is the built site's folder, `SITE` its published origin, and `cspAllowed` the sources, per directive, the
// site allows beyond 'self' and exact HTTPS origins (the plugin's `csp` option).
export async function checkSeo(
  root: string,
  SITE: string,
  cspAllowed: Record<string, string[]> = {},
): Promise<{ failures: string[]; pages: number }> {
  const ROOT = root;
  const origin = new URL(SITE).origin;
  function sameOrigin(value: string): boolean {
    try {
      return new URL(value).origin === origin;
    } catch {
      return false;
    }
  }
  const failures: string[] = [];
  const fail = (where: string, what: string) => failures.push(`${where}: ${what}`);

  // The file a site path is served from, as a static host finds it, with or without `.html`.
  async function exists(path: string): Promise<boolean> {
    const clean = decodeURIComponent(path.split(/[?#]/)[0]);
    const candidates = clean.endsWith("/") ? [`${clean}index.html`] : [clean, `${clean}.html`, `${clean}/index.html`];
    for (const candidate of candidates) {
      try {
        if ((await Deno.stat(ROOT + candidate)).isFile) return true;
      } catch {
        // Not this one: try the next way a host would find it.
      }
    }
    return false;
  }

  async function* htmlFiles(dir: string): AsyncGenerator<string> {
    for await (const entry of Deno.readDir(dir)) {
      const path = `${dir}/${entry.name}`;
      if (entry.isDirectory) yield* htmlFiles(path);
      else if (entry.name.endsWith(".html")) yield path;
    }
  }

  const sitemap = await Deno.readTextFile(`${ROOT}/sitemap.xml`);
  const listed = new Set([...sitemap.matchAll(/<loc>([^<]+)<\/loc>/g)].map(([, loc]) => loc));
  for (const url of listed) {
    if (!sameOrigin(url)) fail("sitemap.xml", `${url} is not under ${SITE}`);
    else if (!(await exists(new URL(url).pathname))) fail("sitemap.xml", `${url} has no page`);
  }

  const robots = await Deno.readTextFile(`${ROOT}/robots.txt`);
  if (!robots.includes(`Sitemap: ${new URL("/sitemap.xml", SITE)}`)) {
    fail("robots.txt", "no Sitemap line for this site");
  }

  for (
    const icon of [
      "/favicon-96.png",
      "/favicon.ico",
      "/favicon.svg",
      "/apple-touch-icon.png",
      "/site.webmanifest",
      "/llms.txt",
      "/404.html",
    ]
  ) {
    if (!(await exists(icon))) fail(icon, "missing");
  }
  const manifest = JSON.parse(await Deno.readTextFile(`${ROOT}/site.webmanifest`));
  if (!manifest.icons?.some((icon: { sizes?: string }) => icon.sizes?.split(/\s+/).includes("512x512"))) {
    fail("site.webmanifest", "no 512x512 icon");
  }
  for (const { src } of manifest.icons ?? []) {
    if (!(await exists(src))) fail("site.webmanifest", `icon ${src} missing`);
  }

  const titles = new Map<string, string>();
  const descriptions = new Map<string, string>();
  for await (const file of htmlFiles(ROOT)) {
    const path = file.slice(ROOT.length).replace(/index\.html$/, "");
    const doc = new DOMParser().parseFromString(await Deno.readTextFile(file), "text/html");
    const attr = (selector: string, name: string) => doc.querySelector(selector)?.getAttribute(name) ?? "";

    for (const element of doc.querySelectorAll("[href], [src]")) {
      const target = element.getAttribute("href") ?? element.getAttribute("src") ?? "";
      if (target.startsWith("/") && !target.startsWith("//") && !(await exists(target))) {
        fail(path, `${target} does not exist`);
      }
    }
    const csp = attr('meta[http-equiv="Content-Security-Policy"]', "content");
    const directives = new Map(
      csp.split(";").filter((part) => part.trim()).map((part) => {
        const [name, ...values] = part.trim().split(/\s+/);
        return [name, values];
      }),
    );
    for (const name of ["default-src", "base-uri", "form-action"]) {
      if (directives.get(name)?.join(" ") !== "'none'") fail(path, `CSP ${name} must be 'none'`);
    }
    for (const name of ["script-src", "style-src", "font-src", "img-src", "connect-src", "manifest-src"]) {
      const values = directives.get(name) ?? [];
      if (
        !values.includes("'self'") || values.some((value) => {
          if (value === "'self'" || cspAllowed[name]?.includes(value)) return false;
          try {
            return new URL(value).origin !== value || !value.startsWith("https://") || value.includes("*");
          } catch {
            return true;
          }
        })
      ) {
        fail(
          path,
          `CSP ${name} requires 'self' and only exact HTTPS origins as exceptions; another source goes in the ` +
            `plugin's csp option, with its reason`,
        );
      }
    }
    if (!doc.querySelector('script[type="application/ld+json"]')) fail(path, "no JSON-LD");
    for (const script of doc.querySelectorAll('script[type="application/ld+json"]')) {
      try {
        JSON.parse(script.textContent);
      } catch (error) {
        fail(path, `JSON-LD does not parse: ${error}`);
      }
    }

    if (path === "/404.html") {
      if (!attr('meta[name="robots"]', "content").split(/[\s,]+/).includes("noindex")) {
        fail(path, "custom 404 must be noindex");
      }
      if (listed.has(new URL(path, SITE).href)) fail(path, "custom 404 must not be in sitemap.xml");
      if (!doc.querySelector("main h1")?.textContent.trim()) fail(path, "custom 404 needs a heading in main");
      if (!doc.querySelector('main a[href="/"]')) fail(path, "custom 404 needs a home link in main");
      continue;
    }
    if (attr('meta[name="robots"]', "content").includes("noindex")) continue;

    const url = new URL(path, SITE).href;
    if (!listed.has(url)) fail(path, "not in sitemap.xml (or noindex it)");
    if (!doc.documentElement?.getAttribute("lang")) fail(path, "no <html lang>");
    if (attr('link[rel="canonical"]', "href") !== url) fail(path, `canonical is not ${url}`);
    if (doc.querySelectorAll("h1").length !== 1) fail(path, "not exactly one <h1>");

    const title = doc.querySelector("title")?.textContent.trim() ?? "";
    const description = attr('meta[name="description"]', "content");
    if (!title) fail(path, "no <title>");
    else if (titles.has(title)) fail(path, `same title as ${titles.get(title)}`);
    else titles.set(title, path);
    if (!description) fail(path, "no meta description");
    else if (descriptions.has(description)) fail(path, `same description as ${descriptions.get(description)}`);
    else descriptions.set(description, path);
    if (description.length > 160) fail(path, `description of ${description.length} characters: search shows ~160`);

    const image = attr('meta[property="og:image"]', "content");
    if (!sameOrigin(image) || !(await exists(new URL(image).pathname))) fail(path, `og:image ${image} missing`);
    for (const property of ["og:title", "og:description", "og:url", "og:image:alt"]) {
      if (!attr(`meta[property="${property}"]`, "content")) fail(path, `no ${property}`);
    }

    // Sitemap alternates make a missing head link detectable, even when all head alternates are removed.
    const sitemapEntry = [...sitemap.matchAll(/<url>([\s\S]*?)<\/url>/g)]
      .find(([, entry]) => entry.includes(`<loc>${url}</loc>`))?.[1] ?? "";
    for (const [, tag] of sitemapEntry.matchAll(/<xhtml:link\b([^>]+)>/g)) {
      const language = /hreflang="([^"]+)"/.exec(tag)?.[1];
      const alternate = /href="([^"]+)"/.exec(tag)?.[1];
      if (
        language && alternate &&
        ![...doc.querySelectorAll('link[rel="alternate"][hreflang]')].some((link) =>
          link.getAttribute("hreflang") === language && link.getAttribute("href") === alternate
        )
      ) fail(path, `missing hreflang ${language} for ${alternate}`);
    }

    // A translated page lists itself and each translation, and each of them is a page of the site.
    for (const link of doc.querySelectorAll('link[rel="alternate"][hreflang]')) {
      const href = link.getAttribute("href") ?? "";
      if (!sameOrigin(href) || !(await exists(new URL(href).pathname))) fail(path, `hreflang ${href} missing`);
    }
  }

  return { failures, pages: titles.size };
}

// For the checks' own tests: `deno run -A seo.ts <built site> <SITE>`.
if (import.meta.main) {
  const [root, site, allowed] = Deno.args;
  const { failures, pages } = await checkSeo(root, site, allowed ? JSON.parse(allowed) : {});
  if (failures.length) {
    console.error(failures.join("\n"));
    Deno.exit(1);
  }
  console.log(`seo: ${pages} indexable pages, no failures`);
}
