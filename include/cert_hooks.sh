#!/usr/bin/env bash

# based on https://github.com/lukas2511/dehydrated/wiki/example-dns-01-nsupdate-script

set -e
set -u
set -o pipefail

case "$1" in
	"deploy_challenge")
		echo ""
		echo "Adding the following to the zone definition of ${2}:"
		echo "$CERT_CHALLENGE_SUBDOMAIN.${2}. IN TXT \"${4}\""
		echo ""
		echo "" > $CERT_CHALLENGE_DIR/$4
		echo ""
	;;
	"clean_challenge")
		echo ""
		echo "Removing the following from the zone definition of ${2}:"
		echo "$CERT_CHALLENGE_SUBDOMAIN.${2}. IN TXT \"${4}\""
		echo ""
		rm -f $CERT_CHALLENGE_DIR/$4
		echo ""
	;;
	"deploy_cert")
		echo ""
		echo "Deploying cert as secret '$SECRET_NAME' to Kubernetes namespace '$SECRET_NAMESPACE'"
		kubectl create secret tls $SECRET_NAME --key /etc/letsencrypt/live/*.${2}/privkey.key --crt /etc/letsencrypt/live/*.${2}/fullchain.crt --dry-run -o yaml | kubectl apply -f -
	;;
	"unchanged_cert")
		echo ""
		echo "Cert unchanged for domain: ${2}"
		echo ""
	;;
	*)
		echo "Unknown hook \"${1}\""
	;;
esac

exit 0