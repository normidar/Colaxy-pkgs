DEFAULT_GOAL := help

.PHONY: help
help: ## List available commands
	@echo "Available make commands:";
	@echo "";
	@grep -hE '^[a-zA-Z_:-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}';
	@echo "";

# The toolchain is pinned in mise.toml; `mise install` picks it up. The former
# per-package Makefiles shelled out to `fvm`, which this repo does not use.
.PHONY: setup
setup: ## Install the pinned toolchain and resolve the workspace
	mise install
	dart pub global activate melos
	flutter pub get

.PHONY: ci
ci: analyze test ## Run everything CI runs

.PHONY: analyze
analyze: ## Analyze every package
	melos run analyze

.PHONY: format
format: ## Format every package
	melos run format

.PHONY: fix
fix: ## Apply `dart fix` to every package
	melos run fix

.PHONY: lint
lint: ## Analyze and format
	melos run lint

.PHONY: test
test: ## Run every package's tests
	melos run test

.PHONY: coverage
coverage: ## Run tests with coverage
	melos run test:coverage

.PHONY: build
build: ## Run build_runner in every package that needs it
	melos exec --depends-on=build_runner -- dart run build_runner build

.PHONY: get
get: ## Resolve workspace dependencies
	flutter pub get

.PHONY: outdated
outdated: ## Show dependencies with newer versions
	flutter pub outdated

.PHONY: publish-check
publish-check: ## Validate packages without uploading
	melos run pub:check

.PHONY: publish
publish: ## Publish updated packages to pub.dev
	melos run pub:release
