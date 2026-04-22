<#
    AKS template using:
    - Azure CNI Overlay
    - Managed Identity only
    - No Service Principal / No Secret
    - Separate identities with least-privilege scoping
    - Public API Server with authorized IP ranges
    - AKS Run Command disabled

    Required permissions:
    Kubelet Identity:
    - Subnet scope: Network Contributor (for Azure CNI)
    - ACR scope: AcrPull (for image pulls)

    Notes:
    - This template deploys a PUBLIC AKS cluster with restricted API access.
    - API server is publicly accessible but restricted to specified IP ranges and RBAC/EntraID access.
    - No private DNS zone required (DNS resolves publicly).
    - Uses separate user-assigned identities for control plane and kubelet.
    - Each identity has only the minimum required permissions (least-privilege).
    - Perfect for teams with fixed office IPs or VPN endpoints.
    - Update the variables before running.
    - AKS helper, to decide or configure with advanced settings: https://azure.github.io/AKS-Construction/
#>

## Azure Container Registry (ACR)
$RG_NAME_ACR = "rg_testing_acr"
$ACR_NAME = "acr_testing"
$SUB_NAME_ACR = "subs_testing_acr"
$SUB_ID_ACR = "sub_id_testing_acr"

## Azure Kubernetes Services (AKS)
$SUB_NAME_AKS = "subscription_name"
$RG_NAME_AKS = "rg_testing"
$SUB_ID_AKS = "subscription_id"
$AKS_NAME = "aks-cni-publicAPI"
$LOCATION = "location"
$KUBERNETES_VERSION = "1.34.3" # Check available versions with: az aks get-versions -l $LOCATION -o table
$SERVICE_CIDR = "10.0.0.0/16"
$DNS_SERVICE_IP = "10.0.0.10"
$POD_CIDR = "10.244.0.0/16"

## API Server Authorized IP Ranges (restrict access to your IPs)
## Add your office public IP, VPN gateway IP, or other trusted IPs
## Format: space-separated list of CIDR blocks, e.g., "203.0.113.0/24 198.51.100.0/24"
## Leave empty to allow all IPs (NOT RECOMMENDED for production)
$API_SERVER_AUTHORIZED_IP_RANGES = "x.x.x.x"  # CHANGE THIS to restrict access curl -s ifconfig.me to get your public IP

## Node Pools Variables
$NODE_SYSTEM = 1
$MIN_COUNT_SYSTEM = 1
$MAX_COUNT_SYSTEM = 1
$NODE_USER = 1
$MIN_COUNT_USER = 1
$MAX_COUNT_USER = 1
$VM_SIZE_SYSTEM = "Standard_D2s_v6" #Options for general purpose: Standard_D2s_v6, Standard_D4s_v6, Standard_D8s_v6. Pricing list here Link: https://azure.microsoft.com/en-us/pricing/details/virtual-machines/linux/#pricing.
$VM_SIZE_USER = "Standard_D2s_v6" #Options for general purpose: Standard_D2s_v6, Standard_D4s_v6, Standard_D8s_v6. Pricing list here Link: https://azure.microsoft.com/en-us/pricing/details/virtual-machines/linux/#pricing.

## Azure VNET (AKS dedicated)
$RG_NAME_VNET_AKS = "rg_testing"
$SUB_NAME_VNET_AKS = "subscription_name"
$SUB_ID_VNET_AKS = "subscription_id"
$VNET_NAME_AKS = "vnet_name"
$SNET_NAME_AKS = "snet_name"

## Roles for the managed identity
$ROLE_SUBNET = "Network Contributor"
$ROLE_ACR_PULL = "AcrPull"

## End Variables

## Select output path and start transcript
Add-Type -AssemblyName System.Windows.Forms
$FolderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
$FolderBrowser.Description = "Select the folder where the deployment log (TXT) will be saved"
$FolderBrowser.RootFolder = [System.Environment+SpecialFolder]::MyComputer
$FolderBrowser.SelectedPath = [System.Environment]::GetFolderPath("Desktop")
if ($FolderBrowser.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
    Write-Host "No folder selected. Exiting." -ForegroundColor Red
    exit 1
}
$Timestamp = Get-Date -Format "dd-MM-yyyy_HH-mm-ss"
$TranscriptPath = Join-Path $FolderBrowser.SelectedPath "AKS-Deployment-$AKS_NAME-$Timestamp.txt"
Start-Transcript -Path $TranscriptPath -Append
Write-Host "Transcript started. Output will be saved to: $TranscriptPath" -ForegroundColor Cyan

