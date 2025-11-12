# Usa a última versão estável do Alpine Linux como imagem base
FROM alpine:latest

# Define o diretório de trabalho, que será o ponto de montagem do GitHub Workspace
ENV BUILD_DIR=/workspace
WORKDIR ${BUILD_DIR}

# 1. Instalação de Dependências de Build
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
    # Limpa o cache APK para manter a imagem pequena
    && rm -rf /var/cache/apk/*

# 2. Copia o script de automação para o contêiner
COPY build_alpine_custom.sh .

# 3. Garante que o script é executável
RUN chmod +x build_alpine_custom.sh

# 4. Define o comando principal
ENTRYPOINT ["/bin/sh", "./build_alpine_custom.sh"]
