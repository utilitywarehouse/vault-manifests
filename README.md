# vault-manifests

This repository provides a Kustomize base for Hashicorp's Vault.

## Usage

Reference it in your `kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
bases:
  - github.com/utilitywarehouse/vault-manifests//base?ref=1.2.3-1
```

## Example

Build the example [example](example/):

```
kustomize build example/
```

## Requires

- https://github.com/kubernetes-sigs/kustomize

```
go get -u sigs.k8s.io/kustomize
```
