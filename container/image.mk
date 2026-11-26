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
# image.sh is next to this file, and the tools it fetches go beside it, inside the folder the project ignores.
IMAGE_HOME := $(dir $(lastword $(MAKEFILE_LIST)))
IMAGE_SH := $(IMAGE_HOME)tools/image.sh
PLATFORMS ?= linux/$(subst aarch64,arm64,$(subst x86_64,amd64,$(shell uname -m)))
export IMAGE IMAGE_DOCKERFILE IMAGE_CONTEXT IMAGE_CHECK IMAGE_BUILD_ARGS IMAGE_STOP IMAGE_MEMORY PLATFORMS

# hadolint, checked against its sha256, with its version in its name so a new one is fetched rather than an old one
# reused: the same here and in CI.
include $(IMAGE_HOME)../lint/fetch.mk
HADOLINT_VERSION := 2.15.1
HADOLINT := $(XOA_TOOLS)/hadolint-$(HADOLINT_VERSION)
ifeq ($(XOA_ARCH),x86_64)
HADOLINT_ARCH := x86_64
HADOLINT_SHA256 := c7187db94eeeeca956519a6af171adc31453941a1e777961f6e680f697c8c507
else ifeq ($(XOA_ARCH),aarch64)
HADOLINT_ARCH := arm64
HADOLINT_SHA256 := f6198ef8090f404dbb771abfee086eb8c48ac177f30da7fd3510aca35b344b5d
endif

.PHONY: image-lint image-check image-oci

image-lint: $(HADOLINT) ## hadolint, and the policy: frontend and bases by digest, distroless, non-root, no secret in ENV or ARG, downloads checked
	@# DL3064 (secrets in ENV or ARG) is image.sh's rule instead: it also flags NAME_FILE, the path a secret is read from.
	@$(HADOLINT) --ignore DL3064 $(IMAGE_DOCKERFILE)
	@$(IMAGE_SH) lint $(IMAGE_DOCKERFILE)

image-check: $(IMAGE_DEPS) ## BuildKit's checks; IMAGE for each of PLATFORMS: architecture, user, environment, IMAGE_CHECK restricted, clean stop
	@$(IMAGE_SH) check

image-oci: $(IMAGE_DEPS) ## Every platform of PLATFORMS in one OCI archive, OCI=<file>, for the publishing job to push
	@$(IMAGE_SH) oci "$(OCI)"

$(HADOLINT):
	$(call xoa-fetch,https://github.com/hadolint/hadolint/releases/download/v$(HADOLINT_VERSION)/hadolint-linux-$(HADOLINT_ARCH),$(HADOLINT_SHA256))
	@chmod 0755 $@.download && mv $@.download $@
