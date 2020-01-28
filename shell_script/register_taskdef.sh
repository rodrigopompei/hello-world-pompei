$ cat ./../../bin/register_taskdef.sh 
#!/bin/bash

#set -e
#set -x
VERSION=v01

# Defaults
REGION=us-east-1
MEMORY=500
JVM_MEM=300

DIR=`dirname $0`
source $DIR/arguments.sh


# Enforce manditory
if [ "$ENV" = "" ]; then print_usage "Environment is required"; fi
if [ "$SERVICE" = "" ]; then print_usage "Service is required"; fi
if [ "$IMAGE" = "" ]; then print_usage "Service docker image is required"; fi
if [ "$POD_ID" = "" ]; then print_usage "Persistence pod id is required"; fi
if [ "$CONSUL_TOKEN" = "" ]; then print_usage "Consul Token is required"; fi

case "$ENV" in
    dev)
        case "$REGION" in
            us-east-1)
                SREGION=ause1
                ;;
            *)
                print_usage "Unsupported Region: $REGION"
                ;;
        esac
        AWS_PROFILE=${ENV}-infra
        ;;
    qa)
        case "$REGION" in
            us-east-1)
                SREGION=ause1
                ;;
            *)
                print_usage "Unsupported Region: $REGION"
                ;;
        esac
        AWS_PROFILE=${ENV}-infra
        ;;
    stage)
        case "$REGION" in
            us-east-1)
                SREGION=ause1
                ;;
            *)
                print_usage "Unsupported Region: $REGION"
                ;;
        esac
        AWS_PROFILE=uat-infra
        ;;
    uat)
        case "$REGION" in
            us-east-1)
                SREGION=ause1
                ;;
            *)
                print_usage "Unsupported Region: $REGION"
                ;;
        esac
        AWS_PROFILE=${ENV}-infra
        ;;
    prod)
        case "$REGION" in
            us-east-1)
                SREGION=ause1
                ;;
            *)
                print_usage "Unsupported Region: $REGION"
                ;;
        esac
        AWS_PROFILE=${ENV}-infra
        ;;
    *)
        print_usage "Unsupported Environment: $ENV"
        ;;
esac

# Update fallbacks
if [ "$TENANT_ID" = "" ]; then TENANT_ID="sym-mt"; fi
if [ "$SERVICE_GROUP" = "" ]; then SERVICE_GROUP="$SERVICE"; fi

# Output state for operaton
echo "ENVIRON:         $ENV"
echo "image:          $IMAGE"
echo "REGION:          $REGION"
echo "SERVICE:         $SERVICE"
echo "SERVICE_GROUP:   $SERVICE_GROUP"
echo "TENANT_ID:       $TENANT_ID"
echo "PERSIST_POD_ID:  $POD_ID"
if [ "$LEGACY_POD_ID" != "" ]; then echo "LEGACY_POD_ID:   $LEGACY_POD_ID"; fi
echo ""

# Update fallbacks
if [ "$LEGACY_POD_ID" = "" ]; then LEGACY_POD_ID="${TENANT_ID}"; fi

