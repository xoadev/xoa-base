# From github.com/xoadev/xoa-base (lint/actions.mk): change it here. `make actions-lint`: actionlint over
# .github/workflows, shellchecking their run: blocks when shellcheck is there too. A project's own runner labels go in
# its .github/actionlint.yaml. actionlint comes with the machine (lint/require.mk).
include $(dir $(lastword $(MAKEFILE_LIST)))require.mk

.PHONY: actions-lint
actions-lint: ## actionlint over the workflows
	$(call xoa-require,actionlint,1.7.0,https://github.com/rhysd/actionlint#install)
	@actionlint
