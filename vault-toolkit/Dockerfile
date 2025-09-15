FROM alpine:3.18

ENV CFSSL_VERSION="1.6.4"
ENV KUBECTL_VERSION="1.28.4"

# following envs are set via make target 'update-secrets-github-plugin'
# its also used by 'vault-install-plugin.sh' script
ENV SECRETS_GH_PLUGIN_VERSION="2.2.2"
ENV SECRETS_GH_PLUGIN_SHA="46056e4ce06961e4c87d30da0ed18422e69b680755f330cd2a78eac1749192b7"

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
