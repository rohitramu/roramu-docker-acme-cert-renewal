#!/bin/sh

# Validate constant environment variables
if [ -z "$WORKING_DIR" ]; then
    echo "ERROR: A working directory was not specified" >&2
    exit 1
fi

if [ -z "$CERT_WORKING_DIR" ]; then
    echo "ERROR: A working directory for certificate generation was not specified" >&2
    exit 1
fi

# $CERT_WORKING_DIR should not be a subdirectory of $WORKING_DIR
if [ "${CERT_WORKING_DIR##$WORKING_DIR}" != "$CERT_WORKING_DIR" ]; then
    echo "ERROR: \$CERT_WORKING_DIR must not be a subdirectory of \$WORKING_DIR" >&2
    echo "    \$WORKING_DIR = $WORKING_DIR" >&2
    echo "    \$CERT_WORKING_DIR = $CERT_WORKING_DIR" >&2
    exit 1
fi

# Absolute path to this script
SCRIPT=$(readlink -f "$0")
# Absolute path this script is in
SCRIPTPATH=$(dirname "$SCRIPT")
# Throw an exception if $WORKING_DIR is not the same as $SCRIPTPATH
if [ $SCRIPTPATH != $WORKING_DIR ]; then
    printf "\$WORKING_DIR must be equal to '$SCRIPTPATH', but it is set to '%s'" "$WORKING_DIR" >&2
    exit 1
fi

# Validate user-provided environment variables
if [ -z "$ACME_SERVER" ]; then
    echo "ERROR: An ACME server URL was not specified" >&2
    exit 1
fi

if [ -z "$CERT_CHALLENGE_SUBDOMAIN" ]; then
    echo "ERROR: An ACME challenge subdomain was not specified" >&2
    exit 1
fi

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
    echo "WARNING: A deploy-hook command was not specified... defaulting to: '$DEPLOY_HOOK'"
fi

if [ -z "$LOAD_HOOK" ] || [ -z "$SAVE_HOOK" ]; then
    DEFAULT_LOAD_HOOK=$WORKING_DIR/load_hook.sh
    DEFAULT_SAVE_HOOK=$WORKING_DIR/save_hook.sh

    if [ -z "$LOAD_HOOK" ]; then
        echo "WARNING: A load-hook command was not specified... defaulting to: '$DEFAULT_LOAD_HOOK'"
    else
        echo "WARNING: A load-hook command was found, but no save-hook was specified... defaulting to: '$DEFAULT_LOAD_HOOK'"
    fi

    if [ -z "$SAVE_HOOK" ]; then
        echo "WARNING: A save-hook command was not specified... defaulting to: '$DEFAULT_SAVE_HOOK'"
    else
        echo "WARNING: A save-hook command was found, but no load-hook was specified... defaulting to: '$DEFAULT_SAVE_HOOK'"
    fi

    LOAD_HOOK=$WORKING_DIR/load_hook.sh
    SAVE_HOOK=$WORKING_DIR/save_hook.sh
fi

# Certificate challenges environment variable (one challenge token per line)
export CERT_CHALLENGES_FILE=$WORKING_DIR/cert_challenges.txt
# Cert hooks command for dehydrated
export CERT_HOOKS=$WORKING_DIR/cert_hooks.pl
# Config file for dehydrated
export DEHYDRATED_CONFIG=$WORKING_DIR/dehydrated_config.sh
# Domains file for dehydrated
export CERT_DOMAINS_TXT=$WORKING_DIR/domains.txt
# PowerDNS hooks
export PDNS_HOOKS=$WORKING_DIR/pdns_backend.pl

# Temp dehydrated working directory
export TEMP_CERT_WORKING_DIR=$WORKING_DIR/dehydrated
# Cert output directory
export CERT_DIR=$TEMP_CERT_WORKING_DIR/certs/$DOMAIN
# Account output directory
export ACCOUNTS_DIR=$TEMP_CERT_WORKING_DIR/accounts
# PowerDNS log file
export PDNS_LOG=$TEMP_CERT_WORKING_DIR/pdns.log
# Deploy log file
export DEPLOY_LOG=$TEMP_CERT_WORKING_DIR/deploy.log
# Deploy error log file
export DEPLOY_LOG_ERR=$DEPLOY_LOG.err

