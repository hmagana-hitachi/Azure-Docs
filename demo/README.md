# Demo AKS Pet Store

## Architecture

![Logical Application Architecture Diagram](images/azure/aks-store-architecture.png)

The application has the following services: 

| Service | Description |
| --- | --- |
| `order-service` | This service is used for placing orders (Javascript) |
| `product-service` | This service is used to perform CRUD operations on products (Rust) |
| `store-front` | Web app for customers to place orders (Vue.js) |
| `rabbitmq` | RabbitMQ for an order queue |

- Create the YAML file for the AKS deployment. This file will define the deployment and service for the pet store application. ``aks-store-quickstart.yaml``
- ``kubectl apply -f aks-store-quickstart.yaml``
- ``kubectl get pods -o wide``
- Run the following command to get the external IP address of the service: 

>
``` powershell
 $endTime = (Get-Date).AddMinutes(5)
while ((Get-Date) -le $endTime) {
    $status = kubectl get pods -l app=store-front -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}'
    
    Write-Host $status
    
    if ($status -eq "True") {
        $env:IP_ADDRESS = kubectl get service store-front --output 'jsonpath={..status.loadBalancer.ingress[0].ip}'
        Write-Host "service IP address: $env:IP_ADDRESS"
        break
    } else {
        Start-Sleep -Seconds 10
    }
}
```

- For reverting the deployment, run the following command: ``kubectl delete -f aks-store-quickstart.yaml``





