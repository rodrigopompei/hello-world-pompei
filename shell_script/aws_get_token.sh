#!/bin/bash
# =============================================================================================
# DescrIption: session token script
# version 1.2
#
# The script will execute the sts get-session-token cmd with the appropriate arguments and will
# create a new profile and attaching a session specific keyId, secret, and token to this new profile.
# The new authenticated profile name will be $passedInProfileName-AUTHENTICATED-MFA-SESSION
# The new authenticated profile can be referenced like any other profile
#
# WARNING - DO NOT TRY TO REUSE THE SAME PROFILE NAME FOR THE AUTHENTICATED PROFILE
# THIS SCRIPT WRITES INTO AWS/CREDENTIALS AND UPDATES AUTHENTICATED PROFILE DIRECTLY - OVERWRITTING THE KEYID AND SECRET
# IF YOU MODIFY THIS SCRIPT AND TRY TO USE THE SAME NAME FOR THE AUTHENTICATED PROFILE YOU WILL OVERWRITE
# THE ORIGINAL KEY-ID AND KEY-SECRET.  PLS. DO NOT DO THIS.
#
# Inputs:
# AWS_USER_PROFILE : name of profile in ~/.aws/credentials file or equivalent
# ARN_OF_MFA       : arn of MFA device associated with your credentials
# MFA_TOKEN_CODE   : MFA 2F number
# DURATION         : session duration, defaults to 1 hour
#
# Outputs:
# AWS_2AUTH_PROFILE: name of profile that has the session token that you can now reference like any regular profile
#
# WARNING -- AWS STS CMD WILL UPDATE YOUR .AWS/CREDENTIALS FILE AND ADD AN ENTRY AWS_SESSION_TOKEN FOR THE PROFILE THAT YOU
#            SPECIFY - THIS MIGHT CAUSE ISSUES LATER WHEN YOU TRY TO RECREATE A NEW TOKEN....AS THE OLD ONE WILL BE THERE
#
# [symphony-aws-qa:chris.fabri]
#aws_access_key_id = ASIAJR2MBTSRC623PP7Q
#aws_secret_access_key = XXXXXXXX
#aws_session_token = FQoDYXdzEMv//////////wEaDMDrYBGV9m6LC++01SKvAU5lGE6p33hP6XyHNbXphMhfGkEQGhAUFdkZGLre152jGRTVOmrHLNhfImrqKs4if3oKW6CpMYwC4EAT53mY0IHwZROX8IzlQrDztGK+OcjTXLcVw7MQBEZ5eqU7/MOXQkT8qZ6sqcai138ABFsL5i5vijfLdwTv52O5xBr6pUOY1Ui7/ATPuQIiTKqYvuhCviAIsWPfEG5JpcoJT13dXFynVnemo2g5/Ol1Y/1m15UoueeF2gU=
#
# usage:
# ./aws_get_token.sh $AWS_USER_PROFILE $ARN_OF_MFA                         $MFA_TOKEN_CODE ($DURATION)
#
# example:
# ./aws_get_token.sh chris.fabri-mso-mfa          arn:aws:iam::111111111111:mfa/chris.fabri@symphony.com    367258  3600      (create a session that lasts 1 hour)
# ./aws_get_token.sh chris-dev                    arn:aws:iam::111111111111:mfa/chris.fabri@symphony.com    006136           (leave off or add number in seconds)
# ./aws_get_token.sh symphony-aws-qa:chris.fabri  arn:aws:iam::111111111111:mfa/chris.fabri@symphony.com    484023           (leave off or add number in seconds)
# ...
# aws s3api list-buckets --query "Buckets[].Name" --profile chris-dev--AUTHENTICATED-MFA-SESSION
#
# Documentation:
# Sample for getting temp session token from AWS STS
#
# Example command to get a session
# aws --profile youriamuser sts get-session-token --duration 3600 \
# --serial-number arn:aws:iam::111111111111:mfa/user --token-code 012345
#
# Based on : https://github.com/EvidentSecurity/MFAonCLI/blob/master/aws-temp-token.sh
#
# =============================================================================================

AWS_CLI=`which aws`

# session duration defaults to .5 hour
DURATION_DEFAULT=1800

# script version
VERSION=1.2

echo "Script version is $VERSION...."

