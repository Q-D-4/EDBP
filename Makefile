SHELL := /bin/bash
.SHELLFLAGS := -Eeuo pipefail -c
.DEFAULT_GOAL := all

VERSION := $(strip $(shell sed -n '1{s/[[:space:]]*$$//;p;}' VERSION))
ARCH := amd64
IMAGE_BASENAME := edbp-$(VERSION)-$(ARCH)
ISO := $(IMAGE_BASENAME).hybrid.iso
PACKAGES := $(IMAGE_BASENAME).packages
MANIFEST := $(IMAGE_BASENAME).manifest.json
BUILD_INPUTS := $(IMAGE_BASENAME).build-inputs.json

ADMIN_KEYS_SOURCE ?= secrets/localadmin_authorized_keys
ADMIN_KEYS_STAGED := config/includes.installer/localadmin_authorized_keys
LOCALADMIN_PASSWORD_HASH_SOURCE ?= secrets/localadmin_password_hash
PRESEED_TEMPLATE := config/includes.installer/preseed.cfg.in
PRESEED_STAGED := config/includes.installer/preseed.cfg

SOURCE_DATE_EPOCH ?= $(shell git log -1 --format=%ct)

export SOURCE_DATE_EPOCH

.PHONY: all clean config build verify verify-test checksums verify-checksums \
	stage-admin-keys stage-preseed stage-build-inputs scrub-build-inputs

# Production entry point. The outer trap also scrubs staged secrets when a
# prerequisite fails before the build target can establish its own trap.
all:
	@cleanup() { \
		status=$$?; \
		trap - EXIT; \
		$(MAKE) --no-print-directory scrub-build-inputs >/dev/null || true; \
		if (( status != 0 )); then rm -f -- "$(BUILD_INPUTS)"; fi; \
		exit "$$status"; \
	}; \
	trap cleanup EXIT; \
	trap 'exit 129' HUP; \
	trap 'exit 130' INT; \
	trap 'exit 143' TERM; \
	$(MAKE) --no-print-directory checksums; \
	$(MAKE) --no-print-directory verify-checksums

verify:
	@EDBP_ADMIN_KEYS_FILE="$(ADMIN_KEYS_SOURCE)" \
	EDBP_LOCALADMIN_PASSWORD_HASH_FILE="$(LOCALADMIN_PASSWORD_HASH_SOURCE)" \
	./scripts/verify-tree

# Static verification only. The synthetic hash is rendered into a temporary
# directory and can never satisfy config/build dependencies.
verify-test:
	@EDBP_ADMIN_KEYS_FILE="$(ADMIN_KEYS_SOURCE)" \
	EDBP_LOCALADMIN_PASSWORD_HASH_FILE="$(LOCALADMIN_PASSWORD_HASH_SOURCE)" \
	EDBP_ALLOW_TEST_PASSWORD_HASH=1 \
	./scripts/verify-tree

stage-admin-keys: verify
	@./scripts/stage-admin-keys \
		"$(ADMIN_KEYS_SOURCE)" \
		"$(ADMIN_KEYS_STAGED)"

stage-preseed: verify
	@./scripts/stage-localadmin-password \
		"$(LOCALADMIN_PASSWORD_HASH_SOURCE)" \
		"$(PRESEED_TEMPLATE)" \
		"$(PRESEED_STAGED)"

