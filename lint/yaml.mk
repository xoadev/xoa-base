# From github.com/xoadev/xoa-base (lint/yaml.mk): change it here. `make yaml-lint` checks the repository's YAML,
# YAML_FILES (default: all of it but what .gitignore leaves out), with prettier, whose version is pinned here and runs
# through Deno; `make yaml-format` applies it.
PRETTIER := deno run --quiet --allow-read --allow-env --allow-sys npm:prettier@3.9.6
PRETTIER_WRITE := deno run --quiet --allow-read --allow-write --allow-env --allow-sys npm:prettier@3.9.6
YAML_FILES ?= '**/*.{yml,yaml}'

.PHONY: yaml-lint yaml-format
yaml-lint: ## The YAML's layout
	@$(PRETTIER) --check $(YAML_FILES)

yaml-format: ## Apply the YAML's layout
	@$(PRETTIER_WRITE) --write $(YAML_FILES)
