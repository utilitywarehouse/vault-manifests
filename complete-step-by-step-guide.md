# Step-by-step: setting up a full system with example configuration for a client app
This is an example of an application accessing an AWS bucket without managing passwords, making use of this vault setup plus some other companion systems.

<!-- vim-markdown-toc GFM -->

* [Overview of the elements of the system](#overview-of-the-elements-of-the-system)
* [Setting up Vault for Kubernetes auth and cloud provider credentials](#setting-up-vault-for-kubernetes-auth-and-cloud-provider-credentials)
  * [Deploying vault](#deploying-vault)
  * [Creating resources needed to configure Vault](#creating-resources-needed-to-configure-vault)
    * [Kubernetes authentication resources](#kubernetes-authentication-resources)
    * [AWS](#aws)
      * [Secrets resources](#secrets-resources)
      * [Terraform applier state backend](#terraform-applier-state-backend)
    * [GCP](#gcp)
      * [Secrets resources](#secrets-resources-1)
      * [Terraform applier state backend](#terraform-applier-state-backend-1)
  * [Creating Vault's backends configuration](#creating-vaults-backends-configuration)
  * [Deploy terraform applier](#deploy-terraform-applier)
  * [Setup alerts](#setup-alerts)
* [Configuring a new app to get aws credentials from Vault](#configuring-a-new-app-to-get-aws-credentials-from-vault)
  * [Prepare the client namespace](#prepare-the-client-namespace)
  * [Enable the new namespace](#enable-the-new-namespace)
  * [Configure Vault to grant a SA access to cloud resources](#configure-vault-to-grant-a-sa-access-to-cloud-resources)
    * [AWS](#aws-1)
    * [GCP](#gcp-1)
  * [Add our Vault sidecar to the app manifest](#add-our-vault-sidecar-to-the-app-manifest)

<!-- vim-markdown-toc -->

## Overview of the elements of the system
* Client app: the application that needs access to some cloud resources
* Vault client sidecar: sidecar to the client app that fetches credentials from
  Vault and serves them via http
* Vault server: this vault server. Provides cloud provider credentials based on
  the Service Account requesting them
* Terraform applier for Vault: applies configuration to Vault from a git repo
* Vault pki: manages the PKI elements for Vault and its clients

## Setting up Vault for Kubernetes auth and cloud provider credentials
We want a Vault server able to provide cloud provider credentials to specific
kubernetes ServiceAccounts. Vault configuration will live in its own repo, and
will be applied to Vault using terraform-applier.

Example setups:
- [AWS](https://github.com/utilitywarehouse/kubernetes-manifests/tree/master/exp-1-aws/sys-vault)
- [GCP](https://github.com/utilitywarehouse/kubernetes-manifests/tree/master/exp-1-gcp/sys-vault)

These are identical except for terraform-applier, which is explained below.

### Deploying vault
* Setup necessary [cluster wide permissions](/example/cluster-wide) for Vault
* Set up [Vault](/example/vault-namespace) in a new dedicated namespace

### Creating resources needed to configure Vault
We need to create some resources on kubernetes and on the cloud provider (AWS or
GCP) for Vault to use, and then configure Vault to use those resources.

#### Kubernetes authentication resources
These are identical, regardless of the cloud provider / vault secrets engine
used.

* To allow pods to login into Vault using their SA, Vault needs to ask kube who
  those SA are. Vault needs a SA with `system:auth-delegator` permission, that
  would allow it to do authentication checks with the SA tokens trying to login.
* An [example](https://github.com/utilitywarehouse/kubernetes-manifests/blob/master/exp-1-aws/sys-vault/terraform-applier.yaml)
  of the SA and secret needed, living in Vault's namespace
* An [example](https://github.com/utilitywarehouse/kubernetes-manifests/blob/master/exp-1-aws/kube-system/05-auth-vault.yaml)
  with the token-authentication cluster role binding granting auth-delegator to
  the SA

#### AWS
##### Secrets resources
* The way Vault will get credentials for the client apps is by assuming roles.
  Vault just needs an IAM user with no permissions, since permission to assume
  the roles are granted in the roles themselves ([example](https://github.com/utilitywarehouse/terraform/blob/master/aws/dev/sys-vault-exp-1/credentials-provider.tf))

##### Terraform applier state backend
* We are using S3 backend, so we need to create the bucket and a user with
  permissions to access it ([example](https://github.com/utilitywarehouse/terraform/blob/master/aws/dev/sys-vault-exp-1/terraform-state.tf))

#### GCP
##### Secrets resources
* The way Vault will get credentials for the client apps is by generating a GCP
  Service Account to issue access tokens for. Vault just needs a ServiceAccount
  with permissions to create Service Accounts and set IAM policies for them
  inside a given project ([example](https://github.com/utilitywarehouse/terraform/blob/master/gcp/system/sys-vault-exp-1/credentials-provider.tf))

##### Terraform applier state backend
* We are using a GCS backend, so we need to create the bucket and a Service
  Account with permissions to access it ([example](https://github.com/utilitywarehouse/terraform/blob/master/gcp/system/sys-vault-exp-1/terraform-state.tf))

### Creating Vault's backends configuration
* Create a repo to host the vault terraform configuration [example](https://github.com/utilitywarehouse/sys-vault-terraform)
  and folders for each kubernetes cluster
* Configure the [kubernetes auth backend](https://github.com/utilitywarehouse/sys-vault-terraform/blob/master/exp-1-aws/backends/kubernetes-auth-method.tf)

Configure a secrets engine backend:
* [aws secret backend](https://github.com/utilitywarehouse/sys-vault-terraform/blob/master/exp-1-aws/backends/aws-secrets-engine.tf)
* [gcp secret backend](https://github.com/utilitywarehouse/sys-vault-terraform/blob/master/exp-1-gcp/backends/gcp-secrets-engine.tf)

### Deploy terraform applier
Setup [terraform applier](https://github.com/utilitywarehouse/terraform-applier/tree/master/manifests/example)
in vault's namespace, and configure it to sync with your vault terraform
configuration repo:

* [AWS](https://github.com/utilitywarehouse/kubernetes-manifests/blob/master/exp-1-aws/sys-vault/terraform-applier-patch.yaml)
* [GCP](https://github.com/utilitywarehouse/kubernetes-manifests/blob/master/exp-1-gcp/sys-vault/terraform-applier-patch.yaml)

These are quite similar with the exception of the credentials provided and an
additional terraform variable for the GCP setup, `TF_VAR_environment`. See
[here](https://github.com/utilitywarehouse/tf_kube_creds_provider_via_vault/blob/master/gcp/variables.tf#L1-L9)
and [here](https://github.com/utilitywarehouse/documentation/blob/master/infra/operational/vault-gcp-sa-cleanup.md)
for an explanation.

### Setup alerts
* Setup prometheus alerts like this [Vault](https://github.com/utilitywarehouse/kubernetes-manifests/blob/master/exp-1-aws/sys-prom/resources/prometheus-alerts.yaml) group

## Configuring a new app to get aws credentials from Vault

### Prepare the client namespace
Create vault-tls configmap and allow vault-pki to edit
configmaps in the client namespace ([example](/example/client-namespace))

### Enable the new namespace
* Add the application's namespace to the `VAULT_CLIENT_NAMESPACES` list in
  Vault's PKI manager ([example](https://github.com/utilitywarehouse/kubernetes-manifests/blob/master/exp-1-aws/sys-vault/vault-pki-patch.yaml))
* Adjust network policies to allow the new application to talk to Vault's

### Configure Vault to grant a SA access to cloud resources

#### AWS
* Create a role with the permission required and grant AssumeRole permission
  to Vault's credential provider user ([example](https://github.com/utilitywarehouse/terraform/blob/master/aws/dev/sys-aws-probe/main.tf))
* In your terraform vault configuration repository, link your applications's
  SA to the new role using our custom module ([example](https://github.com/utilitywarehouse/sys-vault-terraform/blob/master/exp-1-aws/kube-aws-credentials/roles-linked-to-apps.tf))

#### GCP
In your terraform vault configuration repository, link your applications's
SA to the new role using our custom module ([example](https://github.com/utilitywarehouse/sys-vault-terraform/blob/master/exp-1-gcp/kube-gcp-credentials/roles-linked-to-apps.tf))

### Add our Vault sidecar to the app manifest
Configure the app to use our [Vault sidecar](https://github.com/utilitywarehouse/vault-kube-cloud-credentials)
to get credentias for the role
* [AWS example](https://github.com/utilitywarehouse/kubernetes-manifests/blob/master/exp-1-aws/labs/aws-probe.yaml)
* [GCP example](https://github.com/utilitywarehouse/vault-kube-cloud-credentials/blob/master/example/gcp-probe.yaml)
