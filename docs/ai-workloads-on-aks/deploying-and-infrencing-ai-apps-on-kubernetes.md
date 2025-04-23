---
title: Deploying and Inferencing AI Applications on Kubernetes
---

Open VSCode

Click on the Kubernetes extension

Login into your Azure account

Right-click and install KAITO

Deploy a phi-3-mini-128k-instruct workspace and wait 10 minutes for it to be ready

Test the workspace in vscode

Let's look at some code

```
mkdir -p /tmp/app
cd /tmp/app
curl -o main.py https://raw.githubusercontent.com/kaito-project/kaito/refs/heads/main/demo/inferenceUI/chainlit_openai.py
cat main.py
```

https://docs.chainlit.io/integrations/openai
https://docs.chainlit.io/concepts/message


```
echo "WORKSPACE_SERVICE_URL=http://localhost:8080/" > .env
kubectl port-forward service/workspace-phi-3-mini-128k-instruct 8080:80
# ctrl + z, then bg to move the process to the background
```

Run the code

```
uv init
uv add chainlit pydantic==2.11.3 requests openai
uv run --env-file=.env chainlit run main.py
```

Monitor the vLLM runtime

```
curl http://localhost:8080/metrics
```

Deploy a ServiceMonitor to monitor the workspace

```
kubectl label service workspace-phi-3-mini-128k-instruct kaito.sh/workspace=workspace-phi-3-mini-128k-instruct

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
---
apiVersion: azmonitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: workspace-phi-3-mini-128k-instruct-monitor
spec:
  selector:
    matchLabels:
      kaito.sh/workspace: workspace-phi-3-mini-128k-instruct
  podMetricsEndpoints:
    - targetPort: 5000
      path: /metrics
      interval: 10s
EOF
```

https://learn.microsoft.com/en-us/azure/azure-monitor/containers/prometheus-metrics-scrape-crd#create-a-pod-or-service-monitor


View the metrics in Grafana

```
curl -o grafana.json https://raw.githubusercontent.com/vllm-project/vllm/refs/heads/main/examples/online_serving/prometheus_grafana/grafana.json
```

https://docs.vllm.ai/en/latest/getting_started/examples/prometheus_grafana.html
https://github.com/vllm-project/vllm/tree/main/examples/online_serving/prometheus_grafana

https://docs.vllm.ai/en/latest/design/v1/metrics.html