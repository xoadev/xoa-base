# From github.com/xoadev/xoa-base (website/web.mk), which a project's Makefile fetches by commit into
# .xoa-base/<commit>/ and includes: change it there. CI's web.yml runs `make web-browser` and `make web-check`.
#
# What the project sets before the include:
#   WEB  the site's folder (default: web), the one whose deno.json imports xoa-web/ (README.md)
WEB ?= web

# Deno comes with the machine (lint/require.mk).
include $(dir $(lastword $(MAKEFILE_LIST)))../lint/require.mk

.PHONY: web web-check web-browser web-serve

web: ## The site, built into its _site folder; the build runs the plugin's checks
	$(call xoa-require,deno,2.0.0,https://docs.deno.com/runtime/getting_started/installation/)
	@cd $(WEB) && deno task build

web-check: web ## The site's sources (deno fmt and lint), its build with its checks, and its accessibility
	@cd $(WEB) && deno fmt --check && deno lint && deno task a11y

web-browser: ## The headless Chromium the accessibility check drives (once per machine)
	@cd $(WEB) && deno task browser

web-serve: ## The site at http://localhost:3000, rebuilt on every change
	@cd $(WEB) && deno task serve
