# Azure AKS Quick Guide 
> [!IMPORTANT]
> This is a quick guide to deploy AKS following best practices and recommendations, ease of use, ENJOY :sunglasses:.

![AKS](https://learn.microsoft.com/en-us/azure/well-architected/service-guides/azure-kubernetes-service)

![AZ CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)

![Azure Portal](https://portal.azure.com/)

Take a test run now from [Azure Portal Cloud Shell](https://portal.azure.com/#cloudshell)!

## Introduction

The present document provides simple guidance on recommendations, design, implementation, and validation processes related to the configuration of Azure Kubernetes Service (AKS) resources as a container orchestration platform. Additionally, it includes security best practices and hardening guidelines to strengthen the overall security posture of AKS clusters.
The purpose of this document is to serve as a foundation for understanding recommended configurations, best practices, and governance of AKS using Microsoft Azure native tools.

> [!NOTE]
> If your project requires specific configurations or unique features, the AKS Helper can be used as a reference or supporting tool to generate a customized deployment script aligned with your requirements.
> 
> **AKS Helper link:** https://azure.github.io/AKS-Construction/

## Pre-requisites to deploy
- Azure CLI
- AKS extension installed
- RBAC role on the subscription
- Private DNS zone (Required for Private AKS)
- Azure Container Registry (Required for container images)

## Important links

* Networking recommendations: <https://learn.microsoft.com/en-us/azure/aks/plan-networking>
* Node pools recommendations: <https://learn.microsoft.com/en-us/azure/aks/use-system-pools?tabs=azure-cli#system-and-user-node-pools>
* AKS Well Architected Framework (WAF): <https://learn.microsoft.com/en-us/azure/well-architected/service-guides/azure-kubernetes-service?>
* Azure security baseline for Azure Kubernetes Service (AKS): <https://learn.microsoft.com/en-us/security/benchmark/azure/baselines/azure-kubernetes-service-aks-security-baseline?toc=%2Fazure%2Faks%2Ftoc.json&bc=%2Fazure%2Faks%2Fbreadcrumb%2Ftoc.json>
* Configuration WAF recommendations: <https://learn.microsoft.com/en-us/azure/well-architected/service-guides/azure-kubernetes-service#configuration-recommendations>
* Networking comparison blog: <https://techcommunity.microsoft.com/blog/startupsatmicrosoftblog/choosing-the-right-networking-model-for-azure-kubernetes-service-aks-azure-cni-v/4351872>
* AKS best practices: <https://learn.microsoft.com/en-us/azure/aks/best-practices>
* AKS versions: <https://learn.microsoft.com/en-us/azure/aks/supported-kubernetes-versions?tabs=azure-cli#aks-kubernetes-release-calendar>
* AKS helper: <https://azure.github.io/AKS-Construction/>
* AKS roadmap: <https://aka.ms/aks/roadmap>
* AKS blog: <https://aka.ms/aks/blog>
* AKS release notes: <https://aka.ms/aks/release-notes>
* Updates about the service, including new features and new Azure regions:
  [AKS feed in Azure Updates](https://azure.microsoft.com/updates/?product=kubernetes-service)

## AZ CLI Installation

Please refer to the [install guide](https://learn.microsoft.com/cli/azure/install-azure-cli) for detailed install instructions.

A list of common install issues and their resolutions are available at [install troubleshooting](https://github.com/Azure/azure-cli/blob/dev/doc/install_troubleshooting.md).

## AKS Helper
* #### **Step 1**
  Navigate to the AKS Construction [**helper**](https://azure.github.io/AKS-Construction/)

* #### **Step 2** Select your Requirements (optional)
  Select your base `Operational` and `Security` Principles using the presets that have been designed from our field experience

* #### **Step 3** Fine tune (optional)
  Use the tabs to fine tune your cluster requirements

  ![fine tune](images/azure/helper-tabs.jpg)
* #### **Step 4** Deploy
  In the `Deploy` tab, choose how you will deploy your new cluster, and follow the instructions
  
#### Tab completion

![animated preview of AKS Construction Helper](images/azure/animgif.gif)


#### Query

You can use the `--query` parameter and the [JMESPath](http://jmespath.org/) query syntax to customize your output.

```bash
$ az vm list --query "[?provisioningState=='Succeeded'].{ name: name, os: storageProfile.osDisk.osType }"
Name                    Os
----------------------  -------
storevm                 Linux
bizlogic                Linux
demo32111vm             Windows
dcos-master-39DB807E-0  Linux
```

#### Exit codes

For scripting purposes, we output certain exit codes for differing scenarios.

|Exit Code   |Scenario   |
|---|---|
|0  |Command ran successfully.   |
|1   |Generic error; server returned bad status code, CLI validation failed, etc.   |
|2   |Parser error; check input to command line.   |
|3   |Missing ARM resource; used for existence check from `show` commands.   |

### Common scenarios and use Azure CLI effectively

Please check [Tips for using Azure CLI effectively](https://learn.microsoft.com/en-us/cli/azure/use-cli-effectively). It describes some common scenarios:

- [Output formatting (json, table, or tsv)](https://learn.microsoft.com/en-us/cli/azure/use-cli-effectively#output-formatting-json-table-or-tsv)
- [Pass values from one command to another](https://learn.microsoft.com/en-us/cli/azure/use-cli-effectively#pass-values-from-one-command-to-another)
- [Async operations](https://learn.microsoft.com/en-us/cli/azure/use-cli-effectively#async-operations)
- [Generic update arguments](https://learn.microsoft.com/en-us/cli/azure/use-cli-effectively#generic-update-arguments)
- [Generic resource commands - `az resource`](https://learn.microsoft.com/en-us/cli/azure/use-cli-effectively#generic-resource-commands---az-resource)
- [REST API command - `az rest`](https://learn.microsoft.com/en-us/cli/azure/use-cli-effectively#rest-api-command---az-rest)
- [Quoting issues](https://learn.microsoft.com/en-us/cli/azure/use-cli-effectively#quoting-issues)
- [Work behind a proxy](https://learn.microsoft.com/en-us/cli/azure/use-cli-effectively#work-behind-a-proxy)
- [Concurrent builds](https://learn.microsoft.com/en-us/cli/azure/use-cli-effectively#concurrent-builds)

### More samples and snippets

For more usage examples, take a look at our [GitHub samples repo](http://github.com/Azure/azure-cli-samples) or [https://learn.microsoft.com/cli/azure/overview](https://learn.microsoft.com/cli/azure/overview).

### Write and run commands in Visual Studio Code

With the [Azure CLI Tools](https://marketplace.visualstudio.com/items?itemName=ms-vscode.azurecli) Visual Studio Code extension, you can create `.azcli` files and use these features:
- IntelliSense for commands and their arguments.
- Snippets for commands, inserting required arguments automatically.
- Run the current command in the integrated terminal.
- Run the current command and show its output in a side-by-side editor.
- Show documentation on mouse hover.
- Display current subscription and defaults in status bar.
- To enable IntelliSense for other file types like `.ps1` or `.sh`, see [microsoft/vscode-azurecli#48](https://github.com/microsoft/vscode-azurecli/issues/48).

![Azure CLI Tools in Action](https://github.com/microsoft/vscode-azurecli/blob/main/images/in_action.gif?raw=true)

## Data Collection

The software may collect information about you and your use of the software and send it to Microsoft. Microsoft may use this information to provide services and improve our products and services. You may turn off the telemetry as described in the repository. There are also some features in the software that may enable you and Microsoft to collect data from users of your applications. If you use these features, you must comply with applicable law, including providing appropriate notices to users of your applications together with a copy of Microsoft's privacy statement. Our privacy statement is located at https://go.microsoft.com/fwlink/?LinkID=824704. You can learn more about data collection and use in the help documentation and our privacy statement. Your use of the software operates as your consent to these practices.

### Telemetry Configuration

Telemetry collection is on by default. To opt out, please run `az config set core.collect_telemetry=no` to turn it off.

## Reporting issues and feedback

If you encounter any bugs with the tool please file an issue in the [Issues](https://github.com/Azure/azure-cli/issues) section of our GitHub repo.

To provide feedback from the command line, try the `az feedback` command.

\[Microsoft internal] You may contact the developer team via azpycli@microsoft.com.

## Developer installation

### Docker

We maintain a Docker image preconfigured with the Azure CLI.
See our [Docker tags](https://mcr.microsoft.com/v2/azure-cli/tags/list) for available versions.

```bash
$ docker run -u $(id -u):$(id -g) -v ${HOME}:/home/az -e HOME=/home/az --rm -it mcr.microsoft.com/azure-cli:<version>
```

### Edge builds

If you want to get the latest build from the `dev` branch, you can use our "edge" builds.

You can download the latest builds by following the links below:

|      Package      | Link                                       |
|:-----------------:|:-------------------------------------------|
|        MSI        | https://aka.ms/InstallAzureCliWindowsEdge  |
| Homebrew Formula  | https://aka.ms/InstallAzureCliHomebrewEdge |
| Ubuntu Bionic Deb | https://aka.ms/InstallAzureCliBionicEdge   |
| Ubuntu Focal Deb  | https://aka.ms/InstallAzureCliFocalEdge    |
| Ubuntu Jammy Deb  | https://aka.ms/InstallAzureCliJammyEdge    |
|      RPM el8      | https://aka.ms/InstallAzureCliRpmEl8Edge   |

On Windows, you need to uninstall the official version before installing the edge build. (See https://github.com/Azure/azure-cli/issues/25607#issuecomment-1452855212)

You can easily install the latest Homebrew edge build with the following command:

```bash
# You need to uninstall the stable version with `brew uninstall azure-cli` first
curl --location --silent --output azure-cli.rb https://aka.ms/InstallAzureCliHomebrewEdge
brew install --build-from-source azure-cli.rb
```

You can install the edge build on Ubuntu Jammy with the following command:

```bash
curl --location --silent --output azure-cli_jammy.deb https://aka.ms/InstallAzureCliJammyEdge && dpkg -i azure-cli_jammy.deb
```

And install the edge build with rpm package on RHEL 8 or CentOS Stream 8:

```bash
dnf install -y $(curl --location --silent --output /dev/null --write-out %{url_effective} https://aka.ms/InstallAzureCliRpmEl8Edge)
```

Here's an example of installing edge builds with pip3 in a virtual environment. The `--upgrade-strategy=eager` option will install the edge builds of dependencies as well. 

```bash
$ python3 -m venv env
$ . env/bin/activate
$ pip3 install --pre azure-cli --extra-index-url https://azurecliprod.blob.core.windows.net/edge --upgrade-strategy=eager
```

To upgrade your current edge build pass the `--upgrade` option. The `--no-cache-dir` option is also recommended since
the feed is frequently updated.

```bash
$ pip3 install --upgrade --pre azure-cli --extra-index-url https://azurecliprod.blob.core.windows.net/edge --no-cache-dir --upgrade-strategy=eager
```

The edge build is generated for each PR merged to the `dev` branch as a part of the Azure DevOps Pipelines. 

### Get builds of arbitrary commit or PR

If you would like to get builds of arbitrary commit or PR, see:

[Try new features before release](doc/try_new_features_before_release.md)

## Developer setup

If you would like to setup a development environment and contribute to the CLI, see:

[Configuring Your Machine](https://github.com/Azure/azure-cli/blob/dev/doc/configuring_your_machine.md)

[Authoring Command Modules](https://github.com/Azure/azure-cli/tree/dev/doc/authoring_command_modules)

[Code Generation](https://github.com/Azure/aaz-dev-tools)

## Contribute code

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).

For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

If you would like to become an active contributor to this project please
follow the instructions provided in [Microsoft Open Source Guidelines](https://opensource.microsoft.com/collaborate).
