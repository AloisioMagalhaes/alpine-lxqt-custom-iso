#!/bin/sh
# Script para automação da criação da ISO customizada do Alpine Linux (Profile: custom)

# ==========================================================
# 1. CONFIGURAÇÕES E VARIÁVEIS
# ==========================================================
USUARIO="alpineuser"
HOSTNAME="alpine-custom"
KEYMAP="us us"
TIMEZONE="UTC"
DISCO_ALVO="/dev/sda"
ISO_TAG="v3.22-custom-auto"
APORTS_DIR="/workspace/aports"
OUTPUT_DIR="/workspace/iso"
MKIMAGE_WORKDIR="/tmp/mkimage"

# Pacotes mínimos para um ambiente de terminal/desktop básico
APKS_LIST=" \
    bash sudo openssh-server \
    setup-xorg-base xf86-input-libinput mesa-dri-gallium \
    lightdm lightdm-gtk-greeter xfce4 xfce4-terminal \
    dbus polkit-elogind networkmanager \
    font-dejavu ttf-dejavu alsa-utils chrony \
"

# ==========================================================
# 2. PREPARAÇÃO DO AMBIENTE
# ==========================================================
echo "--- 🛠️ Preparando Ambiente de Build ---"

# --- Geração de Chaves ABBUILD (Não Interativa) ---
# Necessário para evitar falha no mkimage.sh em alguns contextos
mkdir -p /root/.abuild
chmod 700 /root/.abuild
echo 'PACKAGER="Docker Builder <docker@example.com>"' > /root/.abuild/abuild.conf
echo ">>> Gerando par de chaves RSA pública/privada para abuild..."
# O pipe com printf simula o ENTER para usar o default e passphrase vazia.
printf "\n" | abuild-keygen -n -i

if [ $? -ne 0 ]; then
    echo "Falha ao gerar chaves abuild."
    exit 1
fi
# --- Fim Geração de Chaves ---

# Clonar aports (se ainda não existir)
if [ ! -d "${APORTS_DIR}" ]; then
    git clone --depth=1 https://gitlab.alpinelinux.org/alpine/aports.git "${APORTS_DIR}" || { echo "Falha ao clonar aports."; exit 1; }
fi

# Define diretórios
SCRIPT_DIR="${APORTS_DIR}/scripts"
mkdir -p "${OUTPUT_DIR}"
mkdir -p "${MKIMAGE_WORKDIR}"
export TMPDIR="${MKIMAGE_WORKDIR}"

# ==========================================================
# 3. CRIAÇÃO DOS ARQUIVOS DE CONFIGURAÇÃO
# ==========================================================
echo "--- 📝 Criando Arquivos de Configuração (Answerfile e Overlay) ---"

# 3.1. Criação do Answerfile (setup-alpine.conf)
echo "# Arquivo de Respostas para setup-alpine" > "${SCRIPT_DIR}/setup-alpine.conf"
echo "KEYMAPOPTS=\"${KEYMAP}\"" >> "${SCRIPT_DIR}/setup-alpine.conf"
echo "HOSTNAMEOPTS=\"${HOSTNAME}\"" >> "${SCRIPT_DIR}/setup-alpine.conf"
echo "TIMEZONEOPTS=\"${TIMEZONE}\"" >> "${SCRIPT_DIR}/setup-alpine.conf"
echo "NTPOPTS=\"chrony\"" >> "${SCRIPT_DIR}/setup-alpine.conf"
echo "SSHDOPTS=\"openssh\"" >> "${SCRIPT_DIR}/setup-alpine.conf"
echo "APKREPOSOPTS=\"-1 -c\"" >> "${SCRIPT_DIR}/setup-alpine.conf"
echo "USEROPTS=\"-a -g audio,video,input,netdev ${USUARIO}\"" >> "${SCRIPT_DIR}/setup-alpine.conf"
echo "DISKOPTS=\"-m sys ${DISCO_ALVO}\"" >> "${SCRIPT_DIR}/setup-alpine.conf"


