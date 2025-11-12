# Dockerfile (Corrigido, Evitando doas/sudo)
FROM docker.io/library/alpine:3.22

# Instalação das dependências e ferramentas de build.
RUN apk update && \
    apk add \
        git \
        abuild \
        alpine-conf \
        syslinux \
        xorriso \
        squashfs-tools \
        grub \
        mtools \
        linux-headers \
        bash \
        coreutils \
        mkinitfs \
        openssl \
        util-linux \
        # 'doas' removido pois não é necessário e causava erro de permissão
        \
    && rm -rf /var/cache/apk/*

# Geração da chave ABBUILD (Não Interativa e Cópia Manual)
RUN echo ">>> Preparando ambiente ABBUILD..." && \
    mkdir -p /root/.abuild && \
    chmod 700 /root/.abuild && \
    echo 'PACKAGER="Docker Builder <docker@example.com>"' > /root/.abuild/abuild.conf && \
    \
    # 1. Gera a chave, mas SEM a flag -i (instalar) para evitar o 'doas'
    printf "\n" | abuild-keygen -n && \
    \
    # 2. Localiza o nome do arquivo da chave pública recém-gerada
    PUBKEY_FILE=$(find /root/.abuild/ -maxdepth 1 -name "*.pub" -print -quit) && \
    \
    # 3. Copia manualmente a chave pública para o diretório de chaves do APK
    echo ">>> Instalando ${PUBKEY_FILE} para /etc/apk/keys..." && \
    cp "${PUBKEY_FILE}" /etc/apk/keys/ && \
    \
    echo "Chaves abuild geradas e instaladas manualmente com sucesso."

# Define o shell padrão para ser sh (BusyBox)
CMD ["/bin/sh"]
