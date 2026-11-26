# From github.com/xoadev/xoa-base (lint/typos.mk): change it here. `make typos-lint`: typos over the repository, with
# its _typos.toml if it has one. typos knows English only: a repository whose documentation is in Spanish excludes it
# there, with that reason. typos comes with the machine (lint/require.mk).
include $(dir $(lastword $(MAKEFILE_LIST)))require.mk

.PHONY: typos-lint
typos-lint: ## typos over the code and the English prose
	$(call xoa-require,typos,1.30.0,https://github.com/crate-ci/typos#install)
	@typos
