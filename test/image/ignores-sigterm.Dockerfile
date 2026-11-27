# syntax=docker/dockerfile:1.29.0@sha256:572cebbc2b15e6f84c077742952674889cb63cd5e9b80abdffcbe587b6f19183
# The test image with a server that ignores SIGTERM, as PID 1 does without a handler: make image-test expects
# image-check to refuse it.
FROM busybox:1.37.0-musl@sha256:f6a95d611e0a8780fabdb2aec43e31275b2720dfefa3e41b16835bfc42454478 AS tool
RUN mkdir /data

FROM gcr.io/distroless/static-debian13:nonroot@sha256:aafe993665bf6200db38a02c11a9351e782a84b6a45e7f33b6695638c88e3931
COPY --from=tool /bin/busybox /usr/local/bin/busybox
# A new volume takes this directory's owner, so nonroot can write into it.
COPY --from=tool --chown=65532:65532 /data /data
# The token is a file the program reads, never the token in a variable.
ENV GREETING_TOKEN_FILE=/run/secrets/greeting
ENTRYPOINT ["/usr/local/bin/busybox"]
CMD ["sleep", "3600"]
