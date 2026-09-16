# The Four — Hoja de ruta v0.3

Diseño completo: [GAME_DESIGN.md](GAME_DESIGN.md). Tareas y evidencias: [TODO.md](TODO.md).

## Implementado — Juego 0.3-H1

Repositorio migrado a `E:\Projects\The Four`, mapa fijo, movimiento en primera persona, colisiones, The Locust estático texturizado y música en bucle con controles. Validación del prototipo: [VALIDATION.md](VALIDATION.md).

H1 completado: interacción, puertas, tres fusibles, panel, ascensor, pausa real, victoria, muerte de prueba y reintento. Validación: [H1_VALIDATION.md](H1_VALIDATION.md). The Locust sigue estático; la captura por IA corresponde a H2.

## Primera etapa — H1 implementado; H2–H6 pendientes

1. **Implementado — Partida completa en mapa fijo:** interacción, puertas, fusibles, panel, ascensor, pausa, victoria, muerte y reintento.
2. **Supervivencia y The Locust:** percepción, navegación, ruido, persecución, búsqueda, resistencia, agacharse y escondites.
3. **Generación y guardado:** módulos, semillas reproducibles, validación, mapa de respaldo y checkpoints.
4. **Campaña de cuatro pisos:** Sunman, The Boiled One y Guilt, primero sobre mapas fijos y después generados.
5. **Presentación y rendimiento:** audio espacial y contextual, materiales, iluminación, VFX, accesibilidad y ajustes persistentes.
6. **Cooperativo y entrega:** 2–4 jugadores, sincronización, recuperación de sesión, exportación, permisos y créditos.

Cada hito conserva las reglas y la aceptación del diseño base. **La siguiente prioridad de desarrollo es el hito 2.**

## Puerta de entrada a la ampliación

Cerrar y validar los seis hitos: campaña completa jugable, objetivos y muerte fiables, generador validado, cooperativo comprobado, entrega preparada y ausencia de errores que bloqueen partidas. Registrar evidencia por hito. No basta con describir las funciones o marcar tareas.

## Ampliación posterior — Segunda etapa

7. **Ritmo y eventos:** director adaptativo, descansos de 30 s, señal ambiental tras 60 s sin amenaza/progreso, separación de 45 s entre eventos jugables y catálogo de 12 eventos.
8. **Variantes y riesgo opcional:** dos variantes por piso, tres objetivos obligatorios, almacén ruidoso, archivo y atajo expuesto; variantes fijas durante la partida y guardadas.
9. **Descubrimientos y desafíos:** 16 entradas, registro de campaña, códigos de partida y dos desafíos; persistencia de conocimiento sin ventajas estadísticas.
10. **Balance y consolidación:** registros locales, partidas de prueba, ajustes de legibilidad antes de dificultad y versión estable antes de más contenido.

El hito 7 depende de la primera etapa; el 8 del 7; el 9 del 8; el 10 del 9. Todos están pendientes y todavía no se activan en el prototipo.

## Límites acordados

Cuatro pisos, una amenaza principal por piso, sin combate, checkpoints entre pisos, progresión por descubrimientos y ritmo adaptativo sin cambiar capacidades de criaturas. No se añaden mejoras permanentes, tiendas, mapas infinitos, editor de mods, clasificaciones en línea ni nuevos enemigos.
