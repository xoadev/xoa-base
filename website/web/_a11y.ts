// Copied from github.com/xoadev/xoa-base (website/web/_a11y.ts): change it there, not in a project's copy.
// The accessibility check of the built site (`deno task a11y`, after `deno task build`): every page of the sitemap,
// and the 404, at a desktop and a phone width, in light and dark mode. A page fails on any axe-core violation of WCAG 2.2 AA or its best
// practices, on a horizontal scroll, and on a console error, which is where a Content Security Policy violation shows.
import { serveDir } from "@std/http/file-server";
import { chromium } from "playwright";
import { AxeBuilder } from "@axe-core/playwright";

const WIDTHS = [1280, 360];
const SCHEMES = ["light", "dark"] as const;
const TAGS = ["wcag2a", "wcag2aa", "wcag21a", "wcag21aa", "wcag22aa", "best-practice"];

const server = Deno.serve(
  { port: 0, onListen: () => {} },
  (request) => serveDir(request, { fsRoot: "_site", quiet: true }),
);
const origin = `http://localhost:${server.addr.port}`;

const sitemap = await Deno.readTextFile("_site/sitemap.xml");
const paths = [...sitemap.matchAll(/<loc>([^<]+)<\/loc>/g)].map(([, loc]) => new URL(loc).pathname);
paths.push("/404.html");

const failures: string[] = [];
const browser = await chromium.launch();
try {
  for (const width of WIDTHS) {
    for (const colorScheme of SCHEMES) {
      const context = await browser.newContext({ viewport: { width, height: 800 }, colorScheme });
      const page = await context.newPage();
      const errors: string[] = [];
      page.on("console", (message) => message.type() === "error" && errors.push(message.text()));
      page.on("pageerror", (error) => errors.push(error.message));
      for (const path of paths) {
        errors.length = 0;
        await page.goto(origin + path, { waitUntil: "networkidle" });
        const where = `${path} at ${width}px, ${colorScheme}`;
        const { violations } = await new AxeBuilder({ page }).withTags(TAGS).analyze();
        for (const { id, help, nodes } of violations) {
          failures.push(`${where}: ${id} (${help}) in ${nodes.map((node) => node.target.join(" ")).join(", ")}`);
        }
        const overflow = await page.evaluate(() => document.documentElement.scrollWidth - innerWidth);
        if (overflow > 0) failures.push(`${where}: scrolls sideways by ${overflow}px`);
        for (const error of errors) failures.push(`${where}: console error: ${error}`);
      }
      await context.close();
    }
  }
} finally {
  await browser.close();
  await server.shutdown();
}

if (failures.length) {
  console.error(failures.join("\n"));
  Deno.exit(1);
}
console.log(`a11y: ${paths.length} pages at ${WIDTHS.join(" and ")}px, light and dark, no failures`);
