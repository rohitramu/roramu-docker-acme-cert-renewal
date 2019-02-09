FROM alpine:latest

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

# Set environment variable to remember directory of copied files
ENV WORKING_DIR=/usr/local/bin/acme-cert-renewal
WORKDIR $WORKING_DIR

# Copy files
COPY include/ .

# Make included files executable
RUN find ./ -type f -exec chmod +x {} \;

# Expose the DNS port
EXPOSE 53/tcp 53/udp

# Set default subdomain that will contain the challenge TXT records, so it can be overridden in child images if required
ENV CERT_CHALLENGE_SUBDOMAIN=_acme-challenge

# Start the entrypoint script
ENTRYPOINT [ "sh", "-c", "exec $WORKING_DIR/entrypoint.sh $0 \"$@\"" ]

# Define defaults to the entrypoint script
CMD [ \
    # The domain that is/will be on the certificate.
    # A wildcard certificate will be generated, meaning all subdomains are also included.
    "test.com", \
    # Authentication domain (this is where the TXT records will be created).
    # The authentication domain does not need to be a subdomain of the certificate domain.
    "auth-test.com", \
    # ACME server.  For example, "Let's Encrypt" certificate authority URLs are:
    #   Staging:    https://acme-staging-v02.api.letsencrypt.org/directory
    #   Production: https://acme-v02.api.letsencrypt.org/directory
    "https://acme-staging-v02.api.letsencrypt.org/directory", \
    # The email address that will be used to register with the ACME server
    "admin@test.com", \
    # Deploy-hook command which can be used to deploy certificate files.
    # Remember to use RUN commands to install necessary packages.
    # The given command will be passed arguments in the following order:
    #   1. The domain name on the certificate
    #   2. Path to key file (privkey.pem)
    #   3. Path to cert file (cert.pem)
    #   4. Path to the full chain file (fullchain.pem)
    #   5. Path to the chain file (chain.pem)
    "perl $WORKING_DIR/deploy_hook.pl" \
    ]