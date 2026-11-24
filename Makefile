# xoa-base — task runner. `make check` is what CI runs.
.DEFAULT_GOAL := help
# The shared head of AGENTS.md, above its <!-- xoadev:end --> line, comes from AGENTS_URL.
AGENTS_URL := https://xoa.dev/_dev/OSS_AGENTS.md
AGENTS_SCRIPT := https://xoa.dev/_dev/agents.sh

# The website's checks run, with the targets a project gets, over a test site: test/site with website/web copied in,
# as a project has them.
CHECKS_WEB := website/web
WEB := build/site
include website/web.mk

# The container image's checks run, with the targets a project gets, over the test image of test/image. Those of
# test/image/rejected each break one rule, and the policy must refuse every one.
IMAGE := xoa-base-test:local
IMAGE_DOCKERFILE := test/image/Dockerfile
IMAGE_CONTEXT := test/image
IMAGE_SH := container/tools/image.sh
# Writes to its volume under the deployment's restrictions and reads it back.
IMAGE_CHECK = test "$$($$IMAGE_RUN "$$IMAGE" sh -c 'echo ok > /data/probe && cat /data/probe')" = ok
include container/image.mk

.PHONY: check lint test format test-web test-rejections test-image-policy test-image agents-sync agents-check help

check: lint test agents-check ## Everything CI runs but the image check, which needs Docker
	@echo "check: OK"

lint: ## The Markdown's layout and the checkers' sources
	@deno run --quiet --allow-read --allow-env --allow-sys npm:prettier@3.9.6 --check --prose-wrap always \
	  --print-width 100 '**/*.md'
	@deno fmt --check test/*.ts
	@deno lint test/*.ts

format: ## Format Markdown and checker sources
	@deno run --quiet --allow-read --allow-write --allow-env --allow-sys npm:prettier@3.9.6 --write --prose-wrap always --print-width 100 '**/*.md'
	@deno fmt test/*.ts
	@cd $(CHECKS_WEB) && deno fmt _seo.ts

test: test-web test-image-policy ## The website's checks over the test site, and the image policy over the test Dockerfiles

# The test site is monolingual; the bilingual one is the same with test/site-en.yml added and its home translated.
test-web: ## The website's checks over the test site, monolingual and bilingual, and what must fail
	@rm -rf build && mkdir build && cp -r test/site build/site && cp -r $(CHECKS_WEB)/. build/site/
	@$(MAKE) --no-print-directory web-check WEB=build/site
	@cp -r build/site build/bilingual && rm -rf build/bilingual/_site && cp test/site-en.yml build/bilingual/_texts/en.yml
	@printf '%s\n' 'export const DEFAULT_LANGUAGE = "es";' 'export const LANGUAGES = { es: { name: "Español", locale: "es_ES" }, en: { name: "English", locale: "en_US" } };' > build/bilingual/_languages.ts
	@cd build/bilingual && deno fmt _languages.ts
	@sed -i 's/^id: index$$/id: index\nlang: [es, en]/' build/bilingual/index.vto
	@$(MAKE) --no-print-directory web-check WEB=build/bilingual
	@$(MAKE) --no-print-directory test-rejections

test-rejections: ## Broken output must fail the installed SEO and policy checks (after make test-web)
	@deno run --allow-read --allow-write=build --allow-run test/rejections.ts

test-image-policy: ## The image policy passes the test image and refuses each Dockerfile of test/image/rejected
	@$(IMAGE_SH) lint $(IMAGE_DOCKERFILE)
	@for dockerfile in test/image/rejected/*.Dockerfile; do \
	  if $(IMAGE_SH) lint "$$dockerfile" 2>/dev/null; then echo "image policy: $$dockerfile should fail" >&2; exit 1; fi; \
	done; echo "image policy: OK"

# The same image with a server that ignores SIGTERM must be refused, and for that reason.
test-image: ## The image's lint and check over the test image, for both architectures. Needs Docker
	@$(MAKE) --no-print-directory image-lint image-check PLATFORMS=linux/amd64,linux/arm64
	@if out=$$($(MAKE) --no-print-directory image-check IMAGE_DOCKERFILE=test/image/ignores-sigterm.Dockerfile 2>&1); then \
	  echo "$$out"; echo "image check: a server that ignores SIGTERM should fail" >&2; exit 1; \
	elif ! echo "$$out" | grep -q 'it ignores SIGTERM'; then echo "$$out"; echo "image check: failed for another reason" >&2; exit 1; fi
	@echo "image check: OK"

agents-sync agents-check:
	@if s=$$(curl -fsS --max-time 20 '$(AGENTS_SCRIPT)'); then sh -c "$$s" agents $(@:agents-%=%) '$(AGENTS_URL)'; \
	else echo "warning: $(AGENTS_SCRIPT) unreachable, $@ not run" >&2; [ $@ = agents-check ]; fi

help:
	@grep -hE '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-17s %s\n", $$1, $$2}'
