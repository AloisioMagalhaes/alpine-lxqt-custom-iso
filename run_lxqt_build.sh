#!/bin/sh
# Script para configurar e executar o 'make-vm-image' com ambiente LXQt.
# Compatível com BusyBox (sh).

# --- Variáveis de Ambiente ---
# Assume que o workspace do GitHub Actions é mapeado para /workspace no container.
WORKSPACE_ROOT="/workspace"
VM_IMAGE_DIR="${WORKSPACE_ROOT}/alpine-make-vm-image"
OUTPUT_DIR="${WORKSPACE_ROOT}/iso_output" 
APORTS_DIR="${WORKSPACE_ROOT}/aports" 

# Variáveis configuráveis (lidas do ambiente Docker ou padrão)
ISO_TAG="${ISO_TAG:-v3.22-lxqt-auto}"
ARCH="${ARCH:-x86_64}"
PROFILE_NAME="lxqt" 
REPO_MAIN="${REPO_MAIN:-https://dl-cdn.alpinelinux.org/alpine/v3.22/main}"

# 2. Lista de Pacotes LXQt (Essenciais para um desktop funcional)
APKS_LIST=" \
    bash sudo openssh-server networkmanager \
    setup-xorg-base xf86-input-libinput mesa-dri-gallium \
    dbus elogind polkit-elogind \
    lxqt lxqt-desktop lximage-qt pcmanfm-qt pavucontrol-qt screengrab \
    sddm \
    font-dejavu ttf-dejavu alsa-utils chrony \
"

# --- 3. Preparação do Ambiente ---
echo "--- Clonando repositórios ---"

# Teste simples de existência de diretório.
if [ ! -d "${APORTS_DIR}" ]; then
    git clone --depth=1 https://gitlab.alpinelinux.org/alpine/aports.git "${APORTS_DIR}"
fi
if [ ! -d "${VM_IMAGE_DIR}" ]; then
    git clone --depth=1 https://github.com/alpinelinux/alpine-make-vm-image.git "${VM_IMAGE_DIR}"
fi

# --- 4. Criação dos Arquivos de Perfil ---
echo "--- Criando Arquivos de Perfil e Overlay LXQt ---"
SCRIPT_DIR="${APORTS_DIR}/scripts"
mkdir -p "${SCRIPT_DIR}"

# 4.1. Cria o arquivo de PERFIL mkimg.lxqt.sh
cat << EOF_PROFILE > "${SCRIPT_DIR}/mkimg.${PROFILE_NAME}.sh"
profile_${PROFILE_NAME}() {
    profile_standard
    kernel_flavors="lts"
    apks="\$apks ${APKS_LIST}"
    touch "\$tmp"/.default_boot_services
    apkovl="aports/scripts/genapkovl-${PROFILE_NAME}.sh"
}
EOF_PROFILE

# 4.2. Cria o arquivo OVERLAY genapkovl-lxqt.sh (Usa rc_add para serviços OpenRC)
cat << EOF_OVERLAY > "${SCRIPT_DIR}/genapkovl-${PROFILE_NAME}.sh"
#!/bin/sh
# Habilita serviços essenciais para o desktop
echo "Adicionando personalizações de overlay LXQt..."

rc_add dbus default
rc_add elogind default
rc_add networkmanager default
rc_add sddm default
rc_add sshd default 

EOF_OVERLAY
chmod +x "${SCRIPT_DIR}/genapkovl-${PROFILE_NAME}.sh"


# --- 5. Execução do make-vm-image ---
echo "--- Executando make-vm-image ---"
mkdir -p "${OUTPUT_DIR}"

# Usa o sub-shell para rodar o script a partir do diretório correto
(cd "${VM_IMAGE_DIR}" && ./make-vm-image \
    --vm-type iso \
    --tag "${ISO_TAG}" \
    --outdir "${OUTPUT_DIR}" \
    --arch "${ARCH}" \
    --repository "${REPO_MAIN}" \
    --aports "${APORTS_DIR}" \
    --profile "${PROFILE_NAME}" \
    --workdir /tmp/vm_build_cache \
    /dev/null \
)

# --- 6. Finalização ---
if [ $? -eq 0 ]; then
    echo "========================================================"
    echo "✅ SUCESSO! ISO LXQt customizada gerada em: ${OUTPUT_DIR}"
    echo "========================================================"
    exit 0
else
    echo "========================================================"
    echo "❌ FALHA na construção da imagem LXQt."
    exit 1
fi
