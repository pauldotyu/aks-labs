---
title: Deploying and Inferencing AI Applications on Kubernetes
---

## Overview

KAITO is a tool designed to automate AI/ML model inference and tuning workloads within Kubernetes clusters, focusing on popular large models like that can be found on [Hugging Face](https://huggingface.co/) like Falcon, Phi-3, and more. Key features include managing large model files using container images, providing preset configurations for different GPU hardware, and supporting popular open-source inference runtimes such as vLLM and transformers.

KAITO simplifies the deployment of AI inference models by automating the provisioning of GPU nodes based on specific model requirements and hosting large model images in public registries when permissible.

This workshop will guide you through deploying and developing and developing with AI inference workloads on Azure Kubernetes Service (AKS) using [Kubernetes AI Toolchain Operator (KAITO)](https://github.com/kaito-project/kaito). KAITO is an open-source operator for Kubernetes that simplifies the deployment and management of AI/ML workloads on AKS.

## Objectives

After completing this workshop, you will be able to:

- Install the KAITO add-on for AKS
- Deploy a KAITO preset workspace with a custom VM size
- Build inference applications using the KAITO workspace
- Test KAITO's vLLM endpoint using the OpenAI API
- Monitor the performance of the KAITO workspace and GPU nodes using Azure Managed Prometheus and Grafana

## Pre-requisites

Before you begin, make sure you have the following:

- [Azure subscription](https://azure.microsoft.com/pricing/purchase-options/pay-as-you-go) with sufficient quota for GPU nodes
- [Visual Studio Code (VS Code)](https://code.visualstudio.com/) with the following extensions:
  - [AKS](https://marketplace.visualstudio.com/items?itemName=ms-kubernetes-tools.vscode-aks-tools) for managing AKS clusters
  - [Kubernetes](https://marketplace.visualstudio.com/items?itemName=ms-kubernetes-tools.vscode-kubernetes-tools) for managing Kubernetes resources
  - [Python](https://marketplace.visualstudio.com/items?itemName=ms-python.python) for Python development
  - [Python Debugger](https://marketplace.visualstudio.com/items?itemName=ms-python.debugpy) for debugging Python code
  - [REST Client](https://marketplace.visualstudio.com/items?itemName=humao.rest-client) for testing REST APIs
- [Azure CLI](https://learn.microsoft.com/cli/azure/what-is-azure-cli) with the following extensions:
  - [AKS](https://learn.microsoft.com/cli/azure/aks?view=azure-cli-latest) for managing AKS clusters
  - [Grafana](https://learn.microsoft.com/en-us/cli/azure/grafana?view=azure-cli-latest) for managing Azure Managed Grafana
- [kubectl](https://kubernetes.io/docs/tasks/tools/) for interacting with Kubernetes API server via CLI
- [Headlamp](https://headlamp.dev/) for managing Kubernetes resources via GUI
- [Python 3.13 or later](https://www.python.org/downloads/) for Python development
- [uv](https://docs.astral.sh/uv/getting-started/installation/) for managing Python package dependencies and projects

> [!knowledge]
> In this lab, all the tooling listed above are included in your lab environment. To keep focus on workshop objectives, we will not cover provisioning some of the Azure services. These have been pre-provisioned for you. You can find your Azure credentials and name of the resource group in the **Resources** tab of the lab environment. Log into the Azure portal to view the resources in the resource group.

## Getting started

Start by opening VS Code then open its integrated **Terminal**.

> [!hint]
> In the menu, click **Terminal** then **New Terminal** or press **Ctrl+Shift+`** to open the terminal in VS Code.

![VS Code](./assets/kaito/vscode.png)

In the terminal, run the following command to log into your Azure account.

```bash
az login
```

Next, connect to the AKS cluster using the Azure CLI.

```bash
az aks get-credentials -g @lab.CloudResourceGroup(ResourceGroup1).Name -n @lab.CloudResourceTemplate(LAB345).Outputs[aksName]
```

Close the terminal for now. You will be using the terminal later in the workshop.

### Deployment options

KAITO can be deployed in two ways on AKS:

1. **[AKS add-on](https://learn.microsoft.com/azure/aks/ai-toolchain-operator)**: This is the easiest way to deploy KAITO on AKS however you will be limited in terms of getting the latest features and updates as soon as they are available upstream. This feature can be enabled using Azure CLI or the Visual Studio Code (VS Code) extension.
1. **[Open source](https://github.com/kaito-project/kaito)**: This requires more steps to deploy but you will have access to the latest features and updates as soon as they are available. To deploy open-source KAITO on AKS, you can [deploy with Terraform](https://github.com/kaito-project/kaito/tree/main/terraform) or [deploy with Helm and Azure CLI](https://github.com/kaito-project/kaito/blob/main/docs/installation.md).

## Install the AKS add-on

In this workshop, you will be using the [AKS add-on to deploy KAITO on AKS](https://learn.microsoft.com/azure/aks/ai-toolchain-operator). This is the easiest way to deploy the add-on is by using the [AKS extension for VS Code](https://marketplace.visualstudio.com/items?itemName=ms-kubernetes-tools.vscode-aks-tools).

> [!knowledge]
> To learn more about the AKS add-on and VS Code extension for KAITO, check out this [video](https://youtu.be/zGQiLeJwLiQ?si=2Qrg45w-7t9pir-D).

### Install KAITO with VS Code

In VS Code, click on the Kubernetes extension icon in the left sidebar.

![Kubernetes extension](./assets/kaito/vscode-k8s-ext.png)

In the **Clouds** section, expand the **Azure** section, then click on **Sign in to Azure**.

![Sign in to Azure](./assets/kaito/vscode-k8s-ext-login.png)

You will see a pop-up windows indicating the **Azure Kubernetes Service extension wants to sign in**. Click the **Allow** button then sign in with your Azure account.

> [!hint]
> After logging in, you may be asked to "Automatically sign in to all desktop apps and websites on this device?" If so, click the **No, this app only** button.
>
> ![Sign in to Azure](./assets/kaito/vscode-k8s-ext-login-confirm.png)

You should see a list of your Azure subscriptions. Expand the subscription that contains your AKS cluster and locate your AKS cluster.

![Azure subscriptions](./assets/kaito/vscode-k8s-cloud-clusters.png)

Right-click your AKS cluster, select **Deploy a LLM with KAITO** and click **Install KAITO**.

![Install KAITO](./assets/kaito/vscode-k8s-kaito-install.png)

The **Install KAITO** tab will open. Click the **Install KAITO** button at the bottom of the tab.

![Install KAITO panel](./assets/kaito/vscode-k8s-kaito-install-button.png)

Installing KAITO can take up to 15 minutes to complete. Once the installation is complete, you will see a message at the bottom of the tab indicating that KAITO has been installed successfully.

While you wait for the installation to complete, move on to the next section to learn about the KAITO architecture.

### KAITO Architecture

The architecture of KAITO follows the [Kubernetes operator design pattern](https://kubernetes.io/docs/concepts/extend-kubernetes/operator/). It is comprised of two controllers, Workspace and GPU provisioner. As a user, you will only manage a workspace custom resource. This is where you can define your model and GPU specification (VM SKU). The GPU provisioner is built on top of [Karpenter](https://karpenter.sh/) APIs and is responsible for provisioning GPU nodes.

When you submit a workspace custom resource to the Kubernetes API server, the Workspace controller creates a [NodeClaim](https://karpenter.sh/docs/concepts/nodeclaims/) custom resource and waits for the GPU provisioner controller to provision a node and configures necessary GPU drivers and libraries to support the model all of which would have been manual steps without KAITO.

Once the GPU node is provisioned, the Workspace controller will proceed to deploy the inference workload using the specified configuration. This configuration can be a custom Pod template that you create, but the best part of KAITO is it's support for preset configurations. Presets are pre-built, optimal GPU configuration for specific models. The Workspace controller creates the Pod and proceeds to pull down the containerized model and run a model inference server which is exposed via a Kubernetes Service, allowing users to access it through a REST API.

KAITO supports both [Hugging Face Transformers](https://huggingface.co/docs/transformers) and [vLLM](https://docs.vllm.ai/en/latest/index.html) as inference runtime but defaults to vLLM for performance, efficiency, compatibility with the OpenAI API, and support for metrics out-of-the-box.

### Deploy Workspace with Headlamp

With the KAITO add-on installed, you can now deploy a workspace custom resource by clicking on the **Generate Workspace** button.

![Generate workspace](./assets/kaito/vscode-k8s-kaito-workspace-button.png)

This will open a new tab where you will be presented with a list of available preset Workspaces. These are the available models that you can deploy with KAITO.

![Available models](./assets/kaito/vscode-k8s-kaito-workspace-list.png)

Expand the **Phi-3** family of models and select **phi-3-5-mini-instruct**.

![Select phi-3-5-mini-instruct](./assets/kaito/vscode-k8s-kaito-workspace-phi-3.png)

In the panel that opens to the right, you will have the option to deploy the default workspace or a customized workspace.

The default workspace is a preset configuration that has been optimized for the most cost-effective VM size that meets the requirements of the model. This is the recommended option for most users. However, you can customize the workspace to use a different VM size if you have specific requirements or if you want to use a VM size that you have sufficient quota for.

Let's customize this workspace. Click on the **Customize workspace CRD** button.

![Customize workspace CRD](./assets/kaito/vscode-k8s-kaito-workspace-customize.png)

If you click on the **Customize workspace CRD** button, the YAML manifest will be displayed in a new tab. Here you can modify the YAML manifest to customize the workspace.

Update the **instanceType** and replace the existing value with `Standard_NC40ads_H100_v5`.

![Customize workspace manifest](./assets/kaito/vscode-k8s-kaito-workspace-customize-manifest.png)

Typically you would save the YAML manifest to a file and apply it using the **kubectl apply** command in the terminal. However, in this case, let's use [Headlamp](https://headlamp.dev/) to apply the manifest directly on the cluster, so no need to save the file but keep it open for now.

#### What is Headlamp?

Headlamp is a Kubernetes Dashboard application that provides a graphical interface for managing Kubernetes resources. It is developed as an open-source project by Microsoft and has [recently been accepted into the core Kubernetes project](https://github.com/kubernetes-sigs/headlamp) within the [Kubernetes SIG UI](https://github.com/kubernetes/community/blob/master/sig-ui/README.md).

> [!knowledge]
> To learn more about Headlamp, check out this [video](https://learn.microsoft.com/shows/open-at-microsoft/headlamp-your-kubernetes-ui-focused-on-extensibility).

Open the **Headlamp** application then click on your AKS cluster.

![Headlamp home page](./assets/kaito/headlamp-home-page.png)

> [!knowledge]
> Headlamp will automatically detect the AKS cluster based on the kubeconfig file it finds in your home directory. If you don't see your AKS cluster, you will need to run the **az aks get-credentials** command to download the kubeconfig file.

In the cluster overview page, click on the **CREATE** button in the bottom left corner.

![Create resource](./assets/kaito/headlamp-create-resource.png)

This will open a a blank YAML editor. Copy the workspace YAML manifest from VS Code and paste it into the YAML editor in Headlamp then click **APPLY**.

![Headlamp YAML editor](./assets/kaito/headlamp-yaml-editor.png)

> [!alert]
> Make sure you have updated the instanceType to `Standard_NC40ads_H100_v5` before applying the manifest.

You will see a message in the bottom left indicating that the workspace has been created successfully. Leave the Headlamp application open for now and go back to VS Code.

![Headlamp workspace created](./assets/kaito/headlamp-workspace-created.png)

Now let's check the status of the workspace in VS Code. Go back to VS Code and make sure the **Kubernetes** extension is selected in the left sidebar. Right-click on your AKS cluster, select **Deploy a LLM with KAITO** and click **Manage KAITO Models**. You will see the workspace deployment progress.

Keep an eye on the **Resource Ready**, **Inference Ready**, and **Workspace Ready** statuses. The workspace deployment can take up to 15 minutes to complete.

![Manage KAITO models](./assets/kaito/vscode-k8s-kaito-manage-models.png)

### Testing with KAITO extension for VS Code

Once the workspace is ready, you will see a **Test** button appear in the workspace panel. This is a panel that allows you to test the inference endpoint, view the workspace logs, and delete the workspace when you are done with it. Click the **Test** button to test the inference endpoint. Being able to view workspace logs is useful for debugging and troubleshooting issues with the workspace.

![View workspace panel](./assets/kaito/vscode-k8s-kaito-workspace-actions.png)

Here you can enter a prompt and configure the following prompt parameters

- **Temperature** for controlling the randomness of the output
- **Top P** for controlling the diversity of the output
- **Top K** for controlling the number of tokens to sample from
- **Repetition Penalty** for controlling the penalty for repeating tokens
- **Max Length** for controlling the maximum length of the output

Adjust the prompt parameters as needed then type a prompt into the textbox, then click the **Submit Prompt** button to send the prompt to model's inference endpoint.

![Submit prompt](./assets/kaito/vscode-k8s-kaito-workspace-test.png)

The response will be displayed to the right of the prompt.

![Response](./assets/kaito/vscode-k8s-kaito-workspace-test-response.png)

## Developing with KAITO

With a workspace deployed, you can now start developing an AI application by interacting with the KAITO workspace endpoint using raw HTTP requests or using a library that supports the OpenAI API. Rather than writing code from scratch, let's download a small sample Python code that uses the [Chainlit](https://chainlit.io/) library to create interactive chat applications using Python.

### Download sample code

Open the VS Code terminal then run the following command to create a new directory for the project.

```bash
mkdir sampleapp
cd sampleapp
```

Using **curl**, download the sample code hosted in the KAITO GitHub repository and save the file as **main.py**.

```bash
curl -o main.py https://raw.githubusercontent.com/kaito-project/kaito/refs/heads/main/demo/inferenceUI/chainlit_openai.py
```

Open file in VS Code using the following command and familiarize yourself with the code.

```bash
code main.py
```

> [!help]
> Since we downloaded the file from the internet, you may be presented with a warning message indicating that the file is untrusted. The file can be trusted 😉 so click the **Open** button to open the file.
>
>![Untrusted file](./assets/kaito/vscode-untrusted-file.png)

The sample code uses the **openai** library to interact with the vLLM server which is serving the model. It uses the **AsyncOpenAI** class to create an OpenAI client for sending requests. The **WORKSPACE_SERVICE_URL** environment variable is used to specify the URL of the KAITO workspace. This is the only external variable that you need to set to run the code.

The sample code also uses the **chainlit** library to create a web UI for the application. When the Chainlit app starts, it will call the **start_chat** function to retrieve the list of models serviced by the vLLM server and select the first model. The **main** function is called when a message is submitted from the web UI. It builds a **messages** request object in a specific format the model can understand, which is setting the context and passing in the query from the web UI as a user message to send to the inference server. The **settings** dictionary near the top of the file is used to configure the prompt parameters and sent as part of the request, like how you configured the prompt parameters in the VS Code **Manage KAITO Deployments** tab. From there, the [Completions API](https://platform.openai.com/docs/guides/text?api-mode=chat) is used to send the message to the model and stream the response back to the web UI. As each part of the stream is received, it updates the web UI to display the partial response until the full response is received.

### Port-forward the workspace service

The Chainlit app needs to connect directly to the KAITO workspace service. The service runs as an internal service via ClusterIP which means it is not accessible from outside the cluster. But you can access it from your local machine when using the [Kubernetes port forwarding](https://kubernetes.io/docs/tasks/access-application-cluster/port-forward-access-application-cluster/) command.

Rather than using the **kubectl port-forward** command, let's use the Headlamp application to port-forward the workspace service.

In the Headlamp application, click on the **Network** tab in the left sidebar. In the list of Services, find the **workspace-phi-3-5-mini-instruct** service and click on it.

![workspace service](./assets/kaito/headlamp-network-service-workspace.png)

In the service details page, click on the **Forward port** button

![workspace service](./assets/kaito/headlamp-port-forward.png)

Make a note of the random port that is assigned to the service. This is the port that you will use to connect to the KAITO workspace.

![Port forward service](./assets/kaito/headlamp-port-forwarded.png)

Keep this port forwarded as you will need it for the remainder of the workshop.

### Configure the environment variable

Remember that the code looks for the **WORKSPACE_SERVICE_URL** environment variable to connect to the KAITO workspace.

Go back to your terminal in VS Code and run the following command to create a **.env** file and set the **WORKSPACE_SERVICE_URL** to point to the port-forwarded service.

```bash
echo "WORKSPACE_SERVICE_URL=http://127.0.0.1:60410/" > .env
```

> [!alert]
> The port number **60410** is what was randomly assigned to the service in the previous step. Make sure to replace this with the port number that was assigned to your service.

### Install dependencies

As you saw in the code, the sample app relies on a few Python packages to run. You could install them using **pip** but let's use a new tool called **uv** to manage the dependencies. [**uv**](https://docs.astral.sh/uv/) is a command line tool for managing Python package dependencies and projects and a good alternative to **pip** as it runs fast and has the ability to manage projects, environments, and dependencies within a single tool.

Run the following command to initialize a new **uv** project.

```bash
uv init
```

Add the following dependencies to the **uv** project. The **chainlit** package is used to create the web UI, **pydantic** is used for data validation, **requests** is used to make HTTP requests, and **openai** is used to interact with the vLLM server.

```bash
uv add chainlit pydantic==2.11.3 requests openai
```

Next, run the following command to start the Chainlit app and set the environment variable for the **WORKSPACE_SERVICE_URL** by passing in the **.env** file using the **--env-file** option.

```bash
uv run --env-file=.env chainlit run main.py
```

This will start a local web server, open a web browser and navigate to [http://localhost:8000](http://localhost:8000).

In the Chainlit app, enter a prompt in the text box and click the submit button to send the prompt to the KAITO workspace. The response will be displayed in the web UI.

![Chainlit app](./assets/kaito/chainlit-response.png)

As you can see, developing against the KAITO workspace is relatively simple. Using the OpenAI library to send requests makes it compatible with any existing codebase that uses the OpenAI API.

Press **Ctrl+c** to stop the Chainlit app.

## Monitoring KAITO workspaces

With workspaces being served using the vLLM runtime, you can monitor the performance of the KAITO workspace using the [metrics emitted by the vLLM server](https://github.com/kaito-project/kaito/blob/main/docs/inference/Monitoring.md). The vLLM server emits metrics in the Prometheus format which makes it very easy to be scraped by Prometheus and visualized in Grafana.

To view the metrics that is emitted by the vLLM server, browse to the **/metrics** endpoint of the workspace service which is [http://localhost:60410/metrics](http://localhost:60410/metrics).

> [!alert]
> The port number **60410** is what was randomly assigned to the service in the previous step. Make sure to replace this with the port number that was assigned to your service.

### Scrape metrics with Prometheus

To scrape the metrics emitted by the vLLM server, you need to have Prometheus installed in your AKS cluster. This AKS cluster in this lab environment is configured with [Azure Managed Prometheus](https://learn.microsoft.com/azure/azure-monitor/metrics/prometheus-metrics-overview) and [Azure Managed Grafana](https://learn.microsoft.com/azure/managed-grafana/overview) configured for monitoring.

With the metrics monitoring configured in the AKS cluster, Prometheus [ServiceMonitor](https://prometheus-operator.dev/docs/developer/getting-started/#using-servicemonitors) and [PodMonitor](https://prometheus-operator.dev/docs/developer/getting-started/#using-podmonitors) CRDs are installed. You could use either custom resource, but ServiceMonitor would be the preferred option because you can configure it at a higher level and it is easier to manage.

> [!knowledge]
> The Azure Managed Prometheus installation comes with special CRDs that use a different API version. The CRDs are installed in the **azmonitoring.coreos.com** API group. You can find more information about the CRDs in the [Azure Managed Prometheus documentation](https://learn.microsoft.com/azure/azure-monitor/containers/prometheus-metrics-scrape-crd).

Before you deploy the ServiceMonitor, you will need to label the workspace's service so that the ServiceMonitor can identify the service to scrape metrics from.

Let's use Headlamp again to label the workspace service. Go back to the Headlamp application and navigate back to the **workspace-phi-3-5-mini-instruct** service details page, click on the **edit** button in the top right corner.

![Edit service](./assets/kaito/headlamp-network-service-workspace-edit.png)

In the YAML editor window, find the **namespace** field and add a new line below it, then add the following text to label the service, then click the **APPLY** button.

```yaml
labels:
  kaito.sh/workspace: workspace-phi-3-5-mini-instruct
```

> [!alert]
> Be careful with the indentation. YAML is very sensitive to indentation and whitespace. Make sure the **labels** field is at the same level as the **namespace** field and the **kaito.sh/workspace** label is indented with two spaces.

![Workspace service edit](./assets/kaito/headlamp-network-service-workspace-label.png)

You should see the label added to the service.

![Label service](./assets/kaito/headlamp-network-service-workspace-labeled.png)

Next, deploy a ServiceMonitor to scrape from the **/metrics** endpoint. In the bottom left corner of the Headlamp application, click on the **CREATE** button to create a new resource.

![Headlamp create resource](./assets/kaito/headlamp-create-servicemonitor-button.png)

In the YAML editor, copy and paste the following YAML manifest to create a ServiceMonitor resource.

```yaml
apiVersion: azmonitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: workspace-phi-3-5-mini-instruct-monitor
spec:
  selector:
    matchLabels:
      kaito.sh/workspace: workspace-phi-3-5-mini-instruct
  endpoints:
  - port: http
    path: /metrics
    interval: 30s
    scheme: http
```

> [!warning]
> You might have to clear the previous YAML manifest in the editor before pasting the new one.

Notice the **selector** field in the ServiceMonitor YAML manifest is used to select the service to scrape metrics from. The **matchLabels** field is used to match the labels on the service. In this case, we are using the label we just added to the workspace service.

![Headlamp create ServiceMonitor](./assets/kaito/headlamp-create-servicemonitor-apply.png)

### Import vLLM Grafana dashboard

vLLM provides a [sample Grafana dashboard](https://docs.vllm.ai/en/latest/getting_started/examples/prometheus_grafana.html#example-materials) that you can use to monitor the performance of the KAITO workspace. You can import this dashboard into Azure Managed Grafana.

In the web browser, open a new tab and navigate to [https://docs.vllm.ai](https://docs.vllm.ai)

In the vLLM docs site, use the search bar to search for `grafana`.

![Grafana search](./assets/kaito/vllm-search-bar.png)

In the search results, click on the **Prometheus and Grafana** link.

![Grafana link](./assets/kaito/vllm-search-result.png)

In the **Prometheus and Grafana** page, scroll down to the **Example materials** section.

![Example materials](./assets/kaito/vllm-example-materials.png)

Expand the **grafana.json** section and click on the **copy** button to copy the JSON to your clipboard.

![Grafana dashboard JSON](./assets/kaito/vllm-grafana-dashboard-copy.png)

Now you need to import the dashboard into your Azure Managed Grafana instance. Open a new browser tab and navigate to [https://portal.azure.com](https://portal.azure.com). In the search bar, type `grafana` and select **Azure Managed Grafana**.

![Azure Managed Grafana](./assets/kaito/azure-grafana.png)

Click on your Azure Managed Grafana instance, then click on the endpoint URL to open the Grafana dashboard.

![Grafana endpoint](./assets/kaito/azure-grafana-endpoint.png)

Log into the Grafana dashboard using your Azure credentials, then click on the **Dashboards** tab on the left side of the screen.

![Grafana dashboards](./assets/kaito/azure-grafana-dashboard-button.png)

In the Grafana dashboards page, click on the **New** button in the top right corner, then click on the **Import** button.

![Grafana import dashboard](./assets/kaito/azure-grafana-new-import.png)

In the **Import** page, scroll down to the **Import via panel json** section and paste the JSON you copied from the vLLM docs site into the text box, then click the **Load** button.

![Grafana import JSON](./assets/kaito/azure-grafana-dashboard-paste.png)

Next, click the **Import** button to import the dashboard.

![Grafana import dashboard](./assets/kaito/azure-grafana-dashboard-import.png)

You should see a new dashboard but with no metrics yet. Click on the **model_name** dropdown and type in the name of the model which is `phi-3.5-mini-instruct` then press **Enter**.

![Grafana model name](./assets/kaito/azure-grafana-model-name.png)

Your dashboard may note be populated with metrics yet. This is because the ServiceMonitor has not had a chance to scrape the metrics yet. Let's generate some metrics by sending some requests to the KAITO workspace.

### Generate more metrics

To generate some metrics, you can run Chainlit app again and ask the model some more questions.

But let's take a different approach and use the **REST Client** extension in VS Code to send raw HTTP requests to the KAITO inference endpoint.

In VS Code, create a new file named `test.http`.

In the **test.http** file, add the following code to send POST requests to the inference endpoint.Be sure to update the port number in the code.

```http
### Ask the model a question
POST /v1/chat/completions
Host: localhost:60410
Content-Type: application/json

{
    "model": "phi-3.5-mini-instruct",
    "messages": [
        {
            "role": "user",
            "content": "What is Kubernetes?"
        }
    ],
    "temperature": 0.7,
    "max_tokens": 500,
    "top_p": 1,
    "frequency_penalty": 0,
    "presence_penalty": 0
}
```

> [!alert]
> The port number **60410** is what was randomly assigned to the service in the previous step. Make sure to replace this with the port number that was assigned to your service.

The request is in the OpenAI API format which is documented [here](https://platform.openai.com/docs/api-reference/chat/create) and is very similar to the request you sent from the Chainlit app.

Save the file then click on the **Send Request** link above the request to send the request to the KAITO workspace.

![Send request](./assets/kaito/vscode-http-request.png)

You should see a response from the KAITO workspace in a new tab on the right.

![Response](./assets/kaito/vscode-http-response.png)

Change the question and click on the **Send Request** link a few more times to generate some metrics.

### View metrics in Grafana

Now that you have generated some metrics, you can go back to the Azure Managed Grafana dashboard and refresh the page.

You should start to see some metrics being generated as you send requests to the KAITO workspace.

![vLLM dashboard metrics](./assets/kaito/azure-grafana-dashboard-vllm-metrics.png)

You may need to refresh the dashboard or expand the time range to see the metrics.

The dashboard includes several panels displaying Prometheus metrics exposed by the vLLM server. You may find these particularly useful:

- **E2E Request Latency**: Shows the total time (in seconds) from when an inference request is sent until the response is fully received. A key indicator of overall responsiveness.
- **Token Throughput**: Indicates how many tokens are processed per second during inference, reflecting the model’s processing speed.
- **Cache Utilization**: Reports the percentage of the key‐value cache in use, helping you assess memory efficiency.
- **Time to First Token**: Measures the delay before the first token is generated, highlighting initial response latency.
- **Finish Reason**: Breaks down why requests end (e.g., completed, max tokens reached, aborted), useful for diagnosing performance constraints.

Feel free to explore the dashboard and see what other metrics are available.

## Summary

Congratulations, now you know how to deploy, manage, and monitor open-source AI models on AKS using KAITO!

In this workshop, you learned how to use Visual Studio Code to deploy the KAITO add-on for AKS and work with the inferencing workspace. You also learned how to monitor the KAITO workspace by scraping metrics with Azure Managed Prometheus and ServiceMonitor CRD and visualizing the metrics by importing the vLLM Grafana dashboard into Azure Managed Grafana.

You also learned a little bit about how the Chainlit library can be used to quickly create interactive chat applications with Python. The KAITO workspace defaults to using the vLLM inference runtime which is a high-performance inference engine for large language models. It's great because it is compatible with the OpenAI API and has support for metrics out-of-the-box.

With Kubernetes and KAITO, you can see how much of the heavy lifting is done for you and you can focus on building your AI applications. The KAITO operator automates the deployment and management of AI/ML workloads, allowing you to easily deploy and manage large models on AKS.

Lastly, as an added bonus, you learned how to use Headlamp to manage Kubernetes resources via a GUI. Headlamp is a great tool for managing Kubernetes resources especially for those who aren't as familiar with using the kubectl CLI.

## What's next?

We've just scratched the surface of what KAITO can do. There are a few more features of KAITO that wasn't covered in this workshop, like fine-tuning models and RAG engine support. But stay tuned for more workshops on KAITO and stay up to date with the latest features and updates by following the [KAITO project on GitHub](https://github.com/kaito-project/kaito).

## Resources

To learn more, check out the following resources:

- [Kubernetes AI Toolchain Operator](https://github.com/kaito-project/kaito)
- [AKS KAITO add-on](https://learn.microsoft.com/azure/aks/ai-toolchain-operator)
- [Deploy and test inference models iwth the AI toolchain operator (KAITO) in Visual Studio Code](https://learn.microsoft.com/en-us/azure/aks/aks-extension-kaito)
- [AKS KAITO Monitoring](https://learn.microsoft.com/azure/aks/ai-toolchain-operator-monitoring)
- [Azure Managed Prometheus - Create a Pod or Service Monitor](https://learn.microsoft.com/azure/azure-monitor/containers/prometheus-metrics-scrape-crd#create-a-pod-or-service-monitor)
- [vLLM Metrics](https://docs.vllm.ai/en/latest/design/v1/metrics.html)
- [vLLM Prometheus and Grafana](https://docs.vllm.ai/en/latest/getting_started/examples/prometheus_grafana.html)
- [Chainlit OpenAI integrations](https://docs.chainlit.io/integrations/openai)
- [Chainlit messages](https://docs.chainlit.io/concepts/message)
- [uv](https://docs.astral.sh/uv/)
- [Headlamp](https://headlamp.dev/)
