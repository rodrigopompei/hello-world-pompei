#!/bin/bash

# Author: Rodrigo Pompei <rodrigo.pompei@gmail.com>
# Version: 0.0.1
#
# Description
#    - This script will create VPN connection between GCP Subnet POD and AWS VPC POD involved on POD Migration process
#
#     Usage:
#          ./setup_vpn_gce_aws.sh -s <source_pod> -sr <source_region> -sp <source_profile> -t <target_pod> -tr <target_region> -tp <target_profile> [-h | --help]
#          actions:
#                create VPN connection between GCP and AWS POD's VPC
#          options:
#                --source_pod: POD that will be migrated in GCP
#                --source_region: POD's Region in GCP
#                --source_profile: POD's Profile account in GCP
#                --target_pod: POD destination in AWS
#                --target_region: POD's Region in AWS
#                --target_profile: POD's Profile account in AWS
#     Examples:
#          ./setup_vpn_gce_aws.sh -s sym-sre3-prod-chat-glb-1 -sr asia-northeast1 -sp symphony-gce-prod -t sym-sre1-prod-chat-glb-1 -tr ap-southeast-1 -tp symphony-aws-customer1

usage () {
    cat <<HELP_USAGE

$0 <-s | --source_pod> <-sr | --source_region> <-sp | --source_profile> <-t | --target_pod> <-tr | --target_region> <-tp | --target_profile> [-h | --help]
    <-s  | --source_pod> Source pod_name  The name of the Source POD to create the VPN.             Example: $0 abcd-na-prod-chat-glb-1
    <-sr | --source_region> Source pod_region  The region of the Source POD to create the VPN.      Example: $0 asia-northeast1
    <-sp | --source_profile> Source pod_profile  The profile of the Source POD to create the VPN.   Example: $0 symphony-gce-prod
    <-t  | --target_pod> Target pod_name  The name of the Target POD to create the VPN.             Example: $0 abcd-na-prod-chat-glb-2
    <-tr | --target_region> Target pod_region  The region of the Target POD to create the VPN.      Example: $0 ap-southeast-1
    <-tp | --target_profile> Target pod_profile  The profile of the Target POD to create the VPN.   Example: $0 symphony-aws-customer1
    [-h  | --help]  Display help.

HELP_USAGE
}

### variables definition
variable_declaration () {

### extract options and their arguments into variables.
while true; do
  case "$1" in
    -h | --help)
    usage
    exit 1
    ;;
    -s | --source_pod )
    SOURCE_POD="$2";
    shift 2
    ;;
    -sr | --source_region )
    SOURCE_REGION="$2";
    shift 2
    ;;
    -sp | --source_profile )
    SOURCE_PROFILE="$2";
    shift 2
    ;;
    -t | --target_pod )
    TARGET_POD="$2";
    shift 2
    ;;
    -tr | --target_region )
    TARGET_REGION="$2";
    shift 2
    ;;
    -tp | --target_profile )
    TARGET_PROFILE="$2";
    shift 2  
    ;;
    -- )
    break
    ;;
    *  )
    break
    ;; 
  esac
done
    if [[ -z "${SOURCE_POD}" ]] || [[ -z "${SOURCE_REGION}" ]] || [[ -z "${SOURCE_PROFILE}" ]] || [[ -z "${TARGET_POD}" ]] || [[ -z "${TARGET_REGION}" ]] || [[ -z "${TARGET_PROFILE}" ]]
    then
        usage
        exit 1
    fi
}

 ### gcp public ip generation
gcp_ip_address () {
    
    gcloud compute addresses create ${SOURCE_POD}-${TARGET_POD} --region ${SOURCE_REGION} --project ${SOURCE_PROFILE}
    GCP_IP=`gcloud compute addresses list --filter="${SOURCE_POD}-${TARGET_POD}" --project ${SOURCE_PROFILE} --format json |jq -r '.[].address'`
    if [ $? -eq 0 ];
    then
        echo "GCP Public IP is $GCP_IP"
    else
        echo "Not possible to get the GCP Public IP"
    fi
}

 ### aws virtual private gw creation
aws_virtual_private_gw () {
    
    VGW=`aws ec2 create-vpn-gateway --type ipsec.1 --profile ${TARGET_PROFILE} --region ${TARGET_REGION} --output json |jq -r '.[].VpnGatewayId'`
    if [ $? -eq 0 ];
    then
        echo "AWS Virtual Private GW is $VGW"
    else
        echo "Not possible to create the Virtual Private GW"
    fi
}

 ### aws virtual private gateway attachment
