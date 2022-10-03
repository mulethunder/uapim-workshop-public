#######################################################################
# Provision Ubuntu VM to run Universal API Management hands-on Labs.
# @Author: Carlos Iturria (https://www.linkedin.com/in/citurria/)
#######################################################################
#################### Reading and validating passed parameters and mandatory files:    

if [ "$#" -ne 4 ]; then

    echo "**************************************** Error: "
    echo " Illegal number of parameters."
    echo " Order: [DEPLOY_API_CATALOG_CLI_BOOLEAN, DEPLOY_KUBERNETES_BOOLEAN, DEPLOY_KUBERNETES_SAMPLE_MICROSERVICES, DEPLOY_FLEX_GATEWAY_BOOLEAN]"
    echo " Example: ./bootstrap.sh true true true false"
    echo "****************************************"
    exit 1
    
fi

DEPLOY_API_CATALOG_CLI_BOOLEAN=$1
DEPLOY_KUBERNETES_BOOLEAN=$2
DEPLOY_KUBERNETES_SAMPLE_MICROSERVICES=$3
DEPLOY_FLEX_GATEWAY_BOOLEAN=$4
K8S_CLUSTER_NAME="my-k8s-cluster-1"

echo "****************************************"
echo "Reading instructions: DEPLOY_API_CATALOG_CLI_BOOLEAN=[${DEPLOY_API_CATALOG_CLI_BOOLEAN}], 
DEPLOY_KUBERNETES_BOOLEAN=[${DEPLOY_KUBERNETES_BOOLEAN}], 
DEPLOY_KUBERNETES_SAMPLE_MICROSERVICES=[${DEPLOY_KUBERNETES_SAMPLE_MICROSERVICES}], 
DEPLOY_FLEX_GATEWAY_BOOLEAN=[${DEPLOY_FLEX_GATEWAY_BOOLEAN}]" 
echo "****************************************"


echo "##########################################################################"
echo "###################### Updating packages ##############################"

sudo apt-get update

echo "####################################################################################"    
echo "################### Installing Git and supporting assets #######################"

sudo apt-get install git -y

## Bringing supporing microservices used for various components of the UAPIM workshop experience:
mkdir -p $HOME/uapim-assets/microservices && cd $HOME/uapim-assets/microservices
git clone https://github.com/mulethunder/payments



if [ "${DEPLOY_API_CATALOG_CLI_BOOLEAN}" == true ]; then

    echo "##########################################################################"
    echo " Deploying API Catalog CLI"
    echo "*******************************"
    
    echo "############### Installing NodeJS via Node Version Manager on an Ubuntu Machine ###############"
    cd -
    pwd
    chmod 755 ./nvm-install.sh
    ./nvm-install.sh

    source ~/.nvm/nvm.sh

    #nvm install v14.17.5
    #Switch: nvm use v14.10.0 
    nvm install 16
    nvm use 16

    sudo apt install npm -y

    echo "############################### Installing API-Catalog CLI #########################"

    # First satisfy API Catalog role in Anypoint Platform for user
    # Satisfy NVP -> Node version 16

    sudo npm install -g api-catalog-cli@latest

fi


