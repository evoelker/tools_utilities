FROM docker:dind

# Install needed packages
RUN apk add --no-cache ca-certificates

# Create CA store for private repo certificate
RUN mkdir -p /etc/docker/certs.d/docker.home\:443

# Upload wiled-card cert CA chain
COPY ./docker-dind/docker.home.crt /etc/ssl/certs/
COPY ./docker-dind/docker.home.crt /etc/docker/certs.d/docker.home\:443/ca.crt

# Update certificate store
RUN cat /etc/ssl/certs/docker.home.crt >> /etc/ssl/certs/ca-certificates.crt

# Update permissions on docker cert
RUN chmod 0644 /etc/docker/certs.d/docker.home\:443/ca.crt

ENTRYPOINT ["dockerd-entrypoint.sh"]
CMD []