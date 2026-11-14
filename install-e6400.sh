#!/bin/bash
# ============================================================================
# BlackHole-E6400 — instalador del sistema "Vista + Black Hole Matrix"
# Dell Latitude E6400 · Core 2 Duo 64-bit · 2 GB RAM · BIOS A14 (Legacy)
#
# Base requerida: antiX 64-bit (base/core) o Debian netinst 64-bit sin
# tarea de escritorio. Ejecutar como usuario normal (pide sudo cuando toca).
#
# Uso:
#   ./install-e6400.sh              # todo el sistema
#   ./install-e6400.sh base         # solo paquetes (paso 1)
#   ./install-e6400.sh memoria      # solo ZRAM + sysctl (paso 2)
#   ./install-e6400.sh escritorio   # solo tema/configs (paso 3)
#   ./install-e6400.sh kernel       # parámetros GRUB (paso 4)
#   ./install-e6400.sh juegos       # extras: Mesa, RetroArch, vídeo (paso 5)
#   ./install-e6400.sh verifica     # comprobaciones finales (paso 6)
# ============================================================================
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFGS="$DIR/configs"

say()  { printf '\n\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }

# ----------------------------------------------------------------------------
paso_base() {
    say "1/6 Paquetes del sistema base"
    sudo apt update
    sudo apt install -y --no-install-recommends \
        xserver-xorg-core xserver-xorg-input-libinput x11-xserver-utils \
        xinit dbus-x11 libgl1-mesa-dri libglx-mesa0 mesa-utils \
        openbox obconf tint2 jgmenu picom feh pcmanfm xterm \
        fonts-opensans fonts-dejavu-core papirus-icon-theme \
        python3-pil alsa-utils networkmanager network-manager-gnome
    say "Base instalada."
}

# ----------------------------------------------------------------------------
paso_memoria() {
    say "2/6 ZRAM + earlyoom + sysctl (2 GB de RAM)"
    sudo apt install -y zram-tools earlyoom
    sudo cp "$CFGS/zramswap" /etc/default/zramswap
    sudo systemctl restart zramswap 2>/dev/null \
        || sudo service zramswap restart
    sudo cp "$CFGS/99-e6400.conf" /etc/sysctl.d/99-e6400.conf
    sudo sysctl --system
    zramctl; swapon --show; free -m
    say "Memoria configurada."
}

# ----------------------------------------------------------------------------
paso_escritorio() {
    say "3/6 Escritorio BlackHole-Aero (look Vista + Matrix)"
    mkdir -p ~/bin ~/.config/tint2 ~/.config/openbox ~/.config/jgmenu \
             ~/.config/gtk-3.0 ~/.themes/BlackHole-Aero/openbox-3

    # Fondo + orbe (se generan solos)
    python3 "$DIR/bin/blackhole.py"

    # Tema de ventanas Openbox
    if [ -d /usr/share/themes/Clearlooks/openbox-3 ]; then
        cp /usr/share/themes/Clearlooks/openbox-3/*.xbm \
           ~/.themes/BlackHole-Aero/openbox-3/ 2>/dev/null \
        || cp /usr/share/themes/*/openbox-3/*.xbm \
              ~/.themes/BlackHole-Aero/openbox-3/ 2>/dev/null || true
    else
        cp /usr/share/themes/*/openbox-3/*.xbm \
           ~/.themes/BlackHole-Aero/openbox-3/ 2>/dev/null || true
    fi
    cp "$CFGS/themerc" ~/.themes/BlackHole-Aero/openbox-3/themerc

    [ -f ~/.config/openbox/rc.xml ] || \
        cp /etc/xdg/openbox/rc.xml ~/.config/openbox/
    sed -i '/<theme>/{n;s|<name>[^<]*</name>|<name>BlackHole-Aero</name>|}' \
        ~/.config/openbox/rc.xml
    sed -i 's|<titleLayout>[^<]*</titleLayout>|<titleLayout>LIMC</titleLayout>|' \
        ~/.config/openbox/rc.xml

    # Barra estilo Vista, menú Inicio, cristal
    cp "$CFGS/tint2rc"   ~/.config/tint2/tint2rc
    cp "$CFGS/jgmenurc"  ~/.config/jgmenu/jgmenurc
    cp "$CFGS/picom.conf" ~/.config/picom.conf

    # GTK oscuro, terminal verde, autostart, arranque en tty1
    cp "$CFGS/gtk-settings.ini" ~/.config/gtk-3.0/settings.ini
    cp "$CFGS/gtk.css"          ~/.config/gtk-3.0/gtk.css
    cp "$CFGS/Xresources"       ~/.Xresources
    cp "$CFGS/autostart"        ~/.config/openbox/autostart
    cp "$CFGS/xinitrc"          ~/.xinitrc
    grep -q 'exec startx' ~/.profile 2>/dev/null \
        || echo '[ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ] && exec startx' >> ~/.profile

    # Servicios que no hacen falta en 2 GB
    sudo systemctl disable --now bluetooth ModemManager avahi-daemon cups \
        2>/dev/null || true

    # Script «juego»: apaga picom, lanza el juego y lo reactiva
    cat > ~/bin/juego <<'EOF'
#!/bin/sh
pkill picom 2>/dev/null
"$@"
picom -b --config ~/.config/picom.conf
EOF
    chmod +x ~/bin/juego

    # Recargar Openbox si hay sesión gráfica activa
    if [ -n "${DISPLAY:-}" ]; then
        openbox --reconfigure 2>/dev/null || true
    fi
    say "Escritorio instalado. Cierra sesión y vuelve a entrar (startx)."
}

# ----------------------------------------------------------------------------
paso_kernel() {
    say "4/6 Parámetros de arranque del kernel"
    warn "Se aplican los parámetros de rendimiento para Core 2 Duo."
    warn "mitigations=off quita las protecciones Meltdown/Spectre (el Core 2"
    warn "no recibe microcódigo anti-Spectre): con navegador es un riesgo real."
    read -r -p "¿Aplicar con mitigations=off? [s/N] " r
    local extra="quiet transparent_hugepage=never zswap.enabled=0 nowatchdog"
    if [[ "$r" =~ ^[Ss]$ ]]; then
        extra="$extra mitigations=off"
    fi
    sudo sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT='$extra'|" \
        /etc/default/grub
    sudo update-grub
    cat /proc/cmdline
    say "Parámetros fijados en /etc/default/grub."
}

# ----------------------------------------------------------------------------
paso_juegos() {
    say "5/6 Mesa, vídeo acelerado y emuladores"
    sudo apt install -y \
        xserver-xorg-video-intel xserver-xorg-video-nouveau \
        i965-va-driver vainfo mpv yt-dlp \
        retroarch libretro-snes9x libretro-genesisplusgx libretro-nestopia \
        libretro-gambatte libretro-mgba libretro-beetle-psx
    say "En RetroArch: Vídeo=gl, Menú=rgui; desactiva Rewind y Run-Ahead."
    say "Navegador recomendado: sudo apt install firefox-esr (+ uBlock Origin)"
}

# ----------------------------------------------------------------------------
paso_verifica() {
    say "6/6 Verificación final"
    echo "--- Parámetros del kernel:"; cat /proc/cmdline
    echo "--- ZRAM:"; zramctl; swapon --show
    echo "--- RAM en reposo (objetivo used ≈200–250MB):"
    free -m
    echo "--- GPU y driver reales:"
    glxinfo -B 2>/dev/null | grep -E 'renderer|OpenGL version' || \
        warn "glxinfo no disponible fuera de sesión gráfica."
    echo "--- Procesos que más RAM consumen:"
    ps -eo rss,comm --sort=-rss | head -15
}

# ----------------------------------------------------------------------------
case "${1:-todo}" in
    todo)       paso_base; paso_memoria; paso_escritorio; paso_kernel; paso_juegos; paso_verifica ;;
    base)       paso_base ;;
    memoria)    paso_memoria ;;
    escritorio) paso_escritorio ;;
    kernel)     paso_kernel ;;
    juegos)     paso_juegos ;;
    verifica)   paso_verifica ;;
    *) echo "Uso: $0 [base|memoria|escritorio|kernel|juegos|verifica]" >&2; exit 1 ;;
esac
