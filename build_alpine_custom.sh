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
echo 'PACKAGER="GitHub Actions Builder <action@github.com>"' > /root/.abuild/abuild.conf
# Define o nome do arquivo de chave que será usado pelo abuild-keygen
# 3. Gera a chave abuild de forma NÃO-INTERATIVA
echo ">>> Gerando par de chaves RSA pública/privada para abuild de forma não interativa..."
yes "" | abuild-keygen -n -i

# Verificação
if [ $? -ne 0 ]; then
    echo "Falha ao gerar chaves abuild. Verifique as dependências."
    exit 1
else
    echo "Chaves abuild geradas com sucesso."
fi
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
# 3. CRIAÇÃO DOS ARQUIVOS DE CONFIGURAÇÃO (REFATORADO COM ECHO)
# ==========================================================
echo "--- 📝 Criando Arquivos de Configuração ---"

# 3.1. Criação do Answerfile (setup-alpine.conf)
# Usa-se `>` na primeira linha para criar/sobrescrever o arquivo.
echo "# Arquivo de Respostas para setup-alpine (GERADO AUTOMATICAMENTE)" > "${SCRIPT_DIR}/setup-alpine.conf"
# Usa-se `>>` nas linhas seguintes para adicionar ao arquivo.
echo "KEYMAPOPTS=\"${KEYMAP}\"" >> "${SCRIPT_DIR}/setup-alpine.conf"
echo "HOSTNAMEOPTS=\"${HOSTNAME}\"" >> "${SCRIPT_DIR}/setup-alpine.conf"
echo "DEVDOPTS=\"mdev\"" >> "${SCRIPT_DIR}/setup-alpine.conf"
echo "INTERFACESOPTS=\"auto lo" >> "${SCRIPT_DIR}/setup-alpine.conf"
echo "iface lo inet loopback" >> "${SCRIPT_DIR}/setup-alpine.conf"
echo "auto eth0" >> "${SCRIPT_DIR}/setup-alpine.conf"
echo "iface eth0 inet dhcp\"" >> "${SCRIPT_DIR}/setup-alpine.conf"
echo "TIMEZONEOPTS=\"${TIMEZONE}\"" >> "${SCRIPT_DIR}/setup-alpine.conf"
echo "NTPOPTS=\"chrony\"" >> "${SCRIPT_DIR}/setup-alpine.conf"
echo "SSHDOPTS=\"openssh\"" >> "${SCRIPT_DIR}/setup-alpine.conf"
echo "APKREPOSOPTS=\"-1 -c\"" >> "${SCRIPT_DIR}/setup-alpine.conf"
echo "USEROPTS=\"-a -g audio,video,input,netdev ${USUARIO}\"" >> "${SCRIPT_DIR}/setup-alpine.conf"
echo "DISKOPTS=\"-m sys ${DISCO_ALVO}\"" >> "${SCRIPT_DIR}/setup-alpine.conf"

echo "    -> setup-alpine.conf criado."


