# From github.com/xoadev/xoa-base (lint/markdown.mk): change it here. `make md-lint` checks the repository's Markdown,
# MD_FILES (default: the tracked *.md), with rumdl: markdownlint's rules, and the prose wrapped at 100 columns so a
# diff shows the sentence that changed (lint/rumdl.toml); `make md-format` applies its fixes and the wrapping. A rule
# the project turns off for some files goes in MD_OPTIONS, as rumdl's inline settings, with its reason above it:
#   MD_OPTIONS := --config 'per-file-ignores = { "web/_content/**" = ["MD025"] }'
# rumdl comes with the machine (lint/require.mk).
include $(dir $(lastword $(MAKEFILE_LIST)))require.mk
XOA_LINT := $(dir $(lastword $(MAKEFILE_LIST)))
MD_FILES ?= $(shell git ls-files '*.md')
MD_OPTIONS ?=
RUMDL = rumdl $(1) --config $(XOA_LINT)rumdl.toml $(MD_OPTIONS)

.PHONY: md-lint md-format
md-lint: ## The Markdown's layout and markdownlint's rules, with rumdl
	$(call xoa-require,rumdl,0.3.5,https://github.com/rvben/rumdl#installation)
	@$(call RUMDL,check) $(MD_FILES)

md-format: ## Apply rumdl's fixes and the Markdown's wrapping
	$(call xoa-require,rumdl,0.3.5,https://github.com/rvben/rumdl#installation)
	@$(call RUMDL,fmt) $(MD_FILES)
