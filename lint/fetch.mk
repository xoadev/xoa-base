# From github.com/xoadev/xoa-base (lint/fetch.mk): change it here. The other .mk files include it.
#
# $(call xoa-fetch,url,sha256): downloads url to $@.download and refuses it unless it matches sha256. The tools land in
# XOA_TOOLS, inside the folder a project fetches xoa-base into, which it ignores.
ifndef xoa-fetch
XOA_TOOLS := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))../.tmp/bin)
XOA_ARCH := $(shell uname -m)
define xoa-fetch
	@test -n "$(2)" || { echo "xoa-base: no pinned $(notdir $@) for $(XOA_ARCH): add its sha256 to its .mk" >&2; exit 1; }
	@mkdir -p $(XOA_TOOLS)
	@curl -fsSL --proto '=https' --retry 3 -o $@.download '$(1)'
	@echo '$(2)  $@.download' | sha256sum -c --quiet - || { rm -f $@.download; exit 1; }
endef
endif
