# From github.com/xoadev/xoa-base (lint/prettier.mk): change it here. markdown.mk and yaml.mk include it. Prettier runs
# through Deno at lint/deno.jsonc's version, which Dependabot moves.
ifndef PRETTIER
XOA_LINT := $(dir $(lastword $(MAKEFILE_LIST)))
PRETTIER_PACKAGE := $(shell sed -n 's/.*"\(npm:prettier@[^"]*\)".*/\1/p' $(XOA_LINT)deno.jsonc)
PRETTIER := deno run --quiet --allow-read --allow-env --allow-sys $(PRETTIER_PACKAGE)
PRETTIER_WRITE := deno run --quiet --allow-read --allow-write --allow-env --allow-sys $(PRETTIER_PACKAGE)
endif
