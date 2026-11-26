# xoa-base — task runner. CI runs `make check` across its jobs (check.yml), plus test-fetch and test-image.
.DEFAULT_GOAL := help
# The generic linters, as a project includes them; container/image.mk below brings hadolint.
include lint/markdown.mk lint/yaml.mk lint/shell.mk lint/actions.mk

# The website's checks are a Lume plugin and a script, which the test site imports as a project's site does: its
# build runs them, and its a11y task the accessibility check. A copy in build/ is what gets built and broken.
CHECKS_WEB := website
# $(call site-check,folder): what a project's web-check does, over a site's folder.
site-check = cd $(1) && deno fmt --check && deno lint && deno task build && deno task a11y

# The container image's checks run, with the targets a project gets, over the test image of test/image. Those of
# test/image/rejected each break one rule, and the policy must refuse every one.
IMAGE := xoa-base-test:local
IMAGE_DOCKERFILE := test/image/Dockerfile
IMAGE_CONTEXT := test/image
# Writes to its volume under the deployment's restrictions and reads it back.
IMAGE_CHECK = test "$$($$IMAGE_RUN "$$IMAGE" sh -c 'echo ok > /data/probe && busybox cat /data/probe')" = ok
include container/image.mk

.PHONY: check lint test format web-browser test-content test-fetch test-web test-rejections test-image-policy test-image help

check: lint test ## Everything CI runs but the image check, which needs Docker
	@echo "check: OK"

