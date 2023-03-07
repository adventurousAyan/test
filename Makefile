
CURRENT_DIR := $(shell pwd)
VERSION=3.6.3
VENV_DIR=$(shell pyenv root)/versions/${VERSION}
PYTHON=${VENV_DIR}/bin/python

BOLD := \033[1m
RESET := \033[0m

## Make sure you have `pyenv` and `pyenv-virtualenv` installed beforehand
##
## https://github.com/pyenv/pyenv
## https://github.com/pyenv/pyenv-virtualenv
##
## On a Mac: $ brew install pyenv pyenv-virtualenv

ifndef NAME
  NAME = src
endif

VIRTUALENV_DIR = ${CURRENT_DIR}/core-env

default: help

.PHONY : help
help:  ## Show this help
	@echo "$(BOLD)Minerva Core Nextgen Makefile$(RESET)"
	@echo "Please use 'make $(BOLD)target$(RESET)' where $(BOLD)target$(RESET) is one of:"
	@grep -h ':\s\+##' Makefile | column -tx -s# | awk -F ":" '{ print "  $(BOLD)" $$1 "$(RESET)" $$2 }'

.PHONY: isvirtualenv
isvirtualenv: ## Check Virtual Env
	@echo "$(BOLD)Check Virtual Env$(RESET)"
	@if [ -z "$(VIRTUALENV_DIR)" ]; then echo "ERROR: Not in a virtualenv." 1>&2; exit 1; fi


setup: ## Set Up Minerva Core App
	@echo "$(BOLD)Set Up Minerva Core App$(RESET)"
	make env

destroy: ## Remove Virtual Env
	@echo "$(BOLD)Remove Virtual Env$(RESET)"
	@rm -fr $(VIRTUALENV_DIR)

.ONESHELL:
env: ## Create Virtual Env
	@echo "$(BOLD)Create/Activate Virtual Environment$(RESET)"
	@echo $(VIRTUALENV_DIR)
	$(PYTHON) -m venv $(VIRTUALENV_DIR) && \
	. $(VIRTUALENV_DIR)/bin/activate && \
	make all-deps

all-deps: ## Installing All Deps
	@echo "$(BOLD)Installing All Deps$(RESET)"
	python3 -m pip install --upgrade pip==20.2 
	python3 -m pip install  --upgrade setuptools wheel
	python3 -m pip install -r base_image/requirements.txt
	cd src && python3 setup.py sdist bdist_wheel && \
	pip install dist/*.whl && \
	cd ..

minerva-deps: ## Installing Minerva Deps
	@echo "$(BOLD)Installing Minerva Depedencies$(RESET)"
	cd src && python3 setup.py sdist bdist_wheel && \
	pip install dist/*.whl && \
	cd ..

unit-test: ## Run Unit tests
	@echo "$(BOLD)Running tests$(RESET)"
	. $(VIRTUALENV_DIR)/bin/activate && \
	pytest tests/unit/ && \
	cd ..

.PHONY : clean
clean: ## Clean Up
	@echo "$(BOLD)Cleaning$(RESET)"
	find . -type f -name "*.DS_Store" -ls -delete
	find . | grep -E "(__pycache__|\.pyc|\.pyo)" | xargs rm -rf
	find . | grep -E ".pytest_cache" | xargs rm -rf
	find . | grep -E ".ipynb_checkpoints" | xargs rm -rf
	find . | grep -E ".egg-info" | xargs rm -rf
	find . -type d -name "build" | xargs rm -rf
	find . -type d -name "dist" | xargs rm -rf
	find . -type d -name ".eggs" | xargs rm -rf

.PHONY : isort
isort: ## Sorts imports using isort
	@echo "$(BOLD)Running isort$(RESET)"
	python3 -m pip install isort
	cd src && isort .

.PHONY : check-black
check-black: ## Sorts imports using isort
	@echo "$(BOLD)Checking black$(RESET)"
	@black --check src/minerva/ tests/

.PHONY: black
black:  ## Run the black tool and update files that need to
	@echo "$(BOLD)Running black$(RESET)"
	@black --target-version py36 .

.PHONY: pretty
pretty:  ## Run all code beautifiers (isort, black)
pretty: isort black

.PHONY: app
app:  ## Start the app
	./docker-up.sh docker-compose.yml

.PHONY: db
db:  ## Start the DB
	./docker-up.sh docker-compose-oracle-db.yml

