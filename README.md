# vault-manifests

Table of Contents
=================

   * [vault-manifests](#vault-manifests)
   * [Table of Contents](#table-of-contents)
      * [Features](#features)
      * [Considerations of this Vault setup](#considerations-of-this-vault-setup)
      * [Usage](#usage)
      * [Examples](#examples)
      * [Requires](#requires)
      * [Step by step guide of a complete system](#step-by-step-guide-of-a-complete-system)

Created by [gh-md-toc](https://github.com/ekalinin/github-markdown-toc)

This repository provides a Kustomize base for Hashicorp's Vault.

**IMPORTANT**: This setup is aimed at a very specific use case. Be careful using it for other use-cases, as some design decision taken here may carry security risks for different uses of Vault.

## Features
* Self-initialization and self-unseal
* Prometheus metrics
* PKI management with aggressive rotation (CA key gets recreated every 24h)
* Highly Available

## Considerations of this Vault setup
* Security considerations based on: configuration via terraform using root token, clients login via kube SA, secrets provided by cloud providers engines (aws/gcp)
* Vault state is driven via configuration: vault can be wiped and recreated at will. There's no need for backups or seal/unseal procedures. If something goes wrong, delete and recreate
* Namespace admins have full-access to vault. The root token, the single unseal key and the TLS secrets all live in the namespace next to vault server
* All the possible vault clients must be controlled by the vault admins. This is needed to allow daily CA key rotation

## Usage

Reference the bases in your `kustomization.yaml`:

In vault's namespace:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
bases:
  - github.com/utilitywarehouse/vault-manifests//base/vault-namespace?ref=1.5.0-1
```

In client's namespaces:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
bases:
  - github.com/utilitywarehouse/vault-manifests//base/client-namespace?ref=1.5.0-1
```

Somewhere with permission to apply cluster-wide resources
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
bases:
  - github.com/utilitywarehouse/vault-manifests//base/cluster-wide?ref=1.5.0-1
```

## Examples

Build the examples [example](example/):

```
kustomize build example/vault-namespace
kustomize build example/client-namespace
kustomize build example/cluster-wide
```

## Requires

- https://github.com/kubernetes-sigs/kustomize

```
go get -u sigs.k8s.io/kustomize
```

## Step by step guide of a complete system
This Vault setup is intended to be used with other elements to provide an easy way for applications to access cloud resources. [Here](complete-step-by-step-guide.md) is a complete step by step guide to easily provide a kubernetes application access to an aws bucket.
