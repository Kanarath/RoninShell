# Arte de RoninShell

El pixel art se escribe como código en `roninshell.px.js` y se renderiza con **pxl**.

```
build_art.cmd
```

Genera los PNG en `assets/sprites/` (los que usa el juego) y los previews ampliados en `art/out/_preview/` (no se versionan). Necesita Node 22.18+.

Paleta "ronin neón": negro, teal para información y oro para recompensas (ver `ui/theme/palette.gd`).

| Sprite | Uso |
| --- | --- |
| `host_you`, `host_pc`, `host_server`, `host_router`, `host_ghost` | Nodos del mapa de red; `host_ghost` es un host aún sin descubrir |
| `door_open`, `door_filtered`, `door_closed` | Estado de los puertos vistos en un escaneo |
| `icon_ssh`, `icon_http`, `icon_ftp`, `icon_lock` | Iconos de servicio |
| `seal_done`, `seal_active`, `seal_pending`, `seal_locked` | Sellos de objetivo |
| `ronin_idle`, `ronin_happy`, `ronin_think`, `ronin_alert` | La mascota, según lo que ocurre |
| `torii` | Decoración |