Write-Host "Starting AKS deployment with Azure CNI Overlay, Public API Server, and Managed Identity..." -ForegroundColor Cyan
Write-Host "WARNING: API server is publicly accessible. Ensure authorized-ip-ranges is configured." -ForegroundColor Yellow
Write-Host "AKS Run Command (command invoke) will be disabled." -ForegroundColor Yellow

## Get subnet ID
az account set --subscription $SUB_ID_VNET_AKS
if ($LASTEXITCODE -ne 0) {
    throw "Could not change to VNET subscription: $SUB_ID_VNET_AKS"
}

$SUBNET_ID = az network vnet subnet show `
    --resource-group $RG_NAME_VNET_AKS `
    --vnet-name $VNET_NAME_AKS `
    --name $SNET_NAME_AKS `
    --query id -o tsv

if (-not $SUBNET_ID) {
    throw "Could not get subnet id for $SNET_NAME_AKS in $VNET_NAME_AKS"
}

Write-Host "Subnet ID: $SUBNET_ID" -ForegroundColor Green

## Create user-assigned managed identity for AKS control plane
az account set --subscription $SUB_ID_AKS
if ($LASTEXITCODE -ne 0) {
    throw "Could not change to AKS subscription: $SUB_ID_AKS"
}

$CONTROL_PLANE_IDENTITY_NAME = "mi-$AKS_NAME-cp"
az identity create --resource-group $RG_NAME_AKS --name $CONTROL_PLANE_IDENTITY_NAME
if ($LASTEXITCODE -ne 0) {
    throw "Could not create control plane managed identity $CONTROL_PLANE_IDENTITY_NAME"
}

## Create user-assigned managed identity for kubelet
$KUBELET_IDENTITY_NAME = "mi-$AKS_NAME-kubelet"
az identity create --resource-group $RG_NAME_AKS --name $KUBELET_IDENTITY_NAME
if ($LASTEXITCODE -ne 0) {
    throw "Could not create kubelet managed identity $KUBELET_IDENTITY_NAME"
}

Write-Host "Waiting 60 seconds for identity propagation..." -ForegroundColor Yellow
Start-Sleep 60

## Get control plane identity details
$CONTROL_PLANE_IDENTITY_ID = az identity show --name $CONTROL_PLANE_IDENTITY_NAME --resource-group $RG_NAME_AKS --query id -o tsv
$CONTROL_PLANE_IDENTITY_PRINCIPAL_ID = az identity show --name $CONTROL_PLANE_IDENTITY_NAME --resource-group $RG_NAME_AKS --query principalId -o tsv
$CONTROL_PLANE_IDENTITY_CLIENT_ID = az identity show --name $CONTROL_PLANE_IDENTITY_NAME --resource-group $RG_NAME_AKS --query clientId -o tsv

if (-not $CONTROL_PLANE_IDENTITY_ID -or -not $CONTROL_PLANE_IDENTITY_PRINCIPAL_ID -or -not $CONTROL_PLANE_IDENTITY_CLIENT_ID) {
    throw "Could not get control plane managed identity details for $CONTROL_PLANE_IDENTITY_NAME"
}

Write-Host "Control Plane Identity ID: $CONTROL_PLANE_IDENTITY_ID" -ForegroundColor Green
Write-Host "Control Plane Identity Principal ID: $CONTROL_PLANE_IDENTITY_PRINCIPAL_ID" -ForegroundColor Green
Write-Host "Control Plane Identity Client ID: $CONTROL_PLANE_IDENTITY_CLIENT_ID" -ForegroundColor Green

