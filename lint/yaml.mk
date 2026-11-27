# From github.com/xoadev/xoa-base (lint/yaml.mk): change it here. `make yaml-lint` checks the repository's YAML,
# YAML_FILES (default: the tracked *.yml and *.yaml), with prettier's layout (lint/prettier.mk) and yamllint's rules
# (lint/yamllint.yml), warnings as errors; `make yaml-format` applies the layout. yamllint comes with the machine
# (lint/require.mk).
include $(dir $(lastword $(MAKEFILE_LIST)))prettier.mk
include $(dir $(lastword $(MAKEFILE_LIST)))require.mk
YAML_FILES ?= $(shell git ls-files '*.yml' '*.yaml')

.PHONY: yaml-lint yaml-format
yaml-lint: ## The YAML's layout and yamllint's rules
	$(call xoa-require,yamllint,1.35.0,https://yamllint.readthedocs.io/en/stable/quickstart.html)
	@$(PRETTIER) --check $(YAML_FILES)
	@yamllint --strict --config-file $(XOA_LINT)yamllint.yml $(YAML_FILES)

yaml-format: ## Apply the YAML's layout
	@$(PRETTIER_WRITE) --write $(YAML_FILES)
