# RoninShell

Simulador de aprendizaje de pentesting, gamificado y 100 % local, hecho en Godot 4.7.

Aprendes Linux, Bash y pentesting **investigando** en un laboratorio controlado: recibes un objetivo, usas una terminal simulada con estado real, interpretas resultados y demuestras con evidencias lo que has conseguido. Sin historia, sin vidas, sin esperas.

## Estado

Paso 1 del plan completado: esqueleto del proyecto Godot y tests en consola. El diseño está en [`docs/GDD.md`](docs/GDD.md).

## Ejecutar los tests

```
run_tests.cmd
```

Lanza Godot en modo consola (`--headless`), descubre `tests/test_*.gd`, ejecuta cada método `test_*` y devuelve código de salida 1 si algo falla. Si Godot no está en la ruta por defecto, define la variable de entorno `GODOT` con la ruta del `.exe` de consola.

## Estructura

| Carpeta | Contenido |
| --- | --- |
| `engine/` | Motor de laboratorio, sin interfaz (próximos pasos) |
| `data/` | Laboratorios, misiones y fichas como datos |
| `ui/`, `scenes/` | Interfaz de Godot |
| `tests/` | Runner y tests automáticos |

## Ideas clave

- **Aprender haciendo:** ningún reto se supera con una secuencia memorizada.
- **Terminal simulada con estado real:** hosts, puertos, servicios, archivos y permisos coherentes entre comandos. Nada llega al sistema anfitrión.
- **Pistas progresivas** en cuatro niveles, sin penalización que bloquee.
- **Pensado para sesiones cortas:** misiones de 10-15 min, micro-victorias, objetivo siempre visible, sin presión de tiempo.
- **Pixel art** generado con `pxl` para que la interfaz también enseñe.

## Requisitos (previstos)

- Godot 4.7 (sin Docker, sin base de datos, sin internet).
