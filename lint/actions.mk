# From github.com/xoadev/xoa-base (lint/actions.mk): change it here. `make actions-lint`: actionlint over
# .github/workflows, with its version pinned by sha256; with lint/shell.mk included before it, it shellchecks the run:
# blocks with that same shellcheck. A project's own runner labels go in its .github/actionlint.yaml.
include $(dir $(lastword $(MAKEFILE_LIST)))fetch.mk
ACTIONLINT_VERSION := 1.7.12
ACTIONLINT := $(XOA_TOOLS)/actionlint-$(ACTIONLINT_VERSION)
ifeq ($(XOA_ARCH),aarch64)
ACTIONLINT_ARCH := arm64
ACTIONLINT_SHA256 := 325e971b6ba9bfa504672e29be93c24981eeb1c07576d730e9f7c8805afff0c6
else ifeq ($(XOA_ARCH),x86_64)
ACTIONLINT_ARCH := amd64
ACTIONLINT_SHA256 := 8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8
endif

.PHONY: actions-lint
actions-lint: $(ACTIONLINT) $(SHELLCHECK) ## actionlint over the workflows
	@$(ACTIONLINT) $(if $(SHELLCHECK),-shellcheck $(SHELLCHECK))

$(ACTIONLINT):
	$(call xoa-fetch,https://github.com/rhysd/actionlint/releases/download/v$(ACTIONLINT_VERSION)/actionlint_$(ACTIONLINT_VERSION)_linux_$(ACTIONLINT_ARCH).tar.gz,$(ACTIONLINT_SHA256))
	@tar -xzOf $@.download actionlint > $@ && chmod 0755 $@ && rm $@.download
