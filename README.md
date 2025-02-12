# vault-manifests

<!-- vim-markdown-toc GFM -->

* [Features](#features)
  * [Storage](#storage)
  * [Auto-initialization](#auto-initialization)
  * [Auto-unsealing](#auto-unsealing)
  * [Root Token](#root-token)
  * [PKI management](#pki-management)
  * [Prometheus metrics](#prometheus-metrics)
* [Usage](#usage)
* [Examples](#examples)
* [Requires](#requires)
* [Step by step guide of a complete system](#step-by-step-guide-of-a-complete-system)

<!-- vim-markdown-toc -->

This repository provides a Kustomize base for Hashicorp's Vault.

This is an opinionated setup based on the following principles/assumptions:

- Automated bootstrapping and management, with a minimum of manual steps
- Expendable storage. The assumption is that Vault is only providing short-lived
  credentials sourced from cloud providers and other secret backends. Configuration
  data is stored outside of Vault and can be reapplied for disaster recovery.

Be careful using it for other use-cases, as some design decision taken here may carry
security risks for different uses of Vault.

## Features

### Storage

The Vault cluster uses [Raft Integrated
Storage](https://www.vaultproject.io/docs/configuration/storage/raft) as its
storage backend.

This provides redundant storage without the operational overhead of maintaining
a separate storage backend.

### Auto-initialization

An `initializer` sidecar runs alongside each replica and is responsible for
forming the cluster when it is first deployed.

The first replica in the `vault` `StatefulSet` will initialize itself as the
leader. The second and third will join the first.

The process of initialization generates an [unseal key](#Auto-unsealing) and a [root
token](#Root-Token).

### Auto-unsealing

A Vault member starts in a ['sealed' state](https://www.vaultproject.io/docs/concepts/seal)
and must be unsealed by a master key. Typically it's considered best practice to
split the key using
[Shamir's Secret Sharing](https://en.wikipedia.org/wiki/Shamir%27s_Secret_Sharing)
so that multiple shards are required to unseal Vault. This means that Vault is not
compromised if a single shard leaks.

Multiple keys complicate the process of automating unsealing, so this setup opts
to generate a single unseal key during [initialization](vault-toolkit/vault-initializer.sh)
which is stored in a secret called `vault` under the key `unseal-key`.

The [`unsealer`](vault-toolkit/vault-unsealer.sh) sidecar uses this secret to
unseal Vault automatically when the replica starts.

### Root Token

When Vault is initialized it generates an initial root token which has full
access to Vault. The typical expectation is that you perform initial setup of an
alternative [authentication method](https://www.vaultproject.io/docs/auth) and
then delete the root token.

However, the setup provided by this base presumes that Vault will only be accessed and
configured by an automation system (see:
[terraform-applier](https://github.com/utilitywarehouse/terraform-applier),
[vault-kube-cloud-credentials](https://github.com/utilitywarehouse/vault-kube-cloud-credentials))
running in the same Kubernetes namespace and therefore the root token is
persisted to the `vault` secret under the key `root-token` for use by these
systems.

### PKI management

Vault uses TLS with a self-signed certificate. Clients communicating
with Vault need to hold the corresponding self-signed CA certificate.

In this deployment `cert-manager` is used to generate certificate using self 
signed issuer. [resources](base/vault-namespace/cert.yaml)

This CA certificate is made available via http endpoint using [vault-ca-cert](base/vault-namespace/ca-server.yaml) deployment. Since cert is rotated every 24h
clients are expected to fetch new cert before starting communication with vault.

### Prometheus metrics

The Prometheus metrics provided by Vault leave a lot to be desired:

- Elements that would ideally be labels in Prometheus are part of the metric name
  (https://github.com/hashicorp/vault/issues/9068)
- Metrics are translated naively from statsd which is event based, which creates
  problems with metric retention
  (https://github.com/hashicorp/vault/issues/7137)

To mitigate these issues metrics are exported by
[`statsd_exporter`](https://github.com/prometheus/statsd_exporter) with [custom
mappings](base/vault-namespace/resources/statsd-mappings.yaml) to create sane
metrics names and labels.

Each Vault replica also runs an instance of
[`vault-exporter`](https://github.com/giantswarm/vault-exporter) which exports
information about the state of the replica (i.e leadership status, whether Vault
is sealed or not).

## Usage

Reference the bases in your `kustomization.yaml`:

In vault's namespace:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
bases:
  - github.com/utilitywarehouse/vault-manifests//base/vault-namespace
```

Somewhere with permission to apply cluster-wide resources

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
bases:
  - github.com/utilitywarehouse/vault-manifests//base/cluster-wide
```

## Examples

Build the [examples](example/):

```
kustomize build example/vault-namespace
kustomize build example/cluster-wide
```

## Requires

- https://github.com/kubernetes-sigs/kustomize

`go get -u sigs.k8s.io/kustomize`

## Step by step guide of a complete system

This Vault setup is intended to be used with other elements to provide an easy
way for applications to access cloud resources.

[Here](complete-step-by-step-guide.md) is a complete step by step guide to easily
provide a kubernetes application access to an aws bucket.
