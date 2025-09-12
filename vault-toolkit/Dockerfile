FROM alpine:3.18

ENV CFSSL_VERSION="1.6.4"
ENV KUBECTL_VERSION="1.28.4"

# following envs also used by script
ENV SECRETS_GH_PLUGIN_VERSION="2.2.2"
ENV SECRETS_GH_PLUGIN_SHA="598c7b0b911c524840199abdaaea1c7b3aaed918a50662ce8ea30aaeeae271ce"

COPY *.sh /usr/local/bin/

RUN apk --no-cache add curl jq bash \
      && wget -O /usr/local/bin/kubectl https://dl.k8s.io/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl \
      && chmod +x /usr/local/bin/kubectl \
      && wget -O /usr/local/bin/cfssl https://github.com/cloudflare/cfssl/releases/download/v${CFSSL_VERSION}/cfssl_${CFSSL_VERSION}_linux_amd64 \
      && chmod +x /usr/local/bin/cfssl \
      && wget -O /usr/local/bin/cfssljson https://github.com/cloudflare/cfssl/releases/download/v${CFSSL_VERSION}/cfssljson_${CFSSL_VERSION}_linux_amd64 \
      && chmod +x /usr/local/bin/cfssljson \
      && wget -O /usr/local/bin/vault-plugin-secrets-github https://github.com/martinbaillie/vault-plugin-secrets-github/releases/download/v${SECRETS_GH_PLUGIN_VERSION}/vault-plugin-secrets-github-linux-amd64 \
      && chmod +x /usr/local/bin/vault-plugin-secrets-github \
      && chmod +x /usr/local/bin/*.sh

ENTRYPOINT ["docker-entrypoint.sh"]
