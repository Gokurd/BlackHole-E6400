# BlackHole-E6400

Sistema Linux para **Dell Latitude E6400** (Core 2 Duo 64-bit, 2 GB de RAM,
BIOS A14 Legacy): base antiX/Debian 64-bit, estabilidad tipo Bodhi 5.1.0,
escritorio mínimo (~250 MB en reposo) y look **«Windows Vista + Black Hole
Matrix»**: cristal oscuro, orbe verde de Inicio, lluvia Matrix y agujero negro.

![Fondo BlackHole](preview-blackhole.png)

## Requisitos

- antiX 64-bit (base/core, sin systemd) o Debian netinst 64-bit **sin** tarea
  de escritorio.
- BIOS (F2): Boot en Legacy, USB boot activado.
- USB creado con `dd` o Rufus (MBR + destino BIOS).

## Instalación (en el equipo ya instalado)

```bash
cd BlackHole-E6400
./install-e6400.sh            # todo el sistema, guiado
```

O por pasos:

| Paso | Comando | Qué hace |
|------|---------|----------|
| 1 | `./install-e6400.sh base` | Paquetes del escritorio mínimo |
| 2 | `./install-e6400.sh memoria` | ZRAM (lz4, 50%) + earlyoom + sysctl |
| 3 | `./install-e6400.sh escritorio` | Tema BlackHole-Aero, tint2, jgmenu, picom, fondo y orbe |
| 4 | `./install-e6400.sh kernel` | Parámetros GRUB (pregunta por mitigations=off) |
| 5 | `./install-e6400.sh juegos` | Mesa, VAAPI, mpv, RetroArch, núcleos libretro |
| 6 | `./install-e6400.sh verifica` | Comprobaciones finales |

Después: cierra sesión y entra en `tty1` — el escritorio arranca solo
(sin gestor de login, ahorra 30–60 MB).

## Notas

- **Wi-Fi Broadcom**: con cable Ethernet, añade `contrib non-free
  non-free-firmware` a las fuentes e instala `firmware-b43-installer`
  (si Bodhi cargaba `b43`) o `broadcom-sta-dkms` (si cargaba `wl`).
- **Fondo y orbe** se generan con `bin/blackhole.py` (resolución por
  argumentos o variables `W`/`H`).
- **Juegos**: `~/bin/juego retroarch` apaga picom, lanza el juego y lo
  reactiva al salir.
- **Navegador**: Firefox ESR con 4–6 pestañas y uBlock Origin; en
  `about:config`: `dom.ipc.processCount=2`,
  `browser.sessionhistory.max_total_viewers=1`,
  `browser.tabs.unloadOnLowMemory=true`.
- **Recuperación**: si algo falla, arranca con el kernel de la distro desde
  «Advanced options» de GRUB y corrige el último paso aplicado.
