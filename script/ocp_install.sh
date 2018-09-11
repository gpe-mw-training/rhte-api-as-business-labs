#!/bin/sh
sudo iptables -F

sleep 10s

# Run following as 'opentlc-mgr' 

# Following Env variables should exist:

REGION=f72e
OCP_DOMAIN=rhte.opentlc.com
OCP_SUFFIX=apps.$OCP_DOMAIN

# Start and End tenants.
START_TENANT=1
END_TENANT=5

 OPENSHIFT_MASTER=https://master.$REGION.$OCP_DOMAIN

 SSO_HOSTNAME_HTTP=sso-unsecured.$OCP_SUFFIX
 SSO_HOSTNAME_HTTPS=sso.$OCP_SUFFIX
 APICURIO_UI_ROUTE=apicurio-studio.$OCP_SUFFIX
 APICURIO_API_ROUTE=apicurio-studio-api.$OCP_SUFFIX
 APICURIO_WS_ROUTE=apicurio-studio-ws.$OCP_SUFFIX
 MICROCKS_ROUTE_HOSTNAME=microcks.$OCP_SUFFIX
 OPENSHIFT_OAUTH_CLIENT_NAME=laboauth

 KEYCLOAK_ROUTE_HOSTNAME=http://$SSO_HOSTNAME_HTTP/auth

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

# Red Hat SSO 7.2
oc create -f https://raw.githubusercontent.com/gpe-mw-training/rhte-api-as-business-labs/master/templates/sso72-x509-mysql-persistent.json -n openshift

# Apicurio Studio
oc create -f https://raw.githubusercontent.com/gpe-mw-training/rhte-api-as-business-labs/master/templates/apicurio-template.yml -n openshift

# Microcks
oc create -f https://raw.githubusercontent.com/gpe-mw-training/rhte-api-as-business-labs/master/templates/microcks-persistent-no-keycloak-template.yml -n openshift

# Red Hat Decision Manager S2I Template
oc create -f https://raw.githubusercontent.com/gpe-mw-training/rhte-api-as-business-labs/master/templates/rhdm70-kieserver-basic-s2i.yaml -n openshift

#Red Hat SSO 7.2 Ephimeral
oc create -f https://raw.githubusercontent.com/pszuster/3ScaleTD/master/templates/sso72-x509-https.json

# NodeJS S2I template
oc create -f https://raw.githubusercontent.com/gpe-mw-training/rhte-api-as-business-labs/master/templates/nodejs-quoting-app-template.json -n openshift

### Create Lab Infra project

oc adm new-project lab-infra --admin=opentlc-mgr --description="Lab Infrastructure project for SSO, Microcks & Apicurio Studio."

### Apicurio
oc new-app --template=apicurio-studio --param=AUTH_ROUTE=http://$HOSTNAME_HTTP/auth --param=UI_ROUTE=$APICURIO_UI_ROUTE --param=API_ROUTE=$APICURIO_API_ROUTE --param=WS_ROUTE=$APICURIO_WS_ROUTE --param=API_JVM_MAX=2000m --param=API_MEM_LIMIT=3000Mi --param=WS_JVM_MAX=2000m --param=WS_MEM_LIMIT=2500Mi --param=UI_JVM_MAX=1800m --param=UI_MEM_LIMIT=2500Mi

## RH SSO
oc create serviceaccount sso-service-account
oc policy add-role-to-user view system:serviceaccount:$(oc project -q):sso-service-account
oc new-app --template=sso72-x509-mysql-persistent --param=SSO_ADMIN_USERNAME=$SSO_ADMIN_USERNAME --param=SSO_ADMIN_PASSWORD=$SSO_ADMIN_PASSWORD  --param=HOSTNAME_HTTP=$SSO_HOSTNAME_HTTP -param=HOSTNAME_HTTPS=$SSO_HOSTNAME_HTTPS

sleep 30s

