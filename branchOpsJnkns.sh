#!/bin/bash
#
# Script to perform brach level operations in a Jetstream Container.
##Usage Notes:
# General Usage: sh branchOpsJnkns.sh "Action to perform" "Container Name" "Branch Name"
# To create brach : sh branchOpsJnkns.sh create  SITEmp testbr
# To activate branch : sh branchOpsJnkns.sh activate  SITEmp testbr
#To delete branch : sh branchOpsJnkns.sh delete  SITEmp testbr

. loginCredentials

rm cookies.txt

echo "This script provides following operations on the boomkarks within the containers on which you haveaccess."
echo "create | delete | activate"


# Create Our Session, including establishing the API version.
        # Pulling the version into parts. The {} are necessary for string manipulation.
        # Strip out longest match following "."  This leaves only the major version.
        major=${VERSION%%.*}
        # Strip out the shortest match preceding "." This leaves minor.micro.
        minorMicro=${VERSION#*.}
        # Strip out the shortest match followint "." This leaves the minor version.
        minor=${minorMicro%.*}
        # Strip out the longest match preceding "." This leaves the micro version.
        micro=${VERSION##*.}

#
# create our session
curl -s -X POST -k --data @- http://${DE}/resources/json/delphix/session -c ~/cookies.txt -H "Content-Type: application/json" <<EOF
{
    "type": "APISession",
    "version": {
        "type": "APIVersion",
        "major": $major,
        "minor": $minor,
        "micro": $micro
    }
}
EOF
echo -e "\n"
#
# authenticate to the DE
curl -s -X POST -k --data @- http://${DE}/resources/json/delphix/login -b ~/cookies.txt -H "Content-Type: application/json" <<EOF
{
    "type": "LoginRequest",
    "username": "${DELPHIX_ADMIN}",
    "password": "${DELPHIX_PASS}"
}
EOF
echo
echo -e "\n"
#
#
# Different options for bookmark operations 

case $1  in
create)
   cntnr=`curl -X GET -k http://${DE}/resources/json/delphix/jetstream/container -b ~/cookies.txt -H "Content-Type: application/json"  | jq --raw-output '.result[] | select(.name=="'"${2}"'") | .reference '`
echo container is  $cntnr

# create the branch
  sh createBranch.sh ${3}  ${cntnr}
;;
activate)
   cntnr=`curl -X GET -k http://${DE}/resources/json/delphix/jetstream/container -b ~/cookies.txt -H "Content-Type: application/json"  | jq --raw-output '.result[] | select(.name=="'"${2}"'") | .reference '`
echo container is  $cntnr


  BRANCH_REF=`curl -s -X GET -k http://${DE}/resources/json/delphix/jetstream/branch?dataLayout=${cntnr}  -b ~/cookies.txt -H "Content-Type: application/json"  | jq --raw-output '.result[] | select(.name=="'"${3}"'") | .reference '`
echo branch is $BRANCH_REF

# activate  the branch
   curl -s -X POST  -k http://${DE}/resources/json/delphix/jetstream/branch/${BRANCH_REF}/activate \
    -b ~/cookies.txt -H "Content-Type: application/json"
;;
delete)
 cntnr=`curl -X GET -k http://${DE}/resources/json/delphix/jetstream/container -b ~/cookies.txt -H "Content-Type: application/json"  | jq --raw-output '.result[] | select(.name=="'"${2}"'") | .reference '`
echo container is  $cntnr


  BRANCH_REF=`curl -s -X GET -k http://${DE}/resources/json/delphix/jetstream/branch?dataLayout=${cntnr}  -b ~/cookies.txt -H "Content-Type: application/json"  | jq --raw-output '.result[] | select(.name=="'"${3}"'") | .reference '`
echo branch is $BRANCH_REF



#delete the branch
   curl -s -X DELETE -k http://${DE}/resources/json/delphix/jetstream/branch/${BRANCH_REF} \
    -b ~/cookies.txt -H "Content-Type: application/json" 
echo
;;
*)
  echo "Unknown option: $1"
;;
esac
echo
