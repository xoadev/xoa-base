# From github.com/xoadev/xoa-base (lint/prettier.mk): change it here. markdown.mk and yaml.mk include it. Prettier runs
# through Deno at lint/deno.jsonc's version, which Dependabot moves, and with lint/deno.lock, frozen: a package that is
# not what the lock says fails.
ifndef PRETTIER
XOA_LINT := $(dir $(lastword $(MAKEFILE_LIST)))
PRETTIER_PACKAGE := $(shell sed -n 's/.*"\(npm:prettier@[^"]*\)".*/\1/p' $(XOA_LINT)deno.jsonc)
XOA_DENO_RUN := deno run --quiet --config $(XOA_LINT)deno.jsonc --allow-read --allow-env --allow-sys
PRETTIER := $(XOA_DENO_RUN) $(PRETTIER_PACKAGE)
PRETTIER_WRITE := $(XOA_DENO_RUN) --allow-write $(PRETTIER_PACKAGE)
endif
