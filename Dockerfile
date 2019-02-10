#
# +-------+
# | USAGE |
# +-------+
# - Files inside the directory specified by the $CERT_WORKING_DIR environment variable should be persisted between runs (e.g. with volumes).
# - The ENTRYPOINT command SHOULD NOT be overridden in child images.
# - Arguments to "docker run" SHOULD be provided in the following order:
#     1. Domain name for which a certificate should be generated/renewed.
#     2. Authentication domain, where the DNS challenge will take place (i.e. TXT records are created here).
#     3. The email address to be included in the certificate.
#     4. The deploy-hook command.  In most cases, this should be a script which can deploy the generated
#        certificate given the location of required files.  The file locations will be provided as arguments
#        to the command in the following order:
#           1. The domain name on the certificate
#           2. Path to key file (privkey.pem)
#           3. Path to cert file (cert.pem)
#           4. Path to the full chain file (fullchain.pem)
#           5. Path to the chain file (chain.pem)
# - The only port required to be open to the internet is port 53 (both TCP and UDP), as the DNS server will
#   be listening on that port.
#

FROM alpine:latest

# WARNING: These environment variables should NOT be overridden by child images.
# The main working directory
ENV WORKING_DIR=/usr/local/bin/acme-cert-renewal
# The certificate working directory, where certs will be stored between runs of this image.
ENV CERT_WORKING_DIR=$WORKING_DIR/cert_working_dir

# Environment variables that can be set to alter the runtime configuration
ENV \
    # Set $DEBUG to any non-empty value to turn on debug mode
    DEBUG= \
    # Default subdomain that will contain the challenge TXT records
    CERT_CHALLENGE_SUBDOMAIN=_acme-challenge \
    # ACME server.  For reference, "Let's Encrypt" v2 certificate authority URLs are:
    #   Staging:    https://acme-staging-v02.api.letsencrypt.org/directory
    #   Production: https://acme-v02.api.letsencrypt.org/directory
    ACME_SERVER=https://acme-staging-v02.api.letsencrypt.org/directory

# Environment variables that SHOULD be set by users at runtime
ENV \
    # The domain that is/will be on the certificate.
    # A wildcard certificate will be generated, meaning all subdomains are also included.
    DOMAIN= \
    # Authentication domain (this is where the TXT records will be created).
    # The authentication domain does not need to be a subdomain of the certificate domain.
    AUTH_DOMAIN= \
    # The email address that will be used to register with the ACME server
    CERT_EMAIL= \
    # Deploy-hook command which can be used to deploy certificate files.
    # Remember to use RUN commands to install necessary packages.
    # The given command will be passed arguments in the following order:
    #   1. The domain name on the certificate
    #   2. Path to key file (privkey.pem)
    #   3. Path to cert file (cert.pem)
    #   4. Path to the full chain file (fullchain.pem)
    #   5. Path to the chain file (chain.pem)
    DEPLOY_HOOK=

# Setup environment
RUN echo "" && \
    # Install build tools
    echo "" && \
    echo "+----------------------------+" && \
    echo "| Install build dependencies |" && \
    echo "+----------------------------+" && \
    apk add --update -t deps jq && \
    echo "" && \
    echo "" && \
    # Install runtime tools
    echo "+--------------+" && \
    echo "| Install bash |" && \
    echo "+--------------+" && \
    apk add bash && \
    echo "" && \
    echo "" && \
    echo "+--------------+" && \
    echo "| Install perl |" && \
    echo "+--------------+" && \
    apk add perl && \
    echo "" && \
    echo "" && \
    echo "+--------------+" && \
    echo "| Install curl |" && \
    echo "+--------------+" && \
    apk add curl && \
    echo "" && \
    echo "" && \
    echo "+-----------------+" && \
    echo "| Install openssl |" && \
    echo "+-----------------+" && \
    apk add openssl && \
    echo "" && \
    echo "" && \
    echo "+--------------------+" && \
    echo "| Install dehydrated |" && \
    echo "+--------------------+" && \
    mkdir dehydrated && \
    curl -L $(curl -L https://api.github.com/repos/lukas2511/dehydrated/releases/latest | jq -r ".assets[] | select(.name | endswith(\"tar.gz\")) | .browser_download_url") -o dehydrated/dehydrated.tar.gz && \
    tar -xvzf dehydrated/dehydrated.tar.gz -C dehydrated/ && \
    find /dehydrated -type f -name dehydrated -exec mv {} /usr/local/bin/ \; && \
    chmod +x /usr/local/bin/dehydrated && \
    rm -rf /dehydrated/ && \
    echo "+------------------+" && \
    echo "| Install PowerDNS |" && \
    echo "+------------------+" && \
    apk add pdns && \
    apk add pdns-backend-pipe && \
    echo "" && \
    echo "" && \
    # Clean up
    echo "+--------------------------+" && \
    echo "| Clean build dependencies |" && \
    echo "+--------------------------+" && \
    apk del --purge deps && \
    echo "" && \
    echo "" && \
    echo "+---------------------+" && \
    echo "| Clean package cache |" && \
    echo "+---------------------+" && \
    rm /var/cache/apk/* && \
    echo "" && \
    echo "" && \
    echo "+------------------------------+" && \
    echo "| Finished installing packages |" && \
    echo "+------------------------------+" && \
    echo ""

# Set working directory
WORKDIR $WORKING_DIR

# Copy files
COPY include/ .

# Make included files executable
RUN find ./ -type f -exec chmod +x {} \;

# Expose the DNS port
EXPOSE 53/tcp 53/udp

# Start the entrypoint script
ENTRYPOINT $WORKING_DIR/entrypoint.sh