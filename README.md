# vault-manifests

This repository provides a Kustomize base for Hashicorp's Vault.

## Usage

Reference it in your `kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
bases:
  - github.com/utilitywarehouse/vault-manifests//base?ref=1.2.0-1
```

## Example

For a full example of a Kustomize overlay please refer to the provider specific example:

- [aws](example/aws)

## Requires

- https://github.com/kubernetes-sigs/kustomize

```
go get -u sigs.k8s.io/kustomize
```