echo ""
echo "========="
echo "Working directory:            $WORKING_DIR"
echo "Persisted directory:          $CERT_WORKING_DIR"
echo ""
echo "Certificate domain:           $DOMAIN"
echo "Authentication domain:        $AUTH_DOMAIN"
echo "ACME challenge subdomain:     $CERT_CHALLENGE_SUBDOMAIN"
echo ""
echo "ACME server:                  $ACME_SERVER"
echo "Cert email address:           $CERT_EMAIL"
echo ""
echo "Deploy-hook:                  $DEPLOY_HOOK"
echo "========="
echo ""

# Create $CERT_WORKING_DIR if it doesn't exist
mkdir -p $CERT_WORKING_DIR

# Load persisted data to the directory
echo ""
echo "+-----------------+"
echo "| Start load-hook |"
echo "+-----------------+"
$LOAD_HOOK "$CERT_WORKING_DIR"
echo "+---------------+"
echo "| End load-hook |"
echo "+---------------+"
echo ""

# Make sure the temp directory exists and is empty
mkdir -p $TEMP_CERT_WORKING_DIR
rm -rf $TEMP_CERT_WORKING_DIR/*

# Copy contents of $CERT_WORKING_DIR to $TEMP_CERT_WORKING_DIR, resolving all symlinks
echo ""
echo "+-------------------------+"
echo "| Start copy loaded files |"
echo "+-------------------------+"
cp -LTR --verbose $CERT_WORKING_DIR $TEMP_CERT_WORKING_DIR/
echo "+-----------------------+"
echo "| End copy loaded files |"
echo "+-----------------------+"
echo ""

# Delete log files if they exist
rm -rf $PDNS_LOG
rm -rf $DEPLOY_LOG
rm -rf $DEPLOY_LOG_ERR

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
if [ "$DEBUG" = "true" ]; then
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

# Don't bother cleaning up or saving files if cert deployment never happened - i.e. there was a failure,
# or the cert didn't need to be created/renewed
if test -f $DEPLOY_LOG; then
    # Delete archived files and empty directories so cleaned up files don't get copied to the output directory
    rm -rf $TEMP_CERT_WORKING_DIR/archive
    find $TEMP_CERT_WORKING_DIR -type d -empty -delete

    # Clear the output directory
    rm -rf $CERT_WORKING_DIR/*

    # Copy contents of $TEMP_CERT_WORKING_DIR to $CERT_WORKING_DIR, resolving all symlinks
    echo ""
    echo "+------------------------------+"
    echo "| Start copy files to be saved |"
    echo "+------------------------------+"
    cp -LTR --verbose $TEMP_CERT_WORKING_DIR $CERT_WORKING_DIR/
    echo "+----------------------------+"
    echo "| End copy files to be saved |"
    echo "+----------------------------+"
    echo ""

    # Call the save-hook to persist the directory's contents
    echo ""
    echo "+-----------------+"
    echo "| Start save-hook |"
    echo "+-----------------+"
    $SAVE_HOOK "$CERT_WORKING_DIR"
    echo "+---------------+"
    echo "| End save-hook |"
    echo "+---------------+"
    echo ""
fi

# Print out the complete runtime log of PowerDNS
# If debug mode is on, don't quit - print PowerDNS log output so requests/responses can be monitored
if [ "$DEBUG" = "true" ]; then
    # Start watching logs
    echo "Debug mode is on - PowerDNS will continue to run and log output will be shown below (press <Ctrl-C> to continue)..."
    trap 'echo ""' INT

    echo ""
    echo "+--------------------+"
    echo "| Start PowerDNS log |"
    echo "+--------------------+"
    tail -f $PDNS_LOG
    echo "+------------------+"
    echo "| End PowerDNS log |"
    echo "+------------------+"
    echo ""

    # Kill the PowerDNS server after user stopped watching logs
    echo "Stopping PowerDNS server"
    kill $PDNS_PID
else
    # Kill the PowerDNS server before printing logs
    echo "Stopping PowerDNS server"
    kill $PDNS_PID

    # Print logs
    echo ""
    echo "+--------------------+"
    echo "| Start PowerDNS log |"
    echo "+--------------------+"
    cat $PDNS_LOG
    echo "+------------------+"
    echo "| End PowerDNS log |"
    echo "+------------------+"
    echo ""
fi
