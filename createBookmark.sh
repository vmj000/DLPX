#!/bin/bash

# A sample script for calls to the API. This one creates a Jet Stream bookmark.

##### Constants

# Describes a Delphix software revision.
# Please change version are per your Delphix Engine CLI, if different
VERSION="1.8.0"




##### Default Values. These can be overwriten with optional arguments.
engine="landsharkengine"
username="dev"
password="delphix"

shared=false

##example##
#./createBookmark.sh -d 172.16.151.154 -u delphix_admin:landshark -p "bookmark test" -e "2016-07-27T23:38:56.453Z" -t "2016-07-27T01:45:56.453Z" -T [tag1,tag2,tag3,tag4,tag5] bkmrk3 JS_BRANCH-44


##### Functions

# Help Menu
function usage {
	echo "Usage: createBookmark.sh [[-h] | options...] <name> <branch>"
	echo "Create a Jet Stream Bookmark on the given branch."
	echo ""
	echo "Positional arguments"
	echo "  <name>"
	echo "  <branch>"
	echo ""
	echo "Optional Arguments:"
	echo "  -h                Show this message and exit"
	echo "  -d                Delphix engine IP address or host name, otherwise revert to default"
	echo "  -u USER:PASSWORD  Server user and password, otherwise revert to default"
	echo "  -D                Description of this bookmark. Type: string"
	echo "  -e                A policy will automatically delete this bookmark at this time. If not present the bookmark will be kept until manually deleted. Type: date, must be in ISO 8601 extended format [yyyy]-[MM]-[dd]T[HH]:[mm]:[ss].[SSS]Z"
	echo "  -s                Present if need to make bookmark in shared mode"
	echo "  -t                The time at which the bookmark should be created. If no time is included, the bookmark will be created at the latest point in time. Type: date, must be in ISO 8601 extended format [yyyy]-[MM]-[dd]T[HH]:[mm]:[ss].[SSS]Z"
	echo "  -T                A set of user-defined labels for this bookmark. No spaces allowed. Array of Type: string. In format, [tag1,tag2,..] "
}

