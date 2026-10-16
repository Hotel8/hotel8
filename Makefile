# SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
# SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
# SPDX-FileCopyrightText: Copyright Contributors to the Hotel8
# SPDX-License-Identifier: Apache-2.0

# Makefile — hotel8/ vertical group (RS §4.4)
#
# Group build in DAG order: the hotel8-sdk facade first, then the services.
# NO docker-compose here — the platform group (../sentin8/) owns the dev
# infra (PostgreSQL 18 + Valkey, §2.2.1); this vertical's services consume
# it over localhost. Each child repo is independent; its own `cargo build`
# is self-sufficient — this file is convenience.

SHELL := /bin/bash
CARGO ?= cargo

# Build identity stamps (BUILDID-1, sentin8-build-info README §3): the
# stamps ride the SAME shell line as the cargo command — make runs each
# recipe line in its own shell, so a standalone `export …` line would
# evaporate before cargo starts. The hash resolves via PLAIN `git
# rev-parse` (no -C path): the stamp expands AFTER the `cd` into the
# repo, so a repo-relative `git -C` would resolve from INSIDE and miss
# (stamping every binary EMPTY). Inside the build-services loop the
# `cd hotel8-$$s` has already happened when the prefix expands.
stamp_env = SENTIN8_BUILD_PROFILE=$(if $(RELEASE),release,debug) SENTIN8_GIT_SHA=$$(git rev-parse --short HEAD 2>/dev/null)

SERVICES := pms pos distrib loyalty upsell meta
APPS := ebooking ecorpbooking eguest ekiosk epms epos

.PHONY: help build build-sdk build-services test status enroll

help: ## Show this help
	@echo "hotel8/ vertical group"
	@grep -E '^[a-z-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

build: build-sdk build-services ## Build the group in DAG order

build-sdk: ## Build the hotel8 facade workspace (services depend on this)
	@cd hotel8-sdk && $(call stamp_env,hotel8-sdk) $(CARGO) build

build-services: build-sdk ## Build every hotel8 service repo
	@for s in $(SERVICES); do \
		echo "=== hotel8-$$s ==="; \
		(cd hotel8-$$s && $(call stamp_env,hotel8-$$s) $(CARGO) build) || exit 1; \
	done

test: ## Run the SDK facade tests + per-service suites
	@cd hotel8-sdk && $(call stamp_env,hotel8-sdk) $(CARGO) test
	@for s in $(SERVICES); do (cd hotel8-$$s && $(call stamp_env,hotel8-$$s) $(CARGO) test) || true; done

enroll: ## Enroll every hotel8 repo (composable registration, RS §6)
	@cd ../sentin8/sentin8-cli && $(call stamp_env,sentin8-cli) $(CARGO) run --bin sentin8-cli -- vertical enroll \
		$(patsubst %,../../hotel8/hotel8-%,$(SERVICES)) \
		$(patsubst %,../../hotel8/hotel8-%,$(APPS))

status: ## Per-repo HEADs
	@for d in */; do \
		[ -d "$$d/.git" ] || continue; \
		printf "%-22s %s\n" "$$d" "$$(git -C $$d log --oneline -1 2>/dev/null | head -c 60)"; \
	done
