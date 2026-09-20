# The Four — Validación del hito 1

> **Informe histórico.** Registra lo comprobado en su fecha, no el estado actual. Para eso están [GAME_DESIGN.md](GAME_DESIGN.md) y [PLAN.md](PLAN.md).

Fecha: 16/09/2026. Juego: **0.3-H1**. Godot: **4.7.2 Steam**. Plataforma: Windows.

Revisión de código evaluada: `8e5117fab1a77db9f44d3fefc3206cfee9006b9f`.

## Resultado

**H1 implementado y validado en su alcance de mapa fijo y muerte de prueba.** 57 comprobaciones aprobadas: 37 funcionales, 18 de regresión y 2 de audio. Además, un recorrido físico automatizado completó el piso usando movimiento e interacción, sin teletransportar al jugador. Se inspeccionaron las capturas del menú, panel y victoria.

La prueba funcional incluye diez ciclos completos de recoger e instalar fusibles, arrancar, ganar, reintentar, activar muerte de prueba, volver al menú e iniciar otra partida. No se detectaron duplicaciones de objetos ni bloqueos de controles en esos ciclos.

## Qué se comprobó

- Inicio desde menú y reinicio completo de objetos, puertas, inventario y controles.
- Interacción por cámara a 2 m; los muros bloquean el foco. Los identificadores desconocidos o repetidos no crean fusibles.
- Puertas con pulsación corta y apertura lenta. El cierre se rechaza si el jugador ocupa el umbral, también al finalizar el movimiento.
- Pausa real: movimiento y reloj detenidos; no se recogen ni instalan objetos mientras está pausado.
- Tres fusibles distintos e instalación individual; no hay victoria con objetivos incompletos.
- Arranque durante 3 s: requiere mirar el panel y estar completamente dentro de la cabina. Soltar E o perder foco cancela el progreso. Instalar el tercer fusible requiere una nueva pulsación antes de arrancar.
- La transición bloquea capturas tardías y termina en victoria de piso; muerte y salida son estados excluyentes.
- Diez ciclos verifican limpieza de inventario, restauración de fusibles y puertas, y botones de menú/reintento.
- Regresión de movimiento, colisiones, paso por puerta abierta, modelo y controles de música.
- Decodificación MP3 real: 61.440 muestras capturadas, pico aproximado 0,025. La pista vuelve al principio al alcanzar el final.

## Reproducción

Desde `E:\Projects\The Four`, ejecutar en PowerShell:

```powershell
./tools/godot.ps1 h1-test
./tools/godot.ps1 test
./tools/godot.ps1 audio-test
./tools/godot.ps1 walkthrough
```

La última prueba abre una ventana de render y maneja un recorrido con entradas de movimiento e interacción. Su informe registra `position_teleports: 0` y `won: true`. Estos recorridos son automatizados; no se presentan como partidas humanas de balance.

Evidencias locales regenerables, excluidas de Git:

- `evidence/h1_tests.json`: 37 comprobaciones y resultado global.
- `evidence/tests.json`: 18 comprobaciones de regresión.
- `evidence/audio_test.json`: mezcla real y bucle.
- `evidence/h1_walkthrough.json`: recorrido físico, objetivos visitados y victoria.
- `evidence/h1_menu.png`, `h1_fuse.png`, `h1_panel.png`, `h1_victory.png`, `h1_defeat.png`: capturas del recorrido.

Para comprobarlo manualmente, abrir `Jugar.cmd`, iniciar, explorar las salas, recoger tres fusibles con E, regresar al panel, instalarlos y mantener E durante 3 s desde dentro de la cabina. Esc pausa. En ejecución de desarrollo, F9 activa la muerte de prueba y permite verificar reintento y menú.

## Límites de esta aceptación

The Locust sigue estático: no existe percepción, persecución ni ataque. F9 es una herramienta de prueba condicionada a `OS.is_debug_build()`, no una mecánica final de muerte. La pantalla final corresponde al primer piso, no a una campaña de cuatro pisos. El reintento restaura el mapa fijo en memoria; todavía no hay guardado persistente.

Los diez ciclos no acreditan IA, generación, guardado, cooperativo, balance o rendimiento final. H2–H6 siguen pendientes. H7–H10 permanecen bloqueados por las dependencias del plan, sin funciones adelantadas. El uso público de los assets sigue sujeto a lo registrado en [ASSETS.md](ASSETS.md).

En algunas ejecuciones del test de audio Godot avisó de dos instancias pendientes al salir; la repetición con salida detallada y limpieza explícita terminó sin ese aviso. Ambas comprobaciones de audio pasaron en todas las ejecuciones registradas.
