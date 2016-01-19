#!/usr/bin/python


import sys
import requests




if len(sys.argv) < 4:
    print "ERROR: TOOLCHAIN_ID, BEARER, or PROJECT_NAME are not defined."
    exit(1)
    
    
TOOLCHAIN_ID = sys.argv[1]
BEARER = sys.argv[2]
PROJECT_NAME = sys.argv[3]
DRA_SERVICE_NAME = 'draservicebroker'
DRA_PRESENT = False



try:
    r = requests.get( 'https://devops-api.stage1.ng.bluemix.net/v1/toolchains/' + TOOLCHAIN_ID + '?include=metadata', headers={ 'Authorization': BEARER })
    
    data = r.json()

    for items in data[ 'items' ]:
        #print items[ 'name' ]
        if items[ 'name' ] == PROJECT_NAME:
            #print items[ 'name' ]
            for services in items[ 'services' ]:
                #print services[ 'service_id' ]
                if services[ 'service_id' ] == DRA_SERVICE_NAME:
                    #print services[ 'service_id' ]
                    DRA_PRESENT = True
except requests.exceptions.RequestException as e:    # This is the correct syntax
    print 'ERROR: ', e
    print 'DRA was disabled for this session.'
    
    
    

                
if DRA_PRESENT:
    exit(0)
else:
    exit(1)