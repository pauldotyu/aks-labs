---
title: Deploying and Inferencing AI Applications on Kubernetes
---

## Overview

## Pre-requisites

- Azure CLI
- Azure Kubernetes Service (AKS)
- Visual Studio Code
- uv
- jq
- POSIX-compliant shell
- Python 3.13 or later

## What is KAITO?

### Workspace operator

### GPU provisioner

### vLLM runtime

### Deployment options

## Install the KAITO add-on

### Visual Studio Code

Open VSCode

Click on the Kubernetes extension

Login into your Azure account

Right-click and install KAITO

Wait for the installation to complete

### Deploy a workspace

With the KAITO extension installed, you can now deploy a workspace by clicking on the Generate Workspace.

Expand the **Phi-3** family of models and select **phi-3-mini-128k-instruct**.

Click the **Deploy default workspace CRD" and wait 10 minutes for it to be ready. Keep an eye on the **Resource Ready** and **Inference Ready** status.

With the workspace successfully deployed, click the **View deployed models** button to test the workspace.

In the workspace panel, you can view logs, test the inference endpoint, and delete the workspace. 

Click the **Test** button to open the testing panel.

Enter a prompt and optionally set prompt parameters, then click the **Submit prompt** button to send the prompt to the workspace.

The response will be displayed in the panel.

## Developing with KAITO workspaces

Let's look at some code

```bash
mkdir -p /tmp/app
cd /tmp/app
```

Download the sample code.

```bash
curl -o main.py https://raw.githubusercontent.com/kaito-project/kaito/refs/heads/main/demo/inferenceUI/chainlit_openai.py
```

View the code.

```bash
cat main.py
```

You can see that the code is using the Chainlit library to create a simple web UI for interacting with the KAITO workspace.
The code uses the `openai` library to send requests to the KAITO workspace and display the responses in the web UI.

Near the top of the file, you can see it relies on the `WORKSPACE_SERVICE_URL` environment variable to connect to the KAITO workspace. This value is the URL of the Kubernetes services that exposes the KAITO workspace. It is currently running internally in the AKS cluster but we can access it from our local machine using port forwarding.

Run the following command to port forward the workspace service to your local machine.

```bash
kubectl port-forward service/workspace-phi-3-mini-128k-instruct 8080:80
```

Move the process to the background by pressing `Ctrl + z`, then press `bg`, and press `Enter`.

To set the `WORKSPACE_SERVICE_URL` environment variable that the code uses, we can use a `.env` file. 

Run the following command to create a `.env` file and set the `WORKSPACE_SERVICE_URL` to point to the port forwarded service on localhost and port 8080.

```bash
echo "WORKSPACE_SERVICE_URL=http://localhost:8080/" > .env
```

We can run the code using **uv** which is a command line tool for managing Python package dependencies and projects.

Run the following command to initialize a new **uv** project.

```bash
uv init
```

The code requires some dependencies to run. We can install them using **uv**.

```bash
uv add chainlit pydantic==2.11.3 requests openai
```

The **chainlit** package is used to create the web UI, **pydantic** is used for data validation, **requests** is used to make HTTP requests, and **openai** is used to interact with the KAITO workspace which is serving the model on a vLLM server. Because the vLLM server supports the OpenAI API, we can use the `openai` library to interact with it.

Finally, we can run the code and pass in the `.env` file to set the environment variables.

```bash
uv run --env-file=.env chainlit run main.py
```

This will start a local web server that you can access in your browser at `http://localhost:8000`.

You can enter a prompt in the text box and click the submit button to send the prompt to the KAITO workspace. The response will be displayed in the web UI.

As you can see, working with the KAITO workspace is very easy. You can use the `openai` library to send requests which makes it compatible with any code that uses the OpenAI API. As for the UI, we chose to use **Chainlit** but you can use any other library or framework that you prefer.

## Monitoring KAITO workspaces

vLLM provides a set of metrics that can be used to monitor the performance of the KAITO workspace. These metrics can be scraped by Prometheus and visualized in Grafana.

You should still have the workspace service port forwarded to your local machine. If not, run the following command to port forward the workspace service to your local machine. To view the metrics that is emitted by the vLLM server, you can use the following command.

```bash
curl http://localhost:8080/metrics
```

### Scrape metrics with Prometheus

To scrape the metrics emitted by the vLLM server, you need to have Prometheus installed in your AKS cluster. In this lab environment we are using Azure Managed Prometheus and Azure Managed Grafana. With Azure Managed Prometheus, you can easily scrape metrics using a ServiceMonitor or PodMonitor CRD.

In order to scrap metrics from the KAITO workspace, you need to label the workspace service with a label that the ServiceMonitor or PodMonitor CRD can use to identify the service.

