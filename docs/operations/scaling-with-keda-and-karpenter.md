---
title: Scaling Kubernetes Workloads with KEDA and Karpenter
sidebar_label: Scaling with KEDA and Karpenter
sidebar_position: 1                  # this dictates the order of the pages in the sidebar 
---

# Scaling Kubernetes Workloads with KEDA and Karpenter

## Objective

In this workshop you'll learn about the Kubernetes Event Driven Autoscaler (aka [KEDA](https://keda.sh)), as well as the AKS Node Auto Provisioner (aka [NAP](https://learn.microsoft.com/en-us/azure/aks/node-autoprovision?tabs=azure-cli)). We'll deploy a sample application, and demonstrate how Keda allows you to scale Kubernetes workloads based on a vast list of potential scale trigger sources. We'll then learn about how Node Auto Provisioner leverages the capabilities set in the [Karpenter](https://karpenter.sh/) open source project, via the [Karpenter Provider for Azure](https://github.com/Azure/karpenter-provider-azure), to improve the scaling behavior and flexibility of your AKS cluster.

## Prerequisites

In this lab we'll be creating an AKS cluster that has both the [Kubernetes Event Driven Autoscaler (KEDA)](https://keda.sh/) and [Node Autoprovisioning (NAP/Karpenter)](https://learn.microsoft.com/en-us/azure/aks/node-autoprovision?tabs=azure-cli) enabled. To use these features you'll need the following:
- [Azure subscription](https://azure.microsoft.com/)
- [Azure CLI](https://learn.microsoft.com/cli/azure/what-is-azure-cli)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [helm](https://helm.sh/docs/intro/install/)
- [Git](https://git-scm.com/)
- Bash shell (e.g. [Windows Terminal](https://www.microsoft.com/p/windows-terminal/9n0dx20hk701) with [WSL](https://docs.microsoft.com/windows/wsl/install-win10) or [Azure Cloud Shell](https://shell.azure.com))

At the writing of this workshop, Node Auto Provisioning is still in preview. Once you've prepared the pre-requisites above, you'll need to enable the preview feature in the Azure Subscription, and install the Preview CLI using the following steps.

1. Select the target subscription

    ```bash
    # Set your subscription ID
    SUBSCRIPTION_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    az account set -s $SUBSCRIPTION_ID

    # Confirm you've selected the right subscription
    az account show -o table
    ```

2. Enable the preview feature on the subscription

    ```bash
    # Enable the preview
    az feature register --namespace "Microsoft.ContainerService" --name "NodeAutoProvisioningPreview"

    # Check the status until the 'RegistrationState' shows as 'Registered'
    # This may take several minutes
    az feature show --namespace "Microsoft.ContainerService" --name "NodeAutoProvisioningPreview"

    # Refresh the provider registration
    az provider register --namespace Microsoft.ContainerService
    ```

3. Enable the AKS preview in your Azure CLI

    ```bash
    # Add the aks-preview extension
    az extension add --name aks-preview

    # Refresh the extension in-case you already had it installed
    az extension update --name aks-preview
    ```

### Environment Preparation

Let's deploy an AKS cluster with both KEDA and Node Auto-provisioning (aka. Karpenter) installed.

```bash
# Prepare Environment Variables
RESOURCE_GROUP=WorkshopRG
LOCATION=eastus2
CLUSTER_NAME=workshopcluster

# Create the Azure Resource Group
az group create -n $RESOURCE_GROUP -l $LOCATION

# Create the AKS cluster with KEDA and NAP enabled
# This operation will take several minutes
az aks create \
--name $CLUSTER_NAME \
--resource-group $RESOURCE_GROUP \
--enable-keda \
--node-provisioning-mode Auto \
--network-plugin azure \
--network-plugin-mode overlay \
--network-dataplane cilium \
--generate-ssh-keys

# Now let's get the cluster access credentials
az aks get-credentials -g $RESOURCE_GROUP -n $CLUSTER_NAME
```

We'll need an application we can use for scaling operations. For this, we'll use the [AKS Store](https://learn.microsoft.com/en-us/samples/azure-samples/aks-store-demo/aks-store-demo/) sample application. This application provides a several moving parts that are excellent targets for autoscaling. The store also includes an 'All-in-One' deployment option, which makes installation simple.

```bash
# Create the pet store namespace
kubectl create ns pets

# Deploy the pet store components
kubectl apply -f https://raw.githubusercontent.com/Azure-Samples/aks-store-demo/main/aks-store-all-in-one.yaml -n pets

# Check the deployment status
kubectl get all -n pets
```

Once all of the pods are in 'Running' state, and the Services are populated with their 'External-IP', you should be ready to move on to the next step.

> *Note:* You may see some restarts and errors while the pods come online. This is due to cross deployment dependencies and health checks. Just wait for all pods to be in a 'Running' state, which may take a few minutes.

```bash
# Get the store URL
echo "Pet Store URL: http://$(kubectl get svc store-front -n pets -o jsonpath={.status.loadBalancer.ingress[0].ip})"
```


## Setup the Keda Scaler

When a customer submits an order, that order is sent to the order service. This initial order creation is a pretty light weight activity, as it just creates a message in rabbitMQ for the order that needs to be processed. However, those orders will sit in the queue until a virtual worker picks them up. It makes sense for us to automatically scale the virtual worker based on the depth of the queue in RabbitMQ. Fortunately, Keda provides a scaler for RabbitMQ that we can use. Lets configure a Keda scaled object that will increase the number of virtual worker pods based on the depth of th orders queue in RabbitMQ. For this, we'll need a Keda ScaledObject, but also the authentication configuration for that RabbitMQ instance.


```bash
RABBITMQ_HOST="rabbitmq.pets.svc.cluster.local:15672"
RABBITMQ_USERNAME="username"
RABBITMQ_PASSWORD="password"
RABBITMQ_CONNECTION_STRING="http://${RABBITMQ_USERNAME}:${RABBITMQ_PASSWORD}@${RABBITMQ_HOST}"

RABBITMQ_CONNECTION_STRING_BASE64=$(echo -n "${RABBITMQ_CONNECTION_STRING}"|base64 -w 0)

cat << EOF > virtual-worker-scaler.yaml
apiVersion: v1
kind: Secret
metadata:
  name: rabbitmq-scaler-secret
  namespace: pets
data:
  host: ${RABBITMQ_CONNECTION_STRING_BASE64}
---
apiVersion: keda.sh/v1alpha1
kind: TriggerAuthentication
metadata:
  name: trigger-auth-rabbitmq-conn
  namespace: pets
spec:
  secretTargetRef:
    - parameter: host
      name: rabbitmq-scaler-secret
      key: host
---
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: virtual-worker-rabbitmq-scaledobject
  namespace: pets
spec:
  scaleTargetRef:
    name: virtual-worker
  minReplicaCount: 1
  pollingInterval: 60
  triggers:
  - type: rabbitmq
    metadata:
      protocol: http
      queueName: orders
      mode: QueueLength
      value: "10"
    authenticationRef:
      name: trigger-auth-rabbitmq-conn
EOF

kubectl apply -f virtual-worker-scaler.yaml
```

### Test Scaling

Now that we have our scaled object, lets increase the number of virtual customers and see if Keda responds to the increased order queue depth by adding replicas to the virtual worker deployment.

```bash
# Increase the virutal customer replica count
kubectl scale deployment virtual-customer -n pets --replicas=4

# You can keep an eye on the deployment with the following commands
kubectl get deployment,pods -n pets
kubectl get deploy -n pets -w

# If you have watch installed, you can run the following
watch kubectl get deployment,pods -n pets
```

In addition to the commands above, we can check out the Horizontal Pod Autoscaler(HPA) events. Since Keda drives the HPA to managed scaling, we can tap into the event stream. We also may want to take a look at the RabbitMQ depth itself, which we can do using the following.

```bash
# Watch the HPA events
kubectl events -w -n pets --for hpa/keda-hpa-virtual-worker-rabbitmq-scaledobject

# Check the queue depth
kubectl exec rabbitmq-0 -n pets -- rabbitmqctl list_queues

# Alternatively, if you prefer to use curl, in one terminal port forward to the rabbitmq service
kubectl exec rabbitmq-0 -n pets -- rabbitmqctl list_queues

# In another terminal, curl the rabbitmq and pipe that to jq to get the length
curl -u username:password http://localhost:15672/api/queues/%2f/orders|jq '.backing_queue_status.len'
```

Great! You should now be seeing the virtual worker count adjusting based on the queue depth. The virtual worker count will likely be pretty close to the virtual customer count, as they process at pretty close to the same speed. Feel free to play around with the deployment replica count to see how the scaler responds.



## Helper commands

```bash
# Helper commands
# RabbitMQ Pod
rabbitmqctl list_queues

# Mongo
show dbs
use orderdb
db.getCollection('orders').find()

kubectl set env deployment/virtual-customer -n pets ORDERS_PER_HOUR=100
kubectl set env deployment/virtual-worker -n pets ORDERS_PER_HOUR=100

kubectl get events --for hpa/keda-hpa-virtual-worker-rabbitmq-scaledobject
```