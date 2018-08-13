#!/bin/bash
#
# sample script to  ...........
#
. loginCredentials


rm cookies.txt

echo "This script provides following operations on the boomkarks within the containers on which you haveaccess."
echo "create | delete | share | unshare"
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
echo "\n"
#
# Different options for bookmark operations 

case $choice  in
create)

    curl -X GET -k http://${DE}/resources/json/delphix/jetstream/container -b ~/cookies.txt -H "Content-Type: application/json"  | sed -e 's/[{}]/''/g' | awk -v RS=',' -F: '{print $1 $2}'  | grep -E 'reference|name'

 echo "Type  only the number from your container  metadata name from above:"
 echo "(Example: If JS_DATA_CONTAINER-12 then type 12)"
 read cntnr

  curl -s -X GET -k http://${DE}/resources/json/delphix/jetstream/branch?dataLayout=JS_DATA_CONTAINER-${cntnr}  -b ~/cookies.txt -H "Content-Type: application/json"  | sed -e 's/[{}]/''/g' | awk -v RS=',' -F: '{print $1 $2}' | grep -wE 'reference|name|dataLayout'

  echo "Below is the list of branches available in your selected container:"
  echo "You need to select the branch on which you want to create the bookmark:"
  echo "Type only the number from your branch  referenca name  from top :"
  echo "(Example: If JS_BRANCH-12 then type 12)"
  read brname
  echo " Provide New Bookmark Name:"
  read bkmk
  sh createBookmark.sh ${bkmk}  JS_BRANCH-${brname}
;;
share)
   curl -X GET -k http://${DE}/resources/json/delphix/jetstream/container -b ~/cookies.txt -H "Content-Type: application/json"  | sed -e 's/[{}]/''/g' | awk -v RS=',' -F: '{print $1 $2}'  | grep -E 'reference|name'

 echo "Type  only the number from your container  metadata name from above:"
 echo "(Example: If JS_DATA_CONTAINER-12 then type 12)"
 read cntnr

  curl -s -X GET -k http://${DE}/resources/json/delphix/jetstream/bookmark?dataLayout=JS_DATA_CONTAINER-${cntnr}  -b ~/cookies.txt -H "Content-Type: application/json"  | sed -e 's/[{}]/''/g' | awk -v RS=',' -F: '{print $1 $2}' | grep -wE 'reference|name|dataLayout'

  echo "Below is the list of bookmarks available in your selected container:"

  echo "Type only the number from your bookmark referenca name  from top :"
  echo "(Example: If JS_BOOKMARK-12 then type 12)"
  read BOOKMARK_REF


# share  the bookmark
  curl -s -X POST  -k http://${DE}/resources/json/delphix/jetstream/bookmark/JS_BOOKMARK-${BOOKMARK_REF}/share \
    -b ~/cookies.txt -H "Content-Type: application/json" 
;;
unshare)
    curl -X GET -k http://${DE}/resources/json/delphix/jetstream/container -b ~/cookies.txt -H "Content-Type: application/json"  | sed -e 's/[{}]/''/g' | awk -v RS=',' -F: '{print $1 $2}'  | grep -E 'reference|name'

 echo "Type  only the number from your container  metadata name from above:"
 echo "(Example: If JS_DATA_CONTAINER-12 then type 12)"
 read cntnr

  curl -s -X GET -k http://${DE}/resources/json/delphix/jetstream/bookmark?dataLayout=JS_DATA_CONTAINER-${cntnr}  -b ~/cookies.txt -H "Content-Type: application/json"  | sed -e 's/[{}]/''/g' | awk -v RS=',' -F: '{print $1 $2}' | grep -wE 'reference|name|dataLayout'

  echo "Below is the list of bookmarks available in your selected container:"

  echo "Type only the number from your bookmark referenca name  from top :"
  echo "(Example: If JS_BOOKMARK-12 then type 12)"
  read BOOKMARK_REF


# unshare  the bookmark
   curl -s -X POST  -k http://${DE}/resources/json/delphix/jetstream/bookmark/JS_BOOKMARK-${BOOKMARK_REF}/unshare \
    -b ~/cookies.txt -H "Content-Type: application/json"
;;
delete)
    curl -X GET -k http://${DE}/resources/json/delphix/jetstream/container -b ~/cookies.txt -H "Content-Type: application/json"  | sed -e 's/[{}]/''/g' | awk -v RS=',' -F: '{print $1 $2}'  | grep -E 'reference|name'

 echo "Type  only the number from your container  metadata name from above:"
 echo "(Example: If JS_DATA_CONTAINER-12 then type 12)"
 read cntnr

  curl -s -X GET -k http://${DE}/resources/json/delphix/jetstream/bookmark?dataLayout=JS_DATA_CONTAINER-${cntnr}  -b ~/cookies.txt -H "Content-Type: application/json"  | sed -e 's/[{}]/''/g' | awk -v RS=',' -F: '{print $1 $2}' | grep -wE 'reference|name|dataLayout'

  echo "Below is the list of bookmarks available in your selected container:"

  echo "Type only the number from your bookmark referenca name  from top :"
  echo "(Example: If JS_BOOKMARK-12 then type 12)"
  read BOOKMARK_REF


#delete the bookmark
   curl -s -X DELETE -k http://${DE}/resources/json/delphix/jetstream/bookmark/JS_BOOKMARK-${BOOKMARK_REF} \
    -b ~/cookies.txt -H "Content-Type: application/json" 
echo
;;
*)
  echo "Unknown option: $1"
;;
esac
echo
