# vault-manifests

This repository provides a Kustomize base for Hashicorp's Vault.

**IMPORTANT**: This setup is aimed at a very specific use case. Be careful using it for other use-cases, as some design decision taken here may carry security risks for different uses of Vault.

## Features
* Local auto-initialization and auto-unseal
* Prometheus metrics
* PKI management with aggressive rotation (CA key gets recreated every 24h)
* Highly Available

## Considerations of this Vault setup
* Security considerations based on: configuration via terraform using root token, clients login via kube SA, secrets provided by cloud providers engines (aws/gcp)
* Vault state is driven via configuration: vault can be wiped and recreated at will. There's no need for backups or seal/unseal procedures. If something goes wrong, delete and recreate
* Namespace admins have full-access to vault. The root token, the single unseal key and the TLS secrets all live in the namespace next to vault server
* All the possible vault clients are controlled by the vault admins. This is needed to allow daily CA key rotation

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
