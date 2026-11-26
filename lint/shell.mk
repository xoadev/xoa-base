# From github.com/xoadev/xoa-base (lint/shell.mk): change it here. `make shell-lint`: shellcheck over the repository's
# shell scripts, SHELL_FILES (default: the tracked *.sh), with its version pinned by sha256.
include $(dir $(lastword $(MAKEFILE_LIST)))fetch.mk
SHELL_FILES ?= $(shell git ls-files '*.sh')
SHELLCHECK_VERSION := 0.11.0
SHELLCHECK := $(XOA_TOOLS)/shellcheck-$(SHELLCHECK_VERSION)
ifeq ($(XOA_ARCH),aarch64)
SHELLCHECK_SHA256 := 12b331c1d2db6b9eb13cfca64306b1b157a86eb69db83023e261eaa7e7c14588
else ifeq ($(XOA_ARCH),x86_64)
SHELLCHECK_SHA256 := 8c3be12b05d5c177a04c29e3c78ce89ac86f1595681cab149b65b97c4e227198
endif

.PHONY: shell-lint
shell-lint: $(SHELLCHECK) ## shellcheck over the shell scripts
	@$(SHELLCHECK) $(SHELL_FILES)

$(SHELLCHECK):
	$(call xoa-fetch,https://github.com/koalaman/shellcheck/releases/download/v$(SHELLCHECK_VERSION)/shellcheck-v$(SHELLCHECK_VERSION).linux.$(XOA_ARCH).tar.xz,$(SHELLCHECK_SHA256))
	@tar -xJOf $@.download shellcheck-v$(SHELLCHECK_VERSION)/shellcheck > $@ && chmod 0755 $@ && rm $@.download