# Create Our Session, including establishing the API version.
function create_session
{
	# Pulling the version into parts. The {} are necessary for string manipulation.
	# Strip out longest match following "."  This leaves only the major version.
	major=${VERSION%%.*}
	# Strip out the shortest match preceding "." This leaves minor.micro.
	minorMicro=${VERSION#*.}
	# Strip out the shortest match followint "." This leaves the minor version.
	minor=${minorMicro%.*}
	# Strip out the longest match preceding "." This leaves the micro version.
	micro=${VERSION##*.}

	# Quick note about the <<-. If the redirection operator << is followed by a - (dash), all leading TAB from the document data will be 
	# ignored. This is useful to have optical nice code also when using here-documents. Otherwise you must have the EOF be on a line by itself, 
	# no parens, no tabs or anything.

	echo "creating session..."
	result=$(curl -s -S -X POST -k --data @- http://${engine}/resources/json/delphix/session \
		-c ~/cookies.txt -H "Content-Type: application/json" <<-EOF
	{
		"type": "APISession",
		"version": {
			"type": "APIVersion",
			"major": $major,
			"minor": $minor,
			"micro": $micro
		}
	}
	EOF)

	check_result
}

# Authenticate the DE for the provided user.
function authenticate_de
{
	echo "authenticating delphix engine..."
	result=$(curl -s -S -X POST -k --data @- http://${engine}/resources/json/delphix/login \
		-b ~/cookies.txt -H "Content-Type: application/json" <<-EOF
	{
		"type": "LoginRequest",
		"username": "${username}",
		"password": "${password}"
	}
	EOF)	

	check_result
}

# Get the branch info so the bookmark to fill in dataLayout 
function get_branch
{
	echo "retrieveing branch $branchRef to find Source Data Layout..."
	result=$(curl -s -X GET -k http://${engine}/resources/json/delphix/jetstream/branch/${branchRef} \
    -b ~/cookies.txt -H "Content-Type: application/json")

    check_result

    # Get everything in the result that comes after dataLayout.
    temp=${result#*\"dataLayout\":\"}
    # Get rid of everything after creat
    dataLayout=${temp%%\"*}

    echo "temp" $temp
    
    echo "dataLayout" $dataLayout
}

function create_bookmark
{	
	get_branch

	# If there is not creation time, we need to use JSTimelinePointLatestTimeInput.
	if [ -z $creationTime ]
	then
		pointParams="\"timelinePointParameters\":{
			\"sourceDataLayout\": \"$dataLayout\",
			\"type\":\"JSTimelinePointLatestTimeInput\"}"

	else
		pointParams="\"timelinePointParameters\":{
			\"sourceDataLayout\": \"$dataLayout\",
			\"time\":\"$creationTime\",
			\"branch\":\"$branchRef\",
			\"type\":\"JSTimelinePointTimeInput\"}"
	fi

	# These are the required parameters.
	paramString="
		\"bookmark\": {
	        \"branch\": \"${branchRef}\", 
	        \"name\": \"${bookmarkName}\","

	# Fill in optional parameters if there are any.
	if [[ -n $description ]]
	then
		paramString="$paramString \"description\": \"$description\","
	fi

	if [[ -n $expiration ]]
	then
		paramString="$paramString \"expiration\": \"$expiration\","
	fi

	if [[ -n $shared ]]
	then
		paramString="$paramString \"shared\": $shared,"
	fi

	if [[ -n $tags ]]
	then
		# Add quotes back to the passed in tags so they are processed correctly.
		tags=${tags//[/[\"}
		tags=${tags//,/\",\"}
		tags=${tags//]/\"]}

		paramString="$paramString \"tags\": $tags,"
	fi

	paramString="$paramString \"type\": \"JSBookmark\"
	    },
	    ${pointParams},
	    \"type\": \"JSBookmarkCreateParameters\""

	result=$(curl -s -X POST -k --data @- http://${engine}/resources/json/delphix/jetstream/bookmark \
	    -b ~/cookies.txt -H "Content-Type: application/json" <<-EOF
	{
	    $paramString
	}
	EOF)

	check_result
	
	echo "confirming job completed successfully..."
	# Get everything in the result that comes after job.
    temp=${result#*\"job\":\"}
    # Get rid of everything after
    jobRef=${temp%%\"*}


    result=$(curl -s -X GET -k http://${engine}/resources/json/delphix/job/${jobRef} \
    -b ~/cookies.txt -H "Content-Type: application/json")

    # Get everything in the result that comes after job.
    temp=${result#*\"jobState\":\"}
    # Get rid of everything after
    jobState=${temp%%\"*}

    check_result

    while [ $jobState = "RUNNING" ]
    do
    	sleep 1
    	result=$(curl -s -X GET -k http://${engine}/resources/json/delphix/job/${jobRef} \
	    -b ~/cookies.txt -H "Content-Type: application/json")

	    # Get everything in the result that comes after job.
	    temp=${result#*\"jobState\":\"}
	    # Get rid of everything after
	    jobState=${temp%%\"*}

	    check_result

    done

    if [ $jobState = "COMPLETED" ]
	then
		echo "successfully created bookmark $bookmarkName"
	else
		echo "unable to create bookmark"
		echo result
	fi

}

# Check the result of the curl. If there are problems, inform the user then exit.
function check_result
{
	exitStatus=$?
	if [ $exitStatus -ne 0 ]
	then
	    echo "command failed with exit status $exitStatus"
	    exit 1
	elif [[ $result != *"OKResult"* ]]
	then
		echo ""
		echo $result
		exit 1
	fi
}

##### Main

while getopts "u:d:D:e:s:t:T:h" flag; do
	case "$flag" in
    	u )             username=${OPTARG%:*}
						password=${OPTARG##*:}
						;;
		d )             engine=$OPTARG
						;;
		D )             description=$OPTARG
						;;
		e )             expiration=$OPTARG
						;;
		s )         	shared=true
						;;
		t )             creationTime=$OPTARG
						;;
		T )             tags=$OPTARG
						;;
		h )             usage
						exit
						;;
		* )             usage
						exit 1
	esac

echo "OPTARG" $OPTARG ####

done


# Shift the parameters so we only have the positional arguments left
shift $((OPTIND-1))

# Check that there are 2 positional arguments
if [ $# != 2 ]
then
	usage
	exit 1
fi

# Get the two positional arguments
bookmarkName=$1
shift
branchRef=$1

create_session
authenticate_de
create_bookmark


