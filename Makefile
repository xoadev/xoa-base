# xoa-base — task runner. `make check` is what CI runs.
.DEFAULT_GOAL := help
# shellcheck and actionlint, fetched into BIN and checked against their sha256: the same version here and in CI.
BIN := .tmp/bin
SHELLCHECK_VERSION := 0.11.0
ACTIONLINT_VERSION := 1.7.12
ifeq ($(shell uname -m),aarch64)
SHELLCHECK_ARCH := aarch64
ACTIONLINT_ARCH := arm64
SHELLCHECK_SHA256 := 12b331c1d2db6b9eb13cfca64306b1b157a86eb69db83023e261eaa7e7c14588
ACTIONLINT_SHA256 := 325e971b6ba9bfa504672e29be93c24981eeb1c07576d730e9f7c8805afff0c6
else
SHELLCHECK_ARCH := x86_64
ACTIONLINT_ARCH := amd64
SHELLCHECK_SHA256 := 8c3be12b05d5c177a04c29e3c78ce89ac86f1595681cab149b65b97c4e227198
ACTIONLINT_SHA256 := 8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8
endif

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
# Writes to its volume under the deployment's restrictions and reads it back.
IMAGE_CHECK = test "$$($$IMAGE_RUN "$$IMAGE" sh -c 'echo ok > /data/probe && busybox cat /data/probe')" = ok
include container/image.mk

.PHONY: check lint test format test-fetch test-web test-rejections test-image-policy test-image help

check: lint test ## Everything CI runs but the image check, which needs Docker
	@echo "check: OK"

lint: $(BIN)/shellcheck $(BIN)/actionlint ## The Markdown's layout, the checkers' sources, the shell scripts and the workflows
	@deno run --quiet --allow-read --allow-env --allow-sys npm:prettier@3.9.6 --check --prose-wrap always \
	  --print-width 100 '**/*.md'
	@deno fmt --check test/*.ts
	@deno lint test/*.ts
	@$(BIN)/shellcheck container/tools/image.sh
	@$(BIN)/actionlint -shellcheck $(BIN)/shellcheck

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
test-fetch: ## A scratch project fetches container/ with the README's snippet, at XOA_BASE_TEST, and runs its policy
	@rm -rf build/fetch && mkdir -p build/fetch && cp test/image/Dockerfile build/fetch/
	@printf 'IMAGE_DOCKERFILE := Dockerfile\n' > build/fetch/Makefile
	@awk '/<!-- fetch -->/ { on = 1; next } on && /^```make/ { inside = 1; next } inside && /^```/ { exit } inside' README.md \
	  | sed 's/<sha>/$(XOA_BASE_TEST)/' >> build/fetch/Makefile
	@printf 'policy:\n\t@$$(IMAGE_SH) lint $$(IMAGE_DOCKERFILE)\n' >> build/fetch/Makefile
	@$(MAKE) --no-print-directory -C build/fetch policy
	@test -f build/fetch/.xoa-base/$(XOA_BASE_TEST)/.fetched && echo "fetch: OK"

# $(call fetch,url,sha256): downloads url to $@.download and refuses it unless it matches sha256.
define fetch
	@mkdir -p $(BIN)
	@curl -fsSL --proto '=https' --retry 3 -o $@.download '$(1)'
	@echo '$(2)  $@.download' | sha256sum -c --quiet - || { rm -f $@.download; exit 1; }
endef

$(BIN)/shellcheck:
	$(call fetch,https://github.com/koalaman/shellcheck/releases/download/v$(SHELLCHECK_VERSION)/shellcheck-v$(SHELLCHECK_VERSION).linux.$(SHELLCHECK_ARCH).tar.xz,$(SHELLCHECK_SHA256))
	@tar -xJf $@.download -C $(BIN) --strip-components=1 shellcheck-v$(SHELLCHECK_VERSION)/shellcheck && rm $@.download

$(BIN)/actionlint:
	$(call fetch,https://github.com/rhysd/actionlint/releases/download/v$(ACTIONLINT_VERSION)/actionlint_$(ACTIONLINT_VERSION)_linux_$(ACTIONLINT_ARCH).tar.gz,$(ACTIONLINT_SHA256))
	@tar -xzf $@.download -C $(BIN) actionlint && rm $@.download
