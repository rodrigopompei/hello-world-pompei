#!/bin/bash
#
# Wrapper to simplify call to aws_get_token.sh. Only need to pass in the MFA token.
#

dir=$(dirname $0)
cmd=$dir/aws_get_token.sh

if [ "$1" = "" ]; then
    echo "usage: aws_get_token_dev.sh mfatok [ duration ]"
    exit 1
fi

act=070995189839
iam=rodrigo.pompei@symphony.com
arn=arn:aws:iam::$act:mfa/$iam
tok=$1
dur=${2:-86400}

$cmd $iam $arn $tok $dur