aws_virtual_private_att () {
    
    VPC_ID=`aws ec2 describe-vpcs --filter "Name=tag:Name,Values=*${TARGET_POD}*" --query 'Vpcs[*].VpcId' --region ${TARGET_REGION} --profile ${TARGET_PROFILE} --output text`
    if [ $? -eq 0 ];
    then
        echo "AWS VPC_Id is $VPC_ID"
    else
        echo "Not possible to get the AWS VPC_Id"
    fi

    VGW_AT=`aws ec2 attach-vpn-gateway --vpn-gateway-id ${VGW} --vpc-id ${VPC_ID} --region ${TARGET_REGION} --profile ${TARGET_PROFILE} --output text`
    if [ $? -eq 0 ];
    then
        echo "AWS Virtual Private GW is attached with VPC"
    else
        echo "Not possible to attach the AWS Virtual Private GW with VPC_Id"
    fi
}

 ### aws customer gateway creation
aws_customer_gw_creation () {
    
    CUSTOMER_GW=`aws ec2 create-customer-gateway --type ipsec.1 --public-ip ${GCP_IP} --bgp-asn 65000 --region ${TARGET_REGION} --profile ${TARGET_PROFILE} --output json |jq -r '.[].CustomerGatewayId'`
    if [ $? -eq 0 ];
    then
        echo "AWS Customer GW is ${CUSTOMER_GW}"
    else
        echo "Not possible to create the AWS Customer GW"
    fi    
 }

 ### aws vpn connection creation
aws_vpn_connection_creation () {
    
    VPN_CONNECTION=`aws ec2 create-vpn-connection --type ipsec.1 --customer-gateway-id ${CUSTOMER_GW} --vpn-gateway-id ${VGW} --options "{\"StaticRoutesOnly\":true}" --region ${TARGET_REGION} --profile ${TARGET_PROFILE} --output json |jq -r '.[].VpnConnectionId'`
    if [ $? -eq 0 ];
    then
        echo "AWS VPN Connection is ${VPN_CONNECTION}"
    else
        echo "Not possible to create the AWS VPN Connection"
    fi

    AWS_OUT_IP=`aws ec2 describe-vpn-connections --vpn-connection-ids ${VPN_CONNECTION} --query 'VpnConnections[*].VgwTelemetry' --region ${TARGET_REGION} --profile ${TARGET_PROFILE} --output text |awk 'NR==1{print $3}'`
    if [ $? -eq 0 ];
    then
        echo "AWS Output IP address is ${AWS_OUT_IP}"
    else
        echo "Not possible to get the AWS Output IP"
    fi

    AWS_OUT_SHARE=`aws ec2 describe-vpn-connections --vpn-connection-ids ${VPN_CONNECTION} --query 'VpnConnections[*].CustomerGatewayConfiguration' --region ${TARGET_REGION} --profile ${TARGET_PROFILE} --output text > /tmp/output.xml && xmllint --xpath "string(//pre_shared_key)" /tmp/output.xml`
    if [ $? -eq 0 ];
    then
        echo "AWS Pre-Shared Key is ${AWS_OUT_SHARE}"
    else
        echo "Not possible to get the AWS Pre-Shared Key"
    fi
 }

 ### aws vpn route creation
aws_vpn_route_creation () {
    
    GCP_SUBNET_CIDR=`gcloud compute networks subnets list --filter="${SOURCE_POD}" --project ${SOURCE_PROFILE} --format json |jq -r '.[].ipCidrRange'`
    if [ $? -eq 0 ];
    then
        echo "GCP Subnet CIDR is ${GCP_SUBNET_CIDR}"
    else
        echo "Not possible to get the GCP Subnet CIDR"
    fi

    VPN_ROUTE=`aws ec2 create-vpn-connection-route --vpn-connection-id ${VPN_CONNECTION} --destination-cidr-block ${GCP_SUBNET_CIDR} --region ${TARGET_REGION} --profile ${TARGET_PROFILE}`
    if [ $? -eq 0 ];
    then
        echo "AWS VPN Route was created"
    else
        echo "Not possible to create the AWS VPN Route"
    fi    
 }

 ### aws vpc route creation
aws_vpc_route_creation () {
  TIMEOUT=0  
  until [[ "$AWS_GW_READY" == "attached" ]] || [[ "$TIMEOUT" == "180" ]]; do
    AWS_GW_READY=$(aws ec2 describe-vpn-gateways --vpn-gateway-id ${VGW} --query 'VpnGateways[*].VpcAttachments' --region ${TARGET_REGION} --profile ${TARGET_PROFILE} --output text |awk '{print $1}')
    TIMEOUT=$(($TIMEOUT + 3))
    echo "AWS Gateway is not attached yet"
  done
    VPC_ROUTE=`aws ec2 describe-route-tables --filter "Name=tag:Name,Values=*${TARGET_POD}*" --query 'RouteTables[*].RouteTableId' --region ${TARGET_REGION} --profile ${TARGET_PROFILE} --output text`
    if [ $? -eq 0 ];
    then
        echo "AWS VPC Route is ${VPC_ROUTE}"
    else
        echo "Not possible to get the AWS VPC Route"
    fi    

    VPC_ROUTE_CREATE=`aws ec2 create-route --route-table-id ${VPC_ROUTE} --destination-cidr-block ${GCP_SUBNET_CIDR} --gateway-id ${VGW} --region ${TARGET_REGION} --profile ${TARGET_PROFILE}`
    if [ $? -eq 0 ];
    then
        echo "AWS VPC Route was created"
    else
        echo "Not possible to create the AWS VPC Route Created"
    fi    
 }

 ### gcp vpn gateway creation
