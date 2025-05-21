---
sidebar_position: 2
title: Kubernetes the Easy Way with AKS Automatic
---

This workshop will show you how easy it is to deploy applications to AKS Automatic. AKS Automatic is a new way to deploy and manage Kubernetes clusters on Azure. It is a fully managed Kubernetes service that simplifies the deployment, management, and operations of Kubernetes clusters. With AKS Automatic, you can deploy a Kubernetes cluster with just a few clicks in the Azure Portal, and it is designed to be simple and easy to use, so you can focus on building your applications!

---

## Objectives

After completing this workshop, you will be able to:

- Deploy an application to an AKS Automatic cluster
- Troubleshoot application issues
- Integrate applications with Azure services
  - Optional: Use Microsoft Authentication Library (MSAL) to implement passwordless authentication with Azure CosmosDB
- Scale your cluster and applications
- Observe your cluster and applications

---

## Prerequisite

- [GitHub Account](http://github.com/signup) - this workshop requires a GitHub account to fork and clone the sample repository.

---

## Deploy your app to AKS Automatic

With AKS, the [Automated Deployments](https://learn.microsoft.com/azure/aks/automated-deployments) feature allows you to create [GitHub Actions workflows](https://docs.github.com/actions) that allows you to start deploying your applications to your AKS cluster with minimal effort, even if you don't already have an AKS cluster. All you need to do is point it at a GitHub repository with your application code.

If you have Dockerfiles or Kubernetes manifests in your repository, that's great, you can simply point to them in the Automated Deployments setup. If you don't have Dockerfiles or Kubernetes manifests in your repository, don't sweat 😅 Automated Deployments can create them for you 🚀

### Fork and clone the sample repository

Open a bash shell and run the following command then follow the instructions printed in the terminal to complete the login process.

```bash
gh auth login
```

Here is an example of the login process with options selected.

```text
$ gh auth login
? Where do you use GitHub? GitHub.com
? What is your preferred protocol for Git operations on this host? HTTPS
? Authenticate Git with your GitHub credentials? Yes
? How would you like to authenticate GitHub CLI? Login with a web browser

! First copy your one-time code: 1234-ABCD
Press Enter to open https://github.com/login/device in your browser...
```

After you've completed the login process, run the following command to fork the [contoso-air](https://github.com/Azure-Samples/contoso-air) repository to your GitHub account.

```bash
gh repo fork Azure-Samples/contoso-air --clone
```

Change into the `contoso-air` directory.

```bash
cd contoso-air
```

> [!alert]
> If you want to walkthrough the coding exercise to implement the passwordless authentication with Azure CosmosDB, you will need to take code from the `msbuild_lab342` branch. You can do this by running the following commands:

```bash
git reset --hard origin/msbuild_lab342
git push --force
```

Also, make sure to set the user name and email address for Git. This will be required to commit changes to your GitHub repository.

```bash
git config user.name "your_name"
git config user.email "your_email_address"
```

Set the default repository to your forked repository.

```bash
gh repo set-default
```

When prompted, select your fork of the repository and press **Enter**.

You're now ready to deploy the sample application to your AKS cluster.

### Automated Deployments setup

In your web browser, navigate to [https://portal.azure.com](https://portal.azure.com).

> [!alert]
> An Azure subscription is provided for you in the lab environment. The credentials can be found in the **Resources** tab in the lab environment.

In the [Azure portal](https://portal.azure.com/) type **Kubernetes services** in the search box at the top of the page and click the **Kubernetes services** option from the search results.

![Kubernetes services](./assets/aks-automatic/aks-search.png)

In the upper left portion of the screen, click the **+ Create** button to view all the available options for creating a new AKS cluster.

Click on the **Deploy application (new)** option.

![Deploy application with Automated Deployment](./assets/aks-automatic/deploy-app.png)

In the **Basics** tab, click on the **Deploy your application** option, then select your Azure subscription and the resource group you created during the lab environment setup.

> [!alert]
> Make a note of the location that the resources are deployed to in your pre-provisioned resource group as you should use the same location for your AKS cluster.

![Automated Deployment basics](./assets/aks-automatic/deploy-app-basics.png)

In the **Repository details** section set **Workflow name** to `contoso-air`.

If you have not already authorized Azure to access your GitHub account, you will be prompted to do so. Click the **Authorize access** button to continue.

![GitHub authorization](./assets/aks-automatic/deploy-app-repo-auth.png)

Once your GitHub account is authorized, you will be able to select the repository you forked earlier.

Click the **Select repository** drop down, then select the **contoso-air** repository you forked earlier, and select the **main** branch.

![GitHub repo selection](./assets/aks-automatic/deploy-app-repo-selection.png)

Click **Next**.

In the **Application** tab, complete the **Image** section with the following details:

- **Container configuration**: Select **Auto-containerize (generate Dockerfile)**
- **Save files in repository**: Click the **Select** link to open the directory explorer, then navigate to the **Root/src** directory, select the checkbox next to the **web** folder, then click **Select**.

![Container image build context](./assets/aks-automatic/deploy-app-image-path.png)

In the **Dockerfile configuration** section, fill in the following details:

- **Application environment**: Select **JavaScript - Node.js 22**
- **Application port**: Enter`3000`
- **Dockerfile build context**: Enter `./src/web`
- **Azure Container Registry**: Select the Azure Container Registry in your resource group
- **Azure Container Registry image**: Click the **Create new** link then enter `contoso-air`

![Container image build configuration](./assets/aks-automatic/deploy-app-image.png)

In the **Deployment configuration** section and fill in the following details:

- **Deployment options**: Select **Generate application deployment files**
- **Save files in repository**: Click the **Select** link to open the directory explorer, then select the checkbox next to the **Root** folder, then click **Select**.

![Kubernetes deployment manifest path](./assets/aks-automatic/deploy-app-manifest-path.png)

Click **Next**.

In the **Cluster configuration** section, ensure the **Create Automatic Kubernetes cluster** option is chosen and specify `myakscluster` as the **Kubernetes cluster name**.

![AKS Automatic cluster creation](./assets/aks-automatic/deploy-app-cluster-new.png)

For **Namespace**, select **Create new** and type `dev`.

> [!alert]
> Be sure to set the namespace to `dev` as instructions later in the workshop will use this namespace.

You can leave the remaining fields as their default values.

![Kubernetes namespace](./assets/aks-automatic/deploy-app-cluster-logging.png)

> [!note]
> You will see that the monitoring and logging options have been enabled by default and set to use the Azure resources that are available in your subscription. If you don't have these resources available, AKS Automatic will create them for you. If you want to change the monitoring and logging settings, you can do so by clicking on the **Change** link and selecting the desired target resources for monitoring and logging.

Click **Next**.

In the **Review** tab, you will see a summary of the configuration you have selected and view a preview of the Dockerfile and Kubernetes deployment files that will be generated for you.

![Automated Deployment configuration review](./assets/aks-automatic/deploy-app-review.png)

When ready, click the **Deploy** button to start the deployment.

![Automated Deployment and AKS Cluster deployment](./assets/aks-automatic/deploy-app-deploy.png)

> [!alert]
> This process can take up to 20 minutes to complete. Do not close the browser window or navigate away from the page until the deployment is complete.

### Review the pull request

Once the deployment is complete, click on the **Approve pull request** button to view the pull request to be taken to the pull request page in your GitHub repository.

![Automated Deployment success](./assets/aks-automatic/deploy-app-done.png)

In the pull request review, click on the **Files changed** tab to view the changes that were made by the Automated Deployments workflow.

![GitHub pull request files changed](./assets/aks-automatic/github-pull-request-files.png)

Navigate back to the **Conversation** tab and click on the **Merge pull request** button to merge the pull request, then click **Confirm merge**.

![GitHub merge pull request](./assets/aks-automatic/github-pull-request-merged.png)

With the pull request merged, the changes will be automatically deployed to your AKS cluster. You can view the deployment logs by clicking on the **Actions** tab in your GitHub repository.

![GitHub Actions tab](./assets/aks-automatic/github-actions.png)

In the **Actions** tab, you will see the Automated Deployments workflow running. Click on the workflow run to view the logs.

![GitHub Actions workflow run](./assets/aks-automatic/github-actions-workflow.png)

In the workflow run details page, you can view the logs of each job in the workflow by simply clicking on the job.

![GitHub Actions workflow logs](./assets/aks-automatic/github-actions-workflow-run.png)

After 5-10 minutes, the workflow will complete and you will see two green check marks next to the **buildImage** and **deploy** jobs. This means that the application has been successfully deployed to your AKS cluster.

![GitHub Actions workflow success](./assets/aks-automatic/github-action-done.png)

> [!hint]
> If the deploy job fails, it is likely that Node Autoprovisioning (NAP) is still provisioning a new node for the cluster. Try clicking the "Re-run" button at the top of the page to re-run the deploy workflow job.

With AKS Automated Deployments, every time you push application code changes to your GitHub repository, the GitHub Action workflow will automatically build and deploy your application to your AKS cluster. This is a great way to automate the deployment process and ensure that your applications are always up-to-date!

### Test the deployed application

Back in the Azure portal, click the **Close** button to close the Automated Deployments setup.

In the left-hand menu, click on **Services and ingresses** under the **Kubernetes resources** section. You should see a new service called `contoso-air` with an external IP address assigned to it. Click on the IP address to view the deployed application.

![Contoso Air service](./assets/aks-automatic/contoso-air-service-ip.png)

Let's test the application functionality by clicking the **Login** link in the upper right corner of the page.

![Contoso Air application](./assets/aks-automatic/contoso-air.png)

There is no real authentication provider in this application, so you can simply type in whatever you like for the username and password and click the **Log in** button.

![Contoso Air login page](./assets/aks-automatic/contoso-air-login.png)

Click on the **Book** link in the top navigation bar and fill in the form with your trip details and click the **Find flights** button.

![Contoso Air book flight](./assets/aks-automatic/contoso-air-book.png)

You will see some available flight options. Scroll to the bottom of the page and click **Next** to continue.

![Contoso Air flight options](./assets/aks-automatic/contoso-air-flights.png)

The application will either redirect you back to the login page or show an error message. What happened? 🤔

Let's find out...

### Troubleshoot the application

Navigate back to the Azure portal and select **Logs** from the **Monitoring** section in the AKS cluster's left-hand menu. This section allows you to access the logs gathered by the Azure Monitor agent operating on the cluster nodes.

![Contoso Air container logs](./assets/aks-automatic/logs.png)

If you are presented with a **Welcome to Log Analytics** pop-up, close it to access the query editor.

Close the **Queries hub** pop-up to get to the query editor, type the following query, then click the **Run** button to view container logs.

```kql
ContainerLogV2
| where LogLevel contains "error" and ContainerName == "contoso-air"
```

> [!hint]
> If the query editor is in **Simple mode**, switch to **KQL mode** by using the drop-down menu in the top-right corner. To make **KQL mode** the default, select the corresponding radio button in the pop-up and click **Save**.

![Contoso Air error log query](./assets/aks-automatic/log-query.png)

Expand some of the logs to view the error messages that were generated by the application.

You should see an error message that says `Azure CosmosDB settings not found. Booking functionality not available.`.

![Contoso Air error logs query results](./assets/aks-automatic/log-query-result.png)

This error occurred because the application is trying to connect to an Azure CosmosDB database to store the booking information, but the connection settings are not configured. We can fix this by adding configuration to the application using the AKS Service Connector!

---

## Integrating apps with Azure services

[AKS Service Connector](https://learn.microsoft.com/azure/service-connector/overview) streamlines connecting applications to Azure resources like Azure CosmosDB by automating the configuration of [Workload Identity](https://learn.microsoft.com/azure/aks/workload-identity-overview?tabs=javascript). This feature allows you to assign identities to pods, enabling them to authenticate with Microsoft Entra ID and access Azure services securely without passwords. For a deeper understanding, check out the [Workload Identity overview](https://learn.microsoft.com/entra/workload-id/workload-identities-overview).

> [!hint]
> Workload Identity is the recommended way to authenticate with Azure services from your applications running on AKS. It is more secure than using service principals and does not require you to manage credentials in your application. To read more about the implementation of Workload Identity for Kubernetes, see [this doc](https://azure.github.io/azure-workload-identity/docs/).

### Use Microsoft Authentication Library (MSAL) to implement passwordless authentication

> [!alert]
> If you opted to implement the passwordless authentication with Azure CosmosDB when you forked and cloned the repository, you will need to follow the instructions below to implement the functionality for Service Connector to work. Otherwise, you can skip this section and continue to the next section.

Open the repo using Visual Studio Code (VSCode) then navigate to **/src/web/repositories** and open the **index.js** file. This is where the BookRepository class is instantiated and the connection information to the Azure CosmosDB database is configured.

> [!knowledge]
> Notice the names of the environment variables (e.g., **AZURE_COSMOS_LISTCONNECTIONSTRINGURL**, **AZURE_COSMOS_SCOPE**, and **AZURE_COSMOS_CLIENTID**) that are used to configure the connection to the Azure CosmosDB database. These environment variables will be set by the Service Connector when it is created.

Let's implement the passwordless authentication with Azure CosmosDB using the Microsoft Authentication Library (MSAL) for JavaScript.

In the VSCode terminal, run the following command to install the necessary dependencies.

> [!alert]
> Make sure to run this command in the **/src/web** directory. This is where the **package.json** file is located.

```bash
cd src/web
npm install @azure/identity axios
```

Open the **/src/web/repositories/book.repository.js** file and add the following code to the top of the file:

```javascript
const { DefaultAzureCredential } = require("@azure/identity");
const axios = require("axios");
```

Next, find the **BookFlightsRepository** class constructor and add the following code to the top of the constructor (before the **initialize** function):

```javascript
const { listConnectionStringUrl, scope, clientId } = options;
let accessToken;
let connectionString;
```

Finally, replace the code in **initialize** function with the following:

```javascript
// Get the access token for the managed identity
const credential = new DefaultAzureCredential({
  managedIdentityClientId: clientId,
});
accessToken = await credential.getToken(scope);

// Get the connection string using the access token
const config = {
  method: "post",
  url: listConnectionStringUrl,
  headers: {
    Authorization: `Bearer ${accessToken.token}`,
  },
};
const response = await axios(config);
const keysDict = response.data;
connectionString = keysDict["connectionStrings"][0]["connectionString"];

// Connect to the MongoDB server using the connection string
mongoose.connect(connectionString, {
  useNewUrlParser: true,
  useUnifiedTopology: true,
});
mongoose.Promise = global.Promise;

console.log("Connected to the database");
```

> [!hint]
> You might have to fix the indentation of the code.

This code will use the **DefaultAzureCredential** class from the MSAL library to get the access token for the managed identity which is identified by the **clientId**. It will then use the access token and make a request to the **listConnectionStringUrl** endpoint to get the connection string for the Azure CosmosDB database.

> [!knowledge]
> Azure CosmosDB with MongoDB API does not natively support the Microsoft Entra ID authentication with Azure RBAC. Instead, it requires a connection string to connect to the database. However, the **listConnectionStringUrl** endpoint is a special endpoint that allows you to get the connection string for the Azure CosmosDB database using the access token.

With the connection string retrieved, it will be passed to the **mongoose.connect** method to connect to the Azure CosmosDB database.

Be sure to save the changes to the file, then commit and push the changes to your GitHub repository using VSCode. If you are using the integrated terminal, you can run the following commands to commit and push the changes.

```bash
git pull
git add .
git commit -m "feat: passwordless authentication for azure cosmosdb"
git push
```

With the GitHub Actions workflow set up, the changes will be automatically deployed to your AKS cluster. You can view the deployment logs by clicking on the **Actions** tab in your GitHub repository.

While that is deploying, let's set up the Service Connector to connect the application to the Azure CosmosDB database.

To view the GitHub Actions workflow running from the terminal, you could run the following command:

```bash
gh run watch
```

Select the workflow run to view status and press **Ctrl + c** to stop the watch command.

### Service Connector setup

In the left-hand menu, click on **Service Connector** under **Settings** then click on the **+ Create** button.

![AKS service connector](./assets/aks-automatic/service-connector.png)

In the **Basics** tab, enter the following details:

- **Kubernetes namespace**: Enter `dev`
- **Service type**: Select **Cosmos DB**
- **API type**: Select **MongoDB**
- **Cosmos DB account**: Select the CosmosDB account you created earlier
- **MongoDB database**: Select **test**

![AKS service connector basics](./assets/aks-automatic/service-connector-basics.png)

Click **Next: Authentication**.

In the **Authentication** tab, select the **Workload Identity** option. You should see a user-assigned managed identity that was created during your lab setup. If no managed identities appear in the dropdown, click the **Create new** link to provision a new one.

![AKS service connector authentication](./assets/aks-automatic/service-connector-auth.png)

> [!hint]
> Optionally, you can expand the **Advanced** section to customize the managed identity settings. By default, the **DocumentDB Account Contributor** role is assigned, granting permissions to read, write, and delete resources in the CosmosDB account. This role enables the workload identity to properly authenticate and interact with your database. You'll also notice there's additional configuration information that Service Connector will set as environment variables in the application. These variables will be saved to a Kubernetes Secret which will then be used to configure the connection to the Azure CosmosDB database.

Click **Next: Networking** then click **Next: Review + create** and finally click **Create**.

![AKS service connector review](./assets/aks-automatic/service-connector-review.png)

> [!knowledge]
> This process will take a few minutes while Service Connector configures the Workload Identity infrastructure. Behind the scenes, it's:
>
> - Assigning appropriate Azure role permissions to the [managed identity](https://learn.microsoft.com/entra/identity/managed-identities-azure-resources/overview) for CosmosDB access
> - Creating a [Federated Credential](https://learn.microsoft.com/entra/workload-id/workload-identity-federation) that establishes trust between your Kubernetes cluster and the managed identity
> - Setting up a Kubernetes [ServiceAccount](https://kubernetes.io/docs/concepts/security/service-accounts/) linked to the managed identity
> - Creating a Kubernetes [Secret](https://kubernetes.io/docs/concepts/configuration/secret/) containing the CosmosDB connection information

### Configure the application for Workload Identity

Once you've successfully set up the Service Connector for your Azure CosmosDB, it's time to configure your application to use these connection details.

In the Service Connector page, select the checkbox next to the CosmosDB connection and click the **Yaml snippet** button.

![AKS service connector yaml snippet](./assets/aks-automatic/service-connector-yaml-snippet.png)

In the **YAML snippet** window, select **Kubernetes Workload** for **Resource type**, then select **contoso-air** for **Kubernetes Workload**.

![AKS service connector yaml snippet for contoso-air](./assets/aks-automatic/service-connector-yaml-deploy.png)

You will see the YAML manifest for the contoso-air application with the highlighted edits required to connect to CosmosDB via Workload Identity.

![AKS service connector yaml snippet for contoso-air](./assets/aks-automatic/service-connector-yaml-deploy.png)

Scroll through the YAML manifest to view the changes highlighted in yellow, then click **Apply** to apply the changes to the application. This will redeploy the contoso-air application with the new connection details.

![AKS service connector yaml snippet apply](./assets/aks-automatic/service-connector-yaml-apply.png)

> [!hint]
> This will apply changes directly to the application deployment but ideally you would want to commit these changes to your repository so that they are versioned and can be tracked and automatically deployed using the Automated Deployments workflow that you set up earlier.

Wait a minute or two for the new pod to be rolled out then navigate back to the application and attempt to book a flight. Now, you should be able to book a flight without any errors!

![Contoso Air flight booking success](./assets/aks-automatic/contoso-air-booked.png)

---

## Observing your cluster and apps

Monitoring and observability are key components of running applications in production. With AKS Automatic, you get a lot of monitoring and observability features enabled out-of-the-box. You experienced some of these features when you used ran queries to look for error logs in the application. Let's take a closer look at how you can monitor and observe your application and cluster.

At the start of the workshop, you set up the AKS Automatic cluster and integrated it with [Azure Log Analytics Workspace](https://learn.microsoft.com/azure/azure-monitor/logs/log-analytics-overview) for logging, [Azure Monitor Managed Workspace](https://learn.microsoft.com/azure/azure-monitor/containers/kubernetes-monitoring-enable?tabs=cli) for metrics collection, and [Azure Managed Grafana](https://azure.microsoft.com/products/managed-grafana) for data visualization.

Now, you can also enable the [Azure Monitor Application Insights for AKS](https://learn.microsoft.com/azure/azure-monitor/app/kubernetes-codeless) feature to automatically instrument your applications with [Azure Application Insights](https://learn.microsoft.com/azure/azure-monitor/app/app-insights-overview).

### Application insights

[Azure Monitor Application Insights](https://learn.microsoft.com/azure/azure-monitor/app/app-insights-overview) is an Application Performance Management (APM) solution designed for real-time monitoring and observability of your applications. Leveraging [OpenTelemetry (OTel)](https://opentelemetry.io/), it collects telemetry data from your applications and streams it to Azure Monitor. This enables you to evaluate application performance, monitor usage trends, pinpoint bottlenecks, and gain actionable insights into application behavior. With AKS, you can enable the [AutoInstrumentation](https://learn.microsoft.com/azure/azure-monitor/app/kubernetes-codeless) feature which allows you to collect telemetry for your applications without requiring any code changes.

> [!alert]
> At the time of this writing, the AutoInstrumentation feature is in public preview. Please refer to the [official documentation](https://learn.microsoft.com/azure/azure-monitor/app/kubernetes-codeless#register-the-azuremonitorappmonitoringpreview-feature-flag) for the most up-to-date information.

You can enable the feature on your AKS cluster with the following command:

Before you run the command below, make sure you are logged into Azure CLI and have variables set for the resource group name and AKS cluster name.

```bash
RG_NAME=myresourcegroup
AKS_NAME=$(az aks list -g $RG_NAME --query "[0].name" -o tsv)
```

> [!alert]
> If you have not already logged into Azure CLI, you can do so by running the following command: `az login`.

With the variables set, run the following command to enable the AutoInstrumentation feature on your AKS cluster.

```bash
az aks update \
-g ${RG_NAME} \
-n ${AKS_NAME} \
--enable-azure-monitor-app-monitoring
```

> [!hint]
> Using the `--enable-azure-monitor-app-monitoring` flag for AKS requires the `aks-preview` extension installed for Azure CLI. Run the `az extension add --name aks-preview` command to install it.

With this feature enabled, you can now deploy a new Instrumentation custom resource to your AKS cluster to automatically instrument your applications without any modifications to the code.

Before proceeding, retrieve the Application Insights connection string from your Azure deployment by running the command below and saving the result to an environment variable:

```bash
APPLICATION_INSIGHTS_CONNECTION_STRING=$(az monitor app-insights component show \
-g ${RG_NAME} \
--query "[0].connectionString" \
-o tsv)
```

> [!hint]
> If you don't have `app-insights` available in your Azure CLI, you can install the extension by running the following command:

```bash
az extension add --name application-insights
```

Connect to the AKS cluster by running the following command.

```bash
az aks get-credentials -g ${RG_NAME} -n ${AKS_NAME}
```

Now, you can deploy the Instrumentation custom resource to the AKS cluster.

```bash
kubectl apply -f - <<EOF
apiVersion: monitor.azure.com/v1
kind: Instrumentation
metadata:
  name: default
  namespace: dev
spec:
  settings:
    autoInstrumentationPlatforms:
      - NodeJs
  destination:
    applicationInsightsConnectionString: $APPLICATION_INSIGHTS_CONNECTION_STRING
EOF
```

This will deploy the Instrumentation custom resource called `default` and instrument all Node.js applications running in the `dev` namespace.

> [!note]
> AKS Automatic clusters are secured using Microsoft Entra ID and Azure RBAC, so you will be prompted to log in to your Azure account. Follow the instructions in the terminal to complete the login process.

Now you need to restart the application pods to apply the changes. Run the following command to restart the application pods.

```bash
kubectl rollout restart deployment contoso-air -n dev
```

Once the pods have restarted, you will notice an **azure-monitor-auto-instrumentation-nodejs** Init Container has been added to the pod along. This container automatically instruments the application with Application Insights. By running the following command, you can review the entire Deployment configuration.

```bash
kubectl describe pods -n dev
```

> [!hint]
> This is a simple example of how to instrument your application across an entire namespace. You can also instrument individual deployments by deploying another Instrumentation custom resource with a different name then annotating the targeted deployment with with the following annotation: **"instrumentation.opentelemetry.io/inject-nodejs": "name_of_instrumentation_resource"** and restarting the deployment. See the [documentation](https://learn.microsoft.com/azure/azure-monitor/app/kubernetes-codeless#mixed-mode-onboarding) for more details.

Now that the application is instrumented with Application Insights, navigate back to the contoso-air application in your web browser and book a few more flights to generate some metrics. Once the metrics have been generated and collected by the OTel collector, you can view the application performance and usage metrics in the Azure portal.

Navigate to the **Application Insights** resource in your resource group.

![Application Insights resource](./assets/aks-automatic/app-insights.png)

Click on the **Application map** under **Investigate** in the left-hand menu to view a high-level overview of the application components, their dependencies, and number of calls.

> [!hint]
> If the MongoDB does not appear in the application map, return to the Contoso Air website and book a flight to generate some data. Then, in the Application Map, click the **Refresh** button. The map will update in real time and should now display the MongoDB database connected to the application, along with the request latency to the database.

![Application map](./assets/aks-automatic/app-insights-map.png)

Click on the **Live Metrics** tab to view the live metrics for the application. Here you can see incoming and outgoing requests, response times, and exceptions in real-time.

![Live metrics](./assets/aks-automatic/app-insights-live-metrics.png)

Finally, click on the **Performance** tab to view the performance metrics for the application. Here you can see the average response time, request rate, and failure rate for the application.

![Application Insights resource](./assets/aks-automatic/app-insights-performance.png)

Feel free to explore the other features of Application Insights and see how you can use it to monitor and observe your applications.

### Container insights

AKS Automatic simplifies monitoring your cluster using [Container Insights](https://learn.microsoft.com/azure/azure-monitor/containers/container-insights-overview) which offers a detailed monitoring solution for your containerized applications running on AKS. It gathers and analyzes logs, metrics, and events from your cluster and applications, providing valuable insights into their performance and health.

To access this feature, navigate back to your AKS cluster in the Azure portal. Under the **Monitoring** section in the left-hand menu, click on **Insights** to view a high-level summary of your cluster's performance.

![Cluster metrics](./assets/aks-automatic/insights.png)

The AKS Automatic cluster was also pre-configured with basic CPU utilization and memory utilization alerts. You can also create additional alerts based on the metrics collected by the Prometheus workspace.

Click on the **Recommended alerts (Preview)** button to view the recommended alerts for the cluster. Expand the **Prometheus community alert rules (Preview)** section to see the list of Prometheus alert rules that are available. You can enable any of these alerts by clicking on the toggle switch.

![Cluster alerts](./assets/aks-automatic/insights-recommended-alerts.png)

Click **Save** to enable the alerts.

#### Workbooks and logs

With Container Insights enabled, you can query logs using Kusto Query Language (KQL) and create custom or pre-configured workbooks for data visualization. In the **Monitoring** section of the AKS cluster menu, click **Workbooks** to access pre-configured options. The **Cluster Optimization** workbook is particularly useful for identifying anomalies, detecting probe failures, and optimizing container resource requests and limits. Explore this and other available workbooks to monitor your cluster effectively.

![Cluster optimization workbook](./assets/aks-automatic/insights-workbooks.png)

> [!hint]
> The workbook visuals will include a query button that you can click to view the KQL query that powers the visual. This is a great way to learn how to write your own queries.

Refer back to the earlier step where we troubleshot the Contoso Air app using the **Logs** section in the left-hand menu. Here, you can create custom KQL queries or use pre-configured ones to analyze logs from your cluster and applications. The **Queries hub** offers a variety of pre-configured queries—simply navigate to the **Container Logs** table in the left-hand menu under **All Queries**, choose a query, and click **Run** to view the results.

> [!note]
> Some of the queries might not have enough data to return results.

### Visualizing with Grafana

The Azure Portal provides a great way to view metrics and logs, but if you prefer to visualize the data using Grafana, or execute complex queries using PromQL, you can use the Azure Managed Grafana instance that was created with the AKS Automatic cluster.

In the AKS cluster's left-hand menu, click on **Insights** under the **Monitoring** section and click on the **View Grafana** button at the top of the page. This will open a window with the linked Azure Managed Grafana instance. Click on the **Browse dashboards** link. This will take you to the Azure Managed Grafana instance.

![Browse dashboards](./assets/aks-automatic/monitor-grafana.png)

Log into the Grafana instance then in the Grafana home page, click on the **Dashboards** link in the left-hand menu. Here you will see a list of pre-configured dashboards that you can use to visualize the metrics collected by the Prometheus workspace.

In the **Dashboards** list, expand the **Azure Managed Prometheus** folder and explore the dashboards available. Each dashboard provides a different view of the metrics collected by the Prometheus workspace with controls to allow you to filter the data.

Click on a **Kubernetes / Compute Resources / Workload** dashboard.

![Grafana dashboards](./assets/aks-automatic/grafana-dashboards.png)

Filter the **namespace** to **dev** the **type** to **deployment**, and the **workload** to **contoso-air**. This will show you the metrics for the contoso-air deployment.

![Grafana compute workload dashboard](./assets/aks-automatic/grafana-compute-workload.png)

#### Querying metrics with PromQL

If you prefer to write your own queries to visualize the data, you can use the **Explore** feature in Grafana. In the Grafana home page, click on the **Explore** link in the left-hand menu, and select the data source name that begins with **Managed_Prometheus_**.

The query editor supports a graphical query builder and a text-based query editor. The graphical query builder is a great way to get started with PromQL. You can select the metric you want to query, the aggregation function, and any filters you want to apply.

![Grafana explore with PromQL](./assets/aks-automatic/grafana-promql.png)

There is a lot you can do with Grafana and PromQL, so take some time to explore the features and visualize the metrics collected by the Prometheus workspace.

---

## Scaling your cluster and apps

Now that you have learned how to deploy applications to AKS Automatic and monitor your cluster and applications, let's explore how to scale your cluster and applications to handle the demands of your workloads effectively.

Right now, the application is running a single pod. When the web app is under heavy load, it may not be able to handle the requests. To automatically scale your deployments, you should use [Kubernetes Event-driven Autoscaling (KEDA)](https://keda.sh/) which allows you to scale your application workloads based on utilization metrics, number of events in a queue, or based on a custom schedule using CRON expressions.

But simply using implementing KEDA is not enough. KEDA can try to deploy more pods, but if the cluster is out of resources, the pods will not be scheduled and remain in pending status.

With AKS Automatic, [Node Autoprovisioning (NAP)](https://learn.microsoft.com/azure/aks/node-autoprovision?tabs=azure-cli) is enabled and is used over the traditional cluster autoscaler. With NAP, it can detect if there are pods pending scheduling and will automatically scale the node pool to meet the demands. We won't go into the details of working with NAP in this workshop, but you can read more about it in the [AKS documentation](https://learn.microsoft.com/azure/aks/node-autoprovision?tabs=azure-cli).

> [!hint]
> NAP will not only automatically scale out additional nodes to meet demand, it will also find the most efficient VM configuration to host the demands of your workloads and scale nodes in when the demand is low to save costs.

For the Kubernetes scheduler to efficiently schedule pods on nodes, it is best practice to include resource requests and limits in your pod configuration. The Automated Deployment setup added some default resource requests and limits to the pod configuration, but they may not be optimal. Knowing what to set the request and limit values to can be challenging. This is where the [Vertical Pod Autoscaler (VPA)](https://kubernetes.io/docs/tasks/run-application/vertical-pod-autoscaling/) can help.

### Vertical Pod Autoscaler (VPA) setup

VPA is a Kubernetes resource that allows you to automatically adjust the CPU and memory requests and limits for your pods based on the actual resource utilization of the pods. This can help you optimize the resource utilization of your pods and reduce the risk of running out of resources.

AKS Automatic comes with the VPA controller pre-installed, so you can use the VPA resource immediately by simply deploying a VPA resource manifest to your cluster.

Navigate to the **Custom resource** section under **Kubernetes resources** in the AKS cluster left-hand menu. Scroll down to the bottom of the page and click on the **Load more** button to view all the available custom resources.

![Load more custom resources](./assets/aks-automatic/custom-resources-load-more.png)

Click on the **VerticalPodAutoscaler** resource to view the VPA resources in the cluster.

![VPA resources](./assets/aks-automatic/custom-resources-vpa.png)

Click on the **+ Create** button where you'll see a **Apply with YAML** editor.

![Create VPA](./assets/aks-automatic/custom-resources-vpa-create.png)

Not sure what to add here? No worries! You can lean on [Microsoft Copilot in Azure](https://learn.microsoft.com/azure/copilot/overview) to help generate the VPA manifest.

Click in the text editor or press **Alt + I** to open the Copilot editor.

In the **Draft with Copilot** text box, type in the following prompt:

```text
Help me create a vertical pod autoscaler manifest for the contoso-air deployment in the dev namespace and set min and max cpu and memory to something typical for a nodejs app. Please apply the values for both requests and limits.
```

Press **Enter** to generate the VPA manifest.

When the VPA manifest is generated, click the **Accept all** button to accept the changes, then click **Add** to create the VPA resource.

![VPA manifest](./assets/aks-automatic/custom-resources-vpa-add.png)

> [!alert]
> Microsoft Copilot in Azure may provide different results. If your results are different, simply copy the following VPA manifest and paste it into the **Apply with YAML** editor.

```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: contoso-air-vpa
  namespace: dev
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: contoso-air
  updatePolicy:
    updateMode: Auto
  resourcePolicy:
    containerPolicies:
      - containerName: contoso-air
        minAllowed:
          cpu: 100m
          memory: 256Mi
        maxAllowed:
          cpu: 1
          memory: 512Mi
        controlledResources: ["cpu", "memory"]
```

> [!knowledge]
> The VPA resource will only update the CPU and memory requests and limits for the pods in the deployment if the number of replicas is greater than 1. Also the pod will be restarted when the VPA resource updates the pod configuration so it is important to create [Pod Disruption Budgets (PDBs)](https://kubernetes.io/docs/concepts/workloads/pods/disruptions/#pod-disruption-budgets) to ensure that the pods are not restarted all at once.

### KEDA scaler setup

AKS Automatic also comes with the KEDA controller pre-installed, so you can use the KEDA resource immediately by simply deploying a KEDA scaler to your cluster.

> [!alert]
> KEDA works with the Horizontal Pod Autoscaler (HPA) to scale your applications based on external metrics. It will automatically create an HPA resource for you when you create a KEDA ScaledObject resource and take ownership of the resource. If you already have an existing HPA resource, you can [transfer ownership](https://keda.sh/docs/2.17/concepts/scaling-deployments/#transferring-ownership-of-an-existing-hpa) so that KEDA manages the existing resource instead of creating one. When the contoso-air application was deployed to Kubernetes with AKS Automated Deployments, a HPA resource was automatically created. Rather than transferring ownership, we will need to delete the existing HPA resource so that KEDA can create a new one.

To delete the existing HPA resource, run the following command:

```bash
kubectl delete hpa contoso-air -n dev
```

Navigate to **Application scaling** under **Settings** in the AKS cluster left-hand menu, then click on the **+ Create** button.

![Application scaling](./assets/aks-automatic/keda.png)

In the **Basics** tab, enter the following details:

- **Name**: Enter `contoso-air-so`
- **Namespace**: Select **dev**
- **Target workload**: Select **contoso-air**
- **Minimum replicas**: Enter `3`
- **Maximum replicas**: Enter `10`
- **Trigger type**: Select **CPU**

![Application scaling basics](./assets/aks-automatic/keda-basics.png)

Leave the rest of the fields as their default values and click **Next**.

In the **Review + create** tab, click **Customize with YAML** to view the YAML manifest for the ScaledObject resource. You can see the YAML manifest the AKS portal generated for the ScaledObject resource. Here you can add additional configuration to the ScaledObject resource if needed.

Click **Save and create** to create the ScaledObject resource.

![Application scaling yaml](./assets/aks-automatic/keda-review.png)

Head over to the **Workloads** section in the left-hand menu under **Kubernetes resources**. In the **Filter by namespace** drop down list, select **dev**. You should see the **contoso-air** deployment is now running (or starting) 3 replicas.

Now that the number of replicas has been increased, the VPA resource will be able to adjust the CPU and memory requests and limits for the pods in the deployment based on the actual resource utilization of the pods the next time it reconciles.

> [!knowledge]
> This was a simple example of using using KEDA. The real power of KEDA comes from its ability to scale your application based on external metrics. There are many [scalers](https://keda.sh/docs/scalers/) available for KEDA that you can use to scale your application based on a variety of external metrics.

If you have time, try to run a simple load test to see the scaling in action. You can use the [hey](https://github.com/rakyll/hey) tool to generate some traffic to the application.

> [!note]
> If you don't have the **hey** tool installed, checkout the [installation guide](https://github.com/rakyll/hey?tab=readme-ov-file#installation) and follow the instructions based on your operating system.

Run the following command to generate some traffic to the application:

```bash
hey -z 30s -c 100 http://<REPLACE_THIS_WITH_CONTOSO_AIR_SERVICE_IP>:3000
```

This will generate some traffic to the application for 30 seconds. You should see the number of replicas for the **contoso-air** deployment increase as the load increases.

---

## Summary

In this workshop, you learned how to create an AKS Automatic cluster and deploy an application to the cluster using Automated Deployments. From there, you learned how to troubleshoot application issues using the Azure portal and how to integrate applications with Azure services using the AKS Service Connector. You also learned how to enable application monitoring with AutoInstrumentation using Azure Monitor Application Insights, which provides deep visibility into your application's performance without requiring any code changes. Additionally, you explored how to configure your applications for resource specific scaling using the Vertical Pod Autoscaler (VPA) and scaling your applications with KEDA. Hopefully, you now have a better understanding of how easy it can be to build and deploy applications on AKS Automatic.

To learn more about AKS Automatic, visit the [AKS documentation](https://learn.microsoft.com/azure/aks/intro-aks-automatic) and checkout our other [AKS Automatic](/docs/operations/operating-aks-automatic) lab in this repo to explore more features of AKS.

In addition to this workshop, you can also explore the following resources:

- [Azure Kubernetes Service (AKS) documentation](https://learn.microsoft.com/azure/aks)
- [Kubernetes: Getting started](https://azure.microsoft.com/solutions/kubernetes-on-azure/get-started/)
- [Learning Path: Introduction to Kubernetes on Azure](https://learn.microsoft.com/training/paths/intro-to-kubernetes-on-azure/)
- [Learning Path: Deploy containers by using Azure Kubernetes Service (AKS)](https://learn.microsoft.com/training/paths/deploy-manage-containers-azure-kubernetes-service/)

If you have any feedback or suggestions for this workshop, please feel free to open an issue or pull request in the [GitHub repository](https://github.com/Azure-Samples/aks-labs)