Run the following command to label the workspace.

```bash
kubectl label service workspace-phi-3-mini-128k-instruct kaito.sh/workspace=workspace-phi-3-mini-128k-instruct
```

Deploy a ServiceMonitor to monitor the workspace

```bash
kubectl apply -f - <<EOF
apiVersion: azmonitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: workspace-phi-3-mini-128k-instruct-monitor
spec:
  selector:
    matchLabels:
      kaito.sh/workspace: workspace-phi-3-mini-128k-instruct
  endpoints:
  - port: http
    path: /metrics
    interval: 30s
    scheme: http
EOF
```

### View the metrics in Grafana

Download the sample Grafana dashboard JSON file.

```bash
curl -o grafana.json https://raw.githubusercontent.com/vllm-project/vllm/refs/heads/main/examples/online_serving/prometheus_grafana/grafana.json
```

Update the JSON file to use the correct model name. This is just for convenience so you don't have to change the model name in the Grafana dashboard UI.

```bash
sed -i 's^/share/datasets/public_models/Meta-Llama-3-8B-Instruct^phi-3-mini-128k-instruct^g' grafana.json
```

Create a folder in Azure Managed Grafana to store the dashboard.

```bash
az grafana folder create \
-n <your_grafana_name> \
-g <your_resource_group_name> \
--title "KAITO"
```

Import the JSON file into Azure Managed Grafana.

```bash
az grafana dashboard create \
-n <your_grafana_name> \
-g <your_resource_group_name> \
--title "vLLM" \
--folder "KAITO" \
--definition "$(cat grafana.json)"
```

In the Azure portal, navigate to the Azure Managed Grafana instance and click on the endpoint URL to open the Grafana dashboard.

Log into the Grafana dashboard using your Azure credentials, then click on the **Dashboards** tab on the left side of the screen.

You should see a folder named **KAITO**. Click on it to open the folder.

Click on the **vLLM** dashboard to open it. You should see a dashboard with various metrics related to the KAITO workspace.

## Retrieval Augmented Generation (RAG) with KAITO

This is new for v0.5.0.

### Uninstall the KAITO add-on

```bash
export RG_NAME=<your_resource_group_name>
export AKS_NAME=$(az aks list -g $RG_NAME --query "[0].name" -o tsv)

# remove kaito add-on
az aks update \
-g $RG_NAME \
-n $AKS_NAME \
--disable-ai-toolchain-operator

# clean up custom resource definitions
kubectl delete crd workspaces.kaito.sh
kubectl delete crd aksnodeclasses.karpenter.azure.com
kubectl delete crd ec2nodeclasses.karpenter.k8s.aws
kubectl delete crd nodeclaims.karpenter.sh
```

### Open source installation

Deploying the open-source version of KAITO is a bit more involved than using the Azure add-on. But it worth knowing the steps.

#### Deploy the KAITO workspace operator

```bash
helm install kaito-workspace https://github.com/kaito-project/kaito/raw/gh-pages/charts/kaito/workspace-0.4.5.tgz \
--namespace kaito-workspace \
--create-namespace \
--wait
```

#### Deploy the KAITO GPU provisioner

Set some local variables to make it easier to work with the gpu-provisioner.

```bash
AKS_RESOURCE=$(az aks show -g $RG_NAME -n $AKS_NAME)
AKS_RESOURCE_ID=$(echo $AKS_RESOURCE | jq -r '.id')
AKS_LOCATION=$(echo $AKS_RESOURCE | jq -r '.location')
AKS_NRG_NAME=$(echo $AKS_RESOURCE | jq -r '.nodeResourceGroup')
AKS_OIDC_ISSUER=$(echo $AKS_RESOURCE | jq -r '.oidcIssuerProfile.issuerUrl')
AZURE_TENANT_ID=$(echo $AKS_RESOURCE | jq -r '.identity.tenantId')
AZURE_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
```

##### Create a user-assigned managed identity for the gpu-provisioner

Create a user-assigned managed identity for the gpu-provisioner and set the principal ID and client ID as local variables.

```bash
KAITO_IDENTITY_PRINCIPAL_ID=$(az identity create \
--name kaito-gpu-provisioner \
-g $RG_NAME --query principalId \
-o tsv)

KAITO_IDENTITY_CLIENT_ID=$(az identity show \
--name kaito-gpu-provisioner \
-g $RG_NAME \
--query clientId \
-o tsv)
```

##### Create a role assignment for the gpu-provisioner identity

Create a role assignment for the gpu-provisioner identity. This will allow the gpu-provisioner to create VM resources in the AKS node resource group.

