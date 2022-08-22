FROM amd64/alpine:3.16

ENV TOOL="/tool"

COPY ./wrapper.sh /wrapper.sh
COPY ./tool ${TOOL}

RUN apk add --update --no-cache curl ca-certificates bash jq && \
    adduser -D -g kronos kronos && \
    chown -R kronos:kronos ${TOOL} && \
    chmod +x -R ${TOOL} && \
    chmod +x /wrapper.sh

USER kronos

ENTRYPOINT /wrapper.sh
