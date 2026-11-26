# From github.com/xoadev/xoa-base (website/web.mk), which a project's Makefile fetches by commit into
# .xoa-base/<commit>/ and includes, with WEB set to the site's folder: change it here. CI runs `make web-check`;
# `make web-serve` is the local preview.
#
# The site builds with its own deno.json (its `build` and `serve` tasks, its dependencies). The checks run from the
# fetched folder with this repository's deno.json and frozen deno.lock, in the site's folder, so their versions are
# this commit's and the site never carries them.
WEB ?= web
XOA_WEB := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))web)
XOA_DENO := deno run --config $(XOA_WEB)/deno.json

.PHONY: web web-lint web-seo web-a11y web-check web-serve web-browser

# The site imports the content reader as xoa-web/_content.ts, which its deno.json maps to .xoa-base/current/: the
# link follows XOA_BASE, so the commit is written once, in the Makefile.
web: ## The site, built into $(WEB)/_site
	@[ -z "$(XOA_BASE)" ] || ln -sfn $(XOA_BASE) .xoa-base/current
	@# Lume reports a page it could not render and still ends well, leaving the page empty: a failure here.
	@cd $(WEB) && out=$$(deno task build 2>&1); status=$$?; echo "$$out"; \
	if [ $$status -ne 0 ] || echo "$$out" | grep -q 'ERROR'; then echo "web: a page failed to build" >&2; exit 1; fi

web-lint: web ## deno fmt and lint over the sources, html-validate over the pages, Stylelint over the stylesheet, no HTML in Markdown
	@cd $(WEB) && deno fmt --check && deno lint
	@cd $(WEB) && $(XOA_DENO) --allow-read --allow-env --allow-sys npm:html-validate@11.16.1 \
	  --config $(XOA_WEB)/.htmlvalidate.json '_site/**/*.html'
	@cd $(WEB) && $(XOA_DENO) --allow-read --allow-env --allow-sys npm:stylelint@17.16.0 \
	  --config $(XOA_WEB)/.stylelintrc.json styles.css
	@cd $(WEB) && $(XOA_DENO) --allow-read --allow-env --allow-sys npm:markdownlint-cli2@0.24.0 \
	  --config $(XOA_WEB)/.markdownlint-cli2.jsonc

web-seo: web ## Sitemap, robots.txt, icons, unique titles and descriptions, canonical, hreflang, social image, JSON-LD, broken links
	@cd $(WEB) && site=$$(deno eval 'console.log((await import("./_data.ts")).SITE)') && \
	XOA_SITE=$$site $(XOA_DENO) --allow-read --allow-env=XOA_SITE --allow-net=cdn.jsdelivr.net $(XOA_WEB)/_seo.ts

web-a11y: web ## axe-core (WCAG 2.2 AA), sideways scroll and console errors on every page, at 1280 and 360 px, light and dark
	@cd $(WEB) && $(XOA_DENO) -A $(XOA_WEB)/_a11y.ts

web-check: web-lint web-seo web-a11y ## Everything CI checks of the site

web-serve: ## The site at http://localhost:3000, rebuilt on every change
	@[ -z "$(XOA_BASE)" ] || ln -sfn $(XOA_BASE) .xoa-base/current
	@cd $(WEB) && deno task serve

web-browser: ## The headless Chromium the accessibility check drives, into Playwright's cache (once per machine)
	@$(XOA_DENO) -A npm:playwright@1.64.1 install chromium-headless-shell