```bash
az role assignment create \
--assignee $KAITO_IDENTITY_PRINCIPAL_ID \
--scope $AKS_RESOURCE_ID \
--role "Contributor"
```

##### Create a federated credential for the gpu-provisioner identity

Create a federated credential for the gpu-provisioner identity. This will allow the gpu-provisioner to authenticate using workload identity.

```bash
az identity federated-credential create \
--name kaito-gpu-provisioner \
--identity-name kaito-gpu-provisioner \
-g $RG_NAME \
--issuer $AKS_OIDC_ISSUER \
--subject system:serviceaccount:"gpu-provisioner:gpu-provisioner" \
--audience api://AzureADTokenExchange \
--subscription $AZURE_SUBSCRIPTION_ID
```

##### Deploy the gpu-provisioner

Create a values.yaml file to configure the gpu-provisioner.

```bash
cat <<EOF > values.yaml
controller:
  env:
  - name: ARM_SUBSCRIPTION_ID
    value: ${AZURE_SUBSCRIPTION_ID}
  - name: LOCATION
    value: ${AKS_LOCATION}
  - name: AZURE_CLUSTER_NAME
    value: ${AKS_NAME}
  - name: AZURE_NODE_RESOURCE_GROUP
    value: ${AKS_NRG_NAME}
  - name: ARM_RESOURCE_GROUP
    value: ${RG_NAME}
  - name: LEADER_ELECT
    value: "false"
workloadIdentity:
  clientId: ${KAITO_IDENTITY_CLIENT_ID}
  tenantId: ${AZURE_TENANT_ID}
settings:
  azure:
    clusterName: ${AKS_NAME}
EOF
```

Install the gpu-provisioner.

```bash
helm install gpu-provisioner https://github.com/Azure/gpu-provisioner/raw/gh-pages/charts/gpu-provisioner-0.3.3.tgz \
--namespace gpu-provisioner \
--create-namespace \
--values values.yaml \
--wait
```

### Deploy an inference workspace

```bash
kubectl apply -f - <<EOF
apiVersion: kaito.sh/v1alpha1
kind: Workspace
metadata:
  name: workspace-phi-3-mini-128k-instruct
resource:
  instanceType: Standard_NC24ads_A100_v4
  labelSelector:
    matchLabels:
      apps: phi-3
inference:
  preset:
    name: phi-3-mini-128k-instruct
EOF
```

### Deploy a RAG workspace

Build from source. This is temporary until the image is published by the KAITO team.

Clone the KAITO repository.

```bash
git clone https://github.com/kaito-project/kaito.git
cd kaito
```

Build the RAG Engine image and push to an ephemeral registry.

```bash
export REGISTRY=ttl.sh 
export RAGENGINE_IMAGE_NAME=$(uuidgen | tr '[:upper:]' '[:lower:]')
export IMG_TAG=8h 
make docker-build-ragengine
```

Install the RAG Engine controller.

```bash
helm install ragengine ./charts/kaito/ragengine \
--namespace kaito-ragengine \
--create-namespace \
--set image.repository=$REGISTRY/$RAGENGINE_IMAGE_NAME \
--set image.tag=$IMG_TAG
```

Deploy a RAG Engine resource

```bash
kubectl apply -f - <<EOF
apiVersion: kaito.sh/v1alpha1
kind: RAGEngine
metadata:
  name: ragengine-start
  annotations:
    llm_model: phi-3-mini-128k-instruct
spec:
  compute:
    instanceType: Standard_NC6s_v3
    labelSelector:
      matchLabels:
        apps: phi-3
  embedding:
    local:
      modelID: BAAI/bge-small-en-v1.5
  inferenceService:  
    url: http://workspace-phi-3-mini-128k-instruct/v1/completions
EOF
```

### Test the RAG workspace

## Summary

In this lab, you learned how to deploy a KAITO workspace and monitor it with Grafana. You also learned how to use the KAITO extension in VSCode to develop and run your code.

## What's next?

Fine tuning with KAITO
Agents

## Resources

https://kaito.sh
https://github.com/kaito-project/kaito
https://learn.microsoft.com/azure/aks/ai-toolchain-operator
https://learn.microsoft.com/azure/aks/ai-toolchain-operator-monitoring
https://learn.microsoft.com/azure/azure-monitor/containers/prometheus-metrics-scrape-crd#create-a-pod-or-service-monitor
https://docs.vllm.ai/en/latest/design/v1/metrics.html
https://docs.vllm.ai/en/latest/getting_started/examples/prometheus_grafana.html
https://github.com/vllm-project/vllm/tree/main/examples/online_serving/prometheus_grafana
https://docs.chainlit.io/integrations/openai
https://docs.chainlit.io/concepts/message
https://docs.astral.sh/uv/
