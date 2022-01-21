# Container image that runs your code
FROM  public.ecr.aws/docker/library/bash:alpine3.14

ENV PACKAGES "jq gettext curl openssl ca-certificates"

RUN apk add --no-cache $PACKAGES

# Copies your code file from your action repository to the filesystem path `/` of the container
COPY token.sh /token.sh

# Code file to execute when the docker container starts up (`entrypoint.sh`)
ENTRYPOINT ["/token.sh"]