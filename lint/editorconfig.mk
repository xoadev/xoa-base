# From github.com/xoadev/xoa-base (lint/editorconfig.mk): change it here. `make editorconfig-lint`: every tracked
# file follows the project's .editorconfig (indentation, line endings, final newline, trailing spaces), which the
# project writes. editorconfig-checker comes with the machine (lint/require.mk).
include $(dir $(lastword $(MAKEFILE_LIST)))require.mk

.PHONY: editorconfig-lint
editorconfig-lint: ## Every file follows the .editorconfig
	$(call xoa-require,editorconfig-checker,3.0.0,https://github.com/editorconfig-checker/editorconfig-checker#installation)
	@editorconfig-checker