if [ "${DEPLOY_KUBERNETES_BOOLEAN}" == true ]; then

    echo "#########################################################################################"
    echo " Deploying K3D Kubernetes distribution and all pre-requisistes e.g. Docker ##########"
    echo "*******************************"
    

    echo "############# Installing and configuring Docker for Dev #######################"

    sudo apt-get install docker.io -y
    sudo usermod -G docker ubuntu
    # sudo usermod -G docker vagrant
    docker --version


    # Install kubectl
    echo "#################### Install kubectl"
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl 

    # Install k3d - current release (as in: https://k3d.io/v5.0.0/#installation):
    echo "#################### Install k3d"
    curl -s https://raw.githubusercontent.com/rancher/k3d/main/install.sh | bash

   # Create a cluster calles mycluster with just a single server node:
    #k3d cluster create mycluster
    echo "#################### Create cluster"
    # sudo runuser -l vagrant -c "k3d cluster create cluster-fg-ic-conn-1 --k3s-arg '--disable=traefik@server:*' --port '80:80@server:*' --port '443:443@server:*' --wait --timeout '300s'"

    ## Testing creating cluster with port 8081 auto-mapping: (see: https://k3d.io/v5.4.1/usage/exposing_services/)
    ## INFO[0000] portmapping '8081:8081' targets the loadbalancer: defaulting to [servers:*:proxy agents:*:proxy]
    ## To open ports in k3d/docker land after cluster is created, see hack here: https://github.com/k3d-io/k3d/issues/89
    sudo runuser -l ubuntu -c "k3d cluster create ${K8S_CLUSTER_NAME} --k3s-arg '--disable=traefik@server:*' --port '8081:8081@loadbalancer' --port '8082:8082@loadbalancer' --port '8083:8083@loadbalancer' --wait --timeout '300s'"

    ## List clusters: 
    k3d cluster list
    ## Stop a cluster: k3d cluster stop my-cluster-1
    ## Restart cluster: k3d cluster start my-cluster-1

    ## Merge kube config and set context:
    #k3d kubeconfig merge ${K8S_CLUSTER_NAME} --kubeconfig-switch-context

    # Get cluster info
    echo "#################### Get cluster info"
    kubectl cluster-info
    kubectl get nodes
    kubectl get pods -A 

fi


if [ "${DEPLOY_KUBERNETES_SAMPLE_MICROSERVICES}" == true ]; then

    echo "###########################################################################################################"
    echo "#################### Installing supporing demo microservices in Kubernetes #########################"

    cd $HOME/uapim-assets/microservices/payments/deploy && ./deploy.sh

fi

