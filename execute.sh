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

	export CF_TOKEN=$(sed -e 's/^.*"AccessToken":"\([^"]*\)".*$/\1/' ~/.cf/config.json)
	chmod 777 ${EXT_DIR}/*.py
    ${EXT_DIR}/is_dra_there.py ${PIPELINE_TOOLCHAIN_ID} "${CF_TOKEN}" "${IDS_PROJECT_NAME}"
	IS_DRA_RESULT=$?
	
	if [ $IS_DRA_RESULT -eq 0 ]; then
		echo "DRA is present";
		dra_commands "${DRA_SERVICE_LIST}"
	else
		echo "DRA is not present";
		return 0
	fi
}

function dra_commands {

	npm install grunt
    npm install grunt-cli
	npm install grunt-idra2
    dra_grunt_command=""
	
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
		#echo -e "\nEvent Variable: $event_variable"
		
		event_to_file='echo $event_variable > deployInfo.json'
		eval $event_to_file
		#echo -e "\nEvent file created:"
		#cat deployInfo.json
		
		send_event='grunt --gruntfile=node_modules/grunt-idra2/idra.js -eventType=deployInfo -file=deployInfo.json'
		echo -e "\nSending deployInfo event to iDRA ..."
		echo -e "${no_color}"
		eval $send_event
		echo -e "${no_color}"
		
		if [ ${DRA_ENABLE_BOUND_SERVICE} == true ]; then
		
			echo -e "\nChecking status of services bound to this application ...\n"
			
			criteria_variable='{ "name": "DRADeploy_BOUND_COMPARE", "revision": 2, "project": "key", "mode": "decision", "rules": [ { "name": "Check for bound services", "conditions": [ { "eval": "_areApplicationBoundServicesAvailable", "op": "=", "value": true } ] } ] }'
			echo -e "\nCriteria Variable: $criteria_variable"
			
			criteria_to_file='echo $criteria_variable > criteriafile.json'
			eval $criteria_to_file
			echo -e "\nCriteria created:\n"
			cat criteriafile.json
			
			get_decision='grunt --gruntfile=node_modules/grunt-idra2/idra.js -decision=dynamic -criteriafile=criteriafile.json'
			echo -e "\nRequesting decision from API...\n"
			eval $get_decision
			RESULT2=$?
			echo -e "Result of check bound services: $RESULT2"
		else
			RESULT2=0
			echo -e "\nSkipping 'Bound Services' check ...\n"
        fi
		
		if [ ${DRA_ENABLE_COMPARE_APPS} == true ]; then
			echo -e "\nComparing applications now ...\n"
			event_name="$(echo -e "${IDS_STAGE_NAME}" | tr -d '[[:space:]]')"
			event_name+='_'
			event_name+="$(echo -e "${IDS_JOB_NAME}" | tr -d '[[:space:]]')"
			
			send_manifest_event='grunt --gruntfile=node_modules/grunt-idra2/idra.js -eventType='
			send_manifest_event+=$event_name
			send_manifest_event+=' -file='
			send_manifest_event+=${DRA_MANIFEST_FILE}
			echo -e "\nEvent created: $send_manifest_event\n"
			echo -e "\nSending event to iDRA ...\n"
			eval $send_manifest_event
		else
			RESULT3=0
			echo -e "\nSkipping 'Compare deployments' check ...\n"
        fi
		
		if [ -n "$1" ] && [ "$1" != " " ]; then
			echo -e "Estado service list: $1 is defined and not empty"
			estado_criteria_variable='{ "name": "DRADeploy_ESTADO_CHECK", "revision": 2, "project": "key", "mode": "decision", "rules": [ { "name": "Check for Estado Services", "conditions": [ { "eval": "_isEnvironmentListPassing('
			estado_criteria_variable+=$1
			estado_criteria_variable+=')", "op": "=", "value": true } ] } ] }'
			
			estado_criteria_to_file='echo $estado_criteria_variable > estadocriteriafile.json'
			eval $estado_criteria_to_file
			echo -e "\nEstado criteria file:\n"
			cat estadocriteriafile.json
			
						
			#dra_grunt_command='grunt --gruntfile=node_modules/grunt-idra2/idra.js -statusCheck="'
			#dra_grunt_command+=$1
			#dra_grunt_command+='"'
			dra_grunt_command='grunt --gruntfile=node_modules/grunt-idra2/idra.js -decision=dynamic -criteriafile=estadocriteriafile.json'
			echo -e "\nFinal command sent to grunt-iDRA to check Estado Services:\n"
			echo -e $dra_grunt_command
			
			echo -e "${no_color}"
			eval $dra_grunt_command
			RESULT1=$?
			echo -e "${no_color}"
			
			#echo -e "Result of check Estado services: $RESULT1"
			
			if [[ $RESULT1 != 0 && $DRA_ATTEMPT_MAX -ge 1 ]]; then 
				echo -e "\nTRYING MULTIPLE ATTEMPTS TO CHECK FOR SERVICE STATUS ...\n"
				ATTEMPT=1
			fi
			while [[ $RESULT1 -ne 0 && $ATTEMPT -ge 1 && $ATTEMPT -le $DRA_ATTEMPT_MAX ]]
			do
				sleep 6
				echo -e "${no_color}"
				eval $dra_grunt_command
				RESULT1=$?
				echo -e "${no_color}"
				
				echo -e "Result of attempt #$ATTEMPT: $RESULT1"
				ATTEMPT=`expr $ATTEMPT + 1`
			done
		else
			RESULT1=0
			echo -e "Service List is not defined or is empty .. proceeding with deployment ..."
		fi
		
		if [[ $RESULT1 != 0 || $RESULT2 != 0 ]]; then
			return 1
		else
			return 0
		fi

}

dra_logger

#custom_cmd