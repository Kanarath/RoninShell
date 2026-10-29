# RoninShell

Simulador de aprendizaje de pentesting, gamificado y 100 % local, hecho en Godot 4.7.

Aprendes Linux, Bash y pentesting **investigando** en un laboratorio controlado: recibes un objetivo, usas una terminal simulada con estado real, interpretas resultados y demuestras con evidencias lo que has conseguido. Sin historia, sin vidas, sin esperas.

## Estado

Fase de diseño. Todavía no hay código; el documento de diseño está en [`docs/GDD.md`](docs/GDD.md).

## Ideas clave

- **Aprender haciendo:** ningún reto se supera con una secuencia memorizada.
- **Terminal simulada con estado real:** hosts, puertos, servicios, archivos y permisos coherentes entre comandos. Nada llega al sistema anfitrión.
- **Pistas progresivas** en cuatro niveles, sin penalización que bloquee.
- **Pensado para sesiones cortas:** misiones de 10-15 min, micro-victorias, objetivo siempre visible, sin presión de tiempo.
- **Pixel art** generado con `pxl` para que la interfaz también enseñe.

## Requisitos (previstos)

- Godot 4.7 (sin Docker, sin base de datos, sin internet).
