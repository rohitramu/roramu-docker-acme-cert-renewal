#!/bin/sh

ACME_SERVER_PROD=https://acme-v02.api.letsencrypt.org/directory
ACME_SERVER_STAGING=https://acme-staging-v02.api.letsencrypt.org/directory

# Arguments
export DOMAIN=${1:-example.com}
export AUTH_DOMAIN=${2:-acme-cert-renewal}
export SECRET_NAME=${3:-k8s-tls-secret}
export SECRET_NAMESPACE=${4:-default}
ACME_IS_PRODUCTION=${5:-false}
export CERT_EMAIL=${6:-admin@example.com}

# ACME Server URL
if [ $ACME_IS_PRODUCTION = true ]; then
    export ACME_SERVER=$ACME_SERVER_PROD
else
    export ACME_SERVER=$ACME_SERVER_STAGING
fi

# Certificate challenge auth subdomain
export CERT_CHALLENGE_SUBDOMAIN=_acme-challenge

# Certificate challenges environment variable (one challenge token per line)
export CERT_CHALLENGES_FILE=$WORKING_DIR/cert_challenges.txt

# Certificate output directory
export CERT_DIR=$WORKING_DIR/certs

# Cert hooks command for dehydrated
export CERT_HOOKS=$WORKING_DIR/cert_hooks.pl

# Domains file for dehydrated
export DOMAINS_TXT=$WORKING_DIR/domains.txt

# Config file for dehydrated
export DEHYDRATED_CONFIG=$WORKING_DIR/dehydrated_config.sh

# PowerDNS hooks
export PDNS_HOOKS=$WORKING_DIR/pdns.pl

# PowerDNS log file
export PDNS_LOG=$WORKING_DIR/pdns.log

echo ""
echo "========"
echo "Certificate will be generated for domains: \"$DOMAIN\" and \"*.$DOMAIN\""
echo "Authentication domain: $AUTH_DOMAIN"
echo "ACME challenge domain: $CERT_CHALLENGE_SUBDOMAIN"
echo "Kubernetes TLS secret name: $SECRET_NAME"
echo "ACME server: $ACME_SERVER"
echo "ACME registration email address: $CERT_EMAIL"
echo "========"
echo ""

# Write domains.txt
echo "$DOMAIN *.$DOMAIN" > $DOMAINS_TXT

# Start PowerDNS server for ACME DNS-01 auth challenge
nohup pdns_server --no-config --daemon=no --local-address=0.0.0.0 --local-port=53 --launch=pipe --pipe-command=$PDNS_HOOKS &>$PDNS_LOG &
PDNS_PID=$!

# Wait for some time in case PowerDNS took longer than usual to start
sleep 2

# Print out the startup log of PowerDNS
echo ""
echo "+--------------------+"
echo "| Start PowerDNS Log |"
echo "+--------------------+"
cat $PDNS_LOG
echo "+------------------+"
echo "| End PowerDNS Log |"
echo "+------------------+"
echo ""


# Get/renew cert for the domain
echo "Registering with Let's Encrypt using dehydrated"
dehydrated --register --accept-terms --config $DEHYDRATED_CONFIG
echo "Running dehydrated"
dehydrated --cron --config $DEHYDRATED_CONFIG
echo "Finished running dehydrated"

# Kill the PowerDNS server
kill $PDNS_PID
echo "Stopped PowerDNS server"
