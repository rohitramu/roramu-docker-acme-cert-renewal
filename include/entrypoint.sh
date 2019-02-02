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

# Certificate challenges folder
export CERT_CHALLENGE_DIR=$WORKING_DIR/cert_challenges

# Certificate output directory
export CERT_DIR=$WORKING_DIR/certs

# Cert hooks file for dehydrated
export CERT_HOOKS=$WORKING_DIR/cert_hooks.sh

# Domains file for dehydrated
export DOMAINS_TXT=$WORKING_DIR/domains.txt

# Config file for dehydrated
export DEHYDRATED_CONFIG=$WORKING_DIR/dehydrated_config.sh

# PowerDNS hooks
export PDNS_HOOKS=$WORKING_DIR/pdns.pl

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

# Start PowerDNS server for ACME DNS-01 auth challenge
nohup pdns_server --no-config --daemon=no --local-address=0.0.0.0 --local-port=53 --launch=pipe --pipe-command=$PDNS_HOOKS &>pdns.log &
sleep 2

# Write domains.txt
echo "$DOMAIN *.$DOMAIN" > $DOMAINS_TXT

# Create the CERT_CHALLENGE_DIR if it doesn't exist
mkdir -p $CERT_CHALLENGE_DIR

# Get/renew cert for the domain
dehydrated --register --accept-terms --config $DEHYDRATED_CONFIG
dehydrated --cron --config $DEHYDRATED_CONFIG

/bin/sh