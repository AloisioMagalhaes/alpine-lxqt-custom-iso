# Dockerfile
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
        \
    && rm -rf /var/cache/apk/*

# Geração da chave ABBUILD (Não Interativa e BusyBox-Friendly)
RUN echo ">>> Preparando ambiente ABBUILD..." && \
    mkdir -p /root/.abuild && \
    chmod 700 /root/.abuild && \
    echo 'PACKAGER="Docker Builder <docker@example.com>"' > /root/.abuild/abuild.conf && \
    printf "\n" | abuild-keygen -n -i && \
    echo "Chaves abuild geradas com sucesso."

# Define o shell padrão para ser sh (BusyBox)
CMD ["/bin/sh"]
