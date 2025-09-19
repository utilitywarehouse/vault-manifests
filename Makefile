SHELL := /bin/bash

SEC_GITHUB_PLUGIN_VERSION=2.3.0

TMPDIR := $(shell mktemp -d)
secrets_github_sig := "${TMPDIR}/SHA256SUMS.sig"
secrets_github_sums := "${TMPDIR}/SHA256SUMS"

# update-secrets-github-plugin will download SHA256SUMS and sig files for given version
# verify its signature and then parse SUM file to extract plugin binary's SHA256
# that SHA value will be used by script to register plugin with vault.
# vault does verification of actual plugin binary and registered SHA of the plugin
.PHONY: update-secrets-github-plugin
update-secrets-github-plugin:
	@curl -sSL -o $(secrets_github_sig) https://github.com/martinbaillie/vault-plugin-secrets-github/releases/download/v${SEC_GITHUB_PLUGIN_VERSION}/SHA256SUMS.sig
	@curl -sSL -o $(secrets_github_sums) https://github.com/martinbaillie/vault-plugin-secrets-github/releases/download/v${SEC_GITHUB_PLUGIN_VERSION}/SHA256SUMS
	@curl -sS https://github.com/martinbaillie.gpg | gpg --import -
	@gpg --verify $(secrets_github_sig) $(secrets_github_sums)
	@sd '^ENV SEC_GITHUB_PLUGIN_VERSION=.*' 'ENV SEC_GITHUB_PLUGIN_VERSION="$(SEC_GITHUB_PLUGIN_VERSION)"' vault-toolkit/Dockerfile
	@PLUGIN_SHA=$$(grep vault-plugin-secrets-github-linux-amd64$$ $(secrets_github_sums) | cut -d' ' -f1); \
	echo "SHA:$$PLUGIN_SHA will be used to register plugin"; \
	sd '^ENV SECRETS_GH_PLUGIN_SHA=.*' 'ENV SECRETS_GH_PLUGIN_SHA="'"$$PLUGIN_SHA"'"' vault-toolkit/Dockerfile

release:
	@sd "newTag: master" "newTag: $(VERSION)" base/vault-namespace/kustomization.yaml
	@git add -- base/vault-namespace/kustomization.yaml
	@git commit -m "Release $(VERSION)"
	@sd "newTag: $(VERSION)" "newTag: master" base/vault-namespace/kustomization.yaml
	@git add -- base/vault-namespace/kustomization.yaml
	@git commit -m "Clean up release $(VERSION)"