## Get kubelet identity details
$KUBELET_IDENTITY_ID = az identity show --name $KUBELET_IDENTITY_NAME --resource-group $RG_NAME_AKS --query id -o tsv
$KUBELET_IDENTITY_PRINCIPAL_ID = az identity show --name $KUBELET_IDENTITY_NAME --resource-group $RG_NAME_AKS --query principalId -o tsv
$KUBELET_IDENTITY_CLIENT_ID = az identity show --name $KUBELET_IDENTITY_NAME --resource-group $RG_NAME_AKS --query clientId -o tsv

if (-not $KUBELET_IDENTITY_ID -or -not $KUBELET_IDENTITY_PRINCIPAL_ID -or -not $KUBELET_IDENTITY_CLIENT_ID) {
    throw "Could not get kubelet managed identity details for $KUBELET_IDENTITY_NAME"
}

Write-Host "Kubelet Identity ID: $KUBELET_IDENTITY_ID" -ForegroundColor Green
Write-Host "Kubelet Identity Principal ID: $KUBELET_IDENTITY_PRINCIPAL_ID" -ForegroundColor Green
Write-Host "Kubelet Identity Client ID: $KUBELET_IDENTITY_CLIENT_ID" -ForegroundColor Green

## Assign role to kubelet identity on subnet for Azure CNI Overlay
az role assignment create `
    --assignee-object-id $KUBELET_IDENTITY_PRINCIPAL_ID `
    --assignee-principal-type ServicePrincipal `
    --role $ROLE_SUBNET `
    --scope $SUBNET_ID

Write-Host "Assigned Network Contributor role to kubelet identity on subnet" -ForegroundColor Yellow

## Create AKS using Azure CNI Overlay with public API server and separate identities
az aks create `
    --location $LOCATION `
    --resource-group $RG_NAME_AKS `
    --name $AKS_NAME `
    --kubernetes-version $KUBERNETES_VERSION `
    --nodepool-name systempool `
    --node-count $NODE_SYSTEM `
    --enable-cluster-autoscaler `
    --min-count $MIN_COUNT_SYSTEM `
    --max-count $MAX_COUNT_SYSTEM `
    --node-vm-size $VM_SIZE_SYSTEM `
    --network-plugin azure `
    --network-plugin-mode overlay `
    --pod-cidr $POD_CIDR `
    --service-cidr $SERVICE_CIDR `
    --dns-service-ip $DNS_SERVICE_IP `
    --vnet-subnet-id $SUBNET_ID `
    --enable-managed-identity `
    --assign-identity $CONTROL_PLANE_IDENTITY_ID `
    --assign-kubelet-identity $KUBELET_IDENTITY_ID `
    --generate-ssh-keys `
    --api-server-authorized-ip-ranges $API_SERVER_AUTHORIZED_IP_RANGES `
    --load-balancer-sku standard `
    --enable-aad `
    --enable-azure-rbac `
    --enable-image-cleaner `
    --disable-run-command `
    --disable-local-accounts ` # Disable local accounts for better security (only AAD auth)

if ($LASTEXITCODE -ne 0) {
    throw "AKS creation failed"
}

Write-Host "AKS cluster created successfully" -ForegroundColor Green

## Apply taint to system node pool
az aks nodepool update `
    --resource-group $RG_NAME_AKS `
    --cluster-name $AKS_NAME `
    --name systempool `
    --node-taints CriticalAddonsOnly=true:NoSchedule

if ($LASTEXITCODE -ne 0) {
    throw "Failed to apply node taint to systempool"
}

Write-Host "Applied node taint to systempool: CriticalAddonsOnly=true:NoSchedule" -ForegroundColor Yellow

## Create user node pool
az aks nodepool add `
    --resource-group $RG_NAME_AKS `
    --cluster-name $AKS_NAME `
    --name userpool `
    --node-count $NODE_USER `
    --vnet-subnet-id $SUBNET_ID `
    --node-vm-size $VM_SIZE_USER `
    --enable-cluster-autoscaler `
    --min-count $MIN_COUNT_USER `
    --max-count $MAX_COUNT_USER `
    --mode User

if ($LASTEXITCODE -ne 0) {
    throw "User node pool creation failed"
}

Write-Host "User node pool created successfully" -ForegroundColor Green

