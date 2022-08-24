FROM bash:alpine3.15

RUN apk add --no-cache bind-tools jq curl

COPY ./*.sh /

RUN chmod +x /hetzner-dyndns.sh /entrypoint.sh

CMD ["/usr/bin/env" , "bash", "/entrypoint.sh"]