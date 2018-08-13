#!/bin/bash
#
# Script to perform brach level operations in a Jetstream Container.
#

. loginCredentials

rm cookies.txt

echo "This script provides following operations on the boomkarks within the containers on which you haveaccess."
echo "create | delete | activate"
echo "Type your choice  from above:"
read choice

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

case $choice  in
create)
  curl -X GET -k http://${DE}/resources/json/delphix/jetstream/container -b ~/cookies.txt -H "Content-Type: application/json"  | sed -e 's/[{}]/''/g' | awk -v RS=',' -F: '{print $1 $2}'  | grep -E 'reference|name'

 echo "Type  only the number from your container  metadata name from above:"
 echo "(Example: If JS_DATA_CONTAINER-12 then type 12)"
 read cntnr
  echo "New Branch  Name:"
  read brch
  sh createBranch.sh ${brch}  JS_DATA_CONTAINER-${cntnr}
 
 sleep 180
;;
activate)
 curl -X GET -k http://${DE}/resources/json/delphix/jetstream/container -b ~/cookies.txt -H "Content-Type: application/json"  | sed -e 's/[{}]/''/g' | awk -v RS=',' -F: '{print $1 $2}'  | grep -E 'reference|name'

 echo "Type  only the number from your container  metadata name from above:"
 echo "(Example: If JS_DATA_CONTAINER-12 then type 12)"
 read cntnr

curl -s -X GET -k http://${DE}/resources/json/delphix/jetstream/branch?dataLayout=JS_DATA_CONTAINER-${cntnr}  -b ~/cookies.txt -H "Content-Type: application/json"  | sed -e 's/[{}]/''/g' | awk -v RS=',' -F: '{print $1 $2}' | grep -wE 'reference|name|dataLayout' 

  echo "Below is the list of branches available in your selected container:"

  echo "Type only the number from your bookmark referenca name  from top :"
  echo "(Example: If JS_BRANCH-12 then type 12)"
  read BRANCH_REF

# activate  the bookmark
   curl -s -X POST  -k http://${DE}/resources/json/delphix/jetstream/branch/JS_BRANCH-${BRANCH_REF}/activate \
    -b ~/cookies.txt -H "Content-Type: application/json"

 sleep 180
;;
delete)
  curl -X GET -k http://${DE}/resources/json/delphix/jetstream/container -b ~/cookies.txt -H "Content-Type: application/json"  | sed -e 's/[{}]/''/g' | awk -v RS=',' -F: '{print $1 $2}'  | grep -E 'reference|name'

 echo "Type  only the number from your container  metadata name from above:"
 echo "(Example: If JS_DATA_CONTAINER-12 then type 12)"
 read cntnr

  curl -s -X GET -k http://${DE}/resources/json/delphix/jetstream/branch?dataLayout=JS_DATA_CONTAINER-${cntnr}  -b ~/cookies.txt -H "Content-Type: application/json"  | sed -e 's/[{}]/''/g' | awk -v RS=',' -F: '{print $1 $2}' | grep -wE 'reference|name|dataLayout'

  echo "Below is the list of branches available in your selected container:"

  echo "Type only the number from your bookmark referenca name  from top :"
  echo "(Example: If JS_BRANCH-12 then type 12)"
  read BRANCH_REF

#delete the bookmark
   curl -s -X DELETE -k http://${DE}/resources/json/delphix/jetstream/branch/JS_BRANCH-${BRANCH_REF} \
    -b ~/cookies.txt -H "Content-Type: application/json" 

   sleep 180
echo
;;
*)
  echo "Unknown option: $1"
;;
esac
echo