# Stage both inputs as one transaction. A failure in either step removes both
# generated files so that no stale credential is consumed by a later build.
stage-build-inputs: verify
	@{ \
		./scripts/stage-admin-keys \
			"$(ADMIN_KEYS_SOURCE)" \
			"$(ADMIN_KEYS_STAGED)"; \
		./scripts/stage-localadmin-password \
			"$(LOCALADMIN_PASSWORD_HASH_SOURCE)" \
			"$(PRESEED_TEMPLATE)" \
			"$(PRESEED_STAGED)"; \
		admin_keys_sha="$$(sha256sum "$(ADMIN_KEYS_STAGED)" | awk '{print $$1}')"; \
		password_hash_sha="$$(python3 -c 'import hashlib, pathlib, sys; prefix = "d-i passwd/user-password-crypted password "; lines = [line for line in pathlib.Path(sys.argv[1]).read_text(encoding="utf-8").splitlines() if line.startswith(prefix)]; assert len(lines) == 1; print(hashlib.sha256(lines[0][len(prefix):].encode("ascii")).hexdigest())' "$(PRESEED_STAGED)")"; \
		preseed_template_sha="$$(sha256sum "$(PRESEED_TEMPLATE)" | awk '{print $$1}')"; \
		rendered_preseed_sha="$$(sha256sum "$(PRESEED_STAGED)" | awk '{print $$1}')"; \
		record_tmp="$$(mktemp "$(BUILD_INPUTS).tmp.XXXXXX")"; \
		jq --null-input \
			--arg admin_keys_sha256 "$$admin_keys_sha" \
			--arg password_hash_sha256 "$$password_hash_sha" \
			--arg preseed_template_sha256 "$$preseed_template_sha" \
			--arg rendered_preseed_sha256 "$$rendered_preseed_sha" \
			'{localadmin_authorized_keys_sha256: $$admin_keys_sha256, localadmin_password_hash_sha256: $$password_hash_sha256, preseed_template_sha256: $$preseed_template_sha256, rendered_preseed_sha256: $$rendered_preseed_sha256}' \
			> "$$record_tmp"; \
		chmod 0644 "$$record_tmp"; \
		mv -f -- "$$record_tmp" "$(BUILD_INPUTS)"; \
		record_tmp=; \
	} || { \
		status=$$?; \
		if [[ -n "$${record_tmp:-}" ]]; then rm -f -- "$$record_tmp"; fi; \
		rm -f -- "$(ADMIN_KEYS_STAGED)" "$(PRESEED_STAGED)" "$(BUILD_INPUTS)"; \
		exit "$$status"; \
	}

config: stage-build-inputs
	@umask 022; \
	if ! lb config; then \
		$(MAKE) --no-print-directory scrub-build-inputs; \
		rm -f -- "$(BUILD_INPUTS)"; \
		exit 1; \
	fi
	@printf '%s\n' \
		'[EDBP] Secret-bearing installer inputs are staged; run make build or make clean.'

# The generated preseed and staged public-key file are needed throughout
# lb build, then removed on success, failure, interruption, or termination.
build: config
	@cleanup() { \
		status=$$?; \
		trap - EXIT; \
		$(MAKE) --no-print-directory scrub-build-inputs >/dev/null || true; \
		if (( status != 0 )); then rm -f -- "$(BUILD_INPUTS)"; fi; \
		exit "$$status"; \
	}; \
	trap cleanup EXIT; \
	trap 'exit 129' HUP; \
	trap 'exit 130' INT; \
	trap 'exit 143' TERM; \
	umask 022; \
	printf '%s\n' '[EDBP] Building $(ISO)'; \
	if (( EUID == 0 )); then lb build; else sudo lb build; fi \
		2>&1 | tee build.log; \
	test -s "$(ISO)"; \
	test -s "$(PACKAGES)"

checksums: build
	@test -s "$(BUILD_INPUTS)"
	@sha256sum "$(ISO)" "$(PACKAGES)" "$(BUILD_INPUTS)" > SHA256SUMS
	@iso_sha="$$(sha256sum "$(ISO)" | awk '{print $$1}')"; \
	packages_sha="$$(sha256sum "$(PACKAGES)" | awk '{print $$1}')"; \
	build_inputs_sha="$$(sha256sum "$(BUILD_INPUTS)" | awk '{print $$1}')"; \
	admin_keys_sha="$$(jq --exit-status --raw-output '.localadmin_authorized_keys_sha256' "$(BUILD_INPUTS)")"; \
	password_hash_sha="$$(jq --exit-status --raw-output '.localadmin_password_hash_sha256' "$(BUILD_INPUTS)")"; \
	preseed_template_sha="$$(jq --exit-status --raw-output '.preseed_template_sha256' "$(BUILD_INPUTS)")"; \
	rendered_preseed_sha="$$(jq --exit-status --raw-output '.rendered_preseed_sha256' "$(BUILD_INPUTS)")"; \
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
		--arg build_inputs "$(BUILD_INPUTS)" \
		--arg build_inputs_sha256 "$$build_inputs_sha" \
		--arg admin_keys_sha256 "$$admin_keys_sha" \
		--arg password_hash_sha256 "$$password_hash_sha" \
		--arg preseed_template_sha256 "$$preseed_template_sha" \
		--arg rendered_preseed_sha256 "$$rendered_preseed_sha" \
		'{version: $$version, architecture: $$architecture, git_commit: $$git_commit, source_date_epoch: ($$source_date_epoch | tonumber), source_date_utc: $$source_date_utc, manifest_created_utc: $$manifest_created_utc, build_inputs: {localadmin_authorized_keys_sha256: $$admin_keys_sha256, localadmin_password_hash_sha256: $$password_hash_sha256, preseed_template_sha256: $$preseed_template_sha256, rendered_preseed_sha256: $$rendered_preseed_sha256}, artifacts: {iso: {path: $$iso, sha256: $$iso_sha256}, packages: {path: $$packages, sha256: $$packages_sha256}, build_inputs: {path: $$build_inputs, sha256: $$build_inputs_sha256}}}' \
		> "$(MANIFEST)"