if [ "${DEPLOY_FLEX_GATEWAY_BOOLEAN}" == true ]; then

    ####################
    ## Commenting all commands to allow installing Flex Gateway manually as part of the 
    ## UAPIM Workshop Hands-on Labs... 
    ## Leaving all commands for reference purposes...
    ####################

    echo "############################### Installing FlexGateway #########################"

    #####################
    ####### Flex Gateway can be installed in different ways:
    ####### - Option 1: Ubuntu OS service
    ####### - Option 2: Docker image
    ####### - OPtion 3: Ingress Controller via official helm chart (supports HPA)
    #####################

    ## Option 2: Running as a container:
    ## 2.1 Pull the Flex GW
    # docker pull mulesoft/flex-gateway:1.1.0
    ## Register:
    # docker run --entrypoint flexctl \
    #   -v "$(pwd)":/registration mulesoft/flex-gateway:1.1.0 \
    #   register --organization=5570eba4-1c6c-4651-b6bd-60913917293c \
    #   --token=443cfa09-4664-4668-8fbb-8e9bd38d7c3c \
    #   --output-directory=/registration \
    #   --connected=true \
    #   <gateway-name>
    #
    ## Start:
    # docker run --rm \
    #   -v "$(pwd)":/usr/local/share/mulesoft/flex-gateway/conf.d \
    #   -p 8081:8081 \
    #   mulesoft/flex-gateway:1.1.0

    ## Accessed the container: 
    # docker ps
    # docker exec -it [PID] bash


    ## Optoin 3: Running Flex Gateway as an Ingress Controller


    echo "################################################################################################"
    echo "################ Installing Flex Gateway as an Ingress Controller in Kubernetes #########################"


    ## Pull the image:
    # docker pull mulesoft/flex-gateway:1.1.0
    #
    ## Register the gateway:
    # docker run --entrypoint flexctl \
    # -v "$(pwd)":/registration mulesoft/flex-gateway:1.1.0 \
    # register --organization=5570eba4-1c6c-4651-b6bd-60913917293c \
    # --token=443cfa09-4664-4668-8fbb-8e9bd38d7c3c \
    # --output-directory=/registration \
    # --connected=true \
    # <gateway-name>
    #
    ## Install Helm:
    # Install helm:
    # echo "#################### Install helm"
    # curl https://baltocdn.com/helm/signing.asc | sudo apt-key add -
    # sudo apt install apt-transport-https --yes
    # echo "deb https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
    # sudo apt update
    # sudo apt install helm -y
    #
    ## Add Flex gateway Helm chart
    ## Remove any old Flex Gateway Helm repo:
    # helm repo remove flex-gateway
    # helm repo add flex-gateway https://flex-packages.anypoint.mulesoft.com/helm
    # helm repo up
    ## Show the helm repo:
    # helm repo ls
    #
    ## Deploy Flex-Gateway Helm Chart as Ingress Controller:
    # helm -n gateway upgrade -i --create-namespace --wait ingress flex-gateway/flex-gateway \
    # --set-file registration.content=registration.yaml \
    # --set replicaCount=1 \
    # --set autoscaling.enabled=false \
    # --set resources.limits.cpu=500m \
    # --set resources.limits.memory=512Mi \
    # --set service.enabled=true \
    # --set service.type=LoadBalancer \
    # --set service.http.enabled=true \
    # --set service.http.port=8081 \
    # --set service.https.enabled=false
    # # --set autoscaling.minReplicas=1 \
    # # --set autoscaling.maxReplicas=2 \
    # # --set autoscaling.targetCPUUtilizationPercentage=50 \
    # # --set autoscaling.targetMemoryUtilizationPercentage=70 \


    ## Show all Custom Resource Definitions:
    # kubectl get crd
    #     # apiinstances.gateway.mulesoft.com     2022-06-03T05:16:26Z
    #     # configurations.gateway.mulesoft.com   2022-06-03T05:16:26Z
    #     # extensions.gateway.mulesoft.com       2022-06-03T05:16:26Z
    #     # policybindings.gateway.mulesoft.com   2022-06-03T05:16:26Z
    #     # services.gateway.mulesoft.com         2022-06-03T05:16:26Z

    ## Verify the IC was created:
    # kubectl get apiinstances -n gateway
    #     # NAME            ADDRESS
    #     # ingress-https   http://0.0.0.0:443
    #     # ingress-http    http://0.0.0.0:80



    ## List all Services and ApiInstances created and forward the Ingress port to localhost
    # echo "#################### List all services and API-instances in -n gateway"
    # kubectl -n gateway get svc,apiinstances


    ## Forward the Ingress port to localhost and hit it, it should return a 404 response
    # echo "#################### Trying to access the ingress -> Should be 404 for now..."
    # kubectl --namespace gateway port-forward svc/ingress 8000:80 & 
    # curl -v http://localhost:8000/

fi

echo "################################################"
echo "#################################################################"
echo "################################################################################"


## Clean exit - no errors found... 
exit 0

###################################################################
#################################################################
############## Some troubleshooting commands for you:


## If you need to attach to the ingres pod and execute curl commands.
## For example, if you need to troubleshoot inside the ingress container
## to debug all the internal apiInstances that are deployed in the Flex Gateway:
kubectl exec --stdin --tty pod/ingress-XXXXXXXX -- /bin/bash
apt update && apt install net-tools -y && apt install curl -y
 curl localhost:9999/status/gateway/namespaces/default/apiInstances
 curl http://localhost:9999/api/v1/status/repository/apis/gateway.mulesoft.com/v1alpha1/ApiInstance?format=yaml


## If you need to tail the logs of the ingress pod:
kubectl logs pod/ingress-XXXXXXXX --tail 100 --follow 

## If you need to create a Busybox for testing inside the cluster:
kubectl run mycurlpod --image=curlimages/curl -i --tty -- sh
## Any subsequent use (once the busybox pod is running)
kubectl exec --stdin --tty mycurlpod -- sh
## Then, you can run curl commands to Kubernetes services, e.g.
curl http://payments-service.payments.svc.cluster.local:3000/payments
curl http://payments-service.payments.svc:3000/payments


#################################################################
###################################################################