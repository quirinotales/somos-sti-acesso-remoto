# Somos STI Acesso Remoto - imagem local do servidor.
# Os binários (hbbs, hbbr, rustdesk-utils) são estáticos e vêm da release do GitHub, já conferidos por SHA-256.
FROM alpine:3.22
RUN apk add --no-cache ca-certificates tzdata \
 && adduser -D -H -u 10001 -s /sbin/nologin sti
COPY hbbs hbbr rustdesk-utils /usr/local/bin/
ENV TZ=America/Sao_Paulo
USER sti
WORKDIR /dados
