# From github.com/xoadev/xoa-base (lint/yaml.mk): change it here. `make yaml-lint` checks the repository's YAML,
# YAML_FILES (default: all of it but what .gitignore leaves out), with prettier (lint/prettier.mk); `make yaml-format`
# applies it.
include $(dir $(lastword $(MAKEFILE_LIST)))prettier.mk
YAML_FILES ?= '**/*.{yml,yaml}'

.PHONY: yaml-lint yaml-format
yaml-lint: ## The YAML's layout
	@$(PRETTIER) --check $(YAML_FILES)

yaml-format: ## Apply the YAML's layout
	@$(PRETTIER_WRITE) --write $(YAML_FILES)
