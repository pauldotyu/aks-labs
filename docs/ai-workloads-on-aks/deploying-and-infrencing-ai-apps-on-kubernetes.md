---
title: Deploying and Inferencing AI Applications on Kubernetes
---

## Overview

This workshop will guide you through deploying and managing AI/ML workloads on Azure Kubernetes Service (AKS) using the KAITO operator. You will learn how to deploy a KAITO workspace, monitor it with Grafana, and use the KAITO extension in Visual Studio Code to develop and run your code.

## Pre-requisites

Before you begin, make sure you have the following:

- [Azure subscription](https://azure.microsoft.com/pricing/purchase-options/pay-as-you-go)
- [Visual Studio Code](https://code.visualstudio.com/)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [Azure CLI](https://learn.microsoft.com/cli/azure/what-is-azure-cli) with extensions for the following:
  - [AKS](https://learn.microsoft.com/cli/azure/aks?view=azure-cli-latest)
  - [Grafana](https://learn.microsoft.com/en-us/cli/azure/grafana?view=azure-cli-latest)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/)
- [Git](https://git-scm.com/)
- [uv](https://docs.astral.sh/uv/getting-started/installation/)
- [jq](https://jqlang.org/)
- [Python 3.13 or later](https://www.python.org/downloads/)
- POSIX-compliant shell (i.e. bash, zsh, etc.)

## What is KAITO?

KAITO is a tool designed to automate AI/ML model inference and tuning workloads within Kubernetes clusters, focusing on popular large models like Falcon, Phi-3, and more. Key features include managing large model files using container images, providing preset configurations for different GPU hardware, and supporting popular open-source inference runtimes such as vLLM and transformers.

KAITO simplifies the deployment of AI inference models by automating the provisioning of GPU nodes based on specific model requirements and hosting large model images in public registries when permissible.

### Architecture

The architecture of KAITO follows the Kubernetes Custom Resource Definition (CRD)/controller design pattern, where users manage workspace custom resources to describe GPU needs and specifications. The workspace controller creates machine custom resources to trigger node provisioning and deploys the inference workload. The GPU provisioner controller interacts with the AKS APIs to add new GPU nodes to the AKS cluster.

Once the GPU nodes are provisioned, the KAITO workspace controller deploys the inference workload using the specified model and configuration. The inference workload is exposed via a Kubernetes service, allowing users to access it through a REST API.

By default, KAITO uses the vLLM inference runtime, which is a high-performance inference engine for large language models. It also supports other runtimes like HuggingFace Transformers, but generally, you'll want to use vLLM for its performance, efficiency, compatibility with the OpenAI API, and support for metrics out-of-the-box.

### Deployment options

KAITO can be deployed in two ways on AKS:

1. **AKS add-on**: This is the easiest way to deploy KAITO on AKS however you will be limited in terms of getting the latest features and updates as soon as they are available upstream. This feature can be enabled using Azure CLI or the Visual Studio Code (VSCode) extension.
2. **Open source**: This requires more steps to deploy but you will have access to the latest features and updates as soon as they are available. To deploy open-source KAITO on AKS, you can follow this [guide](https://github.com/kaito-project/kaito/tree/main/terraform) to deploy with Terraform or use this [guide](https://github.com/kaito-project/kaito/blob/main/docs/installation.md) to deploy with Azure CLI.

## Install the AKS add-on

In this workshop, we will be using the AKS add-on to deploy KAITO on AKS. This is the easiest way to deploy the add-on is by using the [AKS extension for VSCode](https://marketplace.visualstudio.com/items?itemName=ms-kubernetes-tools.vscode-aks-tools).

### Install with Visual Studio Code

Start by opening VSCode.

![VSCode](https://placehold.co/600x400)

Click on the Kubernetes extension.

![Kubernetes extension](https://placehold.co/600x400)

Expand the **Clouds** section, then expand **Azure** section and login into your Azure account. If your Azure account is tied to multiple tenants, you will be prompted to select a tenant. Select the tenant that contains your AKS cluster.

![Azure login](https://placehold.co/600x400)

You should see a list of your Azure subscriptions. Select the subscription that contains your AKS cluster.

![Azure subscriptions](https://placehold.co/600x400)

Expand the subscription and find your AKS cluster.

![AKS cluster](https://placehold.co/600x400)

Right-click your AKS cluster and select **Deploy an LLM with KAITO** and click **Install KAITO**.

![Install KAITO](https://placehold.co/600x400)

In the panel that opens, click the **Install KAITO** button. Installing KAITO will take a few minutes to complete.

![Install KAITO panel](https://placehold.co/600x400)

Once the installation is complete, you will see a message in the panel.

![KAITO installed](https://placehold.co/600x400)

### Deploy a workspace

With the KAITO add-on installed, you can now deploy a Workspace by clicking on the **Generate Workspace** button.

![Generate workspace](https://placehold.co/600x400)

Here you will see a list of available Workspace presets. These are the available models that you can deploy with KAITO.

![Available models](https://placehold.co/600x400)

Expand the **Phi-3** family of models and select **phi-3-mini-128k-instruct**.

![Select phi-3-mini-128k-instruct](https://placehold.co/600x400)

Here you have the option to deploy the default workspace or a custom workspace. If you click on the **Customize workspace CRD** button, the YAML manifest will be displayed in a new tab. You can modify the YAML manifest to customize the workspace deployment then apply the manifest using the **kubectl apply** command.

Click the **Deploy default workspace CRD" and wait 10 minutes for it to be ready. Keep an eye on the **Resource Ready** and **Inference Ready** statuses. Also as part of this process, subscription quota will be checked and if you don't have enough quota, the workspace will not be deployed.

![Deploy workspace CRD](https://placehold.co/600x400)

With the workspace successfully deployed, click the **View deployed models** button to test the workspace.

![View deployed models](https://placehold.co/600x400)

In the workspace panel you can see it's a place where you can quickly test the inference endpoint, view logs, and delete the workspace.

![View workspace panel](https://placehold.co/600x400)

Click the **Test** button to open the testing panel.

![Test workspace](https://placehold.co/600x400)

Here you can enter a prompt and configure the prompt parameters such as **Temperature**, **Top P**, **Top K**, and **Max Length**.

Enter a prompt and optionally set prompt parameters, then click the **Submit prompt** button to send the prompt to the workspace.

![Submit prompt](https://placehold.co/600x400)

The response will be displayed in the panel.

![Response](https://placehold.co/600x400)

## Developing with KAITO

With a workspace deployed, you can now start developing your code. In this lab, we will be using the [Chainlit](https://chainlit.io/) library to create a simple web UI for interacting with the KAITO workspace.

### Chainlit app with OpenAI API

Chainlit is a Python library that allows you to create interactive web applications for interacting with models. It provides a simple way to create a web UI for your model and allows you to quickly build prototypes and test using a web browser.

Run the following command to create a new directory for the project.

```bash
mkdir -p /tmp/app
cd /tmp/app
```

Download the sample code.

```bash
curl -o main.py https://raw.githubusercontent.com/kaito-project/kaito/refs/heads/main/demo/inferenceUI/chainlit_openai.py
```

Run the following command to view the code file.

```bash
cat main.py
```

The code uses the OpenAI library to send requests to the KAITO workspace and display the responses in the web UI which is created using Chainlit.

Near the top of the file, you can see it relies on the `WORKSPACE_SERVICE_URL` environment variable to connect to the KAITO workspace. This value is the URL of the Kubernetes services that exposes the KAITO workspace. The service runs as an internal service in the cluster but we can access it from our local machine using Kubernetes port forwarding.

### Run the Chainlit app

Run the following command to port forward the workspace service to your local machine.

```bash
kubectl port-forward service/workspace-phi-3-mini-128k-instruct 8080:80
```

Move the process to the background by pressing `Ctrl + z`, then press `bg`, and press `Enter`.

To set the `WORKSPACE_SERVICE_URL` environment variable that the code uses, we can use a `.env` file.

Run the following command to create a `.env` file and set the `WORKSPACE_SERVICE_URL` to point to the port forwarded service that you can access locally which is `http://localhost:8080`.

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

![Chainlit app](https://placehold.co/600x400)

As you can see, developing against the KAITO workspace simple. Using the OpenAI library to send requests makes it compatible with any code that uses the OpenAI API.

## Monitoring KAITO workspaces

With vLLM-based workspaces, vLLM metrics are emitted from on the **/metrics** endpoint which enables you to monitor the performance of the KAITO workspace easily with Prometheus and Grafana.

You should still have the workspace service port forwarded to your local machine. If not, run the following command to port forward the workspace service to your local machine.

To view the metrics that is emitted by the vLLM server, you can use the following command.

```bash
curl http://localhost:8080/metrics
```

### Scrape metrics with Prometheus

To scrape the metrics emitted by the vLLM server, you need to have Prometheus installed in your AKS cluster. In this lab environment we are using Azure Managed Prometheus and Azure Managed Grafana. With Azure Managed Prometheus, you can deploy either a ServiceMonitor or PodMonitor CRD. We will use the ServiceMonitor CRD to scrape the metrics emitted by the vLLM server.

Before you deploy the ServiceMonitor, you will need to label the workspace service so that the ServiceMonitor can use it to identify the service.

Run the following command to label the workspace.

```bash
kubectl label service workspace-phi-3-mini-128k-instruct kaito.sh/workspace=workspace-phi-3-mini-128k-instruct
```

Deploy a ServiceMonitor to monitor the workspace which will scrape from the **/metrics** endpoint of the service that has the label `kaito.sh/workspace=workspace-phi-3-mini-128k-instruct`.

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

### Import vLLM Grafana dashboard

vLLM provides a [sample Grafana dashboard](https://docs.vllm.ai/en/latest/getting_started/examples/prometheus_grafana.html#example-materials) that you can use to monitor the performance of the KAITO workspace. You can import this dashboard into Azure Managed Grafana.

Run the following command to download the sample Grafana dashboard JSON file.

```bash
curl -s -o grafana.json https://raw.githubusercontent.com/vllm-project/vllm/refs/heads/main/examples/online_serving/prometheus_grafana/grafana.json
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

![Grafana endpoint](https://placehold.co/600x400)

Log into the Grafana dashboard using your Azure credentials, then click on the **Dashboards** tab on the left side of the screen.

![Grafana dashboards](https://placehold.co/600x400)

You should see a folder named **KAITO**. Click on it to open the folder.

![KAITO folder](https://placehold.co/600x400)

Click on the **vLLM** dashboard to open it. You should see a dashboard with various metrics related to the KAITO workspace.

![vLLM dashboard](https://placehold.co/600x400)

> [!note] The dashboard may not have metrics to display yet if you have not run any inference requests yet. You can run some inference requests using the Chainlit app that you created earlier to generate some metrics.

## RAG with KAITO

As you build AI applications and work with LLMs, you will often need to ground the LLM with your own data. This is where the KAITO RAG Engine comes in. The RAG Engine allows you to index your data and use it to answer questions or provide suggestions based on the data.

The RAG Engine is a separate component that works with the KAITO workspace. It uses the same architecture as the KAITO workspace and is deployed as a separate custom resource. When you deploy a RAG Engine custom resource, it will create an application Pod includes an vector database and lightweight embedding model which is used to create embeddings for the data and store them in the vector database. The RAG Engine will also create a service that exposes several endpoints for indexing and querying the data.

When you query the RAG Engine, it will use the in-memory vector database to find the most relevant data based on the query then send the data to the KAITO workspace for inference.

> [!note]
> At the time of this writing, the RAG Engine is not yet available as an AKS add-on. You will need to deploy it using the open-source version of KAITO.

### Uninstall the KAITO add-on

```bash
RG_NAME=<your_resource_group_name>
AKS_NAME=$(az aks list -g $RG_NAME --query "[0].name" -o tsv)

# delete the workspace
kubectl delete workspace workspace-phi-3-mini-128k-instruct

# remove kaito add-on
az aks update \
-g $RG_NAME \
-n $AKS_NAME \
--disable-ai-toolchain-operator

# clean up custom resource definitions
kubectl delete crd aksnodeclasses.karpenter.azure.com
kubectl delete crd nodeclaims.karpenter.sh
kubectl delete crd workspaces.kaito.sh
```

### Open source installation

Deploying the open-source version of KAITO is a bit more involved than using the Azure add-on. You will need to deploy the KAITO workspace operator and the GPU provisioner separately. Before you deploy the GPU provisioner, you will need to create a user-assigned managed identity for the GPU provisioner and assign it the necessary permissions to create VM resources in the AKS node resource group.

Run the following command to install the KAITO workspace Helm chart.

```bash
helm install kaito-workspace https://github.com/kaito-project/kaito/raw/gh-pages/charts/kaito/workspace-0.4.5.tgz \
--namespace kaito-workspace \
--create-namespace \
--wait
```

Deploying the GPU provisioner requires a few variables. Run the following command to get the AKS resource and pull out the necessary variables.

```bash
AKS_RESOURCE=$(az aks show -g $RG_NAME -n $AKS_NAME)
AKS_RESOURCE_ID=$(echo $AKS_RESOURCE | jq -r '.id')
AKS_LOCATION=$(echo $AKS_RESOURCE | jq -r '.location')
AKS_NRG_NAME=$(echo $AKS_RESOURCE | jq -r '.nodeResourceGroup')
AKS_OIDC_ISSUER=$(echo $AKS_RESOURCE | jq -r '.oidcIssuerProfile.issuerUrl')
AZURE_TENANT_ID=$(echo $AKS_RESOURCE | jq -r '.identity.tenantId')
AZURE_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
```

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

Create a role assignment for the gpu-provisioner identity. This will allow the gpu-provisioner to create VM resources in the AKS node resource group.

```bash
az role assignment create \
--assignee $KAITO_IDENTITY_PRINCIPAL_ID \
--scope $AKS_RESOURCE_ID \
--role "Contributor"
```

> [!note]
> If this command fails, wait a few seconds and try again.

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

Now, you have enough information to deploy the gpu-provisioner. Run the following command to deploy the gpu-provisioner Helm chart.

```bash
helm install gpu-provisioner https://github.com/Azure/gpu-provisioner/raw/gh-pages/charts/gpu-provisioner-0.3.3.tgz \
--namespace gpu-provisioner \
--create-namespace \
--values values.yaml \
--wait
```

### Deploy an inference workspace

With the open-source KAITO fully installed, you can now deploy a workspace.

```bash
kubectl apply -f - <<EOF
apiVersion: kaito.sh/v1alpha1
kind: Workspace
metadata:
  name: phi-3-mini-128k-instruct-wks
resource:
  instanceType: Standard_NC24ads_A100_v4
  labelSelector:
    matchLabels:
      apps: phi-3-wks
inference:
  preset:
    name: phi-3-mini-128k-instruct
EOF
```

This will deploy a workspace with the `phi-3-mini-128k-instruct` model as we did with the AKS add-on. You can check the status of the workspace by running the following command.

```bash
kubectl get workspace
```

While the workspace is being deployed, let's move on to the next step.

### Build the RAG Engine from source

At the time of this writing, the RAG Engine container image is not yet available in a public registry. You will need to build the image from source and push it to a temporary registry provided by friends at [ttl.sh](https://ttl.sh). The KAITO team is working on publishing the image to a public registry, so this step will not be necessary in the future.

Run the following command to clone the KAITO repository.

```bash
git clone https://github.com/kaito-project/kaito.git
cd kaito
```

Run the following commands to set environment variables for the RAG Engine image and build the image.

```bash
export REGISTRY=ttl.sh 
export RAGENGINE_IMAGE_NAME=$(uuidgen | tr '[:upper:]' '[:lower:]')
export IMG_TAG=8h 
make docker-build-ragengine
```

### Install the RAG Engine

Run the following command to deploy the RAG Engine Helm chart.

```bash
helm install ragengine ./charts/kaito/ragengine \
--namespace kaito-ragengine \
--create-namespace \
--set image.repository=$REGISTRY/$RAGENGINE_IMAGE_NAME \
--set image.tag=$IMG_TAG
```

Deploy a RAG Engine custom resource.

```bash
kubectl apply -f - <<EOF
apiVersion: kaito.sh/v1alpha1
kind: RAGEngine
metadata:
  name: phi-3-mini-128k-instruct-rag
spec:
  compute:
    instanceType: Standard_NC6s_v3
    labelSelector:
      matchLabels:
        apps: phi-3-rag
  embedding:
    local:
      modelID: BAAI/bge-small-en-v1.5
  inferenceService:  
    url: http://workspace-phi-3-mini-128k-instruct/v1/completions
EOF
```

This custom resource will deploy a RAG Engine on a new AKS node with a local embedding model and reference to the KAITO workspace for inference. The embedding model is used to create vector embeddings for the data that you want to index and query. The inference service URL is the URL of the KAITO workspace that you deployed earlier.

### Test the RAG workspace

To test the RAG workspace, let's first test the workspace without RAG. In the Contoso Pet Supply store demo application, there are some sample product data that we can use to test how RAG can help us find the right product for our customers.

The sample data can be found [here](https://github.com/Azure-Samples/aks-store-demo/blob/main/src/product-service/src/data.rs).

To test the workspace without RAG support, run the following command to port-forward the workspace service to your local machine.

```bash
kubectl port-forward service/workspace-phi-3-mini-128k-instruct 8080:80
```

Press `Ctrl + z`, then press `bg`, and press `Enter` to move the process to the background.

Ask the LLM to suggest a product for your cat. As a potential shopping assistant for the Contoso Pet Supply store, I'd expect to see it suggest the [Seashell Snuggle Bed](https://github.com/Azure-Samples/aks-store-demo/blob/b07b73215c4e7f3d8f1aaabe20956473c7ff1a1a/src/product-service/src/data.rs#L50)

Run the following command to send a request to the workspace.

```bash
curl -s http://localhost:8080/v1/chat/completions \
-H "Content-Type: application/json" \
-d '{
      "model": "phi-3-mini-128k-instruct",
      "messages": [
        {
          "role": "user",
          "content": "I need a new bed for my cat. Can you help me?"
        }
      ],
      "top_k": 5,
      "temperature": 0.7,
      "max_tokens": 2048
    }' | jq
```

We can see that the LLM is not able to suggest the expected product. This is because the LLM is not grounded with the Contoso Pet Supply store product data.

Press `fg` to bring the port forward process back to the foreground, then press `Ctrl + c` to stop the port forward process.

### Test the RAG Engine

Let's ground the LLM with the product data using the KAITO's RAG Engine.

Start by port-forwarding the RAG Engine service to your local machine.

```bash
kubectl port-forward service/ragengine-start 8080:80
```

Press `Ctrl + z`, then press `bg`, and press `Enter` to move the process to the background.

Download the sample JSON file to index the RAG Engine.

```bash
curl -o /tmp/store_index.json https://gist.githubusercontent.com/pauldotyu/7643742a251d3f1d06d8a3c38d0b432d/raw/f4343732fd7a97017afc147ca56fd1c72550a9e2/store_index.json
```

Create the RAG Engine index.

```bash
curl -X POST http://localhost:8080/index \
-H "Content-Type: application/json" \
-d @/tmp/store_index.json | jq
```

List the RAG Engine index.

```bash
curl -s http://localhost:8080/indexes | jq
```

Query the RAG Engine.

```bash
curl -s http://localhost:8080/query -X POST \
-H 'Content-Type: application/json' \
-d '{
      "index_name": "store_index",
      "query": "I need a new bed for my cat. Can you help me?",
      "top_k": 5,
      "llm_params": {"temperature": 0.7, "max_tokens": 2048}
    }' | jq
```

You should see that the RAG Engine is able to suggest the expected product. This is because the RAG Engine is able to ground the LLM with the product data!

With KAITO's RAG Engine, you can easily ground the LLM with your own data and use it to answer questions or provide suggestions based on the data.

### Clean up

```bash
helm uninstall gpu-provisioner --namespace gpu-provisioner
helm uninstall kaito-workspace --namespace kaito-workspace
helm uninstall ragengine --namespace kaito-ragengine
kubectl delete crd aksnodeclasses.karpenter.azure.com
kubectl delete crd ec2nodeclasses.karpenter.k8s.aws
kubectl delete crd nodeclaims.karpenter.sh
kubectl delete crd ragengines.kaito.sh
kubectl delete crd workspaces.kaito.sh
```

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
https://huggingface.co/BAAI/bge-small-en-v1.5
https://faiss.ai/