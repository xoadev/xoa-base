# From github.com/xoadev/xoa-base (lint/markdown.mk): change it here. `make md-lint` checks the repository's Markdown,
# MD_FILES (default: all of it but what .gitignore leaves out): its layout with prettier, wrapped at 100 columns so a
# diff shows the sentence that changed, and markdownlint's rules (lint/markdownlint.jsonc); `make md-format` applies
# the layout. Both run through Deno at lint/deno.jsonc's versions.
include $(dir $(lastword $(MAKEFILE_LIST)))prettier.mk
MD_FILES ?= '**/*.md'
MD_OPTIONS := --prose-wrap always --print-width 100
MARKDOWNLINT := $(XOA_DENO_RUN) \
  $(shell sed -n 's/.*"\(npm:markdownlint-cli2@[^"]*\)".*/\1/p' $(XOA_LINT)deno.jsonc)

.PHONY: md-lint md-format
md-lint: ## The Markdown's layout and markdownlint's rules
	@$(PRETTIER) --check $(MD_OPTIONS) $(MD_FILES)
	@$(MARKDOWNLINT) --config $(XOA_LINT)markdownlint.jsonc $(MD_FILES) '#**/node_modules' '#.xoa-base' '#build'

md-format: ## Apply the Markdown's layout
	@$(PRETTIER_WRITE) --write $(MD_OPTIONS) $(MD_FILES)
