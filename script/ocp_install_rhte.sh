#!/bin/sh
sudo iptables -F

sleep 10s

# Run following as 'opentlc-mgr' 

# Following Env variables should exist:

REGION=0b11
OCP_DOMAIN=rhte.opentlc.com
OCP_SUFFIX=apps.$REGION.$OCP_DOMAIN

# Start and End tenants.
START_TENANT=1
END_TENANT=10

 OPENSHIFT_MASTER=https://master.$REGION.$OCP_DOMAIN

 SSO_HOSTNAME_HTTP=sso-unsecured.$OCP_SUFFIX
 SSO_HOSTNAME_HTTPS=sso.$OCP_SUFFIX
 APICURIO_UI_ROUTE=apicurio-studio.$OCP_SUFFIX
 APICURIO_API_ROUTE=apicurio-studio-api.$OCP_SUFFIX
 APICURIO_WS_ROUTE=apicurio-studio-ws.$OCP_SUFFIX
 MICROCKS_ROUTE_HOSTNAME=microcks.$OCP_SUFFIX
 OPENSHIFT_OAUTH_CLIENT_NAME=laboauth

 KEYCLOAK_ROUTE_HOSTNAME=$SSO_HOSTNAME_HTTP

# For All SSO installs, default username & password:
 SSO_ADMIN_USERNAME=admin
 SSO_ADMIN_PASSWORD=password

# For RHDM, Fixed values:

 APPLICATION_NAME=quoting
 KIE_ADMIN_USER=admin
 KIE_ADMIN_PWD=password
 KIE_SERVER_USER=user
 KIE_SERVER_PWD=password
 KIE_SERVER_CONTAINER_DEPLOYMENT=quoting=com.redhat:insuranceQuoting:1.0.1
 SOURCE_REPOSITORY_URL=https://github.com/gpe-mw-training/rhte-api-as-business-labs
 SOURCE_REPOSITORY_REF=master
 CONTEXT_DIR=services/InsuranceQuoting

### IMPORT IMAGE STREAMS

# Red Hat Decision Manager

oc create -f https://raw.githubusercontent.com/jboss-container-images/rhdm-7-openshift-image/7.0.x/rhdm70-image-streams.yaml -n openshift

## Other necessary image streamsi (already installed):
# Syndesis
# RH SSO 7.2
# Fuse 7.0
# Apicurio
# Microcks
# NodeJS


### IMPORT TEMPLATES


# Red Hat Decision Manager S2I Template

oc delete template rhdm70-kieserver-basic-s2i -n openshift

sleep 5s;

oc create -f https://raw.githubusercontent.com/gpe-mw-training/rhte-api-as-business-labs/master/templates/rhdm70-kieserver-basic-s2i.yaml -n openshift

#Red Hat SSO 7.2 Ephimeral

oc delete template sso72-x509-https -n openshift

sleep 5s;

oc create -f  https://raw.githubusercontent.com/pszuster/3ScaleTD/master/templates/sso72-x509-https.json -n openshift

# NodeJS S2I template

oc delete template quoting-app -n openshift

sleep 5s;

oc create -f https://raw.githubusercontent.com/gpe-mw-training/rhte-api-as-business-labs/master/templates/nodejs-quoting-app-template.json -n openshift


### Create project 'rhdm'

oc adm new-project rhdm --admin=opentlc-mgr --description="Insurance Quote Rules engine decision manager."

oc project rhdm

oc new-app  --name=quoting --template rhdm70-kieserver-basic-s2i  --param=APPLICATION_NAME=$APPLICATION_NAME  --param=KIE_ADMIN_USER=$KIE_ADMIN_USER --param=KIE_ADMIN_PWD=$KIE_ADMIN_PWD --param=KIE_SERVER_USER=$KIE_SERVER_USER --param=KIE_SERVER_PWD=$KIE_SERVER_PWD --param=KIE_SERVER_CONTAINER_DEPLOYMENT=$KIE_SERVER_CONTAINER_DEPLOYMENT --param=SOURCE_REPOSITORY_URL=$SOURCE_REPOSITORY_URL --param=SOURCE_REPOSITORY_REF=$SOURCE_REPOSITORY_REF --param=CONTEXT_DIR=$CONTEXT_DIR

sleep 60s;

## LOOP FOR TENANTS

# loops from START_TENANT to END_TENANT to create tenant projects and applications.
# Each user is given admin rights to their corresponding projects.


    for i in $(seq $START_TENANT $END_TENANT) ; do

	   
	tenantId=user$i;

	echo "Now starting deployment for user :" $tenantId;

        # Give users view access to the infra projects lab-infra & rhdm

	oc adm policy add-role-to-user view $tenantId -n api-lifecycle
	oc adm policy add-role-to-user view $tenantId -n rhdm

	# Create project for user sso (ephemeral)

        oc adm new-project $tenantId-sso --admin=$tenantId  --description=$tenantId 

	sleep 5s;

	# Install SSO (ephemeral)

	oc project $tenantId-sso
	sleep 5s;
	oc create serviceaccount sso-service-account
	oc policy add-role-to-user view system:serviceaccount:$tenantId-sso:sso-service-account

	oc new-app --template=sso72-x509-https --param HOSTNAME_HTTP=$tenantId-sso-unsecured.$OCP_SUFFIX --param HOSTNAME_HTTPS=$tenantId-sso.$OCP_SUFFIX --param SSO_ADMIN_USERNAME=admin --param SSO_ADMIN_PASSWORD=password --param SSO_SERVICE_USERNAME=admin --param SSO_SERVICE_PASSWORD=password --param SSO_REALM=3scaleRealm

	sleep 60s;
	# Create project for Syndesis


        oc adm new-project $tenantId-fuse-ignite --admin=$tenantId  --description=$tenantId 

	sleep 5s;

	# Install Syndesis

	oc project $tenantId-fuse-ignite

	bash install-syndesis --setup

	bash install-syndesis --grant $tenantId

	bash install-syndesis --route $tenantId-fuse-ignite.$OCP_SUFFIX --open --tag=1.5.4-20180910


	# Create NodeJS client project

        oc adm new-project $tenantId-client --admin=$tenantId  --description=$tenantId 
	sleep 5s;

	# Create Gateway Routes

	oc project $tenantId-gw
	sleep 5s;
	# Delete the default route created
	oc delete route --all

	# Provision new routes for Quoting app

	oc create route edge quote-stage --service="stage-apicast" --hostname=$tenantId-quote-stage.$OCP_SUFFIX  
	oc create route edge quote-prod --service="prod-apicast" --hostname=$tenantId-quote-prod.$OCP_SUFFIX  

	# Resume deployment of apicast gateways

	oc rollout resume deployment stage-apicast

	oc rollout resume deployment prod-apicast



    done;	
