#!/bin/bash

# Author: Rodrigo Pompei <rodrigo.pompei@gmail.com>
# Version: 0.0.1
#
# Description
#    - This script will perform Mongo backup from GCE or AWS Source POD, transfer files from GCE salt server to AWS salt server (if necessary) and restore the backup in AWS Target POD
#      0.0.4 version adds support to AWS to AWS Mongo migration.
#
#     Examples:
#          ./mongo_backup_restore.sh -s sym-sre131-prod-chat-glb-1 -t sym-sre13-prod-chat-glb-1

usage () {
    cat <<HELP_USAGE

$0 <-s | --source_pod> <-t | --target_aws_pod> [--yes] [-h | --help]
    <-s  | --source_pod> Source AWS or GCE pod_name  The name of the Source POD in AWS or GCE.   Example: $0 sym-sre131-prod-chat-glb-1
    <-t  | --target_aws_pod> Target AWS pod_name  The name of the Target POD in AWS.             Example: $0 sym-sre13-prod-chat-glb-1
    [--yes] Apply without need of Confirmation prompt
    [-h  | --help]  Display help.

HELP_USAGE
}

### variables definition
variable_validation () {

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
    -t | --target_aws_pod )
    TARGET_POD="$2";
    shift 2
    ;;
    --yes )
    WO_CONF=1;
    shift
    ;;
    -- )
    break
    ;;
    *  )
    break
    ;;
  esac
done
    if [[ -z "${SOURCE_POD}" ]] || [[ -z "${TARGET_POD}" ]]
    then
        usage
        exit 1
    fi
}

### set_mongo_instances
set_mongo_instances () {

    ENV=`echo $SOURCE_POD | cut -d- -f3`
    SOURCE_MONGO_INSTANCE=`ssh gce-${ENV}-salt1 "sudo salt -C 'G@stype:mongo and ${SOURCE_POD}*' grains.get mongos" | awk 'NR==2{print $2}'`

    if [[ -z "${SOURCE_MONGO_INSTANCE}" ]]
    then
        SOURCE_AWS_MONGO_INSTANCE=`salt -C "G@stype:mongo and ${SOURCE_POD}*" grains.get mongos | awk 'NR==2{print $2}'`
        SOURCE_MONGO_INSTANCE=${SOURCE_AWS_MONGO_INSTANCE}
        if [[ -z "${SOURCE_MONGO_INSTANCE}" ]]
        then
            printf "\n  It was not possible to get Mongo instance from grains. \n  Please check Mongo instances configuration \n\n Stopping...\n"
            exit 2
        fi
    fi

    echo "Source Mongo instance is ${SOURCE_MONGO_INSTANCE}"

    TARGET_MONGO_INSTANCE=`salt -C "G@stype:mongo and ${TARGET_POD}*" grains.get mongos | awk 'NR==2{print $2}'`

    if [[ -z "${TARGET_MONGO_INSTANCE}" ]]
    then
        printf "\n  It was not possible to get Mongo instance from grains. \n  Please check Mongo instances configuration \n\n Stopping...\n"
        exit 2
    fi

    echo "Target Mongo instance is ${TARGET_MONGO_INSTANCE}"
}

 ### Mongo backup on Source POD
mongo_backup_source_pod () {

    if [[ -z "${SOURCE_AWS_MONGO_INSTANCE}" ]]
    then
        ssh gce-${ENV}-salt1 "sudo salt ${SOURCE_MONGO_INSTANCE} cmd.run '/opt/mongo/bin/mongodump --ssl --sslAllowInvalidCertificates -d maestro -o /tmp/backup_mongo/'"
    else
        salt ${SOURCE_MONGO_INSTANCE} cmd.run '/opt/mongo/bin/mongodump --ssl --sslAllowInvalidCertificates -d maestro -o /tmp/backup_mongo/'
    fi

    if [ $? -eq 0 ];
    then
        echo "Mongo Source Backup was performed on Source POD"
    else
        echo "Mongo Source Backup was NOT performed on Source POD"
    fi
 }

  ### Mongo backup on Target POD
mongo_backup_target_pod () {

    salt ${TARGET_MONGO_INSTANCE} cmd.run '/opt/mongo/bin/mongodump --ssl --sslAllowInvalidCertificates -d maestro -o /tmp/backup_mongo/'
    if [ $? -eq 0 ];
    then
        echo "Mongo Target Backup was performed on Target POD"
    else
        echo "Mongo Target Backup was NOT performed on Target POD"
    fi
 }

 ### Mongo Target POD backup transfered from Target POD to AWS salt server
