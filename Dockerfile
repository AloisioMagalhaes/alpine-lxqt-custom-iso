# Dockerfile
FROM docker.io/library/alpine:3.22

WORKDIR /workspace

# Instalação das dependências
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
        # Adicionar as ferramentas necessárias para o ambiente desktop
        dbus \
        elogind \
    && rm -rf /var/cache/apk/*

# Copia e torna o script executável
COPY build_custom_iso.sh .
RUN chmod +x build_custom_iso.sh

# Comando de execução padrão
CMD ["./build_custom_iso.sh"]
