# From github.com/xoadev/xoa-base (container/image.mk), which a project's Makefile fetches by commit into
# .xoa-base/<commit>/ and includes: change it there. CI runs
# `make image-lint image-check`; the release's build job `make image-oci`, and its publishing job pushes that archive.
#
# What the project sets before the include:
#   IMAGE             the tag it is built as (default: <folder>:local)
#   IMAGE_DOCKERFILE  the Dockerfile (default: Dockerfile)
#   IMAGE_CONTEXT     the build context (default: .); with prebuilt binaries, the folder IMAGE_DEPS fills with them
#   IMAGE_DEPS        targets the build needs first, such as the one that compiles and lays out the binaries
#   IMAGE_CHECK       a shell command that does inside "$$IMAGE" what a real request does, starting it with
#                     $$IMAGE_RUN "$$IMAGE" ...: `docker run` with the restrictions a deployment uses (read-only, no
#                     capabilities, no new privileges, limited memory and processes) and a fresh volume on /data, on
#                     the platform being checked
#   IMAGE_STOP        1 (default): the default command is a server, which has to stop cleanly on `docker stop`; 0 when
#                     it is not
#   IMAGE_MEMORY      the memory the image runs within (default: 512m)
#   IMAGE_BUILD_ARGS  extra flags for `docker buildx build` (--build-arg VERSION=...)
#   PLATFORMS         linux/amd64,linux/arm64 (default: this machine's)
IMAGE ?= $(notdir $(CURDIR)):local
IMAGE_DOCKERFILE ?= Dockerfile
IMAGE_CONTEXT ?= .
IMAGE_DEPS ?=
IMAGE_CHECK ?=
IMAGE_BUILD_ARGS ?=
IMAGE_STOP ?= 1
IMAGE_MEMORY ?= 512m
# image.sh is next to this file, fetched or copied.
IMAGE_HOME := $(dir $(lastword $(MAKEFILE_LIST)))
IMAGE_SH := $(IMAGE_HOME)tools/image.sh
PLATFORMS ?= linux/$(subst aarch64,arm64,$(subst x86_64,amd64,$(shell uname -m)))
export IMAGE IMAGE_DOCKERFILE IMAGE_CONTEXT IMAGE_CHECK IMAGE_BUILD_ARGS IMAGE_STOP IMAGE_MEMORY PLATFORMS

# hadolint comes with the machine (lint/require.mk).
include $(IMAGE_HOME)../lint/require.mk

.PHONY: image-lint image-check image-oci

image-lint: ## hadolint, and the policy: frontend and bases by digest, distroless, non-root, no secret in ENV or ARG, downloads checked
	$(call xoa-require,hadolint,2.12.0,https://github.com/hadolint/hadolint#install)
	@# DL3064 (secrets in ENV or ARG) is image.sh's rule instead: it also flags NAME_FILE, the path a secret is read from.
	@hadolint --ignore DL3064 $(IMAGE_DOCKERFILE)
	@$(IMAGE_SH) lint $(IMAGE_DOCKERFILE)

image-check: $(IMAGE_DEPS) ## BuildKit's checks; IMAGE for each of PLATFORMS: architecture, user, environment, IMAGE_CHECK restricted, clean stop
	@$(IMAGE_SH) check

image-oci: $(IMAGE_DEPS) ## Every platform of PLATFORMS in one OCI archive, OCI=<file>, for the publishing job to push
	@$(IMAGE_SH) oci "$(OCI)"
