SHELL := /bin/bash

# Usage in README.md#release-process
release:
	@sd "newTag: master" "newTag: $(VERSION)" base/vault-namespace/kustomization.yaml
	@git add -- base/vault-namespace/kustomization.yaml
	@git commit -m "Release $(VERSION)"
	@git tag "$(VERSION)"
	@sd "newTag: $(VERSION)" "newTag: master" base/vault-namespace/kustomization.yaml
	@git add -- base/vault-namespace/kustomization.yaml
	@git commit -m "Clean up release $(VERSION)"
