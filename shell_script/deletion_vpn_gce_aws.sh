#!/bin/bash

# Author: Rodrigo Pompei <rodrigo.pompei@gmail.com>
# Version: 0.0.1
#
# Description
#    - This script will delete VPN connection created between GCP Subnet POD and AWS VPC POD involved on POD Migration process
#
#     Usage:
#          ./deletion_vpn_gce_aws.sh -s <source_pod> -sr <source_region> -sp <source_profile> -t <target_pod> -tr <target_region> -tp <target_profile> [-h | --help]
#          actions:
#                deletion VPN connection between GCP and AWS POD's VPC
#          options:
#                --source_pod: POD that was migrated in GCP
#                --source_region: POD's Region in GCP
#                --source_profile: POD's Profile account in GCP
#                --target_pod: POD destination in AWS
#                --target_region: POD's Region in AWS
#                --target_profile: POD's Profile account in AWS
#     Examples:
#          ./deletion_vpn_gce_aws.sh -s sym-sre3-prod-chat-glb-1 -sr asia-northeast1 -sp symphony-gce-prod -t sym-sre1-prod-chat-glb-1 -tr ap-southeast-1 -tp symphony-aws-customer1

usage () {
    cat <<HELP_USAGE

$0 <-s | --source_pod> <-sr | --source_region> <-sp | --source_profile> <-t | --target_pod> <-tr | --target_region> <-tp | --target_profile> [-h | --help]
    <-s  | --source_pod> Source pod_name  The name of the Source POD to delete the VPN.             Example: $0 abcd-na-prod-chat-glb-1
    <-sr | --source_region> Source pod_region  The region of the Source POD to delete the VPN.      Example: $0 asia-northeast1
    <-sp | --source_profile> Source pod_profile  The profile of the Source POD to delete the VPN.   Example: $0 symphony-gce-prod
    <-t  | --target_pod> Target pod_name  The name of the Target POD to delete the VPN.             Example: $0 abcd-na-prod-chat-glb-2
    <-tr | --target_region> Target pod_region  The region of the Target POD to delete the VPN.      Example: $0 ap-southeast-1
    <-tp | --target_profile> Target pod_profile  The profile of the Target POD to delete the VPN.   Example: $0 symphony-aws-customer1
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

 ### gcp route tunnel deletion
gcp_route_tunnel_deletion () {
    gcloud compute routes delete "${SOURCE_POD}-${TARGET_POD}-gw-route" --project ${SOURCE_PROFILE} --quiet
    if [ $? -eq 0 ];
    then
        echo "GCP Route Tunnel ${SOURCE_POD}-${TARGET_POD}-route was deleted"
    else
        echo "Not possible to delete the GCP Route Tunnel"
    fi    
 }

 ### gcp vpn tunnel deletion
gcp_vpn_tunnel_deletion () {
    gcloud compute vpn-tunnels delete "${SOURCE_POD}-${TARGET_POD}-gw-tunnel" --region ${SOURCE_REGION} --project ${SOURCE_PROFILE} --quiet
    if [ $? -eq 0 ];
    then
        echo "GCP VPN Tunnel ${SOURCE_POD}-${TARGET_POD}-gw-tunnel was deleted"
    else
        echo "Not possible to delete the GCP VPN Tunnel"
    fi
 }

 ### gcp forwarding rules deletion
gcp_fw_rules_deletion () {
    gcloud compute forwarding-rules delete "${SOURCE_POD}-${TARGET_POD}-gw-esp" --region ${SOURCE_REGION} --project ${SOURCE_PROFILE} --quiet
    if [ $? -eq 0 ];
    then
        echo "GCP ESP Forward Rule was deleted"
    else
        echo "Not possible to delete the GCP ESP Forward Rule"
    fi

    gcloud compute forwarding-rules delete "${SOURCE_POD}-${TARGET_POD}-gw-udp500" --region ${SOURCE_REGION} --project ${SOURCE_PROFILE} --quiet
    if [ $? -eq 0 ];
    then
        echo "GCP UDP 500 Forward Rule was deleted"
    else
        echo "Not possible to delete the GCP UDP 500 Forward Rule"
    fi

    gcloud compute forwarding-rules delete "${SOURCE_POD}-${TARGET_POD}-gw-udp4500" --region ${SOURCE_REGION} --project ${SOURCE_PROFILE} --quiet
    if [ $? -eq 0 ];
    then
        echo "GCP UDP 4500 Forward Rule was deleted"
    else
        echo "Not possible to delete the GCP UDP 4500 Forward Rule"
    fi
 }

 ### gcp vpn gateway deletion
gcp_vpn_gateway_deletion () {
    gcloud compute target-vpn-gateways delete "${SOURCE_POD}-${TARGET_POD}-gw" --region ${SOURCE_REGION} --project ${SOURCE_PROFILE} --quiet
    if [ $? -eq 0 ];
    then
        echo "GCP VPN Gateway was deleted ${SOURCE_POD}-${TARGET_POD}-gw"
    else
        echo "Not possible to delete the GCP VPN Gateway"
    fi  
 }

 ### gcp public ip deletion
gcp_ip_address_deletion () {
    gcloud compute addresses delete "${SOURCE_POD}-${TARGET_POD}" --region ${SOURCE_REGION} --project ${SOURCE_PROFILE} --quiet
    if [ $? -eq 0 ];
    then
        echo "GCP Public IP ${SOURCE_POD}-${TARGET_POD} was deleted"
    else
        echo "Not possible to delete the GCP Public IP"
    fi  
}

 ### aws vpc route deletion
aws_vpc_route_deletion () {
    GCP_SUBNET_CIDR=`gcloud compute networks subnets list --filter="${SOURCE_POD}" --format json |jq -r '.[].ipCidrRange'`
    if [ $? -eq 0 ];
    then
        echo "GCP Subnet CIDR is ${GCP_SUBNET_CIDR}"
    else
        echo "Not possible to get the GCP Subnet CIDR"
    fi

    VPC_ROUTE=`aws ec2 describe-route-tables --filter "Name=tag:Name,Values=*${TARGET_POD}*" --query 'RouteTables[*].RouteTableId' --region ${TARGET_REGION} --profile ${TARGET_PROFILE} --output text`
    if [ $? -eq 0 ];
    then
        echo "AWS VPC Route is ${VPC_ROUTE}"
    else
        echo "Not possible to get the AWS VPC Route"
    fi

    aws ec2 delete-route --route-table-id ${VPC_ROUTE} --destination-cidr-block ${GCP_SUBNET_CIDR} --region ${TARGET_REGION} --profile ${TARGET_PROFILE}
    if [ $? -eq 0 ];
    then
        echo "AWS VPC Route was deleted"
    else
        echo "Not possible to delete the AWS VPC Route"
    fi    
 }

 ### aws vpn route deletion
aws_vpn_connection_deletion () {
    VPN_ID=`aws ec2 describe-vpn-connections --filter "Name=route.destination-cidr-block,Values=${GCP_SUBNET_CIDR}" "Name=state,Values=available" --query 'VpnConnections[*].VpnConnectionId' --region ${TARGET_REGION} --profile ${TARGET_PROFILE} --output text`
    if [ $? -eq 0 ];
    then
        echo "AWS VPN_Id is ${VPN_ID}"
    else
        echo "Not possible to get the AWS VPN_Id"
    fi

    VPN_GW=`aws ec2 describe-vpn-connections --filter "Name=route.destination-cidr-block,Values=${GCP_SUBNET_CIDR}" "Name=state,Values=available" --query 'VpnConnections[*].VpnGatewayId' --region ${TARGET_REGION} --profile ${TARGET_PROFILE} --output text`
    if [ $? -eq 0 ];
    then
        echo "AWS VPN Gateway is ${VPN_GW}"
    else
        echo "Not possible to get the AWS VPN Gateway"
    fi

    CUSTOMER_GW=`aws ec2 describe-vpn-connections --filter "Name=route.destination-cidr-block,Values=${GCP_SUBNET_CIDR}" "Name=state,Values=available" --query 'VpnConnections[*].CustomerGatewayId' --region ${TARGET_REGION} --profile ${TARGET_PROFILE} --output text`
    if [ $? -eq 0 ];
    then
        echo "AWS VPN Customer Gateway is ${CUSTOMER_GW}"
    else
        echo "Not possible to get the AWS VPN Customer Gateway"
    fi

    aws ec2 delete-vpn-connection --vpn-connection-id ${VPN_ID} --region ${TARGET_REGION} --profile ${TARGET_PROFILE}
    if [ $? -eq 0 ];
    then
        echo "AWS VPN Connection ${VPN_ID} was deleted"
    else
        echo "Not possible to delete the AWS VPN Connection"
    fi    
 }

 ### aws virtual private gateway dettachment
aws_virtual_private_dett () {
    VPC_ID=`aws ec2 describe-vpcs --filter "Name=tag:Name,Values=*${TARGET_POD}*" --query 'Vpcs[*].VpcId' --region ${TARGET_REGION} --profile ${TARGET_PROFILE} --output text`
    if [ $? -eq 0 ];
    then
        echo "AWS VPC Id is ${VPC_ID}"
    else
        echo "Not possible to get the AWS VPC Id"
    fi

    aws ec2 detach-vpn-gateway --vpn-gateway-id ${VPN_GW} --vpc-id ${VPC_ID} --region ${TARGET_REGION} --profile ${TARGET_PROFILE}
    if [ $? -eq 0 ];
    then
        echo "AWS Virtual Private GW ${VPN_GW} is dettached from VPC ${VPC_ID}"
    else
        echo "Not possible to dettach the AWS Virtual GW from AWS VPC"
    fi    
}

 ### aws virtual private gw deletion
aws_virtual_private_gw_deletion () {
    aws ec2 delete-vpn-gateway --vpn-gateway-id ${VPN_GW} --profile ${TARGET_PROFILE} --region ${TARGET_REGION}
    if [ $? -eq 0 ];
    then
        echo "AWS Virtual Private GW $VGW was deleted"
    else
        echo "Not possible to delete the AWS Virtual Private"
    fi    
}

 ### aws customer gateway deletion
aws_customer_gw_deletion () {
    aws ec2 delete-customer-gateway --customer-gateway-id ${CUSTOMER_GW} --region ${TARGET_REGION} --profile ${TARGET_PROFILE}
    if [ $? -eq 0 ];
    then
        echo "AWS Customer GW ${CUSTOMER_GW} was deleted"
    else
        echo "Not possible to delete the AWS Customer GW"
    fi    
 }

main () {
    variable_declaration $@
    gcp_route_tunnel_deletion
    gcp_vpn_tunnel_deletion
    gcp_fw_rules_deletion
    gcp_vpn_gateway_deletion
    gcp_ip_address_deletion
    aws_vpc_route_deletion
    aws_vpn_connection_deletion
    aws_virtual_private_dett
    aws_virtual_private_gw_deletion
    aws_customer_gw_deletion
 }

main $@

