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
    echo "+-----------------+" && \
    echo "| Install kubectl |" && \
    echo "+-----------------+" && \
    apk add --update ca-certificates && \
    curl -L https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl && \
    chmod +x /usr/local/bin/kubectl && \
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
ENV WORKING_DIR /usr/local/bin/acme-cert-renewal

# Copy files
COPY include/ $WORKING_DIR/

# Make files executable
RUN find $WORKING_DIR/ -type f -exec chmod +x {} \;

# Expose the DNS port
EXPOSE 53/tcp
EXPOSE 53/udp

# Start the entrypoint script (NOTE: keep this path in sync with $WORKING_DIR)
ENTRYPOINT ["/usr/local/bin/acme-cert-renewal/entrypoint.sh"]

# Define defaults to the entrypoint script
CMD [ \
    # Domain to get the certificate for
    "test.com", \
    # Authentication domain (this is where the TXT records will be created)
    "auth.test.com", \
    # The name of the Kubernetes TLS secret that will be created
    "tls-secret", \
    # The Kubernetes namespace in which to create the TLS secret
    "default", \
    # Use the production ACME server? true/false
    "false", \
    # The email address that will be used to register with the ACME server
    "admin@test.com" \
]