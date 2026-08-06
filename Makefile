TERRAFORM ?= terraform
DASHBOARDS := intake-error intake-performance
DASHBOARD ?= intake-error
DASHBOARD_ALIASES := init format fmt-check validate plan apply destroy output state-list migrate

PROJECT_DIR := $(CURDIR)
DASHBOARD_DIR := dashboards/$(DASHBOARD)
COMMON_TFVARS ?= $(PROJECT_DIR)/terraform.tfvars
DASHBOARD_TFVARS := $(PROJECT_DIR)/$(DASHBOARD_DIR)/dashboard.tfvars.json
TF := $(TERRAFORM) -chdir="$(DASHBOARD_DIR)"
TF_VAR_ARGS := -var-file="$(COMMON_TFVARS)" -var-file="$(DASHBOARD_TFVARS)"

.DEFAULT_GOAL := help

.PHONY: help list check-dashboard check-tfvars init fmt fmt-check validate plan apply destroy output state-list migrate-state import-intake-performance

help:
	@echo "Available dashboards: $(DASHBOARDS)"
	@echo
	@echo "Dashboard-specific commands:"
	@for dashboard in $(DASHBOARDS); do \
		echo "  $$dashboard:"; \
		for command in $(DASHBOARD_ALIASES); do \
			echo "    make $$command-$$dashboard"; \
		done; \
	done
	@echo
	@echo "Generic commands:"
	@echo "  make <command> DASHBOARD=<name>"
	@echo "  Commands: init, fmt, fmt-check, validate, plan, apply, destroy, output, state-list, migrate-state"
	@echo
	@echo "Existing dashboard imports:"
	@echo "  make import-intake-performance"

list:
	@printf '%s\n' $(DASHBOARDS)

check-dashboard:
	@test -n "$(DASHBOARD)" || (echo "DASHBOARD is required" && exit 1)
	@test -n "$(filter $(DASHBOARD),$(DASHBOARDS))" || (echo "Dashboard is not registered in Makefile: $(DASHBOARD)" && exit 1)
	@test -d "$(DASHBOARD_DIR)" || (echo "Unknown dashboard: $(DASHBOARD)" && exit 1)
	@test -f "$(DASHBOARD_TFVARS)" || (echo "Missing dashboard config: $(DASHBOARD_TFVARS)" && exit 1)

check-tfvars:
	@test -f "$(COMMON_TFVARS)" || (echo "Missing shared variables: $(COMMON_TFVARS). Copy terraform.tfvars.example first." && exit 1)

init: check-dashboard
	$(TF) init

fmt: check-dashboard
	$(TF) fmt

fmt-check: check-dashboard
	$(TF) fmt -check

validate: check-dashboard
	$(TF) validate

plan: check-dashboard check-tfvars
	$(TF) plan $(TF_VAR_ARGS)

apply: check-dashboard check-tfvars
	$(TF) apply $(TF_VAR_ARGS)

destroy: check-dashboard check-tfvars
	$(TF) destroy $(TF_VAR_ARGS)

output: check-dashboard
	$(TF) output

state-list: check-dashboard
	$(TF) state list

migrate-state: check-dashboard
	@sh scripts/migrate-local-state.sh "$(PROJECT_DIR)" "$(DASHBOARD)"

import-intake-performance: check-tfvars
	@sh scripts/import-intake-performance.sh "$(PROJECT_DIR)" "$(TERRAFORM)"

init-%:
	@$(MAKE) init DASHBOARD=$*

format-%:
	@$(MAKE) fmt DASHBOARD=$*

fmt-check-%:
	@$(MAKE) fmt-check DASHBOARD=$*

validate-%:
	@$(MAKE) validate DASHBOARD=$*

plan-%:
	@$(MAKE) plan DASHBOARD=$*

apply-%:
	@$(MAKE) apply DASHBOARD=$*

destroy-%:
	@$(MAKE) destroy DASHBOARD=$*

output-%:
	@$(MAKE) output DASHBOARD=$*

state-list-%:
	@$(MAKE) state-list DASHBOARD=$*

migrate-%:
	@$(MAKE) migrate-state DASHBOARD=$*
