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

Reference the bases in your `kustomization.yaml`:

In vault's namespace:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
bases:
  - github.com/utilitywarehouse/vault-manifests//base/vault-namespace?ref=1.2.3-1
```

In client's namespaces:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
bases:
  - github.com/utilitywarehouse/vault-manifests//base/client-namespace?ref=1.2.3-1
```

Somewhere with permission to apply cluster-wide resources
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
bases:
  - github.com/utilitywarehouse/vault-manifests//base/cluster-wide?ref=1.2.3-1
```

## Examples

Build the examples [example](example/*):

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

# Step-by-step: setting up a full system with example configuration for a client app
This is an example of an application accessing an AWS bucket without managing passwords, making use of this vault setup plus some other companion systems.

<!-- vim-markdown-toc GFM -->

* [Overview of the elements of the system](#overview-of-the-elements-of-the-system)
* [Setting up Vault for Kubernetes auth and AWS credentials](#setting-up-vault-for-kubernetes-auth-and-aws-credentials)
	* [Deploying vault](#deploying-vault)
	* [Creating resources needed to configure Vault](#creating-resources-needed-to-configure-vault)
		* [Kubernetes authentication resources](#kubernetes-authentication-resources)
		* [AWS secrets resources](#aws-secrets-resources)
		* [Terraform applier state backend](#terraform-applier-state-backend)
	* [Creating Vault's backends configuration](#creating-vaults-backends-configuration)
	* [Deploy terraform applier](#deploy-terraform-applier)
	* [Setup alerts](#setup-alerts)
* [Configuring a new app to get aws credentials from Vault](#configuring-a-new-app-to-get-aws-credentials-from-vault)

<!-- vim-markdown-toc -->

## Overview of the elements of the system
* Client app: the application that needs access to some AWS resources
* Vault client sidecar: sidecar to the client app that fetches credentials from Vault and serves them via http
* Vault server: this vault server. Provides AWS credentials based on the Service Account requesting them
* Terraform applier for Vault: applies configuration to Vault from a git repo
* Vault pki: manages the PKI elements for Vault and it's clients

## Setting up Vault for Kubernetes auth and AWS credentials
We want a Vault server able to provide AWS roles credentials to specific kube SA. Vault configuration will live in its own repo, and will be applied to Vault using terraform-applier.

An example setup can be found [here](https://github.com/utilitywarehouse/kubernetes-manifests/tree/master/exp-1-aws/sys-vault).

### Deploying vault
* Setup necessary [cluster wide permissions](https://github.com/utilitywarehouse/vault-manifests/tree/master/example/cluster-wide) for Vault
* Set up [Vault](https://github.com/utilitywarehouse/vault-manifests/tree/master/example/vault-namespace) in a new dedicated namespace
### Creating resources needed to configure Vault
We need to create some resources on kube and AWS for Vault to use, and then configure Vault to use those resources.
#### Kubernetes authentication resources
* To allow pods to login into Vault using their SA, Vault needs to ask kube who those SA are. Vault needs a SA with `system:auth-delegator` permission, that would allow it to do authentication checks with the SA tokens trying to login.
* An [example](https://github.com/utilitywarehouse/kubernetes-manifests/blob/master/exp-1-aws/sys-vault/terraform-applier.yaml) of the SA and secret needed, living in Vault's namespace
* An [example](https://github.com/utilitywarehouse/kubernetes-manifests/blob/master/exp-1-aws/kube-system/05-auth-vault.yaml) with the token-authentication cluster role binding granting auth-delegator to the SA

#### AWS secrets resources
* The way Vault will get credentials for the client apps is by assuming roles. Vault just needs an IAM user with no permissions, since permission to assume the roles are granted in the roles themselves ([example](https://github.com/utilitywarehouse/terraform/blob/master/aws/dev/sys-vault-exp-1/credentials-provider.tf))
#### Terraform applier state backend
* We are using S3 backend, so we need to create the bucket and a user with permissions to access it ([example](https://github.com/utilitywarehouse/terraform/blob/master/aws/dev/sys-vault-exp-1/terraform-state.tf))

### Creating Vault's backends configuration
* Create a repo to host the vault terraform configuration [example](https://github.com/utilitywarehouse/sys-vault-terraform) and folders for each kubernetes cluster
* Configure the [kubernetes auth backend](https://github.com/utilitywarehouse/sys-vault-terraform/blob/master/exp-1-aws/backends/kubernetes-auth-method.tf)
* Configure the [aws secret backend](https://github.com/utilitywarehouse/sys-vault-terraform/blob/master/exp-1-aws/backends/aws-secrets-engine.tf)

### Deploy terraform applier
* Setup [terraform applier](https://github.com/utilitywarehouse/terraform-applier/tree/master/manifests/example) in vault's namespace, and configure it to sync with your vault terraform configuration repo
### Setup alerts
* Setup prometheus alerts like this [Vault](https://github.com/utilitywarehouse/kubernetes-manifests/blob/master/exp-1-aws/sys-prom/resources/prometheus-alerts.yaml) group

## Configuring a new app to get aws credentials from Vault
* Create a role with the permission required and grant AssumeRole permission to Vault's credential provider user ([example](https://github.com/utilitywarehouse/terraform/blob/naming/aws/dev/sys-aws-probe/main.tf))
* In your terraform vault configuration repository, link your applications's SA to the new role using our custom module ([example](https://github.com/utilitywarehouse/sys-vault-terraform/blob/master/exp-1-aws/kube-aws-credentials/main.tf))
* If not yet present, add the application's namespace to the `VAULT_CLIENT_NAMESPACES` list in Vault's PKI manager ([example](https://github.com/utilitywarehouse/kubernetes-manifests/blob/master/exp-1-aws/sys-vault/vault-pki.yaml))
* Configure the app to use our [Vault sidecar](https://github.com/utilitywarehouse/vault-kube-aws-credentials) to get credentials for the role ([example](https://github.com/utilitywarehouse/kubernetes-manifests/blob/master/exp-1-aws/labs/aws-probe.yaml))
