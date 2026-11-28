# From github.com/xoadev/xoa-base (lint/rust.mk): change it here. `make rust-lint`: rustfmt's layout (the project's
# rustfmt.toml) and clippy over every crate and target, every warning an error and the lockfile as it is; `make
# rust-format` applies the layout. The toolchain is the one the project's rust-toolchain.toml pins, through rustup,
# which comes with the machine (lint/require.mk).
include $(dir $(lastword $(MAKEFILE_LIST)))require.mk

.PHONY: rust-lint rust-format
rust-lint: ## rustfmt's layout and clippy, every warning an error
	$(call xoa-require,cargo,1.80.0,https://rustup.rs)
	@cargo fmt --all --check
	@cargo clippy --workspace --all-targets --locked -- -D warnings

rust-format: ## Apply rustfmt's layout
	$(call xoa-require,cargo,1.80.0,https://rustup.rs)
	@cargo fmt --all
