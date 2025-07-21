---
title: Build RAG applications with KAITO RAGEngine
---

import Prerequisites from "../../src/components/SharedMarkdown/_prerequisites.mdx";

Retrieval Augmented Generation (RAG) is a powerful technique that combines the strengths of large language models (LLMs) with external knowledge sources. This approach enables more accurate and contextually relevant responses by retrieving information from knowledge bases or databases and using it to augment the LLM's output.

This workshop will guide you through setting up an easy-to-use RAG solution using KAITO on Azure Kubernetes Service (AKS). KAITO is a Kubernetes operator that simplifies the deployment and management of AI tooling on Kubernetes. With the v0.5.0 release, KAITO has introduced a new RAGEngine operator that makes it simple to deploy and manage RAG workloads on AKS.

## Objectives

By the end of this workshop, you will be able to:

- Understand the concept of Retrieval Augmented Generation (RAG).
- Set up a RAG solution using KAITO on Azure Kubernetes Service (AKS).
- Deploy and manage RAG workloads with KAITO's RAGEngine operator.
- Integrate external knowledge sources with LLMs for enhanced responses.

<Prerequisites tools={[
  {
    "name": "Helm",
    url: "https://helm.sh/docs/intro/install/"
  },
  {
    "name": "Terraform",
    url: "https://www.terraform.io/downloads.html"
  }
]}
/>

### Setup AKS Cluster with KAITO

To get started with KAITO on AKS, you will first need to set up an Azure Kubernetes Service (AKS) cluster. Then you'll need to install the KAITO operators on your AKS cluster. This process can be a bit complex to start, so we'll lean on the Terraform scripts provided by the KAITO project to simplify the deployment. This will allow you to quickly set up the necessary infrastructure and install the operators without having to manually configure everything.

Start by cloning the KAITO repository and navigating to the **kaito/terraform** directory:

```bash
git clone https://github.com/kaito-project/kaito.git
cd kaito/terraform
```

Next, you need to set up the Terraform CLI so that it can deploy resources in your Azure subscription. If you haven't already, install the Terraform CLI by following the instructions on the [Terraform website](https://www.terraform.io/downloads.html) then run the following command to configure your Azure subscription:

```bash
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
```

Now, you can initialize the Terraform project and apply the configuration to create your AKS cluster:

```bash
terraform init
terraform apply
```

:::note

When prompted, type `yes` to confirm the creation of the resources. This process will take a few minutes to complete.

:::

Once the resources are deployed, connect to the cluster and deploy a sample workload to make this example a bit more real.

Run the following command to connect to your AKS cluster:

```bash
az aks get-credentials \
--resource-group $(terraform output -raw rg_name) \
--name $(terraform output -raw aks_name)
```

### Deploy KAITO Workspace

Once the AKS cluster is set up with KAITO installed, you can deploy a KAITO workspace. KAITO workspaces are used to manage model inference deployments within your cluster. Run the following command to create a workspace for the **phi-4-mini-instruct** model:

```bash
kubectl apply -f- <<EOF
apiVersion: kaito.sh/v1beta1
kind: Workspace
metadata:
  name: workspace-phi-4-mini-instruct
resource:
  instanceType: Standard_NC24ads_A100_v4
  labelSelector:
    matchLabels:
      apps: phi-4-mini-instruct
inference:
  preset:
    name: phi-4-mini-instruct
EOF
```

:::danger

You must have sufficient quota available in your Azure subscription to deploy the workspace. If you don't have at least 24 vCPUs of Standard NCads A100 v4 GPU quota, you will need to request additional quota from Azure support.

:::

### Deploy Sample Workload

Finally, in order to demonstrate a real-world use case for RAG, you will deploy a sample e-commerce application. This application is a simple online store that sells pet supplies. In our scenario, we will use this application and its product data to build a RAG application that can answer questions about the products available in the store.

Run the following command to deploy the sample workload:

```bash
kubectl apply -f https://raw.githubusercontent.com/Azure-Samples/aks-store-demo/refs/heads/main/aks-store-quickstart.yaml
```

Once the deployment is complete, you can access the store front by running the following command to get the external IP address of the service:

```bash
kubectl get service store-front -ojsonpath='{.status.loadBalancer.ingress[0].ip}'
```

This will return the external IP address of the store front service. You can then open this IP address in your web browser to access the store front.

Note the products available in the store, as you will use this data to build and test your RAG application.

## What is KAITO RAGEngine?

KAITO RAGEngine is a Kubernetes

## Deploy RAGEngine

```bash
kubectl apply -f - <<EOF
apiVersion: kaito.sh/v1alpha1
kind: RAGEngine
metadata:
  name: ragdemo
spec:
  compute:
    instanceType: Standard_D8s_v4
    labelSelector:
      matchLabels:
        apps: ragdemo
  embedding:
    local:
      modelID: BAAI/bge-small-en-v1.5
  inferenceService:  
    url: "http://workspace-phi-4-mini-instruct/v1/completions"
EOF
```

## Indexing Data

### Data Preparation

```bash
STORE_IP=$(kubectl get service store-front -ojsonpath='{.status.loadBalancer.ingress[0].ip}')
```

```bash
curl http://${STORE_IP}/api/products | jq
```

Now let's transform this product data into a format suitable for indexing with the RAGEngine:

```bash
curl http://${STORE_IP}/api/products | jq --arg store_ip "$STORE_IP" '{
  index_name: "store_index",
  documents: [
    .[] | {
      text: "\(.name) - \(.description) Price: $\(.price)",
      metadata: {
        author: "Contoso Pet Supply",
        category: (
          if (.name | test("cat|Cat|feline|kitty"; "i")) then "Cat Toys"
          elif (.name | test("dog|Dog|Doggy"; "i")) then "Dog Toys"
          elif (.name | test("Bed|bed"; "i")) then "Pet Beds"
          elif (.name | test("Life Jacket|Jacket"; "i")) then "Pet Accessories"
          else "Pet Toys"
          end
        ),
        url: "http://\($store_ip)/product/\(.id)"
      }
    }
  ]
}' > store_products.json
```

Verify the transformation:

```bash
cat store_products.json | jq
```

### Indexing with RAGEngine

```bash
kubectl port-forward svc/ragdemo 8080:80
```

Press **ctrl+z** to suspend the process then press **bg** to move the process to the background.

```bash
curl -X POST http://localhost:8080/index \
-H "Content-Type: application/json" \
-d @store_products.json | jq
```

```bash
curl http://localhost:8080/indexes
```


```bash
curl -X POST http://localhost:8080/indexes/store_index/documents #todo this is not working
```

```bash
curl -s http://localhost:8080/query \
-X POST \
-H "Content-Type: application/json" \
-d '{
  "index_name": "store_index",
  "query": "I need a new bed for my cat. Can you help me?",
  "top_k": 5,
  "llm_params": {
    "temperature": 0.7,
    "max_tokens": 2048
  }
}' | jq
```

## Querying with RAGEngine

## Summary

## Additional Resources
