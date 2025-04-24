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
kubectl label service workspace-phi-3-mini-128k-instruct app=phi-3-mini-128k-instruct
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
      app: phi-3-mini-128k-instruct
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

### Open source installation

### Deploy a RAG workspace

### Test the RAG workspace

## Summary

In this lab, you learned how to deploy a KAITO workspace and monitor it with Grafana. You also learned how to use the KAITO extension in VSCode to develop and run your code.

## What's next?

Fine tuning with KAITO
Agents

## Resources

https://docs.chainlit.io/integrations/openai
https://docs.chainlit.io/concepts/message
https://docs.astral.sh/uv/
https://learn.microsoft.com/en-us/azure/aks/ai-toolchain-operator-monitoring
https://docs.vllm.ai/en/latest/getting_started/examples/prometheus_grafana.html
https://github.com/vllm-project/vllm/tree/main/examples/online_serving/prometheus_grafana
https://docs.vllm.ai/en/latest/design/v1/metrics.html
https://learn.microsoft.com/en-us/azure/azure-monitor/containers/prometheus-metrics-scrape-crd#create-a-pod-or-service-monitor
