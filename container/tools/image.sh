#!/usr/bin/env bash
# From github.com/xoadev/xoa-base (container/tools/image.sh), fetched by the project's Makefile: change it there.
# The container image's policy, check and build, run by image.mk.
#
#   image.sh lint <Dockerfile>...   what hadolint does not know: the frontend and bases by digest, distroless,
#                                   non-root, no secret in ENV or ARG, no download without its checksum
#   image.sh check                  BuildKit's build checks, then builds IMAGE for each of PLATFORMS, checks its
#                                   architecture, user and environment, runs IMAGE_CHECK in it under the restrictions
#                                   it is deployed with, and stops it as Docker would
#   image.sh oci <file>             builds every platform of PLATFORMS into one OCI archive, for the publishing job
#
# From the environment (image.mk exports them): IMAGE, IMAGE_DOCKERFILE, IMAGE_CONTEXT, IMAGE_BUILD_ARGS, PLATFORMS,
# IMAGE_CHECK, IMAGE_STOP and IMAGE_MEMORY.
set -euo pipefail

# What a deployment should run the image with: OWASP's container rules. The image proves here that it works under them,
# with /data a volume of its own and /tmp the only other place it can write.
RUN_FLAGS=(--read-only --tmpfs /tmp --cap-drop ALL --security-opt no-new-privileges
  --memory "${IMAGE_MEMORY:-512m}" --pids-limit 256)
# How long a server is given to start before it is asked to stop, and Docker's own grace before it kills it.
START_SECONDS=3
STOP_SECONDS=10

# A variable named like a secret, by whole words of its name: TOKEN and API_KEY are, TOKENIZERS_PARALLELISM and a base
# image's GPG_KEY are not. Secrets reach the container as files, so the variable that names one ends in _FILE.
SECRET_NAME='(^|_)(SECRETS?|TOKEN|PASSWORD|PASSWD|CREDENTIALS?|(API|PRIVATE|SECRET|ACCESS)_KEY)(_|$)'

fail() {
  echo "image: $*" >&2
  exit 1
}

is_secret_name() {
  [[ "$1" != *_FILE ]] && grep -qE "$SECRET_NAME" <<< "${1^^}"
}

