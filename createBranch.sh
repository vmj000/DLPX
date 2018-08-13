#!/bin/bash

# A sample script for calls to the API. This one creates a Jet Stream branch.

. loginCredentials

rm ./cookies.txt

##examples##
# Create branch from latest point in time
#./createBranch.sh -d 172.16.151.154 -u delphix_admin:landshark newbranch JS_DATA_CONTAINER-20
# Create branch from specific bookmark
#./createBranch.sh -d 172.16.151.154 -u delphix_admin:landshark -b bookmarkname newbranch JS_DATA_CONTAINER-20
# Create branch from specific point in time
#./createBranch.sh -d 172.16.151.154 -u delphix_admin:landshark -t "2016-07-27T01:45:56.453Z" newbranch JS_DATA_CONTAINER-20

##### Functions
# Help Menu
function usage {
	echo "Usage: createBranch.sh [[-h] | options...] <name> <container>"
	echo "Create a Jet Stream Bookmark on the given branch."
	echo ""
	echo "Positional arguments"
	echo "  <name>"
	echo "  <container> format JS_DATA_CONTAINER-<n>"
	echo ""
	echo "Optional Arguments:"
	echo "  -h                Show this message and exit"
	echo "  -d                Delphix engine IP address or host name, otherwise revert to default"
	echo "  -u USER:PASSWORD  Server user and password, otherwise revert to default"
	echo "  -b                Bookmark name from which need to create branch. If no bookmark is included, the branch will be created at the latest point in time. Type: string. Format JS_BOOKMARK-<n>"
	echo "  -t                The time at which the branch should be created. If no time is included, the branch will be created at the latest point in time. Type: date, must be in ISO 8601 extended format [yyyy]-[MM]-[dd]T[HH]:[mm]:[ss].[SSS]Z"
    echo "  -B                Branch name from which need to create new branch, at specific time."
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
	result=$(curl -s -S -X POST -k --data @- http://${DE}/resources/json/delphix/session \
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
	result=$(curl -s -S -X POST -k --data @- http://${DE}/resources/json/delphix/login \
		-b ~/cookies.txt -H "Content-Type: application/json" <<-EOF
	{
		"type": "LoginRequest",
		"username": "${DELPHIX_ADMIN}",
		"password": "${DELPHIX_PASS}"
	}
	EOF)	

	check_result
}

function create_branch
{
	# If there is not timeInput and no bookmark name, we need to use JSTimelinePointLatestTimeInput.
	if [[ -z $inputTime  &&  -z $bookmark ]]
	then
		pointParams="\"timelinePointParameters\":{
			\"sourceDataLayout\": \"$container\",
			\"type\":\"JSTimelinePointLatestTimeInput\"}"

   # If there is a timeInput and no bookmark name, we need to use Input Time.

	elif [[ -n $inputTime  &&  -z $bookmark ]]
	 then
		pointParams="\"timelinePointParameters\":{
			\"time\":\"$inputTime\",
			\"sourceDataLayout\":\"$container\",
			\"type\":\"JSTimelinePointTimeInput\"}"

   # If there is a bookmark name and no time input, we need to use bookmark

   elif [[ -z $inputTime  &&  -n $bookmark ]]
   then
        pointParams="\"timelinePointParameters\":{
        \"bookmark\":\"$bookmark\",
        \"type\":\"JSTimelinePointBookmarkInput\"}"
	fi

	# These are the required parameters.
	paramString="
	        \"dataContainer\": \"${container}\",
	        \"name\": \"${branchName}\","	        
	        
	paramString="$paramString 
	    ${pointParams},
	    \"type\": \"JSBranchCreateParameters\""
	    

	result=$(curl -s -X POST -k --data @- http://${DE}/resources/json/delphix/jetstream/branch \
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

    result=$(curl -s -X GET -k http://${DE}/resources/json/delphix/job/${jobRef} \
    -b ~/cookies.txt -H "Content-Type: application/json")

    # Get everything in the result that comes after job.
    temp=${result#*\"jobState\":\"}
    # Get rid of everything after
    jobState=${temp%%\"*}

    check_result

    while [ $jobState = "RUNNING" ]
    do
    	sleep 1
    	result=$(curl -s -X GET -k http://${DE}/resources/json/delphix/job/${jobRef} \
	    -b ~/cookies.txt -H "Content-Type: application/json")

	    # Get everything in the result that comes after job.
	    temp=${result#*\"jobState\":\"}
	    # Get rid of everything after
	    jobState=${temp%%\"*}

	    check_result

    done

    if [ $jobState = "COMPLETED" ]
	then
		echo "successfully created branch $branchName"
	else
		echo "unable to create branch"
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

while getopts "u:d:b:t:B:h" flag; do
	case "$flag" in
    	u )             username=${OPTARG%:*}
						password=${OPTARG##*:}
						;;
		d )             engine=$OPTARG
						;;
		b )             bookmark=$OPTARG
						;;
		t )             inputTime=$OPTARG
						;;
        B )             branchRef=$OPTARG
                        ;;
		h )             usage
						exit
						;;
		* )             usage
						exit 1
	esac

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
branchName=$1
shift
container=$1

create_session
authenticate_de
create_branch
