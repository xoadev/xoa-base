# From github.com/xoadev/xoa-base (lint/shell.mk): change it here. `make shell-lint`: shellcheck and shfmt over the
# repository's shell scripts, SHELL_FILES (default: the tracked *.sh); shfmt takes its indentation from the project's
# .editorconfig, and `make shell-format` applies it. Both come with the machine (lint/require.mk).
include $(dir $(lastword $(MAKEFILE_LIST)))require.mk
SHELL_FILES ?= $(shell git ls-files '*.sh')

.PHONY: shell-lint shell-format
shell-lint: ## shellcheck and shfmt over the shell scripts
	$(call xoa-require,shellcheck,0.9.0,apt install shellcheck or https://github.com/koalaman/shellcheck#installing)
	$(call xoa-require,shfmt,3.8.0,https://github.com/mvdan/sh#shfmt)
	@shellcheck $(SHELL_FILES)
	@shfmt --diff $(SHELL_FILES)

shell-format: ## Apply shfmt's layout to the shell scripts
	$(call xoa-require,shfmt,3.8.0,https://github.com/mvdan/sh#shfmt)
	@shfmt --write $(SHELL_FILES)