lint: md-lint yaml-lint shell-lint actions-lint ## The Markdown, YAML, shell scripts and workflows, and the checks' sources
	@deno fmt --check test/*.ts
	@deno lint test/*.ts
	@cd $(CHECKS_WEB) && deno fmt --check && deno lint

format: md-format yaml-format ## Format the Markdown, the YAML and the checks' sources
	@deno fmt test/*.ts
	@cd $(CHECKS_WEB) && deno fmt

test: test-content test-web test-image-policy ## The website's checks over the test site, and the image policy over the test Dockerfiles

# The test site is monolingual; the bilingual one is the same with test/site-en.yml added and its home translated.
web-browser: ## The headless Chromium the accessibility check drives (once per machine), as a project's target
	@cd test/site && deno task browser

test-content: ## The tests of content.ts (pages, sections, items, collections, languages) and of the modules' pinned versions
	@cd $(CHECKS_WEB) && deno test --allow-read --allow-write content_test.ts deps_test.ts

test-web: ## The website's checks over the test site, monolingual and bilingual, and what must fail
	@rm -rf build && mkdir build && cp -r test/site build/site
	@$(call site-check,build/site)
	@cp -r build/site build/bilingual && rm -rf build/bilingual/_site && cp test/site-en.yml build/bilingual/_texts/en.yml
	@printf '%s\n' 'export const DEFAULT_LANGUAGE = "es";' 'export const LANGUAGES = { es: { name: "Español", locale: "es_ES" }, en: { name: "English", locale: "en_US" } };' > build/bilingual/_languages.ts
	@cd build/bilingual && deno fmt _languages.ts
	@sed -i 's/^id: index$$/id: index\nlang: [es, en]/' build/bilingual/index.vto
	@$(call site-check,build/bilingual)
	@$(MAKE) --no-print-directory test-rejections

test-rejections: ## Broken output must fail the installed SEO and policy checks (after make test-web)
	@deno run --allow-read --allow-write=build --allow-run test/rejections.ts

test-image-policy: ## The image policy passes the test image and test/image/accepted, and refuses each of test/image/rejected
	@$(IMAGE_SH) lint $(IMAGE_DOCKERFILE) test/image/accepted/*.Dockerfile
	@for dockerfile in test/image/rejected/*.Dockerfile; do \
	  if $(IMAGE_SH) lint "$$dockerfile" 2>/dev/null; then echo "image policy: $$dockerfile should fail" >&2; exit 1; fi; \
	done; echo "image policy: OK"

# The same image with a server that ignores SIGTERM must be refused, and for that reason.
test-image: ## The image's lint and check over the test image, for both architectures. Needs Docker
	@$(MAKE) --no-print-directory image-lint image-check PLATFORMS=linux/amd64,linux/arm64
	@$(MAKE) --no-print-directory image-oci OCI=build/image.tar PLATFORMS=linux/amd64,linux/arm64
	@tar -xOf build/image.tar index.json | grep -q '"mediaType"' || { echo "image oci: no OCI index in the archive" >&2; exit 1; }
	@if out=$$($(MAKE) --no-print-directory image-check IMAGE_DOCKERFILE=test/image/ignores-sigterm.Dockerfile 2>&1); then \
	  echo "$$out"; echo "image check: a server that ignores SIGTERM should fail" >&2; exit 1; \
	elif ! echo "$$out" | grep -q 'it ignores SIGTERM'; then echo "$$out"; echo "image check: failed for another reason" >&2; exit 1; fi
	@echo "image check: OK"

help:
	@grep -hE '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-17s %s\n", $$1, $$2}'

# The snippet is the README's, as a project copies it, so what is documented is what is tested.
XOA_BASE_TEST ?= $(shell git rev-parse HEAD)
test-fetch: ## A scratch project takes xoa-base at XOA_BASE_TEST as the README says: image policy fetched, site's plugin imported
	@rm -rf build/fetch && mkdir -p build/fetch && cp test/image/Dockerfile build/fetch/ && cp -r test/site build/fetch/web
	@sed -i -e 's#"xoa-web/": "../../website/"#"xoa-web/": "https://raw.githubusercontent.com/xoadev/xoa-base/$(XOA_BASE_TEST)/website/"#' \
	  -e 's#"frozen": true#"frozen": false#' build/fetch/web/deno.json && rm build/fetch/web/deno.lock
	@git init -q build/fetch && mkdir -p build/fetch/.github/workflows && printf 'jobs:\n  image:\n    uses: xoadev/xoa-base/.github/workflows/image.yml@%s # vX.Y.Z\n' \
	  $(XOA_BASE_TEST) > build/fetch/.github/workflows/image.yml
	@printf 'IMAGE_DOCKERFILE := Dockerfile\n' > build/fetch/Makefile
	@awk '/<!-- fetch -->/ { on = 1; next } on && /^```make/ { inside = 1; next } inside && /^```/ { exit } inside' README.md \
	  >> build/fetch/Makefile
	@printf 'policy:\n\t@$$(IMAGE_SH) lint $$(IMAGE_DOCKERFILE)\n' >> build/fetch/Makefile
	@$(MAKE) --no-print-directory -C build/fetch policy
	@cd build/fetch/web && deno task build
	@test -f build/fetch/.xoa-base/$(XOA_BASE_TEST)/.fetched
	@# Two workflows calling xoa-base at two commits: make refuses to pick one.
	@printf 'jobs:\n  web:\n    uses: xoadev/xoa-base/.github/workflows/web.yml@%s\n' $$(printf '0%.0s' $$(seq 40)) \
	  > build/fetch/.github/workflows/web.yml
	@if out=$$($(MAKE) --no-print-directory -C build/fetch policy 2>&1); then echo "fetch: two commits accepted" >&2; exit 1; \
	elif ! echo "$$out" | grep -q 'one commit, in every uses: line'; then echo "$$out" >&2; exit 1; fi
	@# No workflow calls xoa-base yet: make says to add one first.
	@mv build/fetch/.github/workflows build/fetch/.github/held
	@if out=$$($(MAKE) --no-print-directory -C build/fetch policy 2>&1); then echo "fetch: no workflow accepted" >&2; exit 1; \
	elif ! echo "$$out" | grep -q 'no workflow calls xoa-base yet'; then echo "$$out" >&2; exit 1; fi
	@mv build/fetch/.github/held build/fetch/.github/workflows
	@# The site imports xoa-base at a commit the workflows no longer call alone: its build says where to move it.
	@if out=$$(cd build/fetch/web && deno task build 2>&1); then echo "fetch: a site behind the workflows built" >&2; exit 1; \
	elif ! echo "$$out" | grep -q 'move xoa-web/'; then echo "$$out" >&2; exit 1; fi
	@echo "fetch: OK"