# 3.2. Criação do Script de Overlay (genapkovl-laptop-lxqt.sh)
# Note que a string interna precisa ter aspas simples para proteger as variáveis
echo "#!/bin/sh" > "${SCRIPT_DIR}/genapkovl-laptop-lxqt.sh"
echo "# Script de Overlay (GERADO AUTOMATICAMENTE)" >> "${SCRIPT_DIR}/genapkovl-laptop-lxqt.sh"
echo "" >> "${SCRIPT_DIR}/genapkovl-laptop-lxqt.sh"
echo "# Ação 1: Copia o Answerfile para o diretório de destino" >> "${SCRIPT_DIR}/genapkovl-laptop-lxqt.sh"
echo "mkdir -p \"\$tmp\"/etc/" >> "${SCRIPT_DIR}/genapkovl-laptop-lxqt.sh"
echo "cp ${SCRIPT_DIR}/setup-alpine.conf \"\$tmp\"/etc/setup-alpine.conf" >> "${SCRIPT_DIR}/genapkovl-laptop-lxqt.sh"
echo "" >> "${SCRIPT_DIR}/genapkovl-laptop-lxqt.sh"
echo "# Ação 2: Configura a automação no boot do LiveCD" >> "${SCRIPT_DIR}/genapkovl-laptop-lxqt.sh"
echo "mkdir -p \"\$tmp\"/etc/local.d/" >> "${SCRIPT_DIR}/genapkovl-laptop-lxqt.sh"
# Bloco Interno (Autoinstall script): Usamos aspas simples para o echo,
# mas aqui precisaremos ter cuidado especial para não expandir variáveis
# como \$tmp, \$tmp, ou quebrar aspas. O melhor é manter o here-document
# ou usar um echo muito cuidadoso, mas vamos forçar a refatoração com echo:
echo 'cat << INNER_EOF > "$tmp"/etc/local.d/zz-autoinstall.start' >> "${SCRIPT_DIR}/genapkovl-laptop-lxqt.sh"
echo '#!/bin/sh' >> "${SCRIPT_DIR}/genapkovl-laptop-lxqt.sh"
echo '/sbin/setup-alpine -f /etc/setup-alpine.conf' >> "${SCRIPT_DIR}/genapkovl-laptop-lxqt.sh"
echo 'rm -f /etc/local.d/zz-autoinstall.start' >> "${SCRIPT_DIR}/genapkovl-laptop-lxqt.sh"
echo 'INNER_EOF' >> "${SCRIPT_DIR}/genapkovl-laptop-lxqt.sh" # Linha EOF de fechamento
echo 'chmod +x "$tmp"/etc/local.d/zz-autoinstall.start' >> "${SCRIPT_DIR}/genapkovl-laptop-lxqt.sh"
echo "" >> "${SCRIPT_DIR}/genapkovl-laptop-lxqt.sh"
echo "# Ação 3: Habilita serviços cruciais na instalação final" >> "${SCRIPT_DIR}/genapkovl-laptop-lxqt.sh"
echo 'rc_add dbus default' >> "${SCRIPT_DIR}/genapkovl-laptop-lxqt.sh"
echo 'rc_add elogind default' >> "${SCRIPT_DIR}/genapkovl-laptop-lxqt.sh"
echo 'rc_add lightdm default' >> "${SCRIPT_DIR}/genapkovl-laptop-lxqt.sh"
echo 'rc_add cpufreqd default' >> "${SCRIPT_DIR}/genapkovl-laptop-lxqt.sh"
echo 'rc_add networkmanager default' >> "${SCRIPT_DIR}/genapkovl-laptop-lxqt.sh"
echo 'rc_add sshd default' >> "${SCRIPT_DIR}/genapkovl-laptop-lxqt.sh"
echo 'rc_add chronyd default' >> "${SCRIPT_DIR}/genapkovl-laptop-lxqt.sh"

chmod +x "${SCRIPT_DIR}/genapkovl-laptop-lxqt.sh"
echo "    -> genapkovl-laptop-lxqt.sh criado e permissão +x aplicada."


# 3.3. Criação do Perfil de Build (mkimg.laptop-lxqt.sh)
echo "#!/bin/sh" > "${SCRIPT_DIR}/mkimg.laptop-lxqt.sh"
echo "# Perfil mkimage (GERADO AUTOMATICAMENTE)" >> "${SCRIPT_DIR}/mkimg.laptop-lxqt.sh"
echo "" >> "${SCRIPT_DIR}/mkimg.laptop-lxqt.sh"
echo "profile_laptop_lxqt() {" >> "${SCRIPT_DIR}/mkimg.laptop-lxqt.sh"
echo "    profile_standard" >> "${SCRIPT_DIR}/mkimg.laptop-lxqt.sh"
echo "    kernel_flavors=\"lts\"" >> "${SCRIPT_DIR}/mkimg.laptop-lxqt.sh"
echo "    " >> "${SCRIPT_DIR}/mkimg.laptop-lxqt.sh"
echo "    apks=\"\$apks ${APKS_LIST}\"" >> "${SCRIPT_DIR}/mkimg.laptop-lxqt.sh"
echo "" >> "${SCRIPT_DIR}/mkimg.laptop-lxqt.sh"
echo "    # Define o overlay que contém o answerfile e a automação" >> "${SCRIPT_DIR}/mkimg.laptop-lxqt.sh"
echo "    apkovl=\"aports/scripts/genapkovl-laptop-lxqt.sh\"" >> "${SCRIPT_DIR}/mkimg.laptop-lxqt.sh"
echo "}" >> "${SCRIPT_DIR}/mkimg.laptop-lxqt.sh"

echo "    -> mkimg.laptop-lxqt.sh criado."

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
