---
sidebar_position: 1
title: Advanced Container Networking Services
---

## Advanced Networking Concepts

When you created the AKS cluster you might have noticed that we used the Azure CNI network plugin in overlay mode with [Cilium](https://cilium.io/) for the network dataplane and security. This mode is the most advanced networking mode available in AKS and provides the most flexibility in how IP addresses are assigned to pods and how network policies are enforced.

In this section, you will explore advanced networking concepts such as network policies, FQDN filtering, and advanced container networking services.

### Advanced Container Networking Services

Advanced Container Networking Services (ACNS) is a suite of services built to significantly enhance the operational capabilities of your Azure Kubernetes Service (AKS) clusters.
Advanced Container Networking Services contains features split into two pillars:

- **Security**: For clusters using Azure CNI Powered by Cilium, network policies include fully qualified domain name (FQDN) filtering for tackling the complexities of maintaining configuration.
- **Observability**: The inaugural feature of the Advanced Container Networking Services suite bringing the power of Hubble’s control plane to both Cilium and non-Cilium Linux data planes. These features aim to provide visibility into networking and performance.

### Enforcing Network Policy

In this section, we’ll apply network policies to control traffic flow to and from the Pet Shop application. We will start with standard network policy that doesn't require ACNS, then we enforce more advanced FQDN policies.

#### Test Connectivity

Do the following test to make sure that all traffic is allowed by default

Run the following command to test a connection to an external website from the order-service pod.

```bash
kubectl exec -n pets -it $(kubectl get po -n pets -l app=order-service -ojsonpath='{.items[0].metadata.name}') -c order-service -- sh -c 'wget --spider www.bing.com'
```

You should see output similar to the following:

```text
Connecting to www.bing.com (13.107.21.237:80)
remote file exists
```

Now test the connection between the order-service and product-service pods which is allowed but not required by the architecture.

```bash
kubectl exec -n pets -it $(kubectl get po -n pets -l app=order-service -ojsonpath='{.items[0].metadata.name}') -c order-service  -- sh -c 'nc -zv -w2 product-service 3002'
```

You should see output similar to the following:

```text
product-service (10.0.96.101:3002) open
```

In both tests, the connection was successful. This is because all traffic is allowed by default in Kubernetes.

#### Deploy Network Policy

Now, let's deploy some network policy to allow only the required ports in the pets namespace.

Run the following command to download the network policy manifest file.

```bash
curl -o acns-network-policy.yaml https://gist.githubusercontent.com/pauldotyu/64bdb2fdf99b24fc7922ff0101a6af5d/raw/141b085f1f4e57c214281400f576274676103801/acns-network-policy.yaml
```

Take a look at the network policy manifest file by running the following command.

```bash
cat acns-network-policy.yaml
```

Apply the network policy to the pets namespace.

```bash
kubectl apply -n pets -f acns-network-policy.yaml
```

#### Verify Policies

Review the created policies using the following command

```bash
kubectl get cnp -n pets
```

Ensure that only allowed connections succeed and others are blocked. For example, order-service should not be able to access www.bing.com or the product-service.

Run the following command to test the connection to www.bing.com from the order-service pod.

```bash
kubectl exec -n pets -it $(kubectl get po -n pets -l app=order-service -ojsonpath='{.items[0].metadata.name}') -c order-service -- sh -c 'wget --spider --timeout=1 --tries=1 www.bing.com'
```

You should see output similar to the following:

```text
wget: bad address 'www.bing.com'
command terminated with exit code 1
```

Run the following command to test the connection between the order-service and product-service pods.

```bash
kubectl exec -n pets -it $(kubectl get po -n pets -l app=order-service -ojsonpath='{.items[0].metadata.name}') -c order-service  -- sh -c 'nc -zv -w2 product-service 3002'
```

You should see output similar to the following:

```text
nc: bad address 'product-service'
command terminated with exit code 1
```

We've just enforced network policies to control traffic flow to and from pods within the demo application. At the same time, we should be able to access the pet shop app UI and order product normally.

### Configuring FQDN Filtering

Using network policies, you can control traffic flow to and from your AKS cluster. This is traditionally been enforced based on IP addresses and ports. But what if you want to control traffic based on fully qualified domain names (FQDNs)? What if an application owner asks you to allow traffic to a specific domain like Microsoft Graph API?

This is where FQDN filtering comes in.

<div class="info" data-title="Note">

> FQDN filtering is only available for clusters using Azure CNI Powered by Cilium.

</div>

Let's explore how we can apply FQDN-based network policies to control outbound access to specific domains.

#### Test Connectivity

Let's start with testing the connection from the order-service to see if it can contact the Microsoft Graph API endpoint.

Run the following command to test the connection to the Microsoft Graph API from the order-service pod.

```bash
kubectl exec -n pets -it $(kubectl get po -n pets -l app=order-service -ojsonpath='{.items[0].metadata.name}') -c order-service  -- sh -c 'wget --spider --timeout=1 --tries=1 https://graph.microsoft.com'
```

As you can see the traffic is denied. This is an expected behavior because we have implemented zero trust security policy and denying any unwanted traffic.

#### Create an FQDN Policy

To limit egress to certain domains, apply an FQDN policy. This policy permits access only to specified URLs, ensuring controlled outbound traffic.

<div class="info" data-title="Note">

> FQDN filtering requires ACNS to be enabled

</div>

Run the following command to download the FQDN policy manifest file.

```bash
curl -o acns-network-policy-fqdn.yaml https://gist.githubusercontent.com/pauldotyu/fd4cc689d9dcf8b0fd508620f3e6880d/raw/3e60c7e9bfb9ce5e7887ec7d81a6ca423002b14d/acns-network-policy-fqdn.yaml
```

Take a look at the FQDN policy manifest file by running the following command.

```bash
cat acns-network-policy-fqdn.yaml
```

```bash
kubectl apply -n pets -f acns-network-policy-fqdn.yaml
```

#### Verify FQDN Policy Enforcement

Now if we try to access Microsoft Graph API from order-service app, that should be allowed.

```bash
kubectl exec -n pets -it $(kubectl get po -n pets -l app=order-service -ojsonpath='{.items[0].metadata.name}') -c order-service  -- sh -c 'wget --spider --timeout=1 --tries=1 https://graph.microsoft.com'
```

You should see output similar to the following:

```text
Connecting to graph.microsoft.com (20.190.152.88:443)
Connecting to developer.microsoft.com (23.45.149.11:443)
Connecting to developer.microsoft.com (23.45.149.11:443)
remote file exists
```

### Monitoring Advanced Network Metrics and Flows

Advanced Container Networking Services (ACNS) provides deep visibility into your cluster's network activity. This includes flow logs and deep visibility into your cluster's network activity. All communications to and from pods are logged, allowing you to investigate connectivity issues over time

Using Azure Managed Grafana, you can visualize real-time data and gain insights into network traffic patterns, performance, and policy effectiveness.

What if a customer reports a problem in accessing the pets shop? How can you troubleshoot the issue?

We'll work to simulate a problem and then use ACNS to troubleshoot the issue.

#### Introducing Chaos to Test container networking

Let's start by applying a new network policy to cause some chaos in the network. This policy will drop incoming traffic to the store-front service.

Run the following command to download the chaos policy manifest file.

```bash
curl -o acns-network-policy-chaos.yaml https://gist.githubusercontent.com/pauldotyu/9963e1301b8f3a460398b78a1e31ca84/raw/68f98f9a18dca5747248b434968e0074564a9c66/acns-network-policy-chaos.yaml
```

Run the following command to examine the chaos policy manifest file.

```bash
cat acns-network-policy-chaos.yaml
```

Run the following command to apply the chaos policy to the pets namespace.

```bash
kubectl apply -n pets -f acns-network-policy-chaos.yaml
```

#### Access Grafana Dashboard

When you enabled Advanced Container Networking Services (ACNS) on your AKS cluster, you also enabled metrics collection. These metrics provide insights into traffic volume, dropped packets, number of connections, etc. The metrics are stored in Prometheus format and, as such, you can view them in Grafana.

Using your browser, navigate to [Azure Portal](https://aka.ms/publicportal), search for **grafana** resource, then click on the **Azure Managed Grafana** link under the **Services** section. Locate the Azure Managed Grafana resource that was created earlier in the workshop and click on it, then click on the URL next to **Endpoint** to open the Grafana dashboard.

![Azure Managed Grafana overview](assets/acns-grafana-overview.png)

Part of ACNS we provide pre-defined networking dashboards. Review the available dashboards

![ACNS dashboards in Grafana](assets/acns-grafana-dashboards.png)

You can start with the **Kubernetes / Networking / Clusters** dashboard to get an over view of whats is happening in the cluster.

![ACNS networking clusters dashboard](assets/acns-network-clusters-dashboard.png)

Lets' change the view to the **Kubernetes / Networking / Drops**, select the **pets** namespace, and **store-front** workload

![ACNS networking drops dashboard](assets/acns-drops-incoming-traffic.png)

Now you can see increase in the dropped incoming traffic and the reason is "policy_denied" so now we now the reason that something was wrong with the network policy. let's dive dipper and understand why this is happening

[Optional] Familiarize yourself with the other dashboards for DNS, and pod flows

| ![DNS Dashboard](assets/acns-dns-dashboard.png) | ![Pod Flows Dashboard](assets/acns-pod-flows-dashboard.png) |
| ----------------------------------------------- | ----------------------------------------------------------- |

#### Leverage Container Network Flow Logs for Faster Troubleshooting

The Grafana metrics showed you **that** there's a problem - dropped incoming traffic to store-front. But they don't tell you:
- **Who** is being blocked (which specific source IPs or clients)
- **Why** DNS queries fail for specific domains
- **When** exactly the problem started affecting individual flows
- **What** external endpoints are failing vs succeeding

This is where **Container Network Flow Logs** accelerate your troubleshooting. Think of metrics as the "smoke alarm" and flow logs as the "security camera footage" - metrics alert you to the problem, while flow logs show you exactly what happened.

**The Traditional Troubleshooting Approach (Without Flow Logs):**
1. SSH into individual nodes to check iptables rules (risky in production)
2. Enable debug logging on pods (requires restarts, loses existing state)
3. Manually test connections one-by-one to isolate the issue
4. Correlate timestamps across multiple pod logs to understand traffic patterns
5. **Estimated time: 2-4 hours** for a complex network policy issue

**With Container Network Flow Logs (What You'll Do Next):**
1. Run a single KQL query to see exact blocked connections with source IPs
2. Query DNS traffic to identify which domains are allowed vs blocked
3. Correlate DNS success with connection failures in one view
4. Visualize traffic patterns over time to pinpoint when the issue started
5. **Estimated time: 10-15 minutes** to fully diagnose the root cause

Let's see this in action by investigating the issues developers reported.

##### Enable Flow Logs for the Pets Namespace

To enable container network flow logs, you need to apply a `ContainerNetworkLog` custom resource that defines which network flows to capture. Let's create a filter to capture all traffic in the pets namespace.

Create a file named `pets-flow-logs.yaml` with the following content:

```bash
cat <<EOF > pets-flow-logs.yaml
apiVersion: acn.azure.com/v1alpha1
kind: ContainerNetworkLog
metadata:
  name: testcnl # Cluster scoped
spec:
  includefilters: # List of filters
    - name: egress-filter # Capture egress traffic from pets namespace
      from:
        namespacedPod: # List of source namespace/pods. Prepend namespace with /
          - pets/order-service-
          - pets/product-service-
          - pets/rabbitmq
          - pets/store-front-
      protocol: # List of protocols; can be tcp, udp, dns
        - tcp
        - udp
        - dns
      verdict: # List of verdicts; can be forwarded, dropped
        - forwarded
        - dropped
    
    - name: ingress-filter # Capture ingress traffic to pets namespace
      to:
        namespacedPod: # Destination pods
          - pets/store-front-
          - pets/order-service-
          - pets/product-service-
          - pets/rabbitmq
      protocol:
        - tcp
        - udp
      verdict:
        - forwarded
        - dropped
EOF
```

Apply the custom resource to enable flow log collection:

```bash
kubectl apply -f pets-flow-logs.yaml
```

Verify the custom resource was created successfully:

```bash
kubectl describe containernetworklog pets-namespace-flow-logs
```

You should see a `Status` field showing `State: CONFIGURED`. This means flow logs are now being collected for the pets namespace and sent to your Log Analytics workspace.

<div class="info" data-title="Note">

> Flow logs are stored locally on the nodes at `/var/log/acns/hubble/events.log` and then collected by the Azure Monitor Agent and sent to Log Analytics. It may take 2-3 minutes for logs to appear in Log Analytics after network events occur.

</div>

##### Generate Traffic to Observe Flow Logs

Now let's create a realistic troubleshooting scenario. Imagine you're a platform engineer and developers report that the store-front application is experiencing intermittent connectivity issues. Some external API calls work while others fail, and users occasionally can't access the application.

Let's simulate this scenario by applying an additional network policy and generating various types of traffic:

**Step 1: Apply the Combined FQDN and L7 Policy**

This policy adds FQDN filtering and L7 HTTP rules to the store-front application:

```bash
curl -o aks-combined-fqdn-l7.yaml https://raw.githubusercontent.com/shaifaligargmsft/aks-labs-shaif/main/docs/networking/assets/aks-combined-fqdn-l7.yaml
```

Review the policy to understand what traffic it allows:

```bash
cat aks-combined-fqdn-l7.yaml
```

Apply the policy to the pets namespace:

```bash
kubectl apply -f aks-combined-fqdn-l7.yaml
```

**Step 2: Simulate the Reported Issues**

Now let's generate traffic that mimics the issues developers are reporting:

```bash
# Issue 1: External users can't access the application (ingress blocked by chaos policy)
STORE_FRONT_IP=$(kubectl get svc -n pets store-front -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Testing external access to store-front..."
for i in {1..5}; do curl -s -m 2 http://${STORE_FRONT_IP} || echo "Connection failed"; sleep 1; done
```

**Expected Result:** Connection timeout or failure. The chaos policy is blocking all ingress traffic to store-front.

```text
Connection failed
Connection failed
Connection failed
Connection failed
Connection failed
```

<div class="info" data-title="Note">

> If you see curl progress bars instead, the command is still running but timing out. You can verify the connections are being dropped by checking the flow logs in the next section - they will show `Verdict: DROPPED` for `TrafficDirection: INGRESS`.

</div>

```bash
# Issue 2: Some external API calls work, others don't (FQDN policy in action)
echo "Testing allowed FQDN access to microsoft.com..."
kubectl exec -n pets -it $(kubectl get po -n pets -l app=store-front -ojsonpath='{.items[0].metadata.name}') -- sh -c 'wget --spider --timeout=2 https://www.microsoft.com' || true
```

**Expected Result:** Connection succeeds but may get HTTP 403. This proves the FQDN policy is **working** - the network allows the traffic through, even though the web server rejects the request.

```text
Connecting to www.microsoft.com (23.192.18.101:443)
wget: server returned error: HTTP/1.1 403 Forbidden
```

<div class="info" data-title="Note">

> The HTTP 403 error means the **network policy allowed the connection** (Verdict: FORWARDED), but the remote server rejected the HTTP request. This is expected behavior - if the policy was blocking it, you'd see a timeout or DNS failure instead.

</div>

```bash
echo "Testing allowed FQDN access to api.github.com..."
kubectl exec -n pets -it $(kubectl get po -n pets -l app=store-front -ojsonpath='{.items[0].metadata.name}') -- sh -c 'wget --spider --timeout=2 https://api.github.com' || true
```

**Expected Result:** DNS resolution failure - even though `api.github.com` is in the `toFQDNs` list, the DNS query itself is being blocked because `api.github.com` is not in the DNS `matchPattern` rules.

```text
wget: bad address 'api.github.com'
```

<div class="info" data-title="Note">

> This demonstrates an important aspect of FQDN policies: You need **both** DNS rules (to allow the DNS query) **and** toFQDNs rules (to allow the connection to the resolved IP). The policy has the `toFQDNs` rule but is missing `api.github.com` in the DNS patterns.

</div>

```bash
echo "Testing blocked FQDN access to google.com..."
kubectl exec -n pets -it $(kubectl get po -n pets -l app=store-front -ojsonpath='{.items[0].metadata.name}') -- sh -c 'wget --spider --timeout=2 https://www.google.com' || true
```

**Expected Result:** Timeout or DNS resolution failure - `google.com` is NOT in the FQDN allow list.

```text
wget: bad address 'www.google.com'
```

```bash
# Issue 3: DNS query is blocked (not in DNS matchPattern rules)
echo "Testing DNS query for domain not in matchPattern..."
kubectl exec -n pets -it $(kubectl get po -n pets -l app=store-front -ojsonpath='{.items[0].metadata.name}') -- sh -c 'nslookup www.bing.com' || true
kubectl exec -n pets -it $(kubectl get po -n pets -l app=store-front -ojsonpath='{.items[0].metadata.name}') -- sh -c 'wget --spider --timeout=5 https://www.bing.com' || true
```

**Expected Result:** DNS query fails because `bing.com` is not in the DNS `matchPattern` rules.

```text
;; Got recursion not available from 10.0.0.10
Server:         10.0.0.10
Address:        10.0.0.10#53

** server can't find www.bing.com.pets.svc.cluster.local: REFUSED

wget: bad address 'www.bing.com'
```

<div class="info" data-title="Note">

> This shows that `bing.com` is not in the DNS `matchPattern` rules, so the DNS query itself is blocked. This is similar to the `api.github.com` and `google.com` cases - the policy is blocking DNS resolution for domains not explicitly allowed.

</div>

```bash
# Issue 4: Internal DNS resolution
echo "Testing internal DNS resolution..."
kubectl exec -n pets -it $(kubectl get po -n pets -l app=store-front -ojsonpath='{.items[0].metadata.name}') -- sh -c 'nslookup rabbitmq.pets.svc.cluster.local' || true
```

**Expected Result:** Success - internal cluster DNS resolution is allowed.

```text
Server:    10.0.0.10
Address 1: 10.0.0.10 kube-dns.kube-system.svc.cluster.local

Name:      rabbitmq.pets.svc.cluster.local
Address 1: 10.0.96.123 rabbitmq.pets.svc.cluster.local
```

**What You Just Simulated:**

1. **External Access Failures**: The chaos policy is blocking all ingress traffic to store-front
2. **Selective FQDN Filtering**: The FQDN policy allows `*.microsoft.com`, but blocks other domains like `api.github.com`, `google.com`, and `bing.com`
3. **DNS-Level Blocking**: Domains not in the DNS `matchPattern` rules fail at DNS resolution (before even attempting connections)

The `aks-combined-fqdn-l7.yaml` policy you applied contains:
- **DNS rules**: Allow DNS queries for `rabbitmq.pets.svc.cluster.local` and `*.microsoft.com`
- **FQDN rules**: Allow HTTP/HTTPS to `*.microsoft.com` and `api.github.com`
- **L7 HTTP rules**: Allow GET requests to the product-service backend

<div class="info" data-title="Important">

> **Understanding FQDN Policy Requirements**: For FQDN filtering to work in Cilium, you need **both** components:
> 
> 1. **DNS rules** (port 53) - Allow the DNS query to resolve the domain name
> 2. **toFQDNs rules** - Allow the connection to the resolved IP address
> 
> In this policy, `*.microsoft.com` works because it's in **both** the DNS patterns and toFQDNs rules. However, domains like `api.github.com`, `bing.com`, and `google.com` fail because they're missing from the DNS `matchPattern` rules - the DNS query gets blocked first, so the pod never gets to attempt the actual connection. This is a common misconfiguration that container network flow logs help you identify quickly.

</div>

Without container network flow logs, you would need to:
- SSH into nodes to check iptables rules
- Manually correlate pod events with network policies
- Spend hours trying different combinations to find the root cause

**With flow logs, you can instantly see**:
- Which exact connections are being dropped and why
- What external endpoints pods are trying to reach
- When the problem started (correlate with deployment times)
- Traffic patterns across your entire namespace

Let's use Log Analytics to investigate these issues in the next section.

##### Query Flow Logs in Log Analytics

Now that flow logs are being collected and we've generated traffic, let's investigate the issues in minutes instead of hours.

Navigate to [Azure Portal](https://aka.ms/publicportal), search for your AKS cluster, then click on **Logs** in the left navigation menu under **Monitoring**. Close the **Queries** dialog if it appears.

<div class="info" data-title="Note">

> First, run this query to see what fields are available in your flow logs:
> ```kusto
> RetinaNetworkFlowLogs
> | take 1
> ```
> This will show you all available fields including dynamic properties that may not appear in the schema.

</div>

**Troubleshooting Scenario: "Users can't access the store-front application"**

Grafana showed you dropped incoming traffic, but let's use flow logs to find the exact source of the problem.

##### Query 1: Find Exactly Which Connections Are Blocked (30 seconds)

Let's investigate the external access failures. Run this query to see individual blocked connections to store-front:

```kusto
RetinaNetworkFlowLogs
| where TimeGenerated > ago(30m)
| where SourceNamespace == "pets" or DestinationNamespace == "pets"
| where DestinationPodName contains "store-front"
| where Verdict == "DROPPED"
| extend SrcIP = tostring(IP.source), DstIP = tostring(IP.destination)
| extend Layer4Data = parse_json(Layer4)
| extend DstPort = coalesce(tostring(Layer4Data.TCP.destination_port), tostring(Layer4Data.UDP.destination_port))
| project TimeGenerated, SourcePodName, SrcIP, DestinationPodName, DstIP, DstPort, Verdict, TrafficDirection
| order by TimeGenerated desc
| take 20
```

**What you'll see in the results:**
- **External ingress traffic** being dropped (SourcePodName will be empty, TrafficDirection = INGRESS)
- **SourceIP** shows the exact external IPs from your curl commands
- **Timestamp** shows when each connection attempt was made
- **DstPort** shows port 80 (HTTP)

**Troubleshooting value:** In 30 seconds, you identified:
✅ The problem is **ingress** traffic, not application code or backend services  
✅ The exact **source IPs** being blocked (your test machine)  
✅ The exact **time** when connections were dropped  

**Without flow logs:** You'd be SSHing into nodes, checking iptables rules, and guessing which traffic is affected. **Saved time: ~45 minutes**

---

**Troubleshooting Scenario: "API calls to external services are failing"**

Developers report that some external API calls work (microsoft.com) while others fail (api.github.com, google.com). Let's investigate.

##### Query 2: Identify Blocked DNS Queries (1 minute)

Now let's investigate why `api.github.com` and `google.com` failed. Run this query to find DNS-related traffic:

```kusto
RetinaNetworkFlowLogs
| where TimeGenerated > ago(30m)
| where SourceNamespace == "pets"
| extend Layer4Data = parse_json(Layer4)
| extend DstPort = coalesce(tostring(Layer4Data.TCP.destination_port), tostring(Layer4Data.UDP.destination_port))
| where DstPort == "53"  // DNS port
| project TimeGenerated, SourcePodName, DestinationPodName, Verdict, TrafficDirection, DstPort
| order by TimeGenerated desc
| take 20
```

**What you'll see in the results:**
| TimeGenerated | SourcePodName | Verdict | TrafficDirection |
|---|---|---|---|
| 2024-11-04 10:23:15 | store-front-abc123 | FORWARDED | EGRESS |
| 2024-11-04 10:23:18 | store-front-abc123 | FORWARDED | EGRESS |
| 2024-11-04 10:23:22 | store-front-abc123 | **DROPPED** | EGRESS |
| 2024-11-04 10:23:25 | store-front-abc123 | **DROPPED** | EGRESS |

**Troubleshooting value:** In 1 minute, you discovered:
✅ DNS queries for `*.microsoft.com` and `rabbitmq.pets.svc.cluster.local` are **FORWARDED**  
✅ DNS queries for `api.github.com` and `google.com` are **DROPPED**  
✅ This explains why the app shows "bad address" for those domains

**Root cause identified:** The DNS policy is missing `api.github.com` and `google.com` in the `matchPattern` rules.

**Without flow logs:** You'd be manually testing each domain, checking DNS server logs, and trying to correlate events across multiple pods. **Saved time: ~30 minutes**

---

**Troubleshooting Scenario: "Why does microsoft.com work but bing.com fail?"**

Let's investigate why some external domains work while others fail by looking at DNS queries and HTTPS connections together.

##### Query 3: Correlate DNS Queries with Connection Attempts (2 minutes)

This query shows both DNS queries (port 53) and HTTPS connections (port 443) to external endpoints, helping you understand the complete picture:

```kusto
RetinaNetworkFlowLogs
| where TimeGenerated > ago(30m)
| where SourceNamespace == "pets"
| where SourcePodName contains "store-front"
| extend SrcIP = tostring(IP.source), DstIP = tostring(IP.destination)
| extend Layer4Data = parse_json(Layer4)
| extend DstPort = coalesce(tostring(Layer4Data.TCP.destination_port), tostring(Layer4Data.UDP.destination_port))
| where DstPort in ("53", "443")  // DNS and HTTPS
| where isnotempty(DstIP)
| where DstIP !startswith "10." and DstIP !startswith "172." and DstIP !startswith "192.168."  // External IPs only
| project TimeGenerated, SourcePodName, DstIP, DstPort, Verdict, TrafficDirection
| order by TimeGenerated asc
```

**What you'll see in the results:**
| TimeGenerated | SourcePodName | DstIP | DstPort | Verdict |
|---|---|---|---|---|
| 2024-11-04 10:26:15 | store-front-abc123 | 10.0.0.10 | 53 | FORWARDED |
| 2024-11-04 10:26:16 | store-front-abc123 | 23.192.18.101 | 443 | FORWARDED |
| 2024-11-04 10:27:20 | store-front-abc123 | 10.0.0.10 | 53 | **DROPPED** |

**Troubleshooting value:** In 2 minutes, you can see the difference between allowed and blocked domains:

**For `www.microsoft.com` (Working):**
- ✅ **Step 1 (DNS)**: Port 53 query to `10.0.0.10` → Verdict: FORWARDED  
- ✅ **Step 2 (Connection)**: Port 443 to `23.192.18.101` → Verdict: FORWARDED  

**For `www.bing.com` (Failing):**
- ❌ **Step 1 (DNS)**: Port 53 query to `10.0.0.10` → Verdict: **DROPPED**  
- ❌ **Step 2 (Connection)**: Never attempted because DNS failed  

**Root cause identified:** `bing.com` is NOT in the DNS `matchPattern` rules, so the DNS query itself is blocked. The pod never even gets to attempt the HTTPS connection.

**Without flow logs:** You'd be confused about whether it's a DNS issue, firewall issue, or application issue, potentially spending hours checking external network connectivity. **Saved time: ~1 hour**

---

##### Query 4: Visualize When the Problem Started (1 minute)

Create a timeline to see when problems started and correlate with policy deployments:

```kusto
RetinaNetworkFlowLogs
| where TimeGenerated > ago(1h)
| where SourceNamespace == "pets" or DestinationNamespace == "pets"
| summarize 
    Allowed = countif(Verdict == "FORWARDED"),
    Dropped = countif(Verdict == "DROPPED")
    by bin(TimeGenerated, 1m), TrafficDirection
| render timechart
```

**What you'll see in the chart:**
- A visual timeline showing allowed vs dropped traffic
- A clear **spike in DROPPED INGRESS traffic** around the time you applied the chaos policy
- Correlation between the policy deployment time and when users started experiencing issues

**Troubleshooting value:** In 1 minute, you:
✅ Confirmed the problem started at 10:15 AM (when the chaos policy was applied)  
✅ Correlated the issue with a recent configuration change  
✅ Eliminated other potential causes (app deployment, infrastructure issues, etc.)

**Without flow logs:** You'd be checking deployment logs, asking developers when they last released code, and trying to remember when policies were changed. **Saved time: ~20 minutes**

---

##### Query 5: Validate FQDN Policy Enforcement (1 minute)

See which external HTTPS endpoints your store-front pods are successfully reaching (and which are blocked):

```kusto
RetinaNetworkFlowLogs
| where TimeGenerated > ago(30m)
| where SourceNamespace == "pets"
| where SourcePodName contains "store-front"
| extend DstIP = tostring(IP.destination)
| extend Layer4Data = parse_json(Layer4)
| extend DstPort = coalesce(tostring(Layer4Data.TCP.destination_port), tostring(Layer4Data.UDP.destination_port))
| where DstPort == "443"  // HTTPS traffic
| where isnotempty(DstIP)
| where DstIP !startswith "10." and DstIP !startswith "172." and DstIP !startswith "192.168."
| summarize 
    Flows = count(),
    Forwarded = countif(Verdict == "FORWARDED"),
    Dropped = countif(Verdict == "DROPPED")
    by DstIP, Verdict
| order by Flows desc
| take 20
```

**What you'll see in the results:**
| DstIP | Verdict | Flows | Forwarded | Dropped |
|---|---|---|---|---|
| 23.192.18.101 | FORWARDED | 12 | 12 | 0 |
| 142.250.XX.XX | DROPPED | 8 | 0 | 8 |
| 13.107.21.200 | DROPPED | 5 | 0 | 5 |

**Troubleshooting value:** In 1 minute, you validated:
✅ **23.192.18.101** (microsoft.com) - All connections **FORWARDED** ✓  
✅ **142.250.XX.XX** (google.com) - All connections **DROPPED** as expected ✓  
✅ **13.107.21.200** (bing.com) - All connections **DROPPED** (not in FQDN allow list) ✓

**Without flow logs:** You'd be manually testing each endpoint, potentially from different pods, and trying to understand which external dependencies are working. **Saved time: ~30 minutes**

---

##### Query 6: Complete Traffic Analysis by Direction (2 minutes)

Get a comprehensive view of all traffic patterns in the pets namespace:

```kusto
RetinaNetworkFlowLogs
| where TimeGenerated > ago(30m)
| where SourceNamespace == "pets" or DestinationNamespace == "pets"
| summarize 
    TotalFlows = count(),
    DroppedFlows = countif(Verdict == "DROPPED"),
    ForwardedFlows = countif(Verdict == "FORWARDED")
    by TrafficDirection, SourcePodName, DestinationPodName
| extend DropRate = round((DroppedFlows * 100.0) / TotalFlows, 2)
| where TotalFlows > 5  // Filter out noise
| order by DroppedFlows desc
| take 20
```

**What you'll see in the results:**
| TrafficDirection | SourcePodName | DestinationPodName | TotalFlows | DroppedFlows | DropRate% |
|---|---|---|---|---|---|
| INGRESS | (external) | store-front-abc123 | 156 | 156 | **100%** |
| EGRESS | store-front-abc123 | (external) | 89 | 23 | 25.8% |
| EGRESS | store-front-abc123 | kube-dns | 45 | 12 | 26.7% |

**Troubleshooting value:** In 2 minutes, you have a complete picture:
✅ **INGRESS to store-front**: 100% drop rate → Chaos policy blocking all external access  
✅ **EGRESS to external**: 25.8% drop rate → Some domains allowed (microsoft.com), others blocked (bing.com, google.com)  
✅ **EGRESS DNS**: 26.7% drop rate → Some DNS queries blocked (api.github.com, google.com)

**Complete diagnosis achieved:**
1. External users can't access the app → Ingress policy has `ingress: []` (no rules = block all)
2. Some external APIs fail → FQDN policy missing domains in `toFQDNs` list
3. DNS failures → Domains not in DNS `matchPattern` rules

**Total time spent with flow logs: ~10 minutes**  
**Estimated time without flow logs: 2-4 hours**  
**Time saved: 85-95%** ⚡

---

##### Summary: How Flow Logs Complement Grafana Metrics

| **What You Need** | **Grafana Metrics** | **Container Network Flow Logs** |
|---|---|---|
| **Is there a problem?** | ✅ Shows dropped packet count | ✅ Shows individual dropped flows |
| **When did it start?** | ✅ Time series of aggregate drops | ✅ Exact timestamp of each flow |
| **Who is affected?** | ❌ No source IP details | ✅ Exact source/destination IPs |
| **Why is it blocked?** | ❌ No verdict details | ✅ Verdict + policy enforcement |
| **Which endpoints fail?** | ❌ No endpoint visibility | ✅ DNS + connection correlation |
| **Historical investigation** | ⚠️ Limited retention | ✅ Long-term queryable storage |

**Best Practice:** Use Grafana to **detect** issues in real-time, then use flow logs to **diagnose** the root cause with forensic precision.

<div class="info" data-title="Note">

> Flow logs may take 2-3 minutes to appear in Log Analytics after network events occur. For real-time troubleshooting, use Hubble CLI (covered in the next section).

</div>

##### Key Takeaways

Flow logs accelerate troubleshooting by providing:

- **Individual flow records** with complete context (source, destination, verdict, reason)
- **Historical queryability** to investigate issues that occurred hours or days ago
- **Forensic details** that metrics alone cannot provide
- **Correlation capabilities** to connect issues with deployments and policy changes

Now that we've identified the issue using flow logs, let's use Hubble to get real-time visibility into the network flows.

#### Observe network flows with hubble

ACNS integrates with Hubble to provide flow logs and deep visibility into your cluster's network activity. All communications to and from pods are logged allowing you to investigate connectivity issues over time.

But first we need to install Hubble CLI

Install Hubble CLI

```bash
# Set environment variables
export HUBBLE_VERSION="v0.11.0"
export HUBBLE_OS="$(uname | tr '[:upper:]' '[:lower:]')"
export HUBBLE_ARCH="$(uname -m)"

#Install Hubble CLI
if [ "$(uname -m)" = "aarch64" ]; then HUBBLE_ARCH="arm64"; fi
curl -L --fail --remote-name-all https://github.com/cilium/hubble/releases/download/${HUBBLE_VERSION}/hubble-${HUBBLE_OS}-${HUBBLE_ARCH}.tar.gz{,.sha256sum}
sha256sum --check hubble-${HUBBLE_OS}-${HUBBLE_ARCH}.tar.gz.sha256sum
sudo tar xzvfC hubble-${HUBBLE_OS}-${HUBBLE_ARCH}.tar.gz /usr/local/bin
rm hubble-${HUBBLE_OS}-${HUBBLE_ARCH}.tar.gz{,.sha256sum}
```

Port forward Hubble Relay using the kubectl port-forward command.

```bash
kubectl port-forward -n kube-system svc/hubble-relay --address 127.0.0.1 4245:443
```

Move the port forward to the background by pressing **Ctrl + z** and then type **bg**.

Configure the client with hubble certificate

```bash
#!/usr/bin/env bash

set -euo pipefail
set -x

# Directory where certificates will be stored
CERT_DIR="$(pwd)/.certs"
mkdir -p "$CERT_DIR"

declare -A CERT_FILES=(
  ["tls.crt"]="tls-client-cert-file"
  ["tls.key"]="tls-client-key-file"
  ["ca.crt"]="tls-ca-cert-files"
)

for FILE in "${!CERT_FILES[@]}"; do
  KEY="${CERT_FILES[$FILE]}"
  JSONPATH="{.data['${FILE//./\\.}']}"

  # Retrieve the secret and decode it
  kubectl get secret hubble-relay-client-certs -n kube-system -o jsonpath="${JSONPATH}" | base64 -d > "$CERT_DIR/$FILE"

  # Set the appropriate hubble CLI config
  hubble config set "$KEY" "$CERT_DIR/$FILE"
done

hubble config set tls true
hubble config set tls-server-name instance.hubble-relay.cilium.io
```

Check Hubble pods are running using the `kubectl get pods` command.

```bash
kubectl get pods -o wide -n kube-system -l k8s-app=hubble-relay
```

Your output should look similar to the following example output:

```text
NAME                            READY   STATUS    RESTARTS   AGE    IP            NODE                                 NOMINATED NODE   READINESS GATES
hubble-relay-7ff97868ff-tvwcf   1/1     Running   0          101m   10.244.2.57   aks-systempool-10200747-vmss000000   <none>           <none>
```

Using hubble we will look for what is dropped.

```bash
hubble observe --verdict DROPPED
```

Here we can see traffic coming from world dropped in store-front

![Hubble CLI](assets/acns-hubble-cli.png)

So now we can tell that there is a problem with the frontend ingress traffic configuration, let's review the **allow-store-front-traffic** policy

```bash
kubectl describe -n pets cnp allow-store-front-traffic
```

Here we go, we see that the Ingress traffic is not allowed

![Ingress traffic not allowed](assets/acns-policy-output.png)

Now to solve the problem we will apply the original policy.

Run the following command to apply the original network policy to the pets namespace.

```bash
curl -o acns-network-policy-allow-store-front-traffic.yaml https://gist.githubusercontent.com/pauldotyu/013c496a3b26805ca213b5858d69e07c/raw/e7c7eb7d9bd2799a59eb66db9191c248435f2db4/acns-network-policy-allow-store-front-traffic.yaml
```

View the contents of the network policy manifest file.

```bash
cat acns-network-policy-allow-store-front-traffic.yaml
```

Apply the network policy to the pets namespace.

```bash
kubectl apply -n pets -f acns-network-policy-allow-store-front-traffic.yaml
```

You should now see the traffic flowing again and you are able to access the pets shop app UI.

### Visualize traffic with Hubble UI

#### Install Hubble UI

Run the following command to download the Hubble UI manifest file.

```bash
curl -o acns-hubble-ui.yaml https://gist.githubusercontent.com/pauldotyu/0daaba9833a714dc28ed0032158fb6fe/raw/801f9981a65009ed53e6596d06a9a8e73286ed21/acns-hubble-ui.yaml
```

Optionally, run the following command to take a look at the Hubble UI manifest file.

```bash
cat acns-hubble-ui.yaml
```

Apply the hubble-ui.yaml manifest to your cluster, using the following command

```bash
kubectl apply -f acns-hubble-ui.yaml
```

#### Forward Hubble Relay Traffic

Set up port forwarding for Hubble UI using the kubectl port-forward command.

```bash
kubectl -n kube-system port-forward svc/hubble-ui 12000:80
```

#### Access Hubble UI

Access Hubble UI by entering http://localhost:12000/ into your web browser.

![Accessing the Hubble UI](assets/acns-hubble-ui.png)

