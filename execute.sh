#!/bin/bash

#********************************************************************************
# Copyright 2014 IBM
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#********************************************************************************

#############
# Colors    #
#############
export green='\e[0;32m'
export red='\e[0;31m'
export label_color='\e[0;33m'
export no_color='\e[0m' # No Color

##################################################
# Simple function to only run command if DEBUG=1 # 
### ###############################################
debugme() {
  [[ $DEBUG = 1 ]] && "$@" || :
}

set +e
set +x 

function dra_logger {
    npm install grunt
    npm install grunt-cli
    npm install grunt-idra

    #echo "Service List: ${DRA_SERVICE_LIST}"
    echo -e ""

    #dra_commands "${DRA_EVENT_TYPE_1}" "${DRA_FILE_1}" "${DRA_SERVER}"
    #dra_commands "${DRA_EVENT_TYPE_2}" "${DRA_FILE_2}" "${DRA_SERVER}"
    #dra_commands "${DRA_EVENT_TYPE_3}" "${DRA_FILE_3}" "${DRA_SERVER}"
    #dra_commands "${DRA_EVENT_TYPE_1}" "${DRA_FILE_1}"
    #dra_commands "${DRA_EVENT_TYPE_2}" "${DRA_FILE_2}"
    #dra_commands "${DRA_EVENT_TYPE_3}" "${DRA_FILE_3}"
	dra_commands "${DRA_SERVICE_LIST}"


    
    #grunt --gruntfile=node_modules/grunt-idra/idra.js -eventType=istanbulCoverage -file=tests/coverage/reports/coverage-summary.json
    #grunt --gruntfile=node_modules/grunt-idra/idra.js -eventType=testComplete -deployAnalyticsServer=https://da-test.oneibmcloud.com    
}

function dra_commands {
    dra_grunt_command=""
    
    #if [ -n "$1" ] && [ "$1" != " " ]; then
        #echo -e "Service List: $1 is defined and not empty"
		echo -e "DRA_ENABLE_BOUND_SERVICE value: $DRA_ENABLE_BOUND_SERVICE"
		#dra_grunt_command='grunt --gruntfile=node_modules/grunt-idra/idra.js -statusCheck="'
		#dra_grunt_command+=$1
		#dra_grunt_command+='"'
		#echo -e "Final command sent to grunt-iDRA to check services:\n"
		#echo -e $dra_grunt_command
		
		if [ ${DRA_ENABLE_BOUND_SERVICE} == true ]; then
		
			event_variable='{"CF_ORG":"'
			event_variable+=${CF_ORG}
			event_variable+='","CF_SPACE":"'
			event_variable+=${CF_SPACE}
			event_variable+='","CF_APP":"'
			event_variable+=${CF_APP}
			event_variable+='","CF_TARGET_URL":"'
			event_variable+=${CF_TARGET_URL}
			event_variable+='","CF_ORG_ID":"'
			event_variable+=${CF_ORGANIZATION_ID}
			event_variable+='","CF_SPACE_ID":"'
			event_variable+=${CF_SPACE_ID}
			event_variable+='"}'
			echo -e "\nEvent Variable: $event_variable"
			
			event_to_file='echo $event_variable > deployInfo.json'
			eval $event_to_file
			echo -e "\nEvent file created:\n"
			cat deployInfo.json
			
			send_event='grunt --gruntfile=node_modules/grunt-idra/idra.js -eventType=deployInfoProd -file=deployInfo.json'
			echo -e "\nSending event ...\n"
			eval $send_event
			
			delete_criteria='curl -H "projectKey: ${DRA_PROJECT_KEY}" -H "Content-Type: application/json" -X DELETE http://da.oneibmcloud.com/api/v1/criteria?name=DRADeploy_BOUND_COMPARE'
			echo -e "Deleting criteria ...\n"
			eval $delete_criteria
			
			criteria_variable='{ "name": "DRADeploy_BOUND_COMPARE", "revision": 2, "project": "key", "mode": "decision", "rules": [ { "name": "Check for bound services", "conditions": [ { "eval": "_areApplicationBoundServicesAvailable", "op": "=", "value": true } ] } ] }'
			echo -e "\nCriteria Variable: $criteria_variable"
			
			criteria_to_file='echo $criteria_variable > criteriafile.json'
			eval $criteria_to_file
			echo -e "\nCriteria created:\n"
			cat criteriafile.json
			
			post_criteria='curl -H "projectKey: ${DRA_PROJECT_KEY}" -H "Content-Type: application/json" -X POST -d @criteriafile.json http://da.oneibmcloud.com/api/v1/criteria'
			echo -e "\nPosting criteria to API...\n"
			eval $post_criteria
		else
			echo -e "\nUnchecked the box!\n"
        fi
		
    #else
        #echo -e "\nService List is not defined or is empty .. proceeding with deployment ..\n"
    #fi
}

dra_logger

#custom_cmd
