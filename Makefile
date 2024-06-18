#!/usr/bin/make
SHELL := /bin/bash

include project.env


.PHONY: help
help:: ## This info
	@echo
	@cat Makefile | grep -E '^[a-zA-Z\/_-]+:.*?## .*$$' | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
	@echo


.PHONY: up
up: ## Run the service and its docker dependencies, using a cached build if available
	@echo "Running $@"
	docker compose --env-file=project.env --file docker-compose.yaml up --detach


.PHONY: down
down: ## Stop and remove this service's docker set
	@echo "Running $@"
	docker compose --env-file=project.env --file docker-compose.yaml down


.PHONY: build
build: ## Build this service, removing the previous image
	@echo "Running $@"
	docker compose --env-file=project.env --file docker-compose.yaml build --force-rm --pull


.PHONY: clean
clean: ## Tear down all project assets
	@echo "Running $@"
	docker compose --env-file=project.env --file docker-compose.yaml down -v