##  RH SSO Realms & OAuthClient
oc process -f https://raw.githubusercontent.com/gpe-mw-training/rhte-api-as-business-labs/master/templates/sso-oauth-realm-templates.yml--param=OPENSHIFT_MASTER=$OPENSHIFT_MASTER --param=KEYCLOAK_ROUTE_HOSTNAME=$KEYCLOAK_ROUTE_HOSTNAME --param=MICROCKS_ROUTE_HOSTNAME=$MICROCKS_ROUTE_HOSTNAME --param=APICURIO_UI_ROUTE_HOSTNAME=$APICURIO_UI_ROUTE_HOSTNAME --param=OPENSHIFT_OAUTH_CLIENT_NAME=$OPENSHIFT_OAUTH_CLIENT_NAME  | oc create -f -

## Microcks

oc new-app --template=microcks-persistent-no-keycloak --param=APP_ROUTE_HOSTNAME=$MICROCKS_ROUTE_HOSTNAME --param=KEYCLOAK_ROUTE_HOSTNAME=$KEYCLOAK_ROUTE_HOSTNAME

### Create project 'rhdm'

oc adm new-project rhdm --admin=opentlc-mgr --description="Insurance Quote Rules engine decision manager."

oc project rhdm

oc new-app  --name=quoting --template rhdm70-kieserver-basic-s2i  --param=APPLICATION_NAME=$APPLICATION_NAME  --param=KIE_ADMIN_USER=$KIE_ADMIN_USER --param=KIE_ADMIN_PWD=$KIE_ADMIN_PWD --param=KIE_SERVER_USER=$KIE_SERVER_USER --param=KIE_SERVER_PWD=$KIE_SERVER_PWD --param=KIE_SERVER_CONTAINER_DEPLOYMENT=$KIE_SERVER_CONTAINER_DEPLOYMENT --param=SOURCE_REPOSITORY_URL=$SOURCE_REPOSITORY_URL --param=SOURCE_REPOSITORY_REF=$SOURCE_REPOSITORY_REF --param=CONTEXT_DIR=$CONTEXT_DIR

## LOOP FOR TENANTS

# loops from START_TENANT to END_TENANT to create tenant projects and applications.
# Each user is given admin rights to their corresponding projects.


    for i in $(seq ${startTenant} ${endTenant}) ; do

	   
	tenantId = user$i;

        # Give users view access to the infra projects lab_infra & rhdm

	oc adm policy add-role-to-user view $tenantId -n lab_infra
	oc adm policy add-role-to-user view $tenantId -n rhdm

	# Create project for user sso (ephemeral)

        oc adm new-project $tenantId-sso --admin=$tenantId  --description=$tenantId 

	sleep 5s;

	# Install SSO (ephemeral)

	oc project $tenantId-sso
	oc create serviceaccount sso-service-account
	oc policy add-role-to-user view system:serviceaccount:$tenantId-sso:sso-service-account
	oc new-app --template=sso72-x509-https --param HOSTNAME_HTTP=$tenantId-sso-unsecured.$OCP_SUFFIX --param HOSTNAME_HTTPS=$tenantId-sso.$OC_SUFFIX --param SSO_ADMIN_USERNAME=admin --param SSO_ADMIN_PASSWORD=password --param SSO_SERVICE_USERNAME=admin --param SSO_SERVICE_PASSWORD=password --param SSO_REALM=3scaleRealm

	# Create project for Syndesis


        oc adm new-project $tenantId-fuse-ignite --admin=$tenantId  --description=$tenantId 

	sleep 5s;

	# Install Syndesis

	oc project $tenantId-fuse-ignite

	bash install-syndesis --setup

	bash install-syndesis --grant $tenantId

	bash install-syndesis --route $tenantId-fuse-ignite.$OCP_SUFFIX --open --tag=1.5.4-20180910


	# Create NodeJS project

        oc adm new-project $tenantId-nodejs --admin=$tenantId  --description=$tenantId 


    done;	