# 3.2. Criação do Script de Overlay (genapkovl-custom.sh)
echo "#!/bin/sh" > "${SCRIPT_DIR}/genapkovl-custom.sh"
echo "# Script de Overlay (Autoinstall e Serviços)" >> "${SCRIPT_DIR}/genapkovl-custom.sh"
echo "" >> "${SCRIPT_DIR}/genapkovl-custom.sh"
echo "# Copia o Answerfile e configura o autoinstall no boot" >> "${SCRIPT_DIR}/genapkovl-custom.sh"
echo "mkdir -p \"\$tmp\"/etc/local.d/ \"\$tmp\"/etc/" >> "${SCRIPT_DIR}/genapkovl-custom.sh"
echo "cp ${SCRIPT_DIR}/setup-alpine.conf \"\$tmp\"/etc/setup-alpine.conf" >> "${SCRIPT_DIR}/genapkovl-custom.sh"
echo 'cat << INNER_EOF > "$tmp"/etc/local.d/zz-autoinstall.start' >> "${SCRIPT_DIR}/genapkovl-custom.sh"
echo '#!/bin/sh' >> "${SCRIPT_DIR}/genapkovl-custom.sh"
echo '/sbin/setup-alpine -f /etc/setup-alpine.conf' >> "${SCRIPT_DIR}/genapkovl-custom.sh"
echo 'rm -f /etc/local.d/zz-autoinstall.start' >> "${SCRIPT_DIR}/genapkovl-custom.sh"
echo 'INNER_EOF' >> "${SCRIPT_DIR}/genapkovl-custom.sh" 
echo 'chmod +x "$tmp"/etc/local.d/zz-autoinstall.start' >> "${SCRIPT_DIR}/genapkovl-custom.sh"
echo "" >> "${SCRIPT_DIR}/genapkovl-custom.sh"
echo "# Habilita serviços cruciais" >> "${SCRIPT_DIR}/genapkovl-custom.sh"
echo 'rc_add dbus default' >> "${SCRIPT_DIR}/genapkovl-custom.sh"
echo 'rc_add elogind default' >> "${SCRIPT_DIR}/genapkovl-custom.sh"
echo 'rc_add lightdm default' >> "${SCRIPT_DIR}/genapkovl-custom.sh"
chmod +x "${SCRIPT_DIR}/genapkovl-custom.sh"


# 3.3. Criação do Perfil de Build (mkimg.custom.sh)
echo "#!/bin/sh" > "${SCRIPT_DIR}/mkimg.custom.sh"
echo "# Perfil mkimage customizado" >> "${SCRIPT_DIR}/mkimg.custom.sh"
echo "profile_custom() {" >> "${SCRIPT_DIR}/mkimg.custom.sh"
echo "    profile_standard" >> "${SCRIPT_DIR}/mkimg.custom.sh"
echo "    kernel_flavors=\"lts\"" >> "${SCRIPT_DIR}/mkimg.custom.sh"
echo "    apks=\"\$apks ${APKS_LIST}\"" >> "${SCRIPT_DIR}/mkimg.custom.sh"
echo "    # Adiciona o arquivo .default_boot_services para suporte a LiveCD com instalador" >> "${SCRIPT_DIR}/mkimg.custom.sh"
echo "    touch \"\$tmp\"/.default_boot_services" >> "${SCRIPT_DIR}/mkimg.custom.sh"
echo "    apkovl=\"aports/scripts/genapkovl-custom.sh\"" >> "${SCRIPT_DIR}/mkimg.custom.sh"
echo "}" >> "${SCRIPT_DIR}/mkimg.custom.sh"


# ==========================================================
# 4. EXECUÇÃO DO BUILD DA ISO
# ==========================================================
echo "--- 🚀 Iniciando Construção da ISO ---"

(cd ${APORTS_DIR} && sh scripts/mkimage.sh \
    --tag "${ISO_TAG}" \
    --outdir "${OUTPUT_DIR}" \
    --arch x86_64 \
    --repository https://dl-cdn.alpinelinux.org/alpine/v3.22/main \
    --profile custom \
)

# ==========================================================
# 5. FINALIZAÇÃO
# ==========================================================
if [ $? -eq 0 ]; then
    echo "========================================================"
    echo "✅ SUCESSO! A ISO customizada está em: ${OUTPUT_DIR}"
    echo "========================================================"
else
    echo "========================================================"
    echo "❌ FALHA: A ISO customizada não foi gerada."
    echo "========================================================"
fi
