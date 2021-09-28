SHELL := /bin/bash

release:
	@sd "newTag: master" "newTag: $(VERSION)" base/vault-namespace/kustomization.yaml
	@git add -- base/vault-namespace/kustomization.yaml
	@git commit -m "Release $(VERSION)"
	@sd "newTag: $(VERSION)" "newTag: master" base/vault-namespace/kustomization.yaml
	@git add -- base/vault-namespace/kustomization.yaml
	@git commit -m "Clean up release $(VERSION)"
