#!/bin/sh
# Script para automatizar a criação da ISO customizada do Alpine Linux (LXQt Laptop)

# ==========================================================
# 1. CONFIGURAÇÕES E VARIÁVEIS (AJUSTE AQUI!)
# ==========================================================
USUARIO="alpineuser"
HOSTNAME="alpine-lxqt-laptop"
KEYMAP="br br" # br para ABNT2, us para Americano
TIMEZONE="America/Sao_Paulo"
DISCO_ALVO="/dev/sda" # Disco real onde o Alpine será instalado
ISO_TAG="v3.22-lxqt-auto"
APORTS_DIR="/workspace/aports" # Ajuste para o WORKDIR do Docker
OUTPUT_DIR="/workspace/iso" # Ajuste para o WORKDIR do Docker

# Lista de pacotes para o Desktop LXQt e Laptop
APKS_LIST=" \
    agetty greetd greetd-gtkgreet doas audit logrotate bash-completion openssh-server iptables fprintd intel-ucode ip6tables ufw squid ucarp haproxy git setup-xorg-base xscreensaver pm-utils acpi hdparm libxinerama xrandr \
    mesa-dri-gallium xf86-input-libinput xf86-video-intel \
    dosfstools abuild alpine-conf syslinux xorriso squashfs-tools mtools e2fsprogs grub grub-bios grub-efi mkinitfs nano openssl gnupg libgcc libmcrypt libmhash libstdc++ libjpeg-turbo steghide cryptsetup cfdisk lvm2 ecryptfs-utils physlock \
    lxqt lightdm lightdm-gtk-greeter lxqt-desktop lximage-qt pavucontrol-qt pcmanfm-qt fuse-openrc gvfs-fuse udisks2 gvfs-smb font-dejavu arandr obconf-qt screengrab sddm lxqt-policykit picom libstatgrab libsysstat adwaita-qt adwaita-icon-theme qt5ct qt5-qtgraphicaleffects qt5-qtquickcontrols qt5-qtquickcontrols2 \
    dbus polkit-elogind networkmanager cpufreqd wpa-supplicant dhcpcd chrony macchanger wireless-tools iputils secure-delete\
    alsa-utils chrony ttf-dejavu sudo \
"

# ==========================================================
# 2. PREPARAÇÃO DO AMBIENTE
# ==========================================================
echo "--- 🛠️ Preparando Ambiente de Build ---"

# --- Novo Bloco de Geração de Chaves ---
# 1. Define o nome da chave para evitar o prompt interativo.
# Usamos um nome de chave estático no ambiente CI/CD.
# O diretório /root/.abuild deve existir antes.
mkdir -p /root/.abuild
chmod 700 /root/.abuild

# Define o nome do arquivo de chave que será usado pelo abuild-keygen
export ABUILD_KEY="/root/.abuild/ci-build-key"

# 2. Cria chaves de assinatura abuild de forma não interativa.
# O 'yes |' fornece entradas vazias (sem senha) para todos os prompts.
echo ">>> Gerando par de chaves RSA para abuild (não-interativo)"
yes | abuild-keygen -a -n || { echo "Falha ao criar chaves abuild."; exit 1; }
# --- Fim do Bloco de Geração de Chaves ---

# Clonar aports (se ainda não existir)
if [ ! -d "${APORTS_DIR}" ]; then
    git clone --depth=1 https://gitlab.alpinelinux.org/alpine/aports.git "${APORTS_DIR}" || { echo "Falha ao clonar aports."; exit 1; }
fi

# Define o diretório de trabalho temporário
mkdir -p /tmp/mkimage # Usamos /tmp no Alpine
export TMPDIR="/tmp/mkimage"

# Define os diretórios de scripts
SCRIPT_DIR="${APORTS_DIR}/scripts"
mkdir -p "${OUTPUT_DIR}"