# ECS Task Definition Template
if [ "$SERVICE_PORT" = "" ]; then
    cat > /tmp/ecs-${ENV}-${TENANT_ID}-${SERVICE}-taskdef.json <<EOF
{
    "family": "${ENV}-${TENANT_ID}-${SERVICE}",
    "containerDefinitions": [
        {
            "name": "${SERVICE}",
            "image": "${IMAGE}",
            "memory": ${MEMORY},
            "essential": true,
            "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-group": "${ENV}-${TENANT_ID}-${SERVICE_GROUP}",
                    "awslogs-region": "${REGION}",
                    "awslogs-stream-prefix": "${SERVICE}"
                }
            },
            "environment": [
                {
                    "name": "CONSUL_SERVER",
                    "value": "consul-${ENV}.symphony.com:8080"
                },
                {
                    "name": "CONSUL_HTTP_SSL",
                    "value": "true"
                },
                {
                    "name": "CONSUL_TOKEN",
                    "value": "${CONSUL_TOKEN}"
                },
                {
                    "name": "INFRA_NAME",
                    "value": "${POD_ID}"
                },
                {
                    "name": "POD_NAME",
                    "value": "${LEGACY_POD_ID}"
                },
                {
                    "name": "SYM_ENV",
                    "value": "${ENV}"
                },
                {
                    "name": "SYM_ES_JAVAARGS",
                    "value": "-Xms${JVM_MEM}m -Xmx${JVM_MEM}m -XX:+UseConcMarkSweepGC -XX:+CMSParallelRemarkEnabled -XX:+UseCMSInitiatingOccupancyOnly -XX:CMSInitiatingOccupancyFraction=50 -XX:+ScavengeBeforeFullGC -XX:+CMSScavengeBeforeRemark -XX:+PrintGCDateStamps -verbose:gc -XX:+PrintGCDetails -Dcom.sun.management.jmxremote.port=10483 -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false  -Dagent.cloudlogger.enabled=true -Dagent.cloudmetrics.enabled=true"
                },
                {
                    "name": "SYM_ES_JAVA_ARGS",
                    "value": "-Xms${JVM_MEM}m -Xmx${JVM_MEM}m -XX:+UseConcMarkSweepGC -XX:+CMSParallelRemarkEnabled -XX:+UseCMSInitiatingOccupancyOnly -XX:CMSInitiatingOccupancyFraction=50 -XX:+ScavengeBeforeFullGC -XX:+CMSScavengeBeforeRemark -XX:+PrintGCDateStamps -verbose:gc -XX:+PrintGCDetails -Dcom.sun.management.jmxremote.port=10483 -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false  -Dagent.cloudlogger.enabled=true -Dagent.cloudmetrics.enabled=true"
                }
            ]
        }
    ]
}
EOF
else
cat > /tmp/ecs-${ENV}-${TENANT_ID}-${SERVICE}-taskdef.json <<EOF
{
    "family": "${ENV}-${TENANT_ID}-${SERVICE}",
    "containerDefinitions": [
        {
            "name": "${SERVICE}",
            "image": "${IMAGE}",
            "memory": ${MEMORY},
            "portMappings": [
                {
                    "hostPort": 0,
                    "protocol": "tcp",
                    "containerPort": ${SERVICE_PORT}
                }
            ],
            "essential": true,
            "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-group": "${ENV}-${TENANT_ID}-${SERVICE_GROUP}",
                    "awslogs-region": "${REGION}",
                    "awslogs-stream-prefix": "${SERVICE}"
                }
            },
            "environment": [
                {
                    "name": "CONSUL_SERVER",
                    "value": "consul-${ENV}.symphony.com:8080"
                },
                {
                    "name": "CONSUL_HTTP_SSL",
                    "value": "true"
                },
                {
                    "name": "CONSUL_TOKEN",
                    "value": "${CONSUL_TOKEN}"
                },
                {
                    "name": "INFRA_NAME",
                    "value": "${POD_ID}"
                },
                {
                    "name": "POD_NAME",
                    "value": "${LEGACY_POD_ID}"
                },
                {
                    "name": "SYM_ENV",
                    "value": "${ENV}"
                },
                {
                    "name": "SYM_ES_JAVAARGS",
                    "value": "-Xms${JVM_MEM}m -Xmx${JVM_MEM}m -XX:+UseConcMarkSweepGC -XX:+CMSParallelRemarkEnabled -XX:+UseCMSInitiatingOccupancyOnly -XX:CMSInitiatingOccupancyFraction=50 -XX:+ScavengeBeforeFullGC -XX:+CMSScavengeBeforeRemark -XX:+PrintGCDateStamps -verbose:gc -XX:+PrintGCDetails -Dcom.sun.management.jmxremote.port=10483 -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false  -Dagent.cloudlogger.enabled=true -Dagent.cloudmetrics.enabled=true"
                },
                {
                    "name": "SYM_ES_JAVA_ARGS",
                    "value": "-Xms${JVM_MEM}m -Xmx${JVM_MEM}m -XX:+UseConcMarkSweepGC -XX:+CMSParallelRemarkEnabled -XX:+UseCMSInitiatingOccupancyOnly -XX:CMSInitiatingOccupancyFraction=50 -XX:+ScavengeBeforeFullGC -XX:+CMSScavengeBeforeRemark -XX:+PrintGCDateStamps -verbose:gc -XX:+PrintGCDetails -Dcom.sun.management.jmxremote.port=10483 -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false  -Dagent.cloudlogger.enabled=true -Dagent.cloudmetrics.enabled=true"
                }
            ]
        }
    ]
}
EOF
fi


# ECS Task Definition Registration
aws --profile $AWS_PROFILE ecs register-task-definition \
    --region $REGION \
    --cli-input-json file:///tmp/ecs-${ENV}-${TENANT_ID}-${SERVICE}-taskdef.json \
    | tee -a aws.log | jq -c ".taskDefinition.taskDefinitionArn"
