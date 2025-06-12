---
title: Scaling AI Workloads with Ray on AKS
description: Learn how to deploy and scale distributed AI workloads using Ray on Azure Kubernetes Service (AKS). This lab covers Ray cluster setup, distributed machine learning training, and scaling AI inference workloads.
sidebar_position: 2
sidebar_label: Ray on AKS
level: intermediate
authors:
  - AKS Labs Team
duration_minutes: 120
tags: 
  - ai
  - ray
  - distributed-computing
  - machine-learning
  - kubernetes
---

# Scaling AI Workloads with Ray on AKS

In this lab, you will learn how to deploy and scale distributed AI workloads using Ray on Azure Kubernetes Service (AKS). Ray is an open-source framework for scaling AI and Python applications, providing distributed computing capabilities that are essential for modern machine learning workloads.

## Overview

Ray enables you to scale your AI workloads from a single machine to a cluster of machines with minimal code changes. It provides several key libraries:

- **Ray Core**: Distributed computing primitives
- **Ray Train**: Distributed machine learning training
- **Ray Serve**: Scalable model serving
- **Ray Tune**: Hyperparameter tuning at scale
- **Ray Data**: Distributed data processing

In this lab, we'll deploy a Ray cluster on AKS and demonstrate distributed machine learning training and inference serving.

## Objectives

By the end of this lab, you will be able to:

- Deploy a Ray cluster on AKS using the KubeRay operator
- Run distributed machine learning training jobs with Ray Train
- Serve ML models at scale using Ray Serve
- Monitor and scale Ray workloads on Kubernetes
- Implement distributed data processing with Ray Data
- Configure auto-scaling for Ray worker nodes

## Prerequisites

Before you begin this lab, you will need:

