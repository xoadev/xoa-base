# From github.com/xoadev/xoa-base (lint/shell.mk): change it here. `make shell-lint`: shellcheck over the repository's
# shell scripts, SHELL_FILES (default: the tracked *.sh). shellcheck comes with the machine (lint/require.mk).
include $(dir $(lastword $(MAKEFILE_LIST)))require.mk
SHELL_FILES ?= $(shell git ls-files '*.sh')

.PHONY: shell-lint
shell-lint: ## shellcheck over the shell scripts
	$(call xoa-require,shellcheck,0.9.0,apt install shellcheck or https://github.com/koalaman/shellcheck#installing)
	@shellcheck $(SHELL_FILES)
