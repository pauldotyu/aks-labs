---
title: Build a GitOps-Driven Platform on AKS with the App of Apps Pattern
sidebar: Build a GitOps-Driven Platform on AKS with the App of Apps Pattern
---

# Build a GitOps-Driven Platform on AKS with the App of Apps Pattern

Welcome to the **Platform Engineering on AKS** workshop. This hands-on workshop will guide you through implementing a robust platform engineering environment using the Cloud Native pattern on Azure Kubernetes Service (AKS). The environment leverages GitOps practices and integrates tools such as [ArgoCD](https://argo-cd.readthedocs.io/en/stable/), and the [Cluster API Provider for Azure (CAPZ)](https://github.com/kubernetes-sigs/cluster-api-provider-azure) along with [Azure Service Operator (ASO)](https://azure.github.io/azure-service-operator/). By the end of this workshop, participants will be able to deploy infrastructure and application environments using these tools.

---

## Objectives

- Provide a foundational understanding of key tools in the platform engineering space
- Build a control plane AKS cluster using Azure CLI
- Bootstrap GitOps with ArgoCD
- Demonstrate how CAPZ and ASO can provision infrastructure and Kubernetes clusters
- Show how to deploy application environments on both existing AKS clusters and newly created dedicated clusters

:::tip
If you have used Infrastructure as Code tools like `teraform` to create resources in Azure, you can use the `asoctl` tool to convert these Azure resources into ASO deployments. To find out more about `asoctl` take a look [here](https://azure.github.io/azure-service-operator/tools/). You can download `asoctl` [here](https://github.com/Azure/azure-service-operator/releases/tag/v2.13.0)
:::
---

## Prerequisites

This module is part of a series. Before doing this lab you should've completed the [Platform Engineering lab using AKS, GitOps, CAPZ, and ASOv2](./aks-capz-aso.md). 

Before you continue, load the environment variables as defined in [Step 1: Create the AKS cluster](./aks-capz-aso.md#step-1-create-the-aks-cluster). 

```bash
source .envrc
```
---

# Platform Engineering: Exploring the App of Apps pattern


### Using the App of Apps pattern

[The App of Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/#app-of-apps-pattern) an approach where you use one parent Argo CD Application to declaratively manage many child Argo CD Applications.

This parent application acts as the single source of truth that bootstraps other apps by pointing to a directory (or chart) that contains YAML definitions of additional Argo CD Applications.

Think of it as a recursive GitOps pattern: your Argo CD app deploys other Argo CD apps.

---
Here is a summary of the applications installed by Argo CD in the cluster:

| Application Name                   | Purpose                                                                                                           |
|-------------------------------------|-------------------------------------------------------------------------------------------------------------------|
| cluster-addons                     | A general-purpose application for deploying shared or foundational cluster components (e.g., networking, storage, observability, etc.). Often used as a parent or umbrella app. |
| addon-aks-labs-gitops-argo-cd      | Installs and manages the Argo CD GitOps controller that syncs desired state from Git repositories to Kubernetes clusters. |
| addon-aks-labs-gitops-argo-events  | Argo Events, used to trigger workflows based on external events (webhooks, schedules, etc.). Useful for event-driven automation. |
| addon-aks-labs-gitops-argo-rollouts| Argo Rollouts, a Kubernetes controller for progressive delivery strategies like blue/green, canary, and experimentation. |
| addon-aks-labs-gitops-argo-workflows| Argo Workflows, a Kubernetes-native workflow engine for orchestrating CI/CD pipelines.                             |
| addon-aks-labs-gitops-cert-manager | Installs cert-manager, a controller that automatically provisions and renews TLS certificates (e.g., from Let’s Encrypt). |
| addon-aks-labs-gitops-kargo        | Deploys Kargo, an Argo ecosystem project for automating promotion of container images across environments based on predefined policies. |

---

Step 1: Bootstrap the cluster addons using Argo CD

Export the environment variables for your environment:

```bash
# Create the secret manifest
cat <<EOF> aks-labs-gitops.yaml
apiVersion: v1
kind: Secret
metadata:
  name: aks-labs-gitops
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
    akuity.io/argo-cd-cluster-name: ${AKS_CLUSTER_NAME}
    argo_rollouts_chart_version: 2.37.7
    argocd_chart_version: 7.6.10
    cluster_name: ${AKS_CLUSTER_NAME}
    enable_argo_events: "true"
    enable_argo_rollouts: "true"
    enable_argo_workflows: "true"
    enable_argocd: "true"
    enable_azure_crossplane_upbound_provider: "false"
    enable_cert_manager: "true"
    enable_cluster_api_operator: "false"
    enable_cluster_proportional_autoscaler: "false"
    enable_crossplane: "false"
    enable_crossplane_helm_provider: "false"
    enable_crossplane_kubernetes_provider: "false"
    enable_gatekeeper: "false"
    enable_gpu_operator: "false"
    enable_ingress_nginx: "false"
    enable_kargo: "true"
    enable_kube_prometheus_stack: "false"
    enable_kyverno: "false"
    enable_metrics_server: "false"
    enable_prometheus_adapter: "false"
    enable_secrets_store_csi_driver: "false"
    enable_vpa: "false"
    environment: control-plane
    kargo_chart_version: 0.9.1
  annotations:
    addons_repo_url: "${GITOPS_ADDONS_ORG}/${GITOPS_ADDONS_REPO}"
    addons_repo_basepath: "${GITOPS_ADDONS_BASEPATH}"
    addons_repo_path: "${GITOPS_ADDONS_PATH}"
    addons_repo_revision: "${GITOPS_ADDONS_REVISION}"
    cluster_name: ${AKS_CLUSTER_NAME}
    environment: control-plane
    infrastructure_provider: capz
    akspe_identity_id: "${AZURE_CLIENT_ID}"
    tenant_id: "${AZURE_TENANT_ID}"
    subscription_id: "${AZURE_SUBSCRIPTION_ID}"
type: Opaque
stringData:
  name: aks-labs-gitops
  server: https://kubernetes.default.svc
  config: |
    {
      "tlsClientConfig": {
        "insecure": false
      }
    }
EOF
```

Create the `aks-labs-gitops` secret on the Management Cluster:

```bash
kubectl apply -f aks-labs-gitops.yaml
```

Bootstrap the Argo CD applications in the cluster:

```bash
cat <<EOF> bootstrap-addons.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: cluster-addons
  namespace: argocd
spec:
  syncPolicy:
    preserveResourcesOnDeletion: true
  generators:
    - clusters:
        selector:
          matchExpressions:
            - key: akuity.io/argo-cd-cluster-name
              operator: NotIn
              values: [in-cluster]
  template:
    metadata:
      name: cluster-addons
    spec:
      project: default
      source:
        repoURL: '{{metadata.annotations.addons_repo_url}}'
        path: '{{metadata.annotations.addons_repo_basepath}}{{metadata.annotations.addons_repo_path}}'
        targetRevision: '{{metadata.annotations.addons_repo_revision}}'
        directory:
          recurse: true
          exclude: exclude/*
      destination:
        namespace: 'argocd'
        name: '{{name}}'
      syncPolicy:
        automated: {}
EOF
```

Apply it:

```bash
kubectl apply -f bootstrap-addons.yaml
```

![Argo Apps](./assets/argoCD-Applications.png)

### Sample 1: Create a new cluster as an Argo CD Application Set

In this first sample, we will create an Argo CD ApplicationSet that will deploy a new AKS cluster using a Helm Chart. The [Cluster API Provider Azure Managed Cluster Helm Chart
](https://github.com/mboersma/cluster-api-charts/tree/main/charts/azure-managed-cluster) will create CAPZ resources. 

:::info 
This example is a simplified version of the [Building a Platform Engineering Environment on Azure Kubernetes Service (AKS)](https://github.com/Azure-Samples/aks-platform-engineering/tree/main) repo. For a full, end to end solution, please check the Microsoft Learn documentation on [Building a Platform Engineering Environment on Azure Kubernetes Service (AKS)](https://learn.microsoft.com/en-us/samples/azure-samples/aks-platform-engineering/aks-platform-engineering/) showcases this example and more in details, including how to setup a platform engineering solution using Infrastructure as Code with Terraform.
:::

1. Create the cluster:

```bash
cat <<EOF> clusters-argo-applicationset.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: clusters
  namespace: argocd
spec:
  syncPolicy:
    preserveResourcesOnDeletion: true
  generators:
  - clusters:
      selector:
        matchLabels:
          environment: control-plane
  template:
    metadata:
      name: clusters
    spec:
      project: default
      source:
        repoURL: '{{metadata.annotations.addons_repo_url}}'
        targetRevision: '{{metadata.annotations.addons_repo_revision}}'
        path: 'base/clusters/{{metadata.annotations.infrastructure_provider}}'
      destination:
        name: '{{name}}'
        namespace: workload
      syncPolicy:
        retry:
          limit: 10
        automated: {}
        syncOptions:
          - CreateNamespace=true
EOF
```
Apply it:

```bash
kubectl apply -f clusters-argo-applicationset.yaml
```

2. Get the credentials for the new cluster named `aks1`

```bash
az aks get-credentials -n aks1 -g aks1
```

3. Deploy an application using Argo CD

On the newly created `aks1` cluster, we can now deploy an application. The `aks1` cluster comes with its own instance of `Argo CD` on the `default` namespace and we can, as a member of the dev team, deploy our application into the cluster:

```bash
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: aks-store-demo
  namespace: default
spec:
  project: default
  source:
      repoURL: https://github.com/Azure-Samples/aks-store-demo.git
      targetRevision: HEAD
      path: kustomize/overlays/dev
  syncPolicy:
      automated: {}
  destination:
      namespace: argocd
      server: https://kubernetes.default.svc
EOF
```

Once deployed, you should now see a new application in your `aks1` cluster:

![aks pet store](assets/aks-store-demo.png)

### Sample 2: Create new ASOv2 resources

To create other resources using ASOv2, you can follow the structure of the Git repo for this sample:

```bash
samples/
└──> resourcegroup/
    └──> rg.yaml  <-- contains your ResourceGroup manifest
```

:::note
From now on, when creating resources with ASOv2, we need to include the following annotation:

```bash 
  annotations:
    serviceoperator.azure.com/credential-from: aso-credentials
```

To illustrate this concept, lets create a new resource group:

1. Create a new `namespace`

```bash
kubectl create ns rg-example
```

2. Create a new `secret` scoped to the namespace

```bash
cat <<EOF> rg-example-aso-credentials.yaml
apiVersion: v1
kind: Secret
metadata:
 name: rg-example-aso-credentials
 namespace: rg-example
stringData:
 AZURE_SUBSCRIPTION_ID: "$AZURE_SUBSCRIPTION_ID"
 AZURE_TENANT_ID: "$AZURE_TENANT_ID"
 AZURE_CLIENT_ID: "$AZURE_CLIENT_ID"
 USE_WORKLOAD_IDENTITY_AUTH: "true"
EOF
```

Apply it:

```bash
kubectl apply -f rg-example-aso-credentials.yaml
```

3. Create the resource

```bash
cat <<EOF> rg-example.yaml
apiVersion: resources.azure.com/v1api20200601
kind: ResourceGroup
metadata:
  name: my-rg-example
  namespace: rg-example
  annotations:
    serviceoperator.azure.com/credential-from: rg-example-aso-credentials
spec:
  location: westus3
EOF
```

Apply it:

```bash
kubectl apply -f rg-example.yaml
```

Verify that it was created:

```bash
az group show -n my-rg-example
```

Expect:

```bash
{
  "id": "/subscriptions/6edaa0d4-86e4-431f-a3e2-d027a34f03c9/resourceGroups/my-rg-example",
  "location": "westus3",
  "managedBy": null,
  "name": "my-rg-example",
  "properties": {
    "provisioningState": "Succeeded"
  },
  "tags": null,
  "type": "Microsoft.Resources/resourceGroups"
}
```

To remove this resource, you can do use kubectl as such:

```bash
kubectl delete resourcegroup/my-rg-example -n rg-example
```

---

## Summary

In this lab, we accomplished the following:

- Bootstrapped the environment using GitOps principles.
- Installed Cluster API Provider for Azure (CAPZ) and Azure Service Operator (ASO) to enable infrastructure provisioning.
- Provisioned a workload cluster using Argo CD.
- Deployed the `AKS Store Demo` application to the workload cluster via Argo CD, using the _App of Apps_ pattern.
- Created an AKS cluster using a manifest based on ASOv2.