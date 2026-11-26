# syntax=docker/dockerfile:1.29.0@sha256:572cebbc2b15e6f84c077742952674889cb63cd5e9b80abdffcbe587b6f19183
# Names with a secret's word inside another word, or a key that is not a secret.
FROM gcr.io/distroless/static-debian13:nonroot@sha256:aafe993665bf6200db38a02c11a9351e782a84b6a45e7f33b6695638c88e3931
ENV TOKENIZERS_PARALLELISM=false PUBLIC_KEY_PATH=/data/key.pub CACHE_KEY=v1 GPG_KEY=0123ABCD
