---
title: Updates and Multi-Cluster Management
---

# Updates and Multi-Cluster Management

Maintaining your AKS cluster's updates is crucial for operational hygiene. Neglecting this can lead to severe issues, including losing support and becoming vulnerable to known CVEs (Common Vulnerabilities and Exposures) attacks. In this workshop, we will look and examine all tiers of your AKS infrastructure, and discuss and show the procedures and best practices to keep your AKS cluster up-to-date.

---

## Objectives

After completing this workshop, you will be able to:

- Upgrade the Kubernetes API server and nodes in your AKS cluster
- Upgrade the node image in your AKS cluster
- Configure maintenance windows for your AKS cluster
- Manage multiple AKS clusters with Azure Kubernetes Fleet Manager

---

## Pre-requisites

Before you begin, please make sure that you have provisioned a lab environment. Head over to [Lab Environment Setup](../getting-started/setting-up-lab-environment#lab-environment-setup) and follow the instructions to provision the required resources. Once you've provisioned the resources and [created and AKS cluster](../getting-started/setting-up-lab-environment#creating-an-aks-cluster) come back here to continue with the workshop.

---

## API Server upgrades

AKS is a managed Kubernetes service provided by Azure. Even though AKS is managed, flexibility has been given to customer on controlling the version of the API server they use in their environment. As newer versions of Kubernetes become available, those versions are tested and made available as part of the service. As newer versions are provided, older versions of Kubernetes are phased out of the service and are no longer available to deploy. Staying within the spectrum of supported versions, will ensure you don't compromise support for your AKS cluster.

You have two options for upgrading your AKS API server, you can do manual upgrades at your own designated schedule, or you can configure cluster to subscribe to an auto-upgrade channel. These two options provides you with the flexibility to adopt the most appropriate choice depending on your organizations policies and procedures.

:::note

When you upgrade a supported AKS cluster, you can't skip Kubernetes minor versions. For more information please see [Kubernetes version upgrades](https://learn.microsoft.com/azure/aks/upgrade-aks-cluster?tabs=azure-cli#kubernetes-version-upgrades)

:::

### Manually Upgrading the API Server and Nodes

The first step in manually upgrading your AKS API server is to view the current version, and the available upgrade versions.

```bash
az aks get-upgrades \
--resource-group ${RG_NAME} \
--name ${AKS_NAME} \
--output table
```

We can also, quickly look at the current version of Kubernetes running on the nodes in the nodepools by running the following:

```bash
kubectl get nodes
```

We can see all of the nodes in both the system and user node pools are at version **1.29.9** as well.

```text
NAME                                 STATUS   ROLES    AGE    VERSION
aks-systempool-14753261-vmss000000   Ready    <none>   123m   v1.29.9
aks-systempool-14753261-vmss000001   Ready    <none>   123m   v1.29.9
aks-systempool-14753261-vmss000002   Ready    <none>   123m   v1.29.9
aks-userpool-27827974-vmss000000     Ready    <none>   95m    v1.29.9
```

Run the following command to upgrade the current cluster API server, and the Kubernetes version running on the nodes, from version **1.29.9** to version **1.30.5**.

```bash
az aks upgrade \
--resource-group ${RG_NAME} \
--name ${AKS_NAME} \
--kubernetes-version "1.30.5"
```

:::note

The az aks upgrade command has the ability to separate the upgrade operation to specify just the control plane and/or the node version. In this lab we will run the command that will upgrade both the control plan and nodes at the same time.

:::

Follow the prompts to confirm the upgrade operation. Once the AKS API version has been completed on both the control plane and nodes, you will see a completion message with the updated Kubernetes version shown.

### Setting up the auto-upgrade channel for the API Server and Nodes

A more preferred method for upgrading your AKS API server and nodes is to configure the cluster auto-upgrade channel for your AKS cluster. This feature allow you a "set it and forget it" mechanism that yields tangible time and operational cost benefits. By enabling auto-upgrade, you can ensure your clusters are up to date and don't miss the latest features or patches from AKS and upstream Kubernetes.

There are several auto-upgrade channels you can subscribe your AKS cluster to. Those channels include **none**, **patch**, **stable**, and **rapid**. Each channel provides a different upgrade experience depending on how you would like to keep your AKS clusters upgraded. For a more detailed explanation of each channel, please view the [cluster auto-upgrade channels](https://learn.microsoft.com/azure/aks/auto-upgrade-cluster?tabs=azure-cli#cluster-auto-upgrade-channels) table.

For this lab demonstration, we will configure the AKS cluster to subscribe to the **patch** channel. The patch channel will automatically upgrades the cluster to the latest supported patch version when it becomes available while keeping the minor version the same.

Run the following command to set the auto-upgrade channel.

```bash
az aks update \
--resource-group ${RG_NAME} \
--name ${AKS_NAME} \
--auto-upgrade-channel patch
```

Once the auto-upgrade channel subscription has been enabled for your cluster, you will see the **upgradeChannel** property updated to the chosen channel in the output.

:::important

Configuring your AKS cluster to an auto-upgrade channel can have impact on the availability of workloads running on your cluster. Please review the additional options available to [Customize node surge upgrade](https://learn.microsoft.com/azure/aks/upgrade-aks-cluster?tabs=azure-cli#customize-node-surge-upgrade).

:::

## Node image updates

In addition to you being able to upgrade the Kubernetes API versions of both your control plan and nodepool nodes, you can also upgrade the operating system (OS) image of the VMs for your AKS cluster. AKSregularly provides new node images, so it's beneficial to upgrade your node images frequently to use the latest AKS features. Linux node images are updated weekly, and Windows node images are updated monthly.

Upgrading node images is critical to not only ensuring the latest Kubernetes API functionality will be available from the OS, but also to ensure that the nodes in your AKS cluster have the latest security and CVE patches to prevent any vulnerabilities in your environment.

### Manually Upgrading AKS Node Image

When planning to manually upgrade your AKS cluster, it's good practice to view the available images.

Run the following command to view the available images for your the system node pool.

```bash
az aks nodepool get-upgrades \
--resource-group ${RG_NAME} \
--cluster-name ${AKS_NAME} \
--nodepool-name systempool
```

The command output shows the **latestNodeImageVersion** available for the nodepool.

Check the current node image version for the system node pool by running the following command.

```bash
az aks nodepool show \
--resource-group ${RG_NAME} \
--cluster-name ${AKS_NAME} \
--name systempool \
--query "nodeImageVersion"
```

In this particular case, the system node pool image is the most recent image available as it matches the latest image version available, so there is no need to do an upgrade operation for the node image. If you needed to upgrade your node image, you can run the following command which will update all the node images for all node pools connected to your cluster.

```bash
az aks upgrade \
--resource-group ${RG_NAME} \
--cluster-name ${AKS_NAME} \
--node-image-only
```

## Maintenance windows

Maintenance windows provides you with the predictability to know when maintenance from Kubernetes API updates and/or node OS image updates will occur. The use of maintenance windows can help align to your current organizational operational policies concerning when services are expected to not be available.

There are currently three configuration schedules for maintenance windows, **default**, **aksManagedAutoUpgradeSchedule**, and **aksManagedNodeOSUpgradeSchedule**. For more specific information on these configurations, please see [Schedule configuration types for planned maintenance](https://learn.microsoft.com/azure/aks/planned-maintenance?tabs=azure-cli#schedule-configuration-types-for-planned-maintenance).

It is recommended to use **aksManagedAutoUpgradeSchedule** for all cluster upgrade scenarios and aksManagedNodeOSUpgradeSchedule for all node OS security patching scenarios.

:::note

The default option is meant exclusively for AKS weekly releases. You can switch the default configuration to the **aksManagedAutoUpgradeSchedule** or **aksManagedNodeOSUpgradeSchedule** configuration by using the `az aks maintenanceconfiguration update` command.

:::

When creating a maintenance window, it is good practice to see if any existing maintenance windows have already been configured. Checking to see if existing maintenance windows exists will avoid any conflicts when applying the setting. To check for the maintenance windows on an existing AKS cluster, run the following command:

```bash
az aks maintenanceconfiguration list \
--resource-group ${RG_NAME} \
--cluster-name ${AKS_NAME}
```

If you receive **[]** as output, this means no maintenance windows exists for the AKS cluster specified.

### Adding an AKS Cluster Maintenance Windows

Maintenance window configuration is highly configurable to meet the scheduling needs of your organization. For an in-depth understanding of all the properties available for configuration, please see the [Create a maintenance window](https://learn.microsoft.com/azure/aks/planned-maintenance?tabs=azure-cli#create-a-maintenance-window) guide.

The following command will create a **default** configuration that schedules maintenance to run from 1:00 AM to 2:00 AM every Sunday.

```bash
az aks maintenanceconfiguration add \
--resource-group ${RG_NAME} \
--cluster-name ${AKS_NAME} \
--name default \
--weekday Sunday \
--start-hour 1
```

## Managing Multiple AKS Clusters with Azure Fleet

Azure Kubernetes Fleet Manager (Fleet) enables at-scale management of multiple Azure Kubernetes Service (AKS) clusters. Fleet supports the following scenarios:

- Create a Fleet resource and join AKS clusters across regions and subscriptions as member clusters
- Orchestrate Kubernetes version upgrades and node image upgrades across multiple clusters by using update runs, stages, and groups
- Automatically trigger version upgrades when new Kubernetes or node image versions are published (preview)
- Create Kubernetes resource objects on the Fleet resource's hub cluster and control their propagation to member clusters
- Export and import services between member clusters, and load balance incoming layer-4 traffic across service endpoints on multiple clusters (preview)

For this section of the lab we will focus on two AKS Fleet Manager features, creating a fleet and joining member clusters, and propagating resources from a hub cluster to a member clusters.

You can find and learn about additional AKS Fleet Manager concepts and functionality on the [Azure Kubernetes Fleet Manager](https://learn.microsoft.com/azure/kubernetes-fleet/) documentation page.

### Create Additional AKS Cluster

:::note

If you already have an additional AKS cluster, in addition to your original lab AKS cluster, you can skip this section.

:::

To understand how AKS Fleet Manager can help manage multiple AKS clusters, we will need to create an additional AKS cluster to join as a member cluster. The following commands and instructions will deploy an additional AKS cluster into the same Azure resource group as your existing AKS cluster. For this lab purposes, it is not necessary to deploy the additional cluster in a region and/or subscription to show the benefits of AKS Fleet Manager.

Run the following command to create a new environment variable for the name of the additional AKS cluster.

```bash
AKS_NAME_2="${AKS_NAME}-2"
```

Run the following command to create a new AKS cluster.

```bash
az aks create \
--resource-group ${RG_NAME} \
--name ${AKS_NAME_2} \
--no-wait
```

This command will take a few minutes to complete. You can proceed with the next steps while the command is running.

### Create and configure Access for a Kubernetes Fleet Resource with Hub Cluster

Since this lab will be using AKS Fleet Manager for Kubernetes object propagation, you will need to create the Fleet resource with the hub cluster enabled by specifying the --enable-hub parameter with the az fleet create command. The hub cluster will orchestrate and manage the Fleet member clusters. We will add the lab's original AKS cluster and the newly created additional cluster as a member of the Fleet group in a later step.

In order to use the AKS Fleet Manager extension, you will need to install the extension. Run the following command to install the AKS Fleet Manager extension.

```bash
az extension add --name fleet
```

Run the following command to create new environment variables for the Fleet resource name and reload the environment variables.

```bash
FLEET_NAME="myfleet${RANDOM}"
```

Next run the following command to create the Fleet resource with the hub cluster enabled.

```bash
FLEET_ID="$(az fleet create \
--resource-group ${RG_NAME} \
--name ${FLEET_NAME} \
--location ${LOCATION} \
--enable-hub \
--query id \
--output tsv)"
```

Once the Kubernetes Fleet hub cluster has been created, we will need to gather the credential information to access it. This is similar to using the `az aks get-credentials` command on an AKS cluster. Run the following command to get the Fleet hub cluster credentials.

```bash
az fleet get-credentials \
--resource-group ${RG_NAME} \
--name ${FLEET_NAME}
```

Now that you have the credential information merged to your local Kubernetes config file, we will need to configure and authorize Azure role access for your account to access the Kubernetes API for the Fleet resource.

Once we have all of the terminal environment variables set, we can run the command to add the Azure account to be a **Azure Kubernetes Fleet Manager RBAC Cluster Admin** role on the Fleet resource.

```bash
az role assignment create \
--role "Azure Kubernetes Fleet Manager RBAC Cluster Admin" \
--assignee ${USER_ID} \
--scope ${FLEET_ID}
```

### Joining Existing AKS Cluster to the Fleet

Now that we have our Fleet hub cluster created, along with the necessary Fleet API access, we're now ready to join our AKS clusters to Fleet as member servers. To join AKS clusters to Fleet, we will need the Azure subscription path to each AKS object. To get the subscription path to your AKS clusters, you can run the following commands.

```bash
AKS_FLEET_CLUSTER_1_NAME="$(echo ${AKS_NAME} | tr '[:upper:]' '[:lower:]')"
AKS_FLEET_CLUSTER_2_NAME="$(echo ${AKS_NAME_2} | tr '[:upper:]' '[:lower:]')"
AKS_FLEET_CLUSTER_1_ID="$(az aks show --resource-group ${RG_NAME} --name ${AKS_FLEET_CLUSTER_1_NAME} --query "id" --output tsv)"
AKS_FLEET_CLUSTER_2_ID="$(az aks show --resource-group ${RG_NAME} --name ${AKS_FLEET_CLUSTER_2_NAME} --query "id" --output tsv)"
```

Run the following command to join both AKS clusters to the Fleet.

```bash
# add first AKS cluster to the Fleet
az fleet member create \
--resource-group ${RG_NAME} \
--fleet-name ${FLEET_NAME} \
--name ${AKS_FLEET_CLUSTER_1_NAME} \
--member-cluster-id ${AKS_FLEET_CLUSTER_1_ID}

# add the second AKS cluster to the Fleet
az fleet member create \
--resource-group ${RG_NAME} \
--fleet-name ${FLEET_NAME} \
--name ${AKS_FLEET_CLUSTER_2_NAME} \
--member-cluster-id ${AKS_FLEET_CLUSTER_2_ID}
```

Run the following command to verify both AKS clusters have been added to the Fleet.

```bash
kubectl get memberclusters
```

### Propagate Resources from a Hub Cluster to Member Clusters

The ClusterResourcePlacement API object is used to propagate resources from a hub cluster to member clusters. The ClusterResourcePlacement API object specifies the resources to propagate and the placement policy to use when selecting member clusters. The ClusterResourcePlacement API object is created in the hub cluster and is used to propagate resources to member clusters. This example demonstrates how to propagate a namespace to member clusters using the ClusterResourcePlacement API object with a PickAll placement policy.

:::important

Before running the following commands, make sure your `kubectl conifg` has the Fleet hub cluster as it's current context. To check your current context, run the `kubectl config current-context` command. You should see the output as **hub**. If the output is not **hub**, please run `kubectl config set-context hub`.

:::

Run the following command to create a namespace to place onto the member clusters.

```bash
kubectl create namespace my-fleet-ns
```

Run the following command to create a ClusterResourcePlacement API object in the hub cluster to propagate the namespace to the member clusters.

```bash
kubectl apply -f - <<EOF
apiVersion: placement.kubernetes-fleet.io/v1beta1
kind: ClusterResourcePlacement
metadata:
  name: my-lab-crp
spec:
  resourceSelectors:
    - group: ""
      kind: Namespace
      version: v1
      name: my-fleet-ns
  policy:
    placementType: PickAll
EOF
```

Check the progress of the resource propagation using the following command.

```bash
kubectl get clusterresourceplacement my-lab-crp
```

View the details of the ClusterResourcePlacement object using the following command.

```bash
kubectl describe clusterresourceplacement my-lab-crp
```

Now if you switch your context to one of the member clusters, you should see the namespace **my-fleet-ns** has been propagated to the member cluster.

```bash
kubectl config set-context ${AKS_FLEET_CLUSTER_1_NAME}
```

You should see the namespace **my-fleet-ns** in the list of namespaces.

This is a simple example of how you can use AKS Fleet Manager to manage multiple AKS clusters. There are many more features and capabilities that AKS Fleet Manager provides to help manage and operate multiple AKS clusters. For more information on AKS Fleet Manager, see the [Azure Kubernetes Fleet Manager](https://learn.microsoft.com/azure/kubernetes-fleet/) documentation.

---

## Summary

In this workshop, we covered key practices for maintaining and managing AKS clusters. We demonstrated how to perform Kubernetes version upgrades manually or via auto-upgrade channels to stay within supported versions and apply the latest features and security patches. We also updated node images to address CVEs and enhance security.

We configured maintenance windows to align updates with organizational policies, minimizing disruptions while ensuring timely upgrades. Additionally, we explored Azure Kubernetes Fleet Manager for managing multiple AKS clusters, including creating a Fleet resource, adding member clusters, and propagating resources using ClusterResourcePlacement.

By adopting these practices, you can keep your AKS clusters secure, up-to-date, and efficiently managed, reducing operational complexity and ensuring reliability across your Kubernetes environments.

For more information on AKS best practices and advanced topics, see the following resources:

- [Cluster operator and developer best practices to build and manage applications on Azure Kubernetes Service (AKS)](https://learn.microsoft.com/azure/aks/best-practices)
- [AKS baseline architecture](https://learn.microsoft.com/azure/architecture/reference-architectures/containers/aks/baseline-aks)
- [AKS baseline for multi-region clusters](https://learn.microsoft.com/azure/architecture/reference-architectures/containers/aks-multi-region/aks-multi-cluster)
- [Create a private Azure Kubernetes Service (AKS) cluster](https://learn.microsoft.com/azure/aks/private-clusters?tabs=default-basic-networking%2Cazure-portal)
- [Configure Azure CNI Powered by Cilium in Azure Kubernetes Service (AKS)](https://learn.microsoft.com/azure/aks/azure-cni-powered-by-cilium)
- [Set up Advanced Network Observability for Azure Kubernetes Service (AKS)](https://learn.microsoft.com/azure/aks/advanced-network-observability-cli?tabs=cilium)
- [Install Azure Container Storage for use with Azure Kubernetes Service](https://learn.microsoft.com/azure/storage/container-storage/install-container-storage-aks)
- [Kubernetes resource propagation from hub cluster to member clusters](https://learn.microsoft.com/azure/kubernetes-fleet/concepts-resource-propagation)
