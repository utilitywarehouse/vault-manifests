SHELL := /bin/bash

# Hack to take arguments from command line
# Usage: `make release 1.3.2-1`
# https://stackoverflow.com/questions/6273608/how-to-pass-argument-to-makefile-from-command-line
release:
	@find . -type f \
	\( -name README.md -o -name kustomization.yaml \) \
	-exec sed -ri 's#[0-9]+\.[0-9]+\.[0-9]+-[0-9]+#$(filter-out $@,$(MAKECMDGOALS))#g' {} \;

%:		# matches any task name
	@:	# empty recipe = do nothing
