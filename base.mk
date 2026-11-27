# From github.com/xoadev/xoa-base (base.mk): change it here. What every XOA Makefile shares, included before the rest:
# bash with pipefail, so a pipe fails when any of its commands does; `help` as the default goal; and `make help`, the
# targets that carry `## what it does` on their line, from this Makefile and every one it includes.
SHELL := bash
.SHELLFLAGS := -euo pipefail -c
.DEFAULT_GOAL := help

.PHONY: help
help: ## This list
	@grep -hE '^[a-zA-Z0-9_%-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-20s %s\n", $$1, $$2}'
