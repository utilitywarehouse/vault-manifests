SHELL := /bin/bash
SECRETS_GH_PLUGIN_VERSION=2.2.2

secrets_github_gpg_pub := "./plugin-secrets-github/martinbaillie.gpg"
secrets_github_sig := "./plugin-secrets-github/SHA256SUMS.sig"
secrets_github_sums := "./plugin-secrets-github/SHA256SUMS"

# target to download martinbaillie.gpg public key
# committing this key to keep offline copy to verify plugin SHA256SUMS file
.PHONY: update-secrets-github-plugin-gpg-key
update-secrets-github-plugin-gpg-key:
	curl -sS https://github.com/martinbaillie.gpg > $(secrets_github_gpg_pub)


# update-secrets-github-plugin will download SHA256SUMS and sig files for given version
# verify its signature and then parse SUM file to extract plugin binary's SHA256
# that SHA value will be used by script to register plugin with vault.
# vault does verification of actual plugin binary and registered SHA of the plugin
.PHONY: update-secrets-github-plugin
update-secrets-github-plugin:
	@wget -q -O $(secrets_github_sig) https://github.com/martinbaillie/vault-plugin-secrets-github/releases/download/v${SECRETS_GH_PLUGIN_VERSION}/SHA256SUMS.sig
	@wget -q -O $(secrets_github_sums) https://github.com/martinbaillie/vault-plugin-secrets-github/releases/download/v${SECRETS_GH_PLUGIN_VERSION}/SHA256SUMS
	@gpg --import $(secrets_github_gpg_pub)
	@gpg --verify $(secrets_github_sig) $(secrets_github_sums)
	@sd '^ENV SECRETS_GH_PLUGIN_VERSION=.*' 'ENV SECRETS_GH_PLUGIN_VERSION="$(SECRETS_GH_PLUGIN_VERSION)"' Dockerfile
	@PLUGIN_SHA=$$(grep vault-plugin-secrets-github-linux-amd64$$ $(secrets_github_sums) | cut -d' ' -f1); \
	echo "SHA:$$PLUGIN_SHA will be used to register plugin"; \
	sd '^ENV SECRETS_GH_PLUGIN_SHA=.*' 'ENV SECRETS_GH_PLUGIN_SHA="'"$$PLUGIN_SHA"'"' Dockerfile