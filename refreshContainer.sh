 #!/bin/bash

# A sample script for calls to the API. This one refresh Jet Stream container.
. loginCredentials

##examples##
# Refresh container from latest point in time of Template
#./refreshContainer.sh -T JS_DATA_TEMPLATE-13 JS_DATA_CONTAINER-20
# Refresh container from specific bookmark
#./refreshContainer.sh -b JS_BOOKMARK-76 JS_DATA_CONTAINER-20
# Refresh container from specific point in time of branch
#./refreshContainer.sh -t "2016-08-08T10:00:00.000Z" -B JS_BRANCH-50 JS_DATA_CONTAINER-20

##### Functions

# Help Menu
function usage {
	echo "Usage: refreshContainer.sh [[-h] | options...] <containername> <template>"
	echo "Create a Jet Stream Bookmark on the given branch."
	echo ""
	echo "Positional arguments"
	echo "  <containerName>"
	echo "  <template>"
	echo ""
	echo "Optional Arguments:"
	echo "  -h                Show this message and exit"
	echo "  -d                Delphix engine IP address or host name, otherwise revert to default"
	echo "  -u USER:PASSWORD  Server user and password, otherwise revert to default"
	echo "  -T                template reference from which need to refresh from latest point in time"
	echo "  -b                Bookmark name from which need to refresh container. If no bookmark is included, the branch will be created at the latest point in time. Type: string. Format JS_BOOKMARK-<n> (Optional)"
	echo "  -t                The time from where the container should be refreshed. This must be accompanied with branch name from which need to pick up time. Type: date, must be in ISO 8601 extended format [yyyy]-[MM]-[dd]T[HH]:[mm]:[ss].[SSS]Z"
    echo "  -B                Branch name from which need to refresh container, at specific time. Type: string. Format JS_BRANCH-<n> (Optional)"
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

function restore_container
{

	# If there is not timeInput and no bookmark name, we need to use JSTimelinePointLatestTimeInput from template.
	if [[ -n $template && -z $inputTime  &&  -z $bookmark ]]
	then
		pointParams="\"type\": \"JSTimelinePointLatestTimeInput\",
                     \"sourceDataLayout\": \"${template}\""

   # If there is a timeInput and no bookmark name, we need to use Input Time.

	elif [[ -n $inputTime  && -n $branchRef && -z $bookmark && -z $template ]]
	 then
		pointParams="\"type\": \"JSTimelinePointTimeInput\",
                 \"branch\": \"${branchRef}\",
                 \"time\": \"${inputTime}\""

   # If there is a bookmark name and no time input, we need to use bookmark
    #\"type\": \"JSTimelinePointBookmarkInput\",

   elif [[ -n $bookmark && -z $template && -z $inputTime ]]
   then
        pointParams="\"type\": \"JSTimelinePointBookmarkInput\",
                               \"bookmark\": \"${bookmark}\""
	fi
	
	echo "pointParams" $pointParams
	
	    
	result=$(curl -s -X POST -k --data @- http://${DE}/resources/json/delphix/jetstream/container/${containerRef}/restore \
	    -b ~/cookies.txt -H "Content-Type: application/json" <<-EOF
	{
	    $pointParams
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
		echo "successfully refresh container $containerName"
	else
		echo "unable to refresh container"
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

while getopts "u:d:T:b:t:B:h" flag; do
	case "$flag" in
    	u )             username=${OPTARG%:*}
						password=${OPTARG##*:}
						;;
		d )             engine=$OPTARG
						;;
		T )             template=$OPTARG
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

# Check that there are 1 positional arguments
if [ $# != 1 ]
then
	usage
	exit 1
fi

# Get the one positional arguments
containerRef=$1

create_session
authenticate_de
restore_container
