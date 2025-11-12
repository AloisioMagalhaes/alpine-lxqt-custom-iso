FROM docker.io/library/alpine:latest

# Define o diretório de trabalho principal
WORKDIR /workspace

# Instalação das dependências e ferramentas de build
# Inclui 'printf' para o método de geração de chave não interativa
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
        printf \
    && rm -rf /var/cache/apk/*

# --- Geração de Chaves ABBUILD (Non-interactive) ---
# Cria o diretório, o arquivo de configuração e gera a chave
# O 'printf "\n"' envia um ENTER para aceitar o caminho padrão e sem passphrase.
RUN echo ">>> Preparando ambiente ABBUILD..." && \
    mkdir -p /root/.abuild && \
    chmod 700 /root/.abuild && \
    echo 'PACKAGER="Docker Builder <docker@example.com>"' > /root/.abuild/abuild.conf && \
    printf "\n" | abuild-keygen -n -i && \
    echo "Chaves abuild geradas com sucesso durante o build da imagem."
# --- FIM DO NOVO PASSO ---

COPY build_alpine_custom.sh .
# Garante permissão de execução
RUN chmod +x build_alpine_custom.sh

# O ENTRYPOINT é omitido, pois o GitHub Actions executará o script explicitamente.