lint() {
  local dockerfile errors=0
  [[ $# -gt 0 ]] || fail "lint: name the Dockerfiles"
  for dockerfile in "$@"; do
    [[ -f "$dockerfile" ]] || fail "lint: no $dockerfile (IMAGE_DOCKERFILE in the Makefile)"
    awk -v file="$dockerfile" -v secret="$SECRET_NAME" -f - "$dockerfile" <<'AWK' || errors=1
function complain(message) { printf "%s:%d: %s\n", file, line, message > "/dev/stderr"; failed = 1 }
function secret_name(name) { return name !~ /_FILE$/ && toupper(name) ~ secret }
function remember_stage() {
  if (current == "") return
  stage_base[current] = base; stage_user[current] = user; stage_exempt[current] = exempt
}

# The frontend is code BuildKit downloads and runs: pinned like a base. A parser directive is only one on the first lines.
NR == 1 && $0 !~ /^#[ \t]*syntax=[^ \t]+@sha256:[0-9a-f]{64}[ \t]*$/ {
  line = 1
  complain("the first line pins the Dockerfile frontend by digest: # syntax=docker/dockerfile:X.Y.Z@sha256:...")
}

# Instructions span lines ending in a backslash; comments inside them are not theirs. A comment block right above a
# FROM is that stage's, which is where "not distroless:" says why.
{
  if (pending == "" && $0 ~ /^[ \t]*#/) { comments = comments "\n" $0; next }
  if (pending == "" && $0 ~ /^[ \t]*$/) { comments = ""; next }
  if (pending != "" && $0 ~ /^[ \t]*#/) next
  if (pending == "") line = NR
  text = $0
  if (sub(/\\[ \t]*$/, "", text)) { pending = pending text " "; next }
  instruction = pending text
  pending = ""
  split(instruction, word, /[ \t]+/)
  keyword = toupper(word[1] == "" ? word[2] : word[1])
  sub(/^[ \t]*[^ \t]+[ \t]*/, "", instruction)

  if (keyword == "FROM") {
    n = split(instruction, args, /[ \t]+/)
    image = ""; stage = ""
    for (i = 1; i <= n; i++) {
      if (args[i] ~ /^--/) continue
      if (image == "") image = args[i]
      else if (toupper(args[i]) == "AS") stage = tolower(args[i + 1])
    }
    remember_stage()
    # A stage built FROM an earlier one (stage names are case-insensitive) inherits its base, its user and its reason.
    if (tolower(image) in stage_base) {
      parent = tolower(image)
      base = stage_base[parent]; user = stage_user[parent]; exempt = stage_exempt[parent]
    } else {
      if (image != "scratch" && image !~ /@sha256:[0-9a-f]{64}$/)
        complain("FROM " image ": pin the base by digest (" image "@sha256:...), and let Dependabot move it")
      base = image; user = ""; exempt = 0
    }
    if (comments ~ /#[ \t]*not distroless:/) exempt = 1
    current = stage; final_line = line
  } else if (keyword == "ADD") {
    if (instruction ~ /(^|[ \t])https?:\/\// && instruction !~ /--checksum=sha256:[0-9a-f]{64}/)
      complain("ADD of a URL without --checksum=sha256:...: what is downloaded is checked, or the build takes whatever the server gives")
  } else if (keyword == "USER") {
    user = instruction
  } else if (keyword == "ARG" || keyword == "ENV") {
    n = split(instruction, args, /[ \t]+/)
    for (i = 1; i <= n; i++) {
      name = args[i]
      if (keyword == "ENV" && n > 1 && args[1] !~ /=/ && i > 1) break
      if (name !~ /^[A-Za-z_][A-Za-z0-9_]*(=|$)/) continue
      sub(/=.*/, "", name)
      if (secret_name(name))
        complain(keyword " " name ": a secret is never an " keyword "; at run time the program reads it from a file (" name "_FILE), at build time RUN --mount=type=secret")
    }
  }
  comments = ""
}

END {
  if (base == "") { complain("no FROM"); exit 1 }
  line = final_line
  if (base !~ /^gcr\.io\/distroless\// && base != "scratch" && !exempt)
    complain("FROM " base ": the image runs on gcr.io/distroless (or scratch); if it cannot, a comment right above this FROM says why: # not distroless: <reason>")
  root = (user == "" ? base !~ /:nonroot([@-]|$)/ : user ~ /^(root|0)(:|$)/)
  if (root)
    complain("the image runs as root: USER 65532:65532 (distroless's nonroot) or a :nonroot base")
  exit failed
}
AWK
  done
  return "$errors"
}

check_built() {
  local tag=$1 arch=$2 actual user name
  read -r actual user <<< "$(docker image inspect --format '{{.Architecture}} {{.Config.User}}' "$tag")"
  [[ "$actual" == "$arch" ]] || fail "$tag is $actual, not $arch: the Dockerfile copies or builds for the wrong platform"
  [[ -n "$user" && ! "$user" =~ ^(root|0)(:|$) ]] || fail "$tag runs as root: USER 65532:65532 or a :nonroot base"
  while IFS='=' read -r name _; do
    if [[ -n "$name" ]] && is_secret_name "$name"; then
      fail "$tag has $name in its environment: secrets reach the container as files (${name}_FILE)"
    fi
  done < <(docker image inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$tag")
}

# The default command is a server: started as a deployment would, it has to be running a few seconds later and exit
# cleanly when Docker sends it the stop signal. PID 1 has no default handler for it, so a program that does not handle
# it is killed after STOP_SECONDS, mid-write.
check_stop() {
  local tag=$1 data=$2 id signal number code
  id=$(docker run --detach "${RUN_FLAGS[@]}" --volume "$data:/data" "$tag")
  sleep "$START_SECONDS"
  if [[ "$(docker inspect --format '{{.State.Running}}' "$id")" != true ]]; then
    docker logs "$id" >&2 || true
    docker rm --force "$id" > /dev/null
    fail "$tag: its default command exited within ${START_SECONDS} s, before it was asked to stop; IMAGE_STOP=0 for an image that is not a server"
  fi
  docker stop --time "$STOP_SECONDS" "$id" > /dev/null
  signal=$(docker inspect --format '{{.Config.StopSignal}}' "$id")
  signal=${signal:-SIGTERM}
  [[ "$signal" =~ ^[0-9]+$ ]] && number=$signal || number=$(kill -l "${signal#SIG}")
  code=$(docker inspect --format '{{.State.ExitCode}}' "$id")
  docker rm "$id" > /dev/null
  [[ "$code" == 0 || "$code" == $((128 + number)) ]] ||
    fail "$tag exited $code on docker stop, not 0 or $((128 + number)): it ignores $signal, so Docker killed it after ${STOP_SECONDS} s; handle the signal, or STOPSIGNAL the one it handles"
}

check() {
  local platform arch tag
  volume=""
  trap '[[ -z "$volume" ]] || docker volume rm --force "$volume" > /dev/null' EXIT
  [[ -n "${IMAGE_CHECK:-}" ]] ||
    fail "set IMAGE_CHECK in the Makefile: a command that does inside \$IMAGE what a real request does, not only --version"
  # shellcheck disable=SC2086 # IMAGE_BUILD_ARGS is a list of flags
  docker buildx build --check --file "$IMAGE_DOCKERFILE" ${IMAGE_BUILD_ARGS:-} "$IMAGE_CONTEXT"
  IFS=, read -ra each_platform <<< "$PLATFORMS"
  for platform in "${each_platform[@]}"; do
    arch=${platform#linux/}
    tag="$IMAGE-$arch"
    # Docker loads one platform per tag, so each is built, loaded and checked on its own.
    # shellcheck disable=SC2086 # IMAGE_BUILD_ARGS is a list of flags
    docker buildx build --platform "$platform" --load --tag "$tag" --file "$IMAGE_DOCKERFILE" \
      ${IMAGE_BUILD_ARGS:-} "$IMAGE_CONTEXT"
    check_built "$tag" "$arch"
    volume=$(docker volume create)
    IMAGE=$tag IMAGE_RUN="docker run --rm ${RUN_FLAGS[*]} --volume $volume:/data" DOCKER_DEFAULT_PLATFORM=$platform \
      bash -euo pipefail -c "$IMAGE_CHECK" || fail "IMAGE_CHECK failed in $tag"
    [[ "${IMAGE_STOP:-1}" != 1 ]] || DOCKER_DEFAULT_PLATFORM=$platform check_stop "$tag" "$volume"
    docker volume rm "$volume" > /dev/null && volume=""
    echo "image: $tag checked"
  done
}

oci() {
  local file=${1:-}
  [[ -n "$file" ]] || fail "oci: name the archive, make image-oci OCI=<file>"
  # An OCI archive of several platforms needs a buildx builder of its own (docker/setup-buildx-action creates one).
  # shellcheck disable=SC2086 # IMAGE_BUILD_ARGS is a list of flags
  docker buildx build --platform "$PLATFORMS" --output "type=oci,dest=$file" --tag "$IMAGE" \
    --file "$IMAGE_DOCKERFILE" ${IMAGE_BUILD_ARGS:-} "$IMAGE_CONTEXT"
  echo "image: $IMAGE for $PLATFORMS in $file"
}

command=${1:-}
shift || true
case "$command" in
  lint) lint "$@" ;;
  check) check ;;
  oci) oci "$@" ;;
  *) fail "usage: image.sh lint <Dockerfile>... | check | oci <file>" ;;
esac
