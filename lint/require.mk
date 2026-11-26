# From github.com/xoadev/xoa-base (lint/require.mk): change it here. The other .mk files include it.
#
# The tools come with the machine, never with make: the images of XOA's runners and agent bring them (by-fros/cloud),
# and anywhere else they are installed by hand. $(call xoa-require,tool,minimum,how to install it) is a recipe line
# that fails, saying what is missing, unless `tool` is in the PATH at that version or newer.
ifndef xoa-require
define xoa-require
	@version=$$($(1) --version 2> /dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1); \
	if [ -z "$$version" ]; then \
	  echo "xoa-base: $(1) $(2) or newer is needed and is not in the PATH: $(3)" >&2; exit 1; \
	elif [ "$$(printf '%s\n' "$(2)" "$$version" | sort -V | head -1)" != "$(2)" ]; then \
	  echo "xoa-base: $(1) $$version is older than $(2): $(3)" >&2; exit 1; \
	fi
endef
endif