## Assign ACR pull permission to kubelet identity
az account set --subscription $SUB_ID_ACR
if ($LASTEXITCODE -ne 0) {
    throw "Could not change to ACR subscription: $SUB_ID_ACR"
}

$ACR_ID = az acr show --name $ACR_NAME --resource-group $RG_NAME_ACR --query id --output tsv
if (-not $ACR_ID) {
    throw "Could not get ACR id for $ACR_NAME"
}

az role assignment create `
    --assignee-object-id $KUBELET_IDENTITY_PRINCIPAL_ID `
    --assignee-principal-type ServicePrincipal `
    --role $ROLE_ACR_PULL `
    --scope $ACR_ID

if ($LASTEXITCODE -ne 0) {
    throw "Could not assign AcrPull role to kubelet identity"
}

Write-Host "Assigned AcrPull role to kubelet identity on ACR" -ForegroundColor Yellow

## Optional features
# az aks update -n $AKS_NAME -g $RG_NAME_AKS --enable-oidc-issuer
# az aks update -n $AKS_NAME -g $RG_NAME_AKS --enable-addons azure-keyvault-secrets-provider --enable-workload-identity
# az aks update -n $AKS_NAME -g $RG_NAME_AKS --enable-workload-identity

## Get cluster credentials for kubectl
az account set --subscription $SUB_ID_AKS
az aks get-credentials --resource-group $RG_NAME_AKS --name $AKS_NAME --admin

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "************************************* AKS deployment completed successfully. *************************************" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Cluster Name: $AKS_NAME" -ForegroundColor Green
Write-Host "Resource Group: $RG_NAME_AKS" -ForegroundColor Green
Write-Host "Location: $LOCATION" -ForegroundColor Green
Write-Host "Control Plane Identity: $CONTROL_PLANE_IDENTITY_NAME" -ForegroundColor Green
Write-Host "Kubelet Identity: $KUBELET_IDENTITY_NAME" -ForegroundColor Green
Write-Host "Network Plugin: Azure CNI Overlay" -ForegroundColor Green
Write-Host "API Server: PUBLIC (restricted by IP ranges)" -ForegroundColor Yellow
Write-Host "Command Invoke / Run Command: DISABLED" -ForegroundColor Yellow
Write-Host "Authorized IP Ranges: $API_SERVER_AUTHORIZED_IP_RANGES" -ForegroundColor Yellow
Write-Host "Pod CIDR: $POD_CIDR" -ForegroundColor Green
Write-Host "Service CIDR: $SERVICE_CIDR" -ForegroundColor Green
Write-Host "`nIdentity Roles Summary:" -ForegroundColor Cyan
Write-Host "  Control Plane: Managed credentials only (no explicit role needed)" -ForegroundColor Yellow
Write-Host "  Kubelet: Network Contributor (subnet) + AcrPull (ACR)" -ForegroundColor Yellow
Write-Host "`nTo update authorized IP ranges:" -ForegroundColor Cyan
Write-Host "  az aks update -g $RG_NAME_AKS -n $AKS_NAME --api-server-authorized-ip-ranges <IP_RANGES>" -ForegroundColor Yellow
Write-Host "`nTo allow all IPs (NOT RECOMMENDED):" -ForegroundColor Cyan
Write-Host "  az aks update -g $RG_NAME_AKS -n $AKS_NAME --api-server-authorized-ip-ranges '0.0.0.0/0'" -ForegroundColor Yellow
Write-Host "`nIMPORTANT: Update '\$API_SERVER_AUTHORIZED_IP_RANGES' in this script at the top!`n" -ForegroundColor Red
Write-Host "`nIMPORTANT: Update-Assign cluster admin AKS built-in roles to the desired user!!`n" -ForegroundColor Red
Write-Host "`nROLES:`n" -ForegroundColor Yellow
Write-Host "Azure Kubernetes Service Cluster Admin Role" -ForegroundColor Yellow
write-Host "Azure Kubernetes Service RBAC Cluster Admin" -ForegroundColor Yellow

## Stop transcript and notify user
Stop-Transcript
Write-Host "`nDeployment log saved to: $TranscriptPath" -ForegroundColor Cyan
