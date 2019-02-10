#!/bin/sh

# Absolute path to this script
SCRIPT=$(readlink -f "$0")
# Absolute path this script is in
SCRIPTPATH=$(dirname "$SCRIPT")
# Throw an exception if $WORKING_DIR is not the same as $SCRIPTPATH
if [ $SCRIPTPATH != $WORKING_DIR ]; then
    printf "\$WORKING_DIR must be equal to '$SCRIPTPATH', but it is set to '%s'" "$WORKING_DIR" >&2
    exit 1
fi

# Arguments
export DOMAIN=$DOMAIN
export AUTH_DOMAIN=$AUTH_DOMAIN
export CERT_EMAIL=$CERT_EMAIL
export DEPLOY_HOOK=$DEPLOY_HOOK

# Validate arguments
if [ -z "$DOMAIN" ]; then
    echo "ERROR: A domain for the certificate was not specified" >&2
    exit 1
fi

if [ -z "$AUTH_DOMAIN" ]; then
    echo "ERROR: An authentication domain for the certificate challenge was not specified" >&2
    exit 1
fi

if [ -z "$CERT_EMAIL" ]; then
    echo "ERROR: An email address for the certificate was not specified" >&2
    exit 1
fi

if [ -z "$DEPLOY_HOOK" ]; then
    DEPLOY_HOOK=$WORKING_DIR/deploy_hook.pl
    echo "WARNING: A deploy-hook command was not specified... defaulting to: '$DEPLOY_HOOK'" >&2
fi

# ACME server (certificate authority)
export ACME_SERVER=${ACME_SERVER:-https://acme-staging-v02.api.letsencrypt.org/directory}
# Certificate challenge auth subdomain
export CERT_CHALLENGE_SUBDOMAIN=${CERT_CHALLENGE_SUBDOMAIN:-_acme-challenge}
# Certificate challenges environment variable (one challenge token per line)
export CERT_CHALLENGES_FILE=$WORKING_DIR/cert_challenges.txt
# Cert hooks command for dehydrated
export CERT_HOOKS=$WORKING_DIR/cert_hooks.pl
# Config file for dehydrated
export DEHYDRATED_CONFIG=$WORKING_DIR/dehydrated_config.sh
# PowerDNS hooks
export PDNS_HOOKS=$WORKING_DIR/pdns_backend.pl
# PowerDNS log file
export PDNS_LOG=$WORKING_DIR/pdns.log

# Dehydrated working directory
export CERT_WORKING_DIR=${CERT_WORKING_DIR:-$WORKING_DIR/dehydrated}
# Domains file for dehydrated
export CERT_DOMAINS_TXT=$CERT_WORKING_DIR/domains.txt
# Cert output directory
export CERT_DIR=$CERT_WORKING_DIR/certs/$DOMAIN
# Account output directory
export ACCOUNTS_DIR=$CERT_WORKING_DIR/accounts

echo ""
echo "========="
echo "Certificate domain:       $DOMAIN"
echo "Authentication domain:    $AUTH_DOMAIN"
echo "ACME challenge domain:    $CERT_CHALLENGE_SUBDOMAIN"
echo "ACME server:              $ACME_SERVER"
echo "Cert email address:       $CERT_EMAIL"
echo "Deploy-hook:              $DEPLOY_HOOK"
echo "========="
echo ""

# Create CERT_WORKING_DIR if it doesn't exist
mkdir -p $CERT_WORKING_DIR

# Write domains.txt
echo "$DOMAIN *.$DOMAIN" > $CERT_DOMAINS_TXT

# Write cert_challenges.txt
echo "" > $CERT_CHALLENGES_FILE

# Start PowerDNS server for ACME DNS-01 auth challenge
pdns_server \
    --no-config \
    --loglevel=10 --log-dns-queries --log-dns-details \
    --daemon=no \
    --local-address=0.0.0.0 --local-port=53 \
    --launch=pipe --pipe-command=$PDNS_HOOKS &>$PDNS_LOG &
PDNS_PID=$!

# Wait for some time in case PowerDNS took longer than usual to start
sleep 3

# Print out the startup log of PowerDNS
echo ""
echo "+--------------------+"
echo "| Start PowerDNS log |"
echo "+--------------------+"
cat $PDNS_LOG
echo "+------------------+"
echo "| End PowerDNS log |"
echo "+------------------+"
echo ""

# Make sure PowerDNS started successfully
if ! kill -s 0 $PDNS_PID; then
    echo "Failed to start PowerDNS" >&2
    exit 1
fi

# Allow user to continue when ready if debug mode is on
if ! [ -z "$DEBUG" ]; then
    echo "Debug mode is on - starting shell... run 'exit' to continue, or 'exit 1' to stop"
    sh
    if [ $? -ne 0 ]; then
        exit $?
    fi
fi

# If we didn't have any account info, register an account with the ACME server
echo ""
echo "+--------------------------------+"
echo "| Start ACME server registration |"
echo "+--------------------------------+"
echo "Registering with the ACME server using dehydrated"
dehydrated --register --accept-terms --config $DEHYDRATED_CONFIG
echo "Finished registering with $ACME_SERVER"
echo "+------------------------------+"
echo "| End ACME server registration |"
echo "+------------------------------+"
echo ""

# Get/renew the certificate and call post-hook if it succeeds
echo ""
echo "+----------------------------------+"
echo "| Start generate/renew certificate |"
echo "+----------------------------------+"
echo "Running dehydrated to get/renew certificate"
dehydrated --cron --config $DEHYDRATED_CONFIG
echo "Finished running dehydrated"
echo "+--------------------------------+"
echo "| End generate/renew certificate |"
echo "+--------------------------------+"
echo ""

# If debug mode is on, don't quit - print PowerDNS log output so requests/responses can be monitored
if ! [ -z "$DEBUG" ]; then
    echo "Debug mode is on - PowerDNS will continue to run and log output will be shown below..."
    tail -f $PDNS_LOG
fi

# Kill the PowerDNS server
kill $PDNS_PID
echo "Stopped PowerDNS server"

# Print out the complete runtime log of PowerDNS
echo ""
echo "+--------------------+"
echo "| Start PowerDNS log |"
echo "+--------------------+"
cat $PDNS_LOG
echo "+------------------+"
echo "| End PowerDNS log |"
echo "+------------------+"
echo ""