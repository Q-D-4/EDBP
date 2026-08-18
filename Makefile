SHELL := /bin/bash
.SHELLFLAGS := -Eeuo pipefail -c
.DEFAULT_GOAL := all

VERSION := $(strip $(shell sed -n '1{s/[[:space:]]*$$//;p;}' VERSION))
ARCH := amd64
IMAGE_BASENAME := edbp-$(VERSION)-$(ARCH)
ISO := $(IMAGE_BASENAME).hybrid.iso
PACKAGES := $(IMAGE_BASENAME).packages
MANIFEST := $(IMAGE_BASENAME).manifest.json
ADMIN_KEYS_SOURCE ?= secrets/localadmin_authorized_keys
ADMIN_KEYS_STAGED := config/includes.installer/localadmin_authorized_keys
SOURCE_DATE_EPOCH ?= $(shell git log -1 --format=%ct)

export SOURCE_DATE_EPOCH

.PHONY: all clean config build verify checksums verify-checksums stage-admin-keys

all: checksums
	@$(MAKE) --no-print-directory verify-checksums

verify:
	@EDBP_ADMIN_KEYS_FILE="$(ADMIN_KEYS_SOURCE)" ./scripts/verify-tree

stage-admin-keys: verify
	@./scripts/stage-admin-keys \
		"$(ADMIN_KEYS_SOURCE)" \
		"$(ADMIN_KEYS_STAGED)"

config: stage-admin-keys
	@lb config

build: config
	@printf '%s\n' '[EDBP] Building $(ISO)'
	@sudo lb build 2>&1 | tee build.log
	@test -s "$(ISO)"
	@test -s "$(PACKAGES)"

checksums: build
	@sha256sum "$(ISO)" "$(PACKAGES)" > SHA256SUMS
	@iso_sha="$$(sha256sum "$(ISO)" | awk '{print $$1}')"; \
	packages_sha="$$(sha256sum "$(PACKAGES)" | awk '{print $$1}')"; \
	admin_keys_sha="$$(sha256sum "$(ADMIN_KEYS_STAGED)" | awk '{print $$1}')"; \
	commit="$$(git rev-parse HEAD)"; \
	source_date_utc="$$(date --utc --date="@$(SOURCE_DATE_EPOCH)" +%Y-%m-%dT%H:%M:%SZ)"; \
	manifest_created_utc="$$(date --utc +%Y-%m-%dT%H:%M:%SZ)"; \
	jq --null-input \
		--arg version "$(VERSION)" \
		--arg architecture "$(ARCH)" \
		--arg git_commit "$$commit" \
		--arg source_date_epoch "$(SOURCE_DATE_EPOCH)" \
		--arg source_date_utc "$$source_date_utc" \
		--arg manifest_created_utc "$$manifest_created_utc" \
		--arg iso "$(ISO)" \
		--arg iso_sha256 "$$iso_sha" \
		--arg packages "$(PACKAGES)" \
		--arg packages_sha256 "$$packages_sha" \
		--arg admin_keys_sha256 "$$admin_keys_sha" \
		'{version: $$version, architecture: $$architecture, git_commit: $$git_commit, source_date_epoch: ($$source_date_epoch | tonumber), source_date_utc: $$source_date_utc, manifest_created_utc: $$manifest_created_utc, build_inputs: {localadmin_authorized_keys_sha256: $$admin_keys_sha256}, artifacts: {iso: {path: $$iso, sha256: $$iso_sha256}, packages: {path: $$packages, sha256: $$packages_sha256}}}' \
		> "$(MANIFEST)"

verify-checksums:
	@test -s SHA256SUMS
	@test -s "$(MANIFEST)"
	@test -s "$(ADMIN_KEYS_STAGED)"
	@sha256sum --check --strict SHA256SUMS
	@iso_sha="$$(sha256sum "$(ISO)" | awk '{print $$1}')"; \
	packages_sha="$$(sha256sum "$(PACKAGES)" | awk '{print $$1}')"; \
	admin_keys_sha="$$(sha256sum "$(ADMIN_KEYS_STAGED)" | awk '{print $$1}')"; \
	commit="$$(git rev-parse HEAD)"; \
	source_date_epoch="$$(jq --exit-status --raw-output '.source_date_epoch | select(type == "number" and floor == .)' "$(MANIFEST)")"; \
	[[ "$$source_date_epoch" =~ ^[0-9]+$$ ]]; \
	source_date_utc="$$(date --utc --date="@$$source_date_epoch" +%Y-%m-%dT%H:%M:%SZ)"; \
	jq --exit-status \
		--arg version "$(VERSION)" \
		--arg architecture "$(ARCH)" \
		--arg git_commit "$$commit" \
		--arg source_date_epoch "$$source_date_epoch" \
		--arg source_date_utc "$$source_date_utc" \
		--arg iso "$(ISO)" \
		--arg packages "$(PACKAGES)" \
		--arg iso_sha256 "$$iso_sha" \
		--arg packages_sha256 "$$packages_sha" \
		--arg admin_keys_sha256 "$$admin_keys_sha" \
		'.version == $$version and .architecture == $$architecture and .git_commit == $$git_commit and .source_date_epoch == ($$source_date_epoch | tonumber) and .source_date_utc == $$source_date_utc and (.manifest_created_utc | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$$")) and .build_inputs.localadmin_authorized_keys_sha256 == $$admin_keys_sha256 and .artifacts.iso.path == $$iso and .artifacts.iso.sha256 == $$iso_sha256 and .artifacts.packages.path == $$packages and .artifacts.packages.sha256 == $$packages_sha256' \
		"$(MANIFEST)" >/dev/null

clean:
	@if [[ -e config/common || -d .build || -d chroot || -d binary ]]; then \
		sudo lb clean --purge; \
	fi
	@rm -f -- \
		"$(ADMIN_KEYS_STAGED)" \
		"$(ISO)" \
		"$(PACKAGES)" \
		"$(MANIFEST)" \
		SHA256SUMS \
		build.log