# ==========================================================
# 3. CRIAÇÃO DOS ARQUIVOS DE CONFIGURAÇÃO
# ==========================================================
echo "--- 📝 Criando Arquivos de Configuração ---"

# 3.1. Criação do Answerfile (setup-alpine.conf)
cat << EOF > "${SCRIPT_DIR}/setup-alpine.conf"
# Arquivo de Respostas para setup-alpine (GERADO AUTOMATICAMENTE)
KEYMAPOPTS="${KEYMAP}"
HOSTNAMEOPTS="${HOSTNAME}"
DEVDOPTS="mdev"
INTERFACESOPTS="auto lo
iface lo inet loopback
auto eth0
iface eth0 inet dhcp"
TIMEZONEOPTS="${TIMEZONE}"
NTPOPTS="chrony"
SSHDOPTS="openssh"
APKREPOSOPTS="-1 -c"
USEROPTS="-a -g audio,video,input,netdev ${USUARIO}"
DISKOPTS="-m sys ${DISCO_ALVO}"
EOF
echo "   -> setup-alpine.conf criado."


# 3.2. Criação do Script de Overlay (genapkovl-laptop-lxqt.sh)
cat << EOF > "${SCRIPT_DIR}/genapkovl-laptop-lxqt.sh"
#!/bin/sh
# Script de Overlay (GERADO AUTOMATICAMENTE)

# Ação 1: Copia o Answerfile para o diretório de destino
mkdir -p "\$tmp"/etc/
cp ${SCRIPT_DIR}/setup-alpine.conf "\$tmp"/etc/setup-alpine.conf

# Ação 2: Configura a automação no boot do LiveCD
mkdir -p "\$tmp"/etc/local.d/
cat << INNER_EOF > "\$tmp"/etc/local.d/zz-autoinstall.start
#!/bin/sh
/sbin/setup-alpine -f /etc/setup-alpine.conf
rm -f /etc/local.d/zz-autoinstall.start
INNER_EOF
chmod +x "\$tmp"/etc/local.d/zz-autoinstall.start

# Ação 3: Habilita serviços cruciais na instalação final
rc_add dbus default
rc_add elogind default
rc_add lightdm default
rc_add cpufreqd default
rc_add networkmanager default
rc_add sshd default
rc_add chronyd default
EOF
chmod +x "${SCRIPT_DIR}/genapkovl-laptop-lxqt.sh"
echo "   -> genapkovl-laptop-lxqt.sh criado e permissão +x aplicada."


# 3.3. Criação do Perfil de Build (mkimg.laptop-lxqt.sh)
cat << EOF > "${SCRIPT_DIR}/mkimg.laptop-lxqt.sh"
#!/bin/sh
# Perfil mkimage (GERADO AUTOMATICAMENTE)

profile_laptop_lxqt() {
    profile_standard
    kernel_flavors="lts"
    
    apks="\$apks ${APKS_LIST}"

    # Define o overlay que contém o answerfile e a automação
    apkovl="aports/scripts/genapkovl-laptop-lxqt.sh"
}
EOF
echo "   -> mkimg.laptop-lxqt.sh criado."

# ==========================================================
# 4. EXECUÇÃO DO BUILD DA ISO
# ==========================================================
echo "--- 🚀 Iniciando Construção da ISO ---"

(cd ${APORTS_DIR} && sh scripts/mkimage.sh \
    --tag "${ISO_TAG}" \
    --outdir "${OUTPUT_DIR}" \
    --arch x86_64 \
    --repository https://dl-cdn.alpinelinux.org/alpine/v3.22/main \
    --profile laptop-lxqt \
)

# ==========================================================
# 5. FINALIZAÇÃO
# ==========================================================
if [ $? -eq 0 ]; then
    echo "========================================================"
    echo "✅ CONCLUÍDO! A ISO customizada está em: ${OUTPUT_DIR}"
    echo "========================================================"
else
    echo "========================================================"
    echo "❌ FALHA: Verifique o output acima para detalhes do erro."
    echo "========================================================"
fi
