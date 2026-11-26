// From github.com/xoadev/xoa-base (website/a11y.ts): change it there.
// The accessibility check of the built site (the site's `deno task a11y`, after its build): every page of the sitemap,
// and the 404, at a desktop and a phone width, in light and dark mode. A page fails on any axe-core violation of WCAG
// 2.2 AA or its best practices, on a horizontal scroll, and on a console error, which is where a Content Security
// Policy violation shows. mod.ts exports it, so a site's build already locks its dependencies.
import { serveDir } from "jsr:@std/http@1.1.0/file-server";
import { chromium } from "npm:playwright@1.64.1";
import { AxeBuilder } from "npm:@axe-core/playwright@4.14.0";

// The headless Chromium of this Playwright, downloaded once per machine (the site's `deno task browser`).
export async function installBrowser(): Promise<void> {
  const install = new Deno.Command(Deno.execPath(), {
    args: ["run", "-A", "npm:playwright@1.64.1", "install", "chromium-headless-shell"],
  });
  Deno.exit((await install.spawn().status).code);
}

const WIDTHS = [1280, 360];
const SCHEMES = ["light", "dark"] as const;
const TAGS = ["wcag2a", "wcag2aa", "wcag21a", "wcag21aa", "wcag22aa", "best-practice"];

// Every page of the built site, `root`, in a browser; it exits with the failures, so a task can run it as is.
export async function a11y(root = "_site"): Promise<void> {
  const server = Deno.serve(
    { port: 0, onListen: () => {} },
    (request) => serveDir(request, { fsRoot: root, quiet: true }),
  );
  const origin = `http://localhost:${server.addr.port}`;

  const sitemap = await Deno.readTextFile(`${root}/sitemap.xml`);
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
}