gcp_vpn_gateway_creation () {
    
    GCP_VPN_GATEWAY=`gcloud compute target-vpn-gateways create "${SOURCE_POD}-${TARGET_POD}-gw" --network "default" --region ${SOURCE_REGION} --project ${SOURCE_PROFILE} --format json |jq -r '.[].name'`
    if [ $? -eq 0 ];
    then
        echo "GCP VPN Gateway is ${GCP_VPN_GATEWAY}"
    else
        echo "Not possible to create the GCP VPN Gateway"
    fi    
 }

 ### gcp forwarding rules creation
gcp_fw_rules_creation () {
    
    GCP_ESP_RULE=`gcloud compute forwarding-rules create "${GCP_VPN_GATEWAY}-esp" --address "${GCP_IP}" --ip-protocol "ESP" --target-vpn-gateway "${GCP_VPN_GATEWAY}" --region ${SOURCE_REGION} --project ${SOURCE_PROFILE}`
    if [ $? -eq 0 ];
    then
        echo "GCP ESP Firewall Rule was created"
    else
        echo "Not possible to create the GCP ESP Firewall Rule"
    fi    

    GCP_UDP500_RULE=`gcloud compute forwarding-rules create "${GCP_VPN_GATEWAY}-udp500" --address "${GCP_IP}" --ip-protocol "UDP" --ports "500" --target-vpn-gateway "${GCP_VPN_GATEWAY}" --region ${SOURCE_REGION} --project ${SOURCE_PROFILE}`
    if [ $? -eq 0 ];
    then
        echo "GCP UDP500 Firewall Rule was created"
    else
        echo "Not possible to create the GCP UDP500 Firewall Rule"
    fi

    GCP_UDP4500_RULE=`gcloud compute forwarding-rules create "${GCP_VPN_GATEWAY}-udp4500" --address "${GCP_IP}" --ip-protocol "UDP" --ports "4500" --target-vpn-gateway "${GCP_VPN_GATEWAY}" --region ${SOURCE_REGION} --project ${SOURCE_PROFILE}`
    if [ $? -eq 0 ];
    then
        echo "GCP UDP4500 Firewall Rule was created"
    else
        echo "Not possible to create the GCP UDP4500 Firewall Rule"
    fi
 }

 ### gcp vpn tunnel creation
gcp_vpn_tunnel_creation () {
    
    AWS_VPC_CIDR=`aws ec2 describe-vpcs --filter "Name=tag:Name,Values=*${TARGET_POD}*" --query 'Vpcs[*].CidrBlock' --region ${TARGET_REGION} --profile ${TARGET_PROFILE} --output text`
    if [ $? -eq 0 ];
    then
        echo "AWS VPC CIDR is ${AWS_VPC_CIDR}"
    else
        echo "Not possible to get the AWS VPC CIDR"
    fi

    GCP_VPN_TUNNEL=`gcloud compute vpn-tunnels create "${GCP_VPN_GATEWAY}-tunnel" --ike-version "1" --target-vpn-gateway "${GCP_VPN_GATEWAY}" --peer-address "${AWS_OUT_IP}" --shared-secret "${AWS_OUT_SHARE}" --local-traffic-selector "${GCP_SUBNET_CIDR}" --remote-traffic-selector "${AWS_VPC_CIDR}" --region ${SOURCE_REGION} --project ${SOURCE_PROFILE} --format json |jq -r '.[].name'`
    if [ $? -eq 0 ];
    then
        echo "GCP VPN Tunnel is ${GCP_VPN_TUNNEL}"
    else
        echo "Not possible to create the GCP VPN Tunnel"
    fi    
 }

 ### gcp route tunnel creation
gcp_route_tunnel_creation () {
    
    GCP_ROUTE_TUNNEL=`gcloud compute routes create "${GCP_VPN_GATEWAY}-route" --destination-range "${AWS_VPC_CIDR}" --next-hop-vpn-tunnel "${GCP_VPN_TUNNEL}" --next-hop-vpn-tunnel-region "${SOURCE_REGION}" --project ${SOURCE_PROFILE} --format json |jq -r '.[].name'`
    if [ $? -eq 0 ];
    then
        echo "GCP Route Tunnel is ${GCP_ROUTE_TUNNEL}"
    else
        echo "Not possible to create the GCP Route Tunnel"
    fi
 }

main () {
   variable_declaration $@
   gcp_ip_address
   aws_virtual_private_gw
   aws_virtual_private_att
   aws_customer_gw_creation
   aws_vpn_connection_creation
   aws_vpn_route_creation
   aws_vpc_route_creation
   gcp_vpn_gateway_creation
   gcp_fw_rules_creation
   gcp_vpn_tunnel_creation
   gcp_route_tunnel_creation
 }

main $@

