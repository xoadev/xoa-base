# Copied from github.com/xoadev/xoa-base (website/web.mk): change it there, not in a project's copy.
# The website's targets, included from the project's Makefile (`include web.mk`) with WEB set to the site's folder.
# CI runs `make web-check`; `make web-serve` is the local preview.
WEB ?= web

.PHONY: web web-lint web-content web-seo web-a11y web-check web-serve web-browser

web: ## The site, built into $(WEB)/_site
	@# Lume reports a page it could not render and still ends well, leaving the page empty: a failure here.
	@cd $(WEB) && out=$$(deno task build 2>&1); status=$$?; echo "$$out"; \
	if [ $$status -ne 0 ] || echo "$$out" | grep -q 'ERROR'; then echo "web: a page failed to build" >&2; exit 1; fi

web-lint: web ## deno fmt and lint over the sources, html-validate over the pages, Stylelint over the stylesheet, no HTML in Markdown
	@cd $(WEB) && deno fmt --check && deno lint && deno task html && deno task css && deno task md

web-content: ## The tests of _content.ts: pages cut into sections and items, data by id, collections, languages by id
	@cd $(WEB) && deno task content

web-seo: web ## Sitemap, robots.txt, icons, unique titles and descriptions, canonical, hreflang, social image, JSON-LD, broken links
	@cd $(WEB) && deno task seo

web-a11y: web ## axe-core (WCAG 2.2 AA), sideways scroll and console errors on every page, at 1280 and 360 px, light and dark
	@cd $(WEB) && deno task a11y

web-check: web-lint web-content web-seo web-a11y ## Everything CI checks of the site

web-serve: ## The site at http://localhost:3000, rebuilt on every change
	@cd $(WEB) && deno task serve

web-browser: ## The headless Chromium the accessibility check drives, into Playwright's cache (once per machine)
	@cd $(WEB) && deno task browser
