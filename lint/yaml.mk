# From github.com/xoadev/xoa-base (lint/yaml.mk): change it here. `make yaml-lint` checks the repository's YAML,
# YAML_FILES (default: the tracked *.yml and *.yaml), with yamlfmt's layout (lint/yamlfmt.yml) and yamllint's rules
# (lint/yamllint.yml), warnings as errors; `make yaml-format` applies the layout. Both come with the machine
# (lint/require.mk).
include $(dir $(lastword $(MAKEFILE_LIST)))require.mk
XOA_LINT := $(dir $(lastword $(MAKEFILE_LIST)))
YAML_FILES ?= $(shell git ls-files '*.yml' '*.yaml')

.PHONY: yaml-lint yaml-format
yaml-lint: ## The YAML's layout and yamllint's rules
	$(call xoa-require,yamlfmt,0.21.0,https://github.com/google/yamlfmt#installation)
	$(call xoa-require,yamllint,1.35.0,https://yamllint.readthedocs.io/en/stable/quickstart.html)
	@yamlfmt -conf $(XOA_LINT)yamlfmt.yml -lint $(YAML_FILES)
	@yamllint --strict --config-file $(XOA_LINT)yamllint.yml $(YAML_FILES)

yaml-format: ## Apply the YAML's layout
	$(call xoa-require,yamlfmt,0.21.0,https://github.com/google/yamlfmt#installation)
	@yamlfmt -conf $(XOA_LINT)yamlfmt.yml $(YAML_FILES)
