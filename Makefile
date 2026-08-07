TERRAFORM ?= terraform
DASHBOARDS := intake-alerts intake-error intake-performance
DASHBOARD ?= intake-error
DASHBOARD_ALIASES := init format fmt-check validate workspace-new workspace-show workspace-list plan apply destroy output state-list migrate

PROJECT_DIR := $(CURDIR)
DASHBOARD_DIR := dashboards/$(DASHBOARD)
COMMON_TFVARS ?= $(PROJECT_DIR)/terraform.tfvars
DASHBOARD_TFVARS := $(PROJECT_DIR)/$(DASHBOARD_DIR)/dashboard.tfvars.json
override TFVARS_PROJECT_ID := $(strip $(shell sh scripts/read-posthog-project-id.sh "$(COMMON_TFVARS)" 2>/dev/null))
override PROJECT_WORKSPACE := project-$(TFVARS_PROJECT_ID)
TF := $(TERRAFORM) -chdir="$(DASHBOARD_DIR)"
TF_PROJECT := TF_WORKSPACE="$(PROJECT_WORKSPACE)" $(TF)
TF_VAR_ARGS := -var-file="$(COMMON_TFVARS)" -var-file="$(DASHBOARD_TFVARS)"

.DEFAULT_GOAL := help

.PHONY: help list check-dashboard check-tfvars check-project-id check-project-workspace init fmt fmt-check validate workspace-new workspace-show workspace-list plan apply destroy output state-list migrate-state import-intake-alerts import-intake-performance

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
	@echo "  Commands: init, fmt, fmt-check, validate, workspace-new, workspace-show, workspace-list, plan, apply, destroy, output, state-list, migrate-state"
	@echo
	@echo "Project workspace:"
	@echo "  Stateful commands automatically use project-<posthog_project_id> from terraform.tfvars."
	@echo "  Create it once per dashboard with make workspace-new-<dashboard-name>."
	@echo
	@echo "Existing dashboard imports:"
	@echo "  make import-intake-alerts"
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

check-project-id: check-tfvars
	@test -n "$(TFVARS_PROJECT_ID)" || (echo "posthog_project_id is missing from $(COMMON_TFVARS)." && exit 1)
	@case "$(TFVARS_PROJECT_ID)" in *[!0-9]*) echo "posthog_project_id must contain digits only: $(TFVARS_PROJECT_ID)"; exit 1;; esac

check-project-workspace: check-dashboard check-project-id
	@workspaces=`$(TF) workspace list` || exit $$?; \
	printf '%s\n' "$$workspaces" | awk -v wanted="$(PROJECT_WORKSPACE)" '{ sub(/^[* ]+/, "", $$0); if ($$0 == wanted) found = 1 } END { exit !found }' || { \
		echo "Missing Terraform workspace for PostHog project $(TFVARS_PROJECT_ID): $(PROJECT_WORKSPACE)"; \
		echo "Create it with: make workspace-new-$(DASHBOARD)"; \
		exit 1; \
	}

init: check-dashboard
	$(TF) init

fmt: check-dashboard
	$(TF) fmt

fmt-check: check-dashboard
	$(TF) fmt -check

validate: check-dashboard
	$(TF) validate

workspace-new: check-dashboard check-project-id
	$(TF) workspace new "$(PROJECT_WORKSPACE)"

workspace-show: check-project-workspace
	@echo "PostHog project ID: $(TFVARS_PROJECT_ID)"
	@echo "Terraform workspace: $(PROJECT_WORKSPACE)"

workspace-list: check-dashboard
	$(TF) workspace list

plan: check-project-workspace
	$(TF_PROJECT) plan $(TF_VAR_ARGS)

apply: check-project-workspace
	$(TF_PROJECT) apply $(TF_VAR_ARGS)

destroy: check-project-workspace
	$(TF_PROJECT) destroy $(TF_VAR_ARGS)

output: check-project-workspace
	$(TF_PROJECT) output

state-list: check-project-workspace
	$(TF_PROJECT) state list

migrate-state: check-dashboard check-project-id
	@sh scripts/migrate-local-state.sh "$(PROJECT_DIR)" "$(DASHBOARD)" "$(PROJECT_WORKSPACE)"

import-intake-performance: check-project-id
	@$(MAKE) check-project-workspace DASHBOARD=intake-performance
	@sh scripts/import-intake-performance.sh "$(PROJECT_DIR)" "$(TERRAFORM)" "$(PROJECT_WORKSPACE)" "$(TFVARS_PROJECT_ID)"

import-intake-alerts: check-project-id
	@$(MAKE) check-project-workspace DASHBOARD=intake-alerts
	@sh scripts/import-intake-alerts.sh "$(PROJECT_DIR)" "$(TERRAFORM)" "$(PROJECT_WORKSPACE)" "$(TFVARS_PROJECT_ID)"

init-%:
	@$(MAKE) init DASHBOARD=$*

format-%:
	@$(MAKE) fmt DASHBOARD=$*

fmt-check-%:
	@$(MAKE) fmt-check DASHBOARD=$*

validate-%:
	@$(MAKE) validate DASHBOARD=$*

workspace-new-%:
	@$(MAKE) workspace-new DASHBOARD=$*

workspace-show-%:
	@$(MAKE) workspace-show DASHBOARD=$*

workspace-list-%:
	@$(MAKE) workspace-list DASHBOARD=$*

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
