# From github.com/xoadev/xoa-base (lint/yaml.mk): change it here. `make yaml-lint` checks the repository's YAML,
# YAML_FILES (default: all of it but what .gitignore leaves out), with prettier, which runs through Deno; `make yaml-format` applies it.
# Prettier's version is lint/deno.jsonc's, which Dependabot moves.
PRETTIER_PACKAGE := $(shell sed -n 's/.*"\(npm:prettier@[^"]*\)".*/\1/p' $(dir $(lastword $(MAKEFILE_LIST)))deno.jsonc)
PRETTIER := deno run --quiet --allow-read --allow-env --allow-sys $(PRETTIER_PACKAGE)
PRETTIER_WRITE := deno run --quiet --allow-read --allow-write --allow-env --allow-sys $(PRETTIER_PACKAGE)
YAML_FILES ?= '**/*.{yml,yaml}'

.PHONY: yaml-lint yaml-format
yaml-lint: ## The YAML's layout
	@$(PRETTIER) --check $(YAML_FILES)

yaml-format: ## Apply the YAML's layout
	@$(PRETTIER_WRITE) --write $(YAML_FILES)