- [Azure subscription](https://azure.microsoft.com/free) with AKS deployment permissions
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) installed and authenticated
- [kubectl](https://kubernetes.io/docs/tasks/tools/) configured for your AKS cluster
- [Helm](https://helm.sh/docs/intro/install/) installed
- [Python 3.8+](https://www.python.org/downloads) with pip
- Basic knowledge of Kubernetes, Python, and machine learning concepts

<div class="info" data-title="Note">

> This lab assumes you have an existing AKS cluster. If you need to create one, you can use the AKS Automatic cluster from the previous workshop or create a standard AKS cluster with at least 3 nodes (Standard_DS3_v2 or larger) to handle Ray workloads effectively.

</div>

<div class="important" data-title="Resource Requirements">

> Ray workloads can be resource-intensive. Ensure your AKS cluster has sufficient resources:
> 
> **For CPU deployment (default):**
> - At least 3 worker nodes
> - Minimum 4 vCPUs and 16GB RAM per node (Standard_DS3_v2 or larger)
> - Consider enabling cluster autoscaler for dynamic scaling
> 
> **For GPU deployment (optional):**
> - GPU-enabled node pool with Standard_NC6s_v3 or similar
> - Sufficient GPU quota in your Azure subscription
> - NVIDIA drivers (automatically installed by AKS)

</div>

---

## Choose Your Deployment Type

Before we begin setting up the environment, you need to decide whether to run Ray workloads on CPU or GPU nodes. This choice will affect the configuration throughout the lab.

### CPU-Based Deployment (Recommended for Most Users)

**Best for:**
- Learning Ray concepts and distributed computing
- Cost-effective development and testing
- General machine learning workloads
- Clusters without GPU nodes

**Requirements:**
- Standard AKS cluster with CPU nodes
- Minimum 4 vCPUs and 16GB RAM per node
- No special quota requirements

**Pros:**
- Lower cost
- Easier setup
- Works on any AKS cluster
- Good for most ML workloads

### GPU-Based Deployment (For Accelerated Workloads)

**Best for:**
- Deep learning with large models
- Computer vision workloads
- High-performance training scenarios
- Production ML pipelines requiring acceleration

**Requirements:**
- AKS cluster with GPU-enabled node pools (NC, ND, or NV series VMs)
- GPU quota in your Azure subscription
- NVIDIA device plugin installed on AKS
- Additional cost considerations

**Setup GPU Node Pool:**
```bash
# Add GPU node pool to existing AKS cluster
az aks nodepool add \
    --resource-group myResourceGroup \
    --cluster-name myAKSCluster \
    --name gpunodepool \
    --node-count 1 \
    --node-vm-size Standard_NC6s_v3 \
    --node-taints sku=gpu:NoSchedule \
    --aks-custom-headers UseGPUDedicatedVHD=true \
    --enable-cluster-autoscaler \
    --min-count 1 \
    --max-count 3
```

**Enable NVIDIA Device Plugin:**
```bash
# Install NVIDIA device plugin
kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.14.1/nvidia-device-plugin.yml
```

### Making Your Choice

<div class="tip" data-title="Recommendation">

> **For this lab, we recommend starting with CPU-based deployment** unless you specifically need GPU acceleration and have the required infrastructure setup. All Ray concepts and distributed computing patterns work the same way on both CPU and GPU.

</div>

**Throughout this lab:**
- **CPU users**: Follow the default configurations
- **GPU users**: Look for the GPU variant sections and modify configurations accordingly

---

## Setting up the Environment

### Prepare your AKS cluster

First, let's ensure your AKS cluster is ready for Ray workloads. We'll create a dedicated namespace and configure the necessary RBAC permissions.

```bash
# Create a namespace for Ray workloads
kubectl create namespace ray-system

# Verify cluster nodes and resources
kubectl get nodes -o wide
kubectl top nodes
```

### Install KubeRay Operator

The KubeRay operator simplifies the deployment and management of Ray clusters on Kubernetes. We'll install it using Helm.

```bash
# Add the KubeRay Helm repository
helm repo add kuberay https://ray-project.github.io/kuberay-helm/
helm repo update

# Install the KubeRay operator
helm install kuberay-operator kuberay/kuberay-operator \
  --namespace ray-system \
  --create-namespace \
  --version 1.0.0

# Verify the operator is running
kubectl get pods -n ray-system
kubectl get crd | grep ray
```

<div class="info" data-title="Note">

> The KubeRay operator will create Custom Resource Definitions (CRDs) that allow you to manage Ray clusters as Kubernetes resources.

</div>

## Create a Ray Cluster Configuration

Let's create a Ray cluster configuration that includes both head and worker nodes with appropriate resource allocations.

<div class="tip" data-title="CPU vs GPU Configuration">

> The configuration below is for **CPU deployment**. If you chose GPU deployment in the previous section, scroll down to see the **GPU variant** after the CPU configuration.

</div>

### CPU Configuration (Default)

```yaml
# ray-cluster.yaml
apiVersion: ray.io/v1alpha1
kind: RayCluster
metadata:
  labels:
    controller-tools.k8s.io: "1.0"
    # A unique identifier for the head node and workers of this cluster.
  name: raycluster-ml
  namespace: ray-system
spec:
  rayVersion: '2.8.0'
  # Ray head pod template
  headGroupSpec:
    # The `rayStartParams` are used to start the `ray head` process.
    rayStartParams:
      dashboard-host: '0.0.0.0'
      block: 'true'
    #pod template
    template:
      spec:
        containers:
        - name: ray-head
          image: rayproject/ray-ml:2.8.0-py310
          ports:
          - containerPort: 6379
            name: gcs-server
          - containerPort: 8265
            name: dashboard
          - containerPort: 10001
            name: client
          resources:
            limits:
              cpu: 2
              memory: 4Gi
            requests:
              cpu: 1
              memory: 2Gi
          volumeMounts:
          - mountPath: /tmp/ray
            name: ray-logs
        volumes:
        - name: ray-logs
          emptyDir: {}
  workerGroupSpecs:
  # the pod replicas in this group typed worker
  - replicas: 2
    minReplicas: 1
    maxReplicas: 5
    # logical group name, for this called small-group, also can be functional
    groupName: small-group
    # The `rayStartParams` are used to start the `ray worker` process.
    rayStartParams: {}
    #pod template
    template:
      spec:
        initContainers:
        # The init container is used to wait for the head node to be ready
        - name: init
          image: busybox:1.28
          command: ['sh', '-c', "until nslookup $RAY_IP.$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace).svc.cluster.local; do echo waiting for K8s Service $RAY_IP; sleep 2; done"]
        containers:
        - name: ray-worker
          image: rayproject/ray-ml:2.8.0-py310
          lifecycle:
            preStop:
              exec:
                command: ["/bin/sh","-c","ray stop"]
          resources:
            limits:
              cpu: 2
              memory: 4Gi
            requests:
              cpu: 1
              memory: 2Gi
          volumeMounts:
          - mountPath: /tmp/ray
            name: ray-logs
        volumes:
        - name: ray-logs
          emptyDir: {}
```

### GPU Configuration (Alternative)

If you chose GPU deployment, use this configuration instead:

```yaml
# ray-cluster-gpu.yaml
apiVersion: ray.io/v1alpha1
kind: RayCluster
metadata:
  labels:
    controller-tools.k8s.io: "1.0"
  name: raycluster-ml-gpu
  namespace: ray-system
spec:
  rayVersion: '2.8.0'
  # Ray head pod template (CPU-only for coordination)
  headGroupSpec:
    rayStartParams:
      dashboard-host: '0.0.0.0'
      block: 'true'
    template:
      spec:
        containers:
        - name: ray-head
          image: rayproject/ray-ml:2.8.0-py310
          ports:
          - containerPort: 6379
            name: gcs-server
          - containerPort: 8265
            name: dashboard
          - containerPort: 10001
            name: client
          resources:
            limits:
              cpu: 2
              memory: 4Gi
            requests:
              cpu: 1
              memory: 2Gi
          volumeMounts:
          - mountPath: /tmp/ray
            name: ray-logs
        volumes:
        - name: ray-logs
          emptyDir: {}
  workerGroupSpecs:
  # GPU worker group
  - replicas: 2
    minReplicas: 1
    maxReplicas: 4
    groupName: gpu-workers
    rayStartParams:
      resources: '{"CPU": 4, "GPU": 1}'
    template:
      spec:
        nodeSelector:
          accelerator: nvidia-tesla-v100  # Adjust based on your GPU type
        tolerations:
        - key: sku
          operator: Equal
          value: gpu
          effect: NoSchedule
        initContainers:
        - name: init
          image: busybox:1.28
          command: ['sh', '-c', "until nslookup $RAY_IP.$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace).svc.cluster.local; do echo waiting for K8s Service $RAY_IP; sleep 2; done"]
        containers:
        - name: ray-worker
          image: rayproject/ray-ml:2.8.0-gpu  # GPU-enabled image
          lifecycle:
            preStop:
              exec:
                command: ["/bin/sh","-c","ray stop"]
          resources:
            limits:
              cpu: 4
              memory: 16Gi
              nvidia.com/gpu: 1  # Request 1 GPU
            requests:
              cpu: 2
              memory: 8Gi
              nvidia.com/gpu: 1
          volumeMounts:
          - mountPath: /tmp/ray
            name: ray-logs
        volumes:
        - name: ray-logs
          emptyDir: {}
```

<div class="important" data-title="GPU Configuration Notes">

> **Key differences for GPU deployment:**
> - Uses `rayproject/ray-ml:2.8.0-gpu` image with CUDA support
> - Adds `nvidia.com/gpu: 1` resource requests
> - Includes node selector for GPU nodes
> - Adds tolerations for GPU node taints
> - Configures Ray resources with GPU allocation

</div>

## Deploy the Ray Cluster

Save your chosen configuration and apply it to your cluster:

**For CPU deployment:**
```bash
# Apply the CPU Ray cluster configuration
kubectl apply -f ray-cluster.yaml

# Wait for the cluster to be ready
kubectl get raycluster -n ray-system -w

# Check the status of Ray pods
kubectl get pods -n ray-system -l ray.io/cluster=raycluster-ml
```

**For GPU deployment:**
```bash
# Apply the GPU Ray cluster configuration
kubectl apply -f ray-cluster-gpu.yaml

# Wait for the cluster to be ready
kubectl get raycluster -n ray-system -w

# Check the status of Ray pods (including GPU allocation)
kubectl get pods -n ray-system -l ray.io/cluster=raycluster-ml-gpu
kubectl describe pod -n ray-system -l ray.io/node-type=worker
```

## Access the Ray Dashboard

The Ray dashboard provides a web interface for monitoring your Ray cluster and jobs.

```bash
# Port forward to access the Ray dashboard
kubectl port-forward -n ray-system service/raycluster-ml-head-svc 8265:8265
```

Open your browser and navigate to `http://localhost:8265` to access the Ray dashboard.

<div class="tip" data-title="Dashboard Features">

> The Ray dashboard shows:
> - Cluster resource utilization
> - Running jobs and tasks
> - Actor and task execution details
> - Log streaming
> - Performance metrics

</div>

---

# Distributed Machine Learning with Ray Train

Ray Train enables you to scale machine learning training across multiple nodes with minimal code changes. In this section, we'll implement distributed training for image classification.

## Create a Training Script

First, let's create a distributed training script that uses Ray Train to scale across multiple nodes.

```python
# distributed_training.py
import os
import tempfile
import torch
import torch.nn as nn
import torch.nn.functional as F
from torch.utils.data import DataLoader
from torchvision import datasets, transforms
import ray
from ray import train
from ray.train import Checkpoint, ScalingConfig
from ray.train.torch import TorchTrainer

# Define a simple CNN model
class SimpleCNN(nn.Module):
    def __init__(self):
        super(SimpleCNN, self).__init__()
        self.conv1 = nn.Conv2d(1, 32, 3, 1)
        self.conv2 = nn.Conv2d(32, 64, 3, 1)
        self.dropout1 = nn.Dropout(0.25)
        self.dropout2 = nn.Dropout(0.5)
        self.fc1 = nn.Linear(9216, 128)
        self.fc2 = nn.Linear(128, 10)

    def forward(self, x):
        x = self.conv1(x)
        x = F.relu(x)
        x = self.conv2(x)
        x = F.relu(x)
        x = F.max_pool2d(x, 2)
        x = self.dropout1(x)
        x = torch.flatten(x, 1)
        x = self.fc1(x)
        x = F.relu(x)
        x = self.dropout2(x)
        x = self.fc2(x)
        return F.log_softmax(x, dim=1)

def train_func(config):
    # Model setup
    model = SimpleCNN()
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    model.to(device)
    
    # Data setup
    transform = transforms.Compose([
        transforms.ToTensor(),
        transforms.Normalize((0.1307,), (0.3081,))
    ])
    
    train_dataset = datasets.MNIST(
        root="/tmp/data",
        train=True,
        download=True,
        transform=transform
    )
    
    # Use Ray's DistributedSampler for data parallelism
    train_loader = DataLoader(
        train_dataset,
        batch_size=config["batch_size"],
        sampler=train.torch.get_device().make_data_parallel_sampler(train_dataset)
    )
    
    # Wrap model for distributed training
    model = train.torch.prepare_model(model)
    
    optimizer = torch.optim.Adam(model.parameters(), lr=config["lr"])
    loss_fn = nn.CrossEntropyLoss()
    
    # Training loop
    for epoch in range(config["epochs"]):
        model.train()
        running_loss = 0.0
        correct = 0
        total = 0
        
        for batch_idx, (data, target) in enumerate(train_loader):
            data, target = data.to(device), target.to(device)
            optimizer.zero_grad()
            output = model(data)
            loss = loss_fn(output, target)
            loss.backward()
            optimizer.step()
            
            running_loss += loss.item()
            _, predicted = torch.max(output.data, 1)
            total += target.size(0)
            correct += (predicted == target).sum().item()
            
            if batch_idx % 100 == 0:
                print(f'Epoch: {epoch}, Batch: {batch_idx}, '
                      f'Loss: {loss.item():.4f}, '
                      f'Accuracy: {100 * correct / total:.2f}%')
        
        # Report metrics to Ray Train
        epoch_loss = running_loss / len(train_loader)
        epoch_acc = 100 * correct / total
        
        # Save checkpoint
        with tempfile.TemporaryDirectory() as temp_checkpoint_dir:
            torch.save(model.state_dict(), 
                      os.path.join(temp_checkpoint_dir, "model.pt"))
            
            train.report(
                {"loss": epoch_loss, "accuracy": epoch_acc},
                checkpoint=Checkpoint.from_directory(temp_checkpoint_dir)
            )

def main():
    # Connect to Ray cluster
    ray.init(address="ray://raycluster-ml-head-svc:10001")
    
    # Configure distributed training
    # For CPU deployment (default):
    scaling_config = ScalingConfig(
        num_workers=2,  # Number of distributed workers
        use_gpu=False   # Set to True if using GPU deployment option
    )
    
    # For GPU deployment, use this instead:
    # scaling_config = ScalingConfig(
    #     num_workers=2,
    #     use_gpu=True,
    #     resources_per_worker={"CPU": 2, "GPU": 1}
    # )
    
    # Training configuration
    train_config = {
        "lr": 0.001,
        "batch_size": 64,
        "epochs": 5
    }
    
    # Create and run the trainer
    trainer = TorchTrainer(
        train_loop_per_worker=train_func,
        train_loop_config=train_config,
        scaling_config=scaling_config
    )
    
    result = trainer.fit()
    print(f"Training completed! Best result: {result}")
    
    # Save the final model
    checkpoint = result.checkpoint
    with tempfile.TemporaryDirectory() as temp_dir:
        checkpoint.to_directory(temp_dir)
        print(f"Model saved to: {temp_dir}")

if __name__ == "__main__":
    main()
```

## Create a Training Job Pod

Let's create a Kubernetes job to run our distributed training:

```yaml
# training-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: ray-distributed-training
  namespace: ray-system
spec:
  template:
    spec:
      containers:
      - name: ray-training
        image: rayproject/ray-ml:2.8.0-py310
        command: ["python"]
        args: ["/app/distributed_training.py"]
        resources:
          requests:
            cpu: 1
            memory: 2Gi
          limits:
            cpu: 2
            memory: 4Gi
        volumeMounts:
        - name: training-script
          mountPath: /app
        env:
        - name: RAY_ADDRESS
          value: "ray://raycluster-ml-head-svc:10001"
      volumes:
      - name: training-script
        configMap:
          name: training-script
      restartPolicy: Never
  backoffLimit: 4
```

Create a ConfigMap with the training script:

```bash
# Create ConfigMap with the training script
kubectl create configmap training-script \
  --from-file=distributed_training.py \
  -n ray-system

# Apply the training job
kubectl apply -f training-job.yaml

# Monitor the job
kubectl get jobs -n ray-system -w
kubectl logs -n ray-system job/ray-distributed-training -f
```

---

# Model Serving with Ray Serve

Ray Serve provides scalable model serving capabilities that can handle high-throughput inference workloads. In this section, we'll deploy our trained model for real-time inference.

## Create a Model Serving Application

```python
# model_serving.py
import io
import torch
import torch.nn as nn
import torch.nn.functional as F
from PIL import Image
from torchvision import transforms
import ray
from ray import serve
from ray.serve import Application
import numpy as np
from starlette.requests import Request
from starlette.responses import JSONResponse

# Same model definition as training
class SimpleCNN(nn.Module):
    def __init__(self):
        super(SimpleCNN, self).__init__()
        self.conv1 = nn.Conv2d(1, 32, 3, 1)
        self.conv2 = nn.Conv2d(32, 64, 3, 1)
        self.dropout1 = nn.Dropout(0.25)
        self.dropout2 = nn.Dropout(0.5)
        self.fc1 = nn.Linear(9216, 128)
        self.fc2 = nn.Linear(128, 10)

    def forward(self, x):
        x = self.conv1(x)
        x = F.relu(x)
        x = self.conv2(x)
        x = F.relu(x)
        x = F.max_pool2d(x, 2)
        x = self.dropout1(x)
        x = torch.flatten(x, 1)
        x = self.fc1(x)
        x = F.relu(x)
        x = self.dropout2(x)
        x = self.fc2(x)
        return F.log_softmax(x, dim=1)

@serve.deployment(
    num_replicas=2,
    # For CPU deployment (default):
    ray_actor_options={"num_cpus": 1, "num_gpus": 0}
    # For GPU deployment, use this instead:
    # ray_actor_options={"num_cpus": 2, "num_gpus": 1}
)
class MNISTClassifier:
    def __init__(self, model_path: str = None):
        self.model = SimpleCNN()
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        
        # Load model weights if provided
        if model_path:
            self.model.load_state_dict(torch.load(model_path, map_location=self.device))
        
        self.model.to(self.device)
        self.model.eval()
        
        # Define image transformation
        self.transform = transforms.Compose([
            transforms.Grayscale(),
            transforms.Resize((28, 28)),
            transforms.ToTensor(),
            transforms.Normalize((0.1307,), (0.3081,))
        ])

    async def __call__(self, request: Request) -> JSONResponse:
        try:
            # Handle different input types
            if request.headers.get("content-type", "").startswith("image/"):
                # Handle image upload
                image_bytes = await request.body()
                image = Image.open(io.BytesIO(image_bytes))
            else:
                # Handle JSON with base64 encoded image or raw array
                json_input = await request.json()
                if "image" in json_input:
                    # Base64 encoded image
                    import base64
                    image_bytes = base64.b64decode(json_input["image"])
                    image = Image.open(io.BytesIO(image_bytes))
                elif "data" in json_input:
                    # Raw array data
                    data = np.array(json_input["data"]).reshape(28, 28)
                    image = Image.fromarray((data * 255).astype(np.uint8))
                else:
                    return JSONResponse({"error": "Invalid input format"}, status_code=400)
            
            # Preprocess the image
            input_tensor = self.transform(image).unsqueeze(0).to(self.device)
            
            # Make prediction
            with torch.no_grad():
                output = self.model(input_tensor)
                probabilities = F.softmax(output, dim=1)
                predicted_class = torch.argmax(probabilities, dim=1).item()
                confidence = probabilities[0][predicted_class].item()
            
            return JSONResponse({
                "prediction": predicted_class,
                "confidence": float(confidence),
                "probabilities": probabilities[0].tolist()
            })
            
        except Exception as e:
            return JSONResponse({"error": str(e)}, status_code=500)

# Create the Ray Serve application
app = MNISTClassifier.bind()
```

## Deploy the Serving Application

Create a RayService resource to deploy the model serving application:

```yaml
# ray-service.yaml
apiVersion: ray.io/v1alpha1
kind: RayService
metadata:
  name: mnist-classifier-service
  namespace: ray-system
spec:
  serviceUnhealthySecondThreshold: 900
  deploymentUnhealthySecondThreshold: 300
  serveConfigV2: |
    applications:
      - name: mnist_classifier
        import_path: model_serving:app
        route_prefix: /mnist
        runtime_env:
          working_dir: "."
        deployments:
          - name: MNISTClassifier
            num_replicas: 2
            ray_actor_options:
              num_cpus: 1
  rayClusterConfig:
    rayVersion: '2.8.0'
    headGroupSpec:
      rayStartParams:
        dashboard-host: '0.0.0.0'
        serve-host: '0.0.0.0'
      template:
        spec:
          containers:
          - name: ray-head
            image: rayproject/ray-ml:2.8.0-py310
            ports:
            - containerPort: 6379
              name: gcs-server
            - containerPort: 8265
              name: dashboard
            - containerPort: 10001
              name: client
            - containerPort: 8000
              name: serve
            resources:
              limits:
                cpu: 2
                memory: 4Gi
              requests:
                cpu: 1
                memory: 2Gi
            volumeMounts:
            - mountPath: /tmp/ray
              name: ray-logs
            - mountPath: /app
              name: serve-code
          volumes:
          - name: ray-logs
            emptyDir: {}
          - name: serve-code
            configMap:
              name: serve-code
    workerGroupSpecs:
    - replicas: 2
      minReplicas: 1
      maxReplicas: 4
      groupName: serve-group
      rayStartParams: {}
      template:
        spec:
          containers:
          - name: ray-worker
            image: rayproject/ray-ml:2.8.0-py310
            resources:
              limits:
                cpu: 2
                memory: 4Gi
              requests:
                cpu: 1
                memory: 2Gi
            volumeMounts:
            - mountPath: /tmp/ray
              name: ray-logs
            - mountPath: /app
              name: serve-code
          volumes:
          - name: ray-logs
            emptyDir: {}
          - name: serve-code
            configMap:
              name: serve-code
```

Deploy the serving application:

```bash
# Create ConfigMap with the serving code
kubectl create configmap serve-code \
  --from-file=model_serving.py \
  -n ray-system

# Apply the Ray service
kubectl apply -f ray-service.yaml

# Wait for the service to be ready
kubectl get rayservice -n ray-system -w

# Check the service status
kubectl describe rayservice mnist-classifier-service -n ray-system
```

## Test the Model Serving

Let's create a simple test script to verify our model serving endpoint:

```python
# test_serving.py
import requests
import numpy as np
import json

def test_mnist_service():
    # Create a sample MNIST-like image (28x28 random data)
    sample_data = np.random.rand(28, 28).tolist()
    
    # Service endpoint (using port-forward)
    url = "http://localhost:8000/mnist"
    
    # Test data
    payload = {
        "data": sample_data
    }
    
    try:
        response = requests.post(url, json=payload)
        if response.status_code == 200:
            result = response.json()
            print(f"Prediction: {result['prediction']}")
            print(f"Confidence: {result['confidence']:.4f}")
            print(f"All probabilities: {result['probabilities']}")
        else:
            print(f"Error: {response.status_code} - {response.text}")
    except Exception as e:
        print(f"Request failed: {e}")

if __name__ == "__main__":
    test_mnist_service()
```

Port forward to access the service and test it:

```bash
# Port forward to the Ray Serve endpoint
kubectl port-forward -n ray-system service/mnist-classifier-service-serve-svc 8000:8000

# In another terminal, run the test script
python test_serving.py
```

---

# Auto-scaling and Resource Management

Ray on AKS can automatically scale based on workload demands. Let's configure horizontal pod autoscaling and cluster autoscaling for optimal resource utilization.

## Configure Horizontal Pod Autoscaler

```yaml
# hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: ray-worker-hpa
  namespace: ray-system
spec:
  scaleTargetRef:
    apiVersion: ray.io/v1alpha1
    kind: RayCluster
    name: raycluster-ml
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 100
        periodSeconds: 60
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 50
        periodSeconds: 300
```

Apply the HPA configuration:

```bash
# Ensure metrics server is running
kubectl get deployment metrics-server -n kube-system

# Apply HPA
kubectl apply -f hpa.yaml

# Monitor HPA status
kubectl get hpa -n ray-system -w
```

## Enable Cluster Autoscaler

For complete auto-scaling, enable the AKS cluster autoscaler:

```bash
# Enable cluster autoscaler on existing AKS cluster
az aks update \
  --resource-group <your-resource-group> \
  --name <your-cluster-name> \
  --enable-cluster-autoscaler \
  --min-count 3 \
  --max-count 10

# Verify cluster autoscaler is running
kubectl get pods -n kube-system | grep cluster-autoscaler
```

---

# Distributed Data Processing with Ray Data

Ray Data provides distributed data processing capabilities for large-scale data preprocessing and ETL workloads. Let's demonstrate how to process large datasets efficiently.

## Create a Data Processing Pipeline

```python
# data_processing.py
import ray
import numpy as np
import pandas as pd
from ray import data
from typing import Dict, Any
import time

def preprocess_batch(batch: Dict[str, np.ndarray]) -> Dict[str, np.ndarray]:
    """Process a batch of data"""
    # Simulate data preprocessing
    processed_data = []
    for item in batch['data']:
        # Apply some transformations
        normalized = (item - np.mean(item)) / (np.std(item) + 1e-8)
        processed_data.append(normalized)
    
    return {'processed_data': np.array(processed_data)}

def create_synthetic_dataset(num_samples: int = 10000):
    """Create a synthetic dataset for processing"""
    data_list = []
    for i in range(num_samples):
        data_list.append({
            'id': i,
            'data': np.random.randn(100),  # 100-dimensional data
            'label': np.random.randint(0, 10)
        })
    return data_list

def main():
    # Connect to Ray cluster
    ray.init(address="ray://raycluster-ml-head-svc:10001")
    
    print("Creating synthetic dataset...")
    synthetic_data = create_synthetic_dataset(50000)
    
    # Create Ray Dataset
    print("Creating Ray Dataset...")
    dataset = ray.data.from_items(synthetic_data)
    
    print(f"Dataset size: {dataset.count()} items")
    print(f"Dataset schema: {dataset.schema()}")
    
    # Apply transformations
    print("Applying preprocessing transformations...")
    start_time = time.time()
    
    processed_dataset = dataset.map_batches(
        preprocess_batch,
        batch_size=1000,
        num_cpus=1
    )
    
    # Force computation by collecting a sample
    sample = processed_dataset.take(5)
    end_time = time.time()
    
    print(f"Processing completed in {end_time - start_time:.2f} seconds")
    print(f"Sample processed data shape: {sample[0]['processed_data'].shape}")
    
    # Save processed data (in production, you'd save to cloud storage)
    print("Saving processed dataset...")
    processed_dataset.write_parquet("/tmp/processed_data")
    
    print("Data processing pipeline completed!")

if __name__ == "__main__":
    main()
```

## Run the Data Processing Job

```yaml
# data-processing-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: ray-data-processing
  namespace: ray-system
spec:
  template:
    spec:
      containers:
      - name: ray-data-processing
        image: rayproject/ray-ml:2.8.0-py310
        command: ["python"]
        args: ["/app/data_processing.py"]
        resources:
          requests:
            cpu: 2
            memory: 4Gi
          limits:
            cpu: 4
            memory: 8Gi
        volumeMounts:
        - name: processing-script
          mountPath: /app
        env:
        - name: RAY_ADDRESS
          value: "ray://raycluster-ml-head-svc:10001"
      volumes:
      - name: processing-script
        configMap:
          name: processing-script
      restartPolicy: Never
  backoffLimit: 4
```

Deploy and run the data processing job:

```bash
# Create ConfigMap with the processing script
kubectl create configmap processing-script \
  --from-file=data_processing.py \
  -n ray-system

# Apply the processing job
kubectl apply -f data-processing-job.yaml

# Monitor the job
kubectl logs -n ray-system job/ray-data-processing -f
```

---

# Monitoring and Observability

Effective monitoring is crucial for Ray workloads in production. Let's set up comprehensive monitoring and observability for our Ray cluster.

## Ray Dashboard and Metrics

The Ray dashboard provides real-time insights into cluster performance:

```bash
# Access the Ray dashboard
kubectl port-forward -n ray-system service/raycluster-ml-head-svc 8265:8265
```

Key metrics to monitor:
- **Cluster utilization**: CPU, memory, and network usage
- **Task execution**: Task queues, execution times, and failures
- **Actor lifecycle**: Actor creation, destruction, and resource usage
- **Object store**: Shared memory usage and plasma store statistics

## Integrate with Azure Monitor

Configure Azure Monitor to collect Ray metrics:

```yaml
# ray-monitoring.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: ray-prometheus-config
  namespace: ray-system
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
    scrape_configs:
    - job_name: 'ray-head'
      static_configs:
      - targets: ['raycluster-ml-head-svc:8080']
      metrics_path: /metrics
    - job_name: 'ray-workers'
      kubernetes_sd_configs:
      - role: pod
        namespaces:
          names:
          - ray-system
      relabel_configs:
      - source_labels: [__meta_kubernetes_pod_label_ray_io_node_type]
        action: keep
        regex: worker
      - source_labels: [__address__]
        action: replace
        regex: '([^:]+):.*'
        target_label: __address__
        replacement: '${1}:8080'
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ray-prometheus
  namespace: ray-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ray-prometheus
  template:
    metadata:
      labels:
        app: ray-prometheus
    spec:
      containers:
      - name: prometheus
        image: prom/prometheus:latest
        ports:
        - containerPort: 9090
        volumeMounts:
        - name: config
          mountPath: /etc/prometheus
        args:
        - '--config.file=/etc/prometheus/prometheus.yml'
        - '--storage.tsdb.path=/prometheus/'
        - '--web.console.libraries=/etc/prometheus/console_libraries'
        - '--web.console.templates=/etc/prometheus/consoles'
      volumes:
      - name: config
        configMap:
          name: ray-prometheus-config
```

Apply the monitoring configuration:

```bash
# Deploy Ray monitoring
kubectl apply -f ray-monitoring.yaml

# Access Prometheus dashboard
kubectl port-forward -n ray-system deployment/ray-prometheus 9090:9090
```

---

# Best Practices and Optimization

To ensure optimal performance and reliability of Ray workloads in production, let's explore key optimization strategies and best practices.

## Resource Optimization

Proper resource allocation is critical for Ray cluster performance.

1. **Right-size your containers**: Match CPU and memory requests/limits to actual usage
2. **Use node affinity**: Place Ray head nodes on dedicated machines
3. **Configure resource pools**: Separate compute-intensive and memory-intensive workloads

```yaml
# Example resource pool configuration
spec:
  workerGroupSpecs:
  - replicas: 2
    groupName: cpu-intensive
    rayStartParams:
      resources: '{"CPU": 4}'
    template:
      spec:
        nodeSelector:
          workload: cpu-intensive
        containers:
        - name: ray-worker
          resources:
            requests:
              cpu: 4
              memory: 2Gi
  - replicas: 2
    groupName: memory-intensive
    rayStartParams:
      resources: '{"CPU": 2, "memory": 8000000000}'
    template:
      spec:
        nodeSelector:
          workload: memory-intensive
        containers:
        - name: ray-worker
          resources:
            requests:
              cpu: 2
              memory: 8Gi
```

## Performance Tuning

1. **Batch size optimization**: Tune batch sizes for optimal throughput
2. **Task granularity**: Balance between task overhead and parallelism
3. **Object store management**: Monitor plasma store usage and configure appropriately

```python
# Example of optimized Ray task configuration
@ray.remote(num_cpus=2, memory=1000*1024*1024)  # 1GB memory
def optimized_task(data_batch):
    # Implement efficient processing
    return process_data(data_batch)

# Use optimal batch sizes
futures = []
batch_size = 1000  # Tune based on data size and memory
for i in range(0, len(data), batch_size):
    batch = data[i:i+batch_size]
    futures.append(optimized_task.remote(batch))

results = ray.get(futures)
```

## Security Considerations

1. **Network policies**: Restrict inter-pod communication
2. **RBAC**: Implement proper role-based access control
3. **Secret management**: Use Kubernetes secrets for sensitive data

```yaml
# Example network policy for Ray cluster
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ray-cluster-netpol
  namespace: ray-system
spec:
  podSelector:
    matchLabels:
      ray.io/cluster: raycluster-ml
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          ray.io/cluster: raycluster-ml
    ports:
    - protocol: TCP
      port: 6379
    - protocol: TCP
      port: 8265
  egress:
  - to: []
    ports:
    - protocol: TCP
      port: 443
    - protocol: TCP
      port: 6379
```

---

# Troubleshooting Common Issues

When working with Ray on AKS, you may encounter various issues. Here are common problems and their solutions.

## Ray Cluster Connectivity Issues

```bash
# Check Ray cluster status
kubectl get raycluster -n ray-system
kubectl describe raycluster raycluster-ml -n ray-system

# Verify service connectivity
kubectl get svc -n ray-system
kubectl port-forward -n ray-system service/raycluster-ml-head-svc 8265:8265

# Check pod logs
kubectl logs -n ray-system -l ray.io/cluster=raycluster-ml
```

## Resource Exhaustion

```bash
# Monitor resource usage
kubectl top nodes
kubectl top pods -n ray-system

# Check resource quotas
kubectl describe resourcequota -n ray-system

# Verify HPA status
kubectl get hpa -n ray-system
kubectl describe hpa ray-worker-hpa -n ray-system
```

## Job Failures

```bash
# Check job status and logs
kubectl get jobs -n ray-system
kubectl describe job <job-name> -n ray-system
kubectl logs -n ray-system job/<job-name>

# Check Ray dashboard for task failures
# Access dashboard at http://localhost:8265
```

---

# Cleanup

When you're done with the lab, clean up the resources:

```bash
# Delete Ray jobs
kubectl delete job ray-distributed-training -n ray-system
kubectl delete job ray-data-processing -n ray-system

# Delete Ray services
kubectl delete rayservice mnist-classifier-service -n ray-system

# Delete Ray cluster
kubectl delete raycluster raycluster-ml -n ray-system

# Delete ConfigMaps
kubectl delete configmap training-script processing-script serve-code -n ray-system

# Uninstall KubeRay operator
helm uninstall kuberay-operator -n ray-system

# Delete namespace
kubectl delete namespace ray-system
```

---

# Summary

Congratulations! You've successfully deployed and managed distributed AI workloads using Ray on AKS. In this lab, you learned how to:

- Deploy Ray clusters using the KubeRay operator
- Implement distributed machine learning training with Ray Train
- Serve ML models at scale using Ray Serve  
- Process large datasets with Ray Data
- Configure auto-scaling for dynamic resource management
- Monitor Ray workloads with observability tools
- Apply best practices for production deployments

## Key Takeaways

1. **Ray simplifies distributed computing**: Transform single-machine Python code into distributed applications with minimal changes
2. **Kubernetes integration**: KubeRay operator provides seamless Ray cluster management on Kubernetes
3. **Auto-scaling capabilities**: Combine Ray's dynamic scaling with Kubernetes HPA and cluster autoscaler
4. **Production-ready features**: Ray provides robust monitoring, fault tolerance, and resource management
5. **Ecosystem integration**: Ray works well with popular ML frameworks and Azure services

## Next Steps

To further explore Ray and distributed AI workloads:

- Experiment with Ray Tune for distributed hyperparameter optimization
- Integrate with Azure Machine Learning for MLOps workflows
- Explore Ray's integration with popular ML frameworks (Hugging Face, XGBoost, etc.)
- Implement more complex distributed training scenarios
- Set up continuous deployment pipelines for Ray applications

## Learn More

- [Ray Documentation](https://docs.ray.io/)
- [KubeRay Documentation](https://ray-project.github.io/kuberay/)
- [Azure Kubernetes Service Documentation](https://docs.microsoft.com/azure/aks/)
- [Ray Train Documentation](https://docs.ray.io/en/latest/train/train.html)
- [Ray Serve Documentation](https://docs.ray.io/en/latest/serve/index.html)
- [Ray Data Documentation](https://docs.ray.io/en/latest/data/data.html)

---