verify-checksums:
	@test -s SHA256SUMS
	@test -s "$(MANIFEST)"
	@test -s "$(BUILD_INPUTS)"
	@sha256sum --check --strict SHA256SUMS
	@iso_sha="$$(sha256sum "$(ISO)" | awk '{print $$1}')"; \
	packages_sha="$$(sha256sum "$(PACKAGES)" | awk '{print $$1}')"; \
	build_inputs_sha="$$(sha256sum "$(BUILD_INPUTS)" | awk '{print $$1}')"; \
	jq --exit-status '([.localadmin_authorized_keys_sha256, .localadmin_password_hash_sha256, .preseed_template_sha256, .rendered_preseed_sha256] | all(type == "string" and test("^[0-9a-f]{64}$$"))) and (keys | sort) == ["localadmin_authorized_keys_sha256", "localadmin_password_hash_sha256", "preseed_template_sha256", "rendered_preseed_sha256"]' "$(BUILD_INPUTS)" >/dev/null; \
	admin_keys_sha="$$(jq --raw-output '.localadmin_authorized_keys_sha256' "$(BUILD_INPUTS)")"; \
	password_hash_sha="$$(jq --raw-output '.localadmin_password_hash_sha256' "$(BUILD_INPUTS)")"; \
	preseed_template_sha="$$(jq --raw-output '.preseed_template_sha256' "$(BUILD_INPUTS)")"; \
	rendered_preseed_sha="$$(jq --raw-output '.rendered_preseed_sha256' "$(BUILD_INPUTS)")"; \
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
		--arg build_inputs "$(BUILD_INPUTS)" \
		--arg build_inputs_sha256 "$$build_inputs_sha" \
		--arg admin_keys_sha256 "$$admin_keys_sha" \
		--arg password_hash_sha256 "$$password_hash_sha" \
		--arg preseed_template_sha256 "$$preseed_template_sha" \
		--arg rendered_preseed_sha256 "$$rendered_preseed_sha" \
		'.version == $$version and .architecture == $$architecture and .git_commit == $$git_commit and .source_date_epoch == ($$source_date_epoch | tonumber) and .source_date_utc == $$source_date_utc and (.manifest_created_utc | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$$")) and .build_inputs.localadmin_authorized_keys_sha256 == $$admin_keys_sha256 and .build_inputs.localadmin_password_hash_sha256 == $$password_hash_sha256 and .build_inputs.preseed_template_sha256 == $$preseed_template_sha256 and .build_inputs.rendered_preseed_sha256 == $$rendered_preseed_sha256 and .artifacts.iso.path == $$iso and .artifacts.iso.sha256 == $$iso_sha256 and .artifacts.packages.path == $$packages and .artifacts.packages.sha256 == $$packages_sha256 and .artifacts.build_inputs.path == $$build_inputs and .artifacts.build_inputs.sha256 == $$build_inputs_sha256' \
		"$(MANIFEST)" >/dev/null

scrub-build-inputs:
	@rm -f -- "$(ADMIN_KEYS_STAGED)" "$(PRESEED_STAGED)"

clean:
	@if [[ -e config/common || -d .build || -d chroot || -d binary ]]; then \
		if (( EUID == 0 )); then lb clean --purge; else sudo lb clean --purge; fi; \
	fi
	@rm -f -- \
		"$(ADMIN_KEYS_STAGED)" \
		"$(PRESEED_STAGED)" \
		"$(ISO)" \
		"$(PACKAGES)" \
		"$(MANIFEST)" \
		"$(BUILD_INPUTS)" \
		SHA256SUMS \
		build.log
	@rm -f -- \
		config/binary \
		config/bootstrap \
		config/chroot \
		config/common \
		config/source \
		config/hooks/live/0010-disable-kexec-tools.hook.chroot \
		config/hooks/live/0050-disable-sysvinit-tmpfs.hook.chroot \
		config/package-lists/live.list.chroot
	@if [[ -d config/hooks/normal ]]; then \
		find config/hooks/normal -depth -mindepth 1 -delete; \
		rmdir -- config/hooks/normal; \
	fi
