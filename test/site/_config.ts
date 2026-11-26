import lume from "lume/mod.ts";
import multilanguage from "lume/plugins/multilanguage.ts";
import xoa from "xoa-web/mod.ts";
import { SITE } from "./_data.ts";
import { DEFAULT_LANGUAGE, LANGUAGES } from "./_languages.ts";

// The site's address, for the absolute URLs of the sitemap and the pages' canonical and social links.
const site = lume({ location: new URL(SITE) });

// A translated page is one page per language from one template: the default language stays at the root, the others
// live under /<code>/. With one language it changes nothing.
site.use(multilanguage({ languages: Object.keys(LANGUAGES), defaultLanguage: DEFAULT_LANGUAGE }));

// XOA's checks of what each build makes, and the `json` filter of the pages' JSON-LD.
site.use(xoa());

site.add("styles.css");
site.add("assets");
for (const file of ["favicon.svg", "favicon.ico", "favicon-96.png", "apple-touch-icon.png", "site.webmanifest"]) {
  site.add(file);
}

export default site;
