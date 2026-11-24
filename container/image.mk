# Copied from github.com/xoadev/xoa-base (container/image.mk): change it there, not in a project's copy.
# The container image's targets, included from the project's Makefile (`include image.mk`). CI runs
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
IMAGE_SH ?= tools/image.sh
PLATFORMS ?= linux/$(subst aarch64,arm64,$(subst x86_64,amd64,$(shell uname -m)))
export IMAGE IMAGE_DOCKERFILE IMAGE_CONTEXT IMAGE_CHECK IMAGE_BUILD_ARGS IMAGE_STOP IMAGE_MEMORY PLATFORMS

# hadolint, fetched into IMAGE_BIN and checked against its sha256: the same version here and in CI.
IMAGE_BIN ?= .tmp/bin
HADOLINT_VERSION := 2.15.1
HADOLINT_ARCH := $(shell uname -m)
ifeq ($(HADOLINT_ARCH),x86_64)
HADOLINT_SHA256 := c7187db94eeeeca956519a6af171adc31453941a1e777961f6e680f697c8c507
else ifeq ($(HADOLINT_ARCH),aarch64)
HADOLINT_ARCH := arm64
HADOLINT_SHA256 := f6198ef8090f404dbb771abfee086eb8c48ac177f30da7fd3510aca35b344b5d
endif

.PHONY: image-lint image-check image-oci

image-lint: $(IMAGE_BIN)/hadolint ## hadolint, and the policy: frontend and bases by digest, distroless, non-root, no secret in ENV or ARG, downloads checked
	@$(IMAGE_BIN)/hadolint $(IMAGE_DOCKERFILE)
	@$(IMAGE_SH) lint $(IMAGE_DOCKERFILE)

image-check: $(IMAGE_DEPS) ## BuildKit's checks; IMAGE for each of PLATFORMS: architecture, user, environment, IMAGE_CHECK restricted, clean stop
	@$(IMAGE_SH) check

image-oci: $(IMAGE_DEPS) ## Every platform of PLATFORMS in one OCI archive, OCI=<file>, for the publishing job to push
	@$(IMAGE_SH) oci "$(OCI)"

$(IMAGE_BIN)/hadolint:
	@test -n "$(HADOLINT_SHA256)" || { echo "image: no pinned hadolint for $(HADOLINT_ARCH): add its sha256 to image.mk" >&2; exit 1; }
	@mkdir -p $(IMAGE_BIN)
	@curl -fsSL --proto '=https' --retry 3 -o $@.download \
	  https://github.com/hadolint/hadolint/releases/download/v$(HADOLINT_VERSION)/hadolint-linux-$(HADOLINT_ARCH)
	@echo '$(HADOLINT_SHA256)  $@.download' | sha256sum -c --quiet - || { rm -f $@.download; exit 1; }
	@chmod 0755 $@.download && mv $@.download $@