if [ $? -ne 0 ]; then
  echo "AWS CLI is not installed; exiting"
#  exit 1
else
  echo "Using AWS CLI found at $AWS_CLI"
fi

if [ -z "$1" ]; then
  echo "Usage: $0  <AWS_USER_PROFILE>"
  echo "Where:"
  echo "   <AWS_USER_PROFILE> = profile in .aws/credentials associated with the MFA device"
  exit 2
fi

if [ -z "$2" ]; then
  echo "Usage: $0  <ARN_OF_MFA>"
  echo "Where:"
  echo "   <ARN_OF_MFA> = arn of device associated with the MFA device"
  exit 2
fi

if [ -z "$3" ]; then
  echo "Usage: $0  <MFA_TOKEN_CODE>"
  echo "Where:"
  echo "   <MFA_TOKEN_CODE> = Code from virtual MFA device"
  exit 2
fi

if [ -z "$4" ]; then
  echo "Session duration is defaulting to $DURATION_DEFAULT seconds..."
  DURATION=$DURATION_DEFAULT
else
  DURATION=$4
fi

AWS_USER_PROFILE=$1
ARN_OF_MFA=$2
MFA_TOKEN_CODE=$3

AWS_2AUTH_PROFILE=$1-AUTHENTICATED-MFA-SESSION
AWS_2AUTH_PROFILE=default
AWS_2AUTH_PROFILE=symphony-aws-infra

#DURATION=129600

echo "================================================="
echo "SCRIPT VERSION      : $VERSION"
echo "AWS PROFILE         : $AWS_USER_PROFILE"
echo "MFA ARN             : $ARN_OF_MFA"
echo "MFA Token Code      : $MFA_TOKEN_CODE"
echo "AWS_2AUTH_PROFILE   : $AWS_2AUTH_PROFILE"
echo "SESSION DURATION    : $DURATION"
echo "================================================="

#set -x

read AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN EXPIRATION <<< \
$( aws --profile $AWS_USER_PROFILE sts get-session-token \
  --duration $DURATION  \
  --serial-number $ARN_OF_MFA \
  --token-code $MFA_TOKEN_CODE \
  --output text  | awk '{ print $2, $4, $5, $3 }')
echo "================================================="
echo "AWS_2AUTH_PROFILE     :  $AWS_2AUTH_PROFILE     "
echo "AWS_ACCESS_KEY_ID     :  $AWS_ACCESS_KEY_ID     "
echo "AWS_SECRET_ACCESS_KEY :  $AWS_SECRET_ACCESS_KEY "
echo "AWS_SESSION_TOKEN     :  $AWS_SESSION_TOKEN     "
echo "EXPIRATION            :  $EXPIRATION            "
echo "================================================="

if [ -z "$AWS_ACCESS_KEY_ID" ]
then
  echo "Session token was not created....exiting"
  exit 1
fi

echo "================================================="
echo "Updating new authenticated profile....$AWS_2AUTH_PROFILE with new aws_access_key_id, aws_secret_access_key, and aws_session_token...."
echo "..."
echo "..."
echo "..."
echo "..."

`aws --profile $AWS_2AUTH_PROFILE configure set aws_access_key_id      "$AWS_ACCESS_KEY_ID"`
`aws --profile $AWS_2AUTH_PROFILE configure set aws_secret_access_key  "$AWS_SECRET_ACCESS_KEY"`
`aws --profile $AWS_2AUTH_PROFILE configure set aws_session_token      "$AWS_SESSION_TOKEN"`
`aws --profile $AWS_2AUTH_PROFILE configure set expiration             "$EXPIRATION"`
`aws --profile $AWS_2AUTH_PROFILE configure set arn_mfa                "$ARN_OF_MFA"`
echo "..."
echo "Success!!!"
echo " "
echo "Update of profile $AWS_2AUTH_PROFILE complete."
echo " "
echo "Profile $AWS_2AUTH_PROFILE can now be referrenced to access AWS"
echo "================================================="

echo "Cmds can now be run without specifying a profile. both of the following cmds will now work:"
echo "aws s3api list-buckets --query "Buckets[].Name""
echo "aws s3api list-buckets --query "Buckets[].Name" --profile $AWS_2AUTH_PROFILE"

