# From github.com/xoadev/xoa-base (lint/markdown.mk): change it here. `make md-lint` checks the repository's Markdown,
# MD_FILES (default: all of it but what .gitignore leaves out), with prettier, wrapped at 100 columns so a diff shows
# the sentence that changed; `make md-format` applies it. Prettier's version is pinned here and runs through Deno.
PRETTIER := deno run --quiet --allow-read --allow-env --allow-sys npm:prettier@3.9.6
PRETTIER_WRITE := deno run --quiet --allow-read --allow-write --allow-env --allow-sys npm:prettier@3.9.6
MD_FILES ?= '**/*.md'
MD_OPTIONS := --prose-wrap always --print-width 100

.PHONY: md-lint md-format
md-lint: ## The Markdown's layout
	@$(PRETTIER) --check $(MD_OPTIONS) $(MD_FILES)

md-format: ## Apply the Markdown's layout
	@$(PRETTIER_WRITE) --write $(MD_OPTIONS) $(MD_FILES)