mongo_target_backup_to_aws () {

    scp -r ${TARGET_MONGO_INSTANCE}:/tmp/backup_mongo /tmp/${TARGET_POD}/
    if [ $? -eq 0 ];
    then
        echo "Mongo Target Backup was transfered from Target POD to AWS salt server"
    else
        echo "Mongo Target Backup was NOT transfered from Target POD to AWS salt server"
    fi
 }

 ### Mongo backup transfered from Source POD to GCE Salt Master
mongo_backup_to_gce_salt () {

    if [[ -z "${SOURCE_AWS_MONGO_INSTANCE}" ]]
    then
        ssh gce-${ENV}-salt1 "sudo scp -r ${SOURCE_MONGO_INSTANCE}:/tmp/backup_mongo/ /tmp/${SOURCE_POD}"
        ssh gce-${ENV}-salt1 "sudo chown root:root /tmp/${SOURCE_POD}"
    else
        scp -r ${SOURCE_MONGO_INSTANCE}:/tmp/backup_mongo/ /tmp/${SOURCE_POD}
    fi

    if [ $? -eq 0 ];
    then
        echo "Mongo Source Backup was transfered from Source POD to GCE salt server"
    else
        echo "Mongo Source Backup was NOT transfered from Source POD to GCE salt server"
    fi
 }

 ### Mongo backup transfered from GCE salt to AWS salt
mongo_backup_to_aws_salt () {

    if [[ -z "${SOURCE_AWS_MONGO_INSTANCE}" ]]
    then
        scp -r gce-${ENV}-salt1:/tmp/${SOURCE_POD} /tmp
    fi

    if [ $? -eq 0 ];
    then
        echo "Mongo Source Backup was transfered from GCE salt server to AWS salt server"
    else
        echo "Mongo Source Backup was NOT transfered from GCE salt server to AWS salt server"
    fi
 }

 ### Mongo backup transfered from AWS salt to Target POD
mongo_backup_to_target_pod () {

    salt ${TARGET_MONGO_INSTANCE} cmd.run "rm -rf /tmp/${TARGET_POD}/"
    scp -r /tmp/${SOURCE_POD}/ ${TARGET_MONGO_INSTANCE}:/tmp/${TARGET_POD}
    if [ $? -eq 0 ];
    then
        echo "Mongo Source Backup was transfered from AWS salt server to Target POD"
    else
        echo "Mongo Source Backup was NOT transfered from AWS salt server to Target POD"
    fi
 }

 ### Mongo drops maestro db
mongo_drop_db () {

    salt ${TARGET_MONGO_INSTANCE} cmd.run '/opt/mongo/bin/mongo maestro --ssl --sslAllowInvalidCertificates --eval "printjson(db.dropDatabase())"'
    if [ $? -eq 0 ];
    then
        echo "Mongo Drop Target database before Restore was executed"
    else
        echo "Mongo Drop Target database before Restore was NOT executed"
    fi
 }

 ### Mongo restore performed on Target POD
mongo_restore_target_pod () {

    salt ${TARGET_MONGO_INSTANCE} cmd.run "/opt/mongo/bin/mongorestore --ssl --sslAllowInvalidCertificates -d maestro /tmp/${TARGET_POD}/maestro/"
        if [ $? -eq 0 ];
    then
        echo "Mongo Restore performed on Target POD"
    else
        echo "Mongo Restore didn't perform on Target POD"
    fi
 }

main () {
    variable_validation $@

    echo -e    "This script will:
    1. Perform Backup of Mongo Maestro database to /tmp in \e[4m${SOURCE_POD}\e[0m Source POD
    2. Transfer the Mongo backup from \e[4m${SOURCE_POD}\e[0m Source GCP POD to GCP Salt Master (if necessary)
    3. Transfer the Mongo backup from GCP Salt Master to AWS Salt Master (if necessary)
    4. Transfer the Mongo backup from AWS Salt Master to \e[4m${TARGET_POD}\e[0m Target AWS POD
    5. Perform Mongo Maestro database drop on \e[4m${TARGET_POD}\e[0m Target AWS POD
    6. Perform Restore of Mongo Maestro database in \e[4m${TARGET_POD}\e[0m Target AWS POD"

    if [ "$WO_CONF" != 1 ];
    then
        echo "Do you want to continue? [Y/n]"
            read ANSWER

            if [ ${ANSWER} != "Y" ] && [ ${ANSWER} != "Yes" ];
            then
                exit
            fi
    fi

    set_mongo_instances
    mongo_backup_source_pod
    mongo_backup_target_pod
    mongo_target_backup_to_aws
    mongo_backup_to_gce_salt
    mongo_backup_to_aws_salt
    mongo_backup_to_target_pod
    mongo_drop_db
    mongo_restore_target_pod
 }

main $@

