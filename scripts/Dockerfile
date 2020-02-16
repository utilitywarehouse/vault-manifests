FROM alpine:3.11

ENV CFSSL_VERSION="1.4.1"
ENV KUBECTL_VERSION="1.17.3"

COPY *.sh /usr/local/bin/

RUN apk --no-cache add curl jq &&\
    wget -O /usr/local/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl &&\
    chmod +x /usr/local/bin/kubectl &&\
    wget -O /usr/local/bin/cfssl https://github.com/cloudflare/cfssl/releases/download/v${CFSSL_VERSION}/cfssl_${CFSSL_VERSION}_linux_amd64 &&\
    chmod +x /usr/local/bin/cfssl &&\
    wget -O /usr/local/bin/cfssljson https://github.com/cloudflare/cfssl/releases/download/v${CFSSL_VERSION}/cfssljson_${CFSSL_VERSION}_linux_amd64 &&\
    chmod +x /usr/local/bin/cfssljson &&\
    chmod +x /usr/local/bin/*.sh

ENTRYPOINT ["docker-entrypoint.sh"]
