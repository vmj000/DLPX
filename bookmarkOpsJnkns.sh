#!/bin/bash
#
# sample script to  ...........
#
. loginCredentials


rm cookies.txt

echo "This script provides following operations on the boomkarks within the containers on which you have access."
echo "activate | create | delete | share | unshare"
echo "You are using ${1} option of the script"

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
echo "\n"
#
# Different options for bookmark operations 

case $1  in
create)

    cntnr=`curl -X GET -k http://${DE}/resources/json/delphix/jetstream/container -b ~/cookies.txt -H "Content-Type: application/json"  | jq --raw-output '.result[] | select(.name=="'"${2}"'") | .reference '`
echo container is  $cntnr


 brname=`curl -s -X GET -k http://${DE}/resources/json/delphix/jetstream/branch?dataLayout=${cntnr}  -b ~/cookies.txt -H "Content-Type: application/json"  | jq --raw-output '.result[] | select(.name=="'"${3}"'") | .reference '`
echo branch is $brname

  sh createBookmark.sh ${4} ${brname}
;;
share)
      cntnr=`curl -X GET -k http://${DE}/resources/json/delphix/jetstream/container -b ~/cookies.txt -H "Content-Type: application/json"  | jq --raw-output '.result[] | select(.name=="'"${2}"'") | .reference '`
echo container is  $cntnr


  BOOKMARK_REF=`curl -s -X GET -k http://${DE}/resources/json/delphix/jetstream/bookmark?dataLayout=${cntnr}  -b ~/cookies.txt -H "Content-Type: application/json"  | jq --raw-output '.result[] | select(.name=="'"${3}"'") | .reference '`



# share  the bookmark
  curl -s -X POST  -k http://${DE}/resources/json/delphix/jetstream/bookmark/${BOOKMARK_REF}/share \
    -b ~/cookies.txt -H "Content-Type: application/json" 
;;
unshare)
       cntnr=`curl -X GET -k http://${DE}/resources/json/delphix/jetstream/container -b ~/cookies.txt -H "Content-Type: application/json"  | jq --raw-output '.result[] | select(.name=="'"${2}"'") | .reference '`
echo container is  $cntnr


  BOOKMARK_REF=`curl -s -X GET -k http://${DE}/resources/json/delphix/jetstream/bookmark?dataLayout=${cntnr}  -b ~/cookies.txt -H "Content-Type: application/json"  | jq --raw-output '.result[] | select(.name=="'"${3}"'") | .reference '`



# unshare  the bookmark
   curl -s -X POST  -k http://${DE}/resources/json/delphix/jetstream/bookmark/${BOOKMARK_REF}/unshare \
    -b ~/cookies.txt -H "Content-Type: application/json"
;;
delete)
 cntnr=`curl -X GET -k http://${DE}/resources/json/delphix/jetstream/container -b ~/cookies.txt -H "Content-Type: application/json"  | jq --raw-output '.result[] | select(.name=="'"${2}"'") | .reference '`
echo container is  $cntnr


  BOOKMARK_REF=`curl -s -X GET -k http://${DE}/resources/json/delphix/jetstream/bookmark?dataLayout=${cntnr}  -b ~/cookies.txt -H "Content-Type: application/json"  | jq --raw-output '.result[] | select(.name=="'"${3}"'") | .reference '`


#delete the bookmark
   curl -s -X DELETE -k http://${DE}/resources/json/delphix/jetstream/bookmark/${BOOKMARK_REF} \
    -b ~/cookies.txt -H "Content-Type: application/json" 

;;
activate)
 cntnr=`curl -X GET -k http://${DE}/resources/json/delphix/jetstream/container -b ~/cookies.txt -H "Content-Type: application/json"  | jq --raw-output '.result[] | select(.name=="'"${2}"'") | .reference '`
echo container is  $cntnr


  BOOKMARK_REF=`curl -s -X GET -k http://${DE}/resources/json/delphix/jetstream/bookmark?dataLayout=${cntnr}  -b ~/cookies.txt -H "Content-Type: application/json"  | jq --raw-output '.result[] | select(.name=="'"${3}"'") | .reference '`
echo bookmark is $BOOKMARK_REF

#activate  from this bookmark
curl -s -X POST -k --data @-  http://${DE}/resources/json/delphix/jetstream/container/${cntnr}/restore -b ~/cookies.txt -H "Content-Type: application/json"  <<EOF
{
    "type": "JSDataContainerRestoreParameters",
    "timelinePointParameters": {
        "type": "JSTimelinePointBookmarkInput",
        "bookmark": "${BOOKMARK_REF}"
    },
    "forceOption": false
}
EOF
sleep 120;
;;
*)
  echo "Unknown option: $1"
;;
esac
echo
