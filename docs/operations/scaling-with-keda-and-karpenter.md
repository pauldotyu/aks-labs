---
title: Scaling Kubernetes Workloads with KEDA and Karpenter
sidebar_label: Scaling with KEDA and Karpenter
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

## Using Karpenter

Now that we have a good sense of how Keda works, lets have a look at Node Auto Provisioner(NAP). To do this, we're going to make a couple fairly drastic updates to our cluster and lets see how the cluster responds. 

First, so far, we've been running on the default nodepool that was created for us when we created the cluster. That's not ideal, as it's intended to be the 'system' pool. We should really move everything over to a new 'user' mode pool. For more on system and user pools, see the AKS documentation [here](https://learn.microsoft.com/en-us/azure/aks/use-system-pools?tabs=azure-cli). However, even though the default pool is a system pool, it doesnt have a [Kubernetes taint]() applied to restrict the workloads that will start on the nodepool. Let's enable that taint and then see how the workload response.

>*Note:* In the example below, we'll taint the system pool with 'CriticalAddonsOnly=true:NoExecute'. This is a pretty aggressive way to apply a taint, as the 'NoExecute' will evict any pods that don't tolerate the taint. This was for demo purposes. In the real world you would likely use CriticalAddonsOnly=true:NoSchedule, and then migrate workloads over more gracefully.

```bash
# First make sure your environment variables are still set
RESOURCE_GROUP=WorkshopRG
CLUSTER_NAME=workshopcluster

# Get the default nodepool name. It should be nodepool1, but we'll confirm
DEFAULT_NODEPOOL_NAME=$(az aks nodepool list -g $RESOURCE_GROUP --cluster-name $CLUSTER_NAME --query [0].name -o tsv)

# Now apply the CriticalAddonsOnly taint to the default nodepool
az aks nodepool update \
-g $RESOURCE_GROUP \
--cluster-name $CLUSTER_NAME \
-n $DEFAULT_NODEPOOL_NAME \
--node-taints CriticalAddonsOnly=true:NoExecute
```

While the above command runs, in another terminal window, you can use the following to watch the pods as they transition to the new nodepool which NAP will create. The process will run as follows.

1. All pet store pods will be evicted from the system nodepool, as they don't have the 'CriticalAddonsOnly' toleration
2. Within a minute or two, NAP will start a new node with a name prefix of 'aks-default'
3. Once started, the pet store pods will start on the new node

```bash
# Watch the events raised by karpenter
kubectl get events -A --field-selector source=karpenter -w

# You can also watch the new node start and pods get scheduled
watch kubectl get nodes,pods -n pets -o wide
```

It's cool to see that NAP jumped in and made sure a nodepool was created for us and the pods got scheduled, but it did use the default profile. Let's have a look at that and see how we can create our own custom profile. Let's, for example, imagine that we're looking to minimize our power consumption for a new green compute policy, and move workloads to ARM based compute. Can we create a NAP profile that prioritizes ARM compute?

```bash
# Have a look at the NodePool definitions that ship with the NAP managed add-on
kubectl get nodepool
kubectl describe nodepool default

# Notice how the 'system-surge' nodepool uses the 'kubernetes.azure.com/mode' label to focus on system nodes.
kubectl describe nodepool system-surge
```

Let's create our own Nodepool profile for ARM. We'll use the [weight](https://learn.microsoft.com/en-us/azure/aks/node-autoprovision?tabs=azure-cli#node-pool-weights) parameter to give ours a higher priority than the default.

```bash
cat <<EOF > arm-nodepool-profile.yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: arm-nodepool
spec:
  weight: 10
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    consolidateAfter: 1s
  template:
    spec:
      nodeClassRef:
        group: karpenter.azure.com
        kind: AKSNodeClass
        name: default
      requirements:
      - key: kubernetes.io/arch
        operator: In
        values:
        - arm64
      - key: kubernetes.io/os
        operator: In
        values:
        - linux
      - key: karpenter.sh/capacity-type
        operator: In
        values:
        - on-demand
      - key: karpenter.azure.com/sku-family
        operator: In
        values:
        - D
EOF

# Now apply the new arm nodepool profile and watch the shift
kubectl apply -f arm-nodepool-profile.yaml 

# Watch the events raised by karpenter
kubectl get events -A --field-selector source=karpenter -w

# You can also watch the new node start and pods get scheduled
watch kubectl get nodes,pods -n pets -o wide
```

Within a couple minutes, you should see the following:

1. New ARM node comes online with a name prefix of 'aks-arm'
2. Pet store pod move from the 'aks-default' node to the 'aks-arm' node
3. The 'aks-default' node is removed from the cluster

That was pretty cool, but what about that 'nodeClassRef' section of the nodepool profile. What can we do with that? 

The nodeClassRef is a reference to a [NodeClass](https://learn.microsoft.com/en-us/azure/aks/node-autoprovision?tabs=azure-cli#node-image-updates) definition, where we can define settings about the node, like the OS disk size or the OS version. Lets create our own NodeClass and update the Nodepool profile to reference our own class.

```bash
cat <<EOF > arm-nodepool-profile_v2.yaml
apiVersion: karpenter.azure.com/v1beta1
kind: AKSNodeClass
metadata:
  name: default-azurelinux
  annotations:
    kubernetes.io/description: "General purpose AKSNodeClass for running Azure Linux nodes"
spec:
  imageFamily: AzureLinux
---
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: arm-nodepool
spec:
  weight: 10
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    consolidateAfter: 1s
  template:
    spec:
      nodeClassRef:
        group: karpenter.azure.com
        kind: AKSNodeClass
        name: default-azurelinux
      requirements:
      - key: kubernetes.io/arch
        operator: In
        values:
        - arm64
      - key: kubernetes.io/os
        operator: In
        values:
        - linux
      - key: karpenter.sh/capacity-type
        operator: In
        values:
        - on-demand
      - key: karpenter.azure.com/sku-family
        operator: In
        values:
        - D
EOF

# Apply the new profile with the new NodeClass
kubectl apply -f arm-nodepool-profile_v2.yaml

# Watch the events raised by karpenter
kubectl get events -A --field-selector source=karpenter -w

# You can also watch the new node start and pods get scheduled
watch kubectl get nodes,pods -n pets -o wide
```

## Conclusion

In this lab we walked through using the [Kuberentes Event Driven Autoscaler](https://keda.sh) to drive the replica count of an application based on an external trigger. In our case, we used the queue depth of a RabbitMQ queue to increase an application's replica count. This is an extremely powerful tool in managing how your application can scale, and Keda provides an amazing list of [scalers](https://keda.sh/docs/2.17/scalers/) that you can tap into. It's also open source, so you can add your own!

Next, we took a look at the Karpenter project, and the Azure Provider for Karpenter, which is provided in AKS as the [Node Autoprovisioner](https://learn.microsoft.com/en-us/azure/aks/node-autoprovision?tabs=azure-cli). We saw how you can use the built in NodeClass and NodePool profile to enable autoscaling, but also how you can create your own custom NodeClass and Nodepool profile based on your own requirements. In our example, we wanted to run an Azure Linux pool that used ARM based nodes.

Using these two tools together can give you amazing control over the was your application and your cluster handle scaling, and we only scratched the surface of the potential of these solutions!