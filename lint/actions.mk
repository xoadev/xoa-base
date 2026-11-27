# From github.com/xoadev/xoa-base (lint/actions.mk): change it here. `make actions-lint`: actionlint over
# .github/workflows, shellchecking their run: blocks when shellcheck is there too, and zizmor's security audits over
# the workflows and actions; with GH_TOKEN set, zizmor also runs its online audits (impostor commits, known vulnerable
# actions). A project's own runner labels go in its .github/actionlint.yaml, and an audit it turns off, with its
# reason, in its .github/zizmor.yml. Both tools come with the machine (lint/require.mk).
include $(dir $(lastword $(MAKEFILE_LIST)))require.mk

.PHONY: actions-lint
actions-lint: ## actionlint and zizmor over the workflows and actions
	$(call xoa-require,actionlint,1.7.0,https://github.com/rhysd/actionlint#install)
	$(call xoa-require,zizmor,1.30.0,https://docs.zizmor.sh/installation/)
	@actionlint
	@zizmor --quiet .
