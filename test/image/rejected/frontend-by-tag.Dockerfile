# syntax=docker/dockerfile:1
# A frontend by tag, not digest: BuildKit downloads and runs whatever docker/dockerfile:1 is today.
FROM gcr.io/distroless/static-debian13:nonroot@sha256:aafe993665bf6200db38a02c11a9351e782a84b6a45e7f33b6695638c88e3931
