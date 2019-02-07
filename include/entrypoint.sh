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

#ACME_SERVER_PROD=https://acme-v02.api.letsencrypt.org/directory
#ACME_SERVER_STAGING=https://acme-staging-v02.api.letsencrypt.org/directory

# Arguments
export DOMAIN=${1:-not.defined.com}
export AUTH_DOMAIN=${2:-auth-not-defined.com}
export ACME_SERVER=${3:-https://acme-staging-v02.api.letsencrypt.org/directory}
export CERT_EMAIL=${4:-admin@not-defined.com}
export HOOK_DEPLOY=$(eval echo ${5:-$WORKING_DIR/deploy_hook.pl})
export HOOK_PRE=${6:-echo "No pre-hook defined"}
export HOOK_POST=${7:-echo "No post-hook defined"}

# Certificate challenge auth subdomain
export CERT_CHALLENGE_SUBDOMAIN=_acme-challenge

# Certificate challenges environment variable (one challenge token per line)
export CERT_CHALLENGES_FILE=$WORKING_DIR/cert_challenges.txt

# Cert hooks command for dehydrated
export CERT_HOOKS=$WORKING_DIR/cert_hooks.pl

# Config file for dehydrated
export DEHYDRATED_CONFIG=$WORKING_DIR/dehydrated_config.sh

# PowerDNS hooks
export PDNS_HOOKS=$WORKING_DIR/pdns.pl

# PowerDNS log file
export PDNS_LOG=$WORKING_DIR/pdns.log

# Dehydrated working directory
export CERT_WORKING_DIR=$WORKING_DIR/dehydrated

# Domains file for dehydrated
export CERT_DOMAINS_TXT=$CERT_WORKING_DIR/domains.txt

# Cert output directory
export CERT_DIR=$CERT_WORKING_DIR/certs/$DOMAIN

# Account output directory
export ACCOUNTS_DIR=$CERT_WORKING_DIR/accounts

echo ""
echo "========"
echo "Certificate will be generated for domain (and subdomains under): $DOMAIN"
echo "Authentication domain: $AUTH_DOMAIN"
echo "ACME challenge domain: $CERT_CHALLENGE_SUBDOMAIN"
echo "ACME server: $ACME_SERVER"
echo "ACME registration email address: $CERT_EMAIL"
echo "Deploy-hook: $HOOK_DEPLOY"
echo "Pre-hook: $HOOK_PRE"
echo "Post-hook: $HOOK_POST"
echo "========"
echo ""

# Create CERT_WORKING_DIR if it doesn't exist
mkdir -p $CERT_WORKING_DIR

# Write domains.txt
echo "$DOMAIN *.$DOMAIN" > $CERT_DOMAINS_TXT

# Start PowerDNS server for ACME DNS-01 auth challenge
nohup pdns_server --no-config --daemon=no --local-address=0.0.0.0 --local-port=53 --launch=pipe --pipe-command=$PDNS_HOOKS &>$PDNS_LOG &
PDNS_PID=$!

# Wait for some time in case PowerDNS took longer than usual to start
sleep 2

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

# Hook that can be used to load account and cert info into $CERT_WORKING_DIR
echo ""
echo "+----------------+"
echo "| Start pre-hook |"
echo "+----------------+"
$HOOK_PRE "$CERT_WORKING_DIR"
echo "+--------------+"
echo "| End pre-hook |"
echo "+--------------+"
echo ""

# If we didn't have any account info, register an account with the ACME server
echo "Registering with the ACME server using dehydrated"
dehydrated --register --accept-terms --config $DEHYDRATED_CONFIG
echo "Finished registering with $ACME_SERVER"

# Get/renew the certificate and call post-hook if it succeeds
echo "Running dehydrated to get/renew certificate"
dehydrated --cron --config $DEHYDRATED_CONFIG
echo "Finished running dehydrated"

# Kill the PowerDNS server
kill $PDNS_PID
echo "Stopped PowerDNS server"
