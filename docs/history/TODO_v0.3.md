# The Four — TODO de implementación v0.3

Fuente de reglas y valores: [GAME_DESIGN.md](GAME_DESIGN_v0.3.md). Orden resumido: [ROADMAP.md](ROADMAP_v0.3.md).

**Estado:** juego 0.3-H1; plan 0.3. H1 implementado y validado; H2–H6 pendientes. Las casillas pendientes no representan código existente. Para cerrar un hito, registrar revisión Git, pruebas, resultados y ubicación de evidencias. No usar la validación de una fase anterior para acreditar funciones nuevas.

## Implementado y validado previamente

- [x] Migración del repositorio y conservación del historial Git en E:.
- [x] Mapa fijo, movimiento en primera persona y colisiones.
- [x] The Locust estático con modelo y texturas aportados.
- [x] Música en bucle, silencio y volumen.
- [x] Validación del prototipo 0.2: 18 comprobaciones generales y 2 de audio. Evidencia: [VALIDATION.md](../VALIDATION.md); no se atribuyen a la ampliación futura.

## TODO actual — H1 implementado; H2–H6 pendientes

### H1 — Partida completa en mapa fijo

Estado: **implementado y validado**. Evidencia: [H1_VALIDATION.md](../H1_VALIDATION.md). La muerte es de prueba; ataques y supervivencia se implementarán en H2.

- [x] `GameSession`, estados de partida y autoridad única sobre objetivos/muerte.
- [x] Interacción a 2 m con línea de visión, puertas y tres fusibles únicos.
- [x] Panel y ascensor con arranque de 3 s y requisitos visibles.
- [x] Pausa real, victoria, muerte, reintento y vuelta al menú.
- [x] Completar y reintentar diez veces sin duplicaciones ni controles bloqueados; probar E repetidamente.
- [x] Registrar evidencia y aceptar H1.

### H2 — The Locust y supervivencia

Estado: **pendiente**. Dependencia: H1 aceptado.

- [ ] Navegación, patrulla, visión, ruido, investigación, persecución y búsqueda.
- [ ] Anticipación de ataque, alcance y comprobación de obstáculos.
- [ ] Resistencia, agacharse, escondites, distractores y memoria de entrada observada.
- [ ] Animaciones adecuadas y permisos de su uso.
- [ ] Probar muros, puertas, señuelos y pérdida de rastro; diez partidas con causas de muerte registradas.
- [ ] Registrar evidencia y aceptar H2.

### H3 — Generación y guardado

Estado: **pendiente**. Dependencia: H2 aceptado.

- [ ] Módulos y conectores; grafo conectado con ciclos y referencias visuales.
- [ ] Semillas/versiones; reglas de acceso, objetivos, recursos, cobertura y aparición.
- [ ] Navegación de jugador y criatura; rechazo de solapamientos y dependencias circulares.
- [ ] Veinte intentos máximos y mapa fijo validado de respaldo.
- [ ] Checkpoint por piso, escritura segura y restauración sin duplicaciones.
- [ ] Validar 1.000 semillas del primer piso, recorrer veinte y reproducir una semilla fallida.
- [ ] Registrar evidencia y aceptar H3.

### H4 — Campaña de cuatro pisos

Estado: **pendiente**. Dependencia: H3 aceptado.

- [ ] Sunman: exposición, cobertura, persianas y tres objetivos.
- [ ] The Boiled One: visibilidad real, intrusión, transmisores y tres objetivos.
- [ ] Guilt: registros, señuelos verificables, presión y cacería anunciada.
- [ ] Validar cada criatura en mapa fijo antes de integrar sus módulos al generador.
- [ ] Transiciones, checkpoints y victoria de campaña completa.
- [ ] Reglas aprendibles sin conocer el canon, contramedidas verificables y recorrido completo.
- [ ] Registrar evidencia y aceptar H4.

### H5 — Presentación y rendimiento

Estado: **pendiente**. Dependencia: H4 aceptado.

- [ ] Audio espacial/contextual y buses separados; pistas esenciales audibles.
- [ ] Materiales, iluminación y VFX; evaluar Forward+ antes de migrar el render.
- [ ] Subtítulos, efectos reducidos, opciones accesibles y ajustes persistentes.
- [ ] Perfilar la escena de mayor carga: meta de 60 FPS a 1080p en RTX 4060 Ti y calidad reducida.
- [ ] Recorrer campaña sin errores de recursos y con señales legibles.
- [ ] Registrar evidencia y aceptar H5.

### H6 — Cooperativo y entrega

Estado: **pendiente**. Dependencia: H5 aceptado.

- [ ] Cooperativo 2–4 jugadores y autoridad del servidor para IA, objetivos, objetos y muerte.
- [ ] Incapacitación, reanimación, segunda captura y derrota del grupo según diseño.
- [ ] Espectador sin revelar información oculta.
- [ ] Desconexión/reconexión y recuperación de sesión sin duplicaciones.
- [ ] Permisos de personajes, modelos y canción; créditos o sustituciones necesarias.
- [ ] Exportación y prueba en equipo sin editor instalado.
- [ ] Registrar evidencia y aceptar H6.

## Validación de entrada a segunda etapa

Estado: **no satisfecha**. No comenzar H7 hasta completar estas condiciones.

- [ ] H1–H6 aceptados con evidencia correspondiente a la revisión evaluada.
- [ ] Campaña completa jugable; objetivos y muerte fiables.
- [ ] Generador validado, cooperativo comprobado y entrega preparada.
- [ ] Cero errores conocidos que bloqueen partidas.
- [ ] Registrar decisión de apertura de la segunda etapa y revisión Git.

## Ampliación posterior — pendiente de sus dependencias

### H7 — Ritmo y eventos

- [ ] Director adaptativo y autorización de `GameSession`.
- [ ] Descanso hostil de 30 s; señal ambiental tras 60 s sin amenaza/progreso.
- [ ] Un evento jugable activo y separación mínima de 45 s.
- [ ] Investigación por objetivos sujeta a aparición válida y descanso.
- [ ] No variar capacidades, geometría ni recursos; protección de incapacitación/reanimación.
- [ ] Catálogo de 12 eventos con condiciones, duración, enfriamiento y efecto.
- [ ] Guilt no falsifica menús ni avisos de controles, guardado o accesibilidad.
- [ ] Pruebas de cancelación, exclusión, descanso y accesibilidad de los doce eventos.
- [ ] Registrar evidencia y aceptar H7.

### H8 — Variantes y riesgo opcional

- [ ] Dos variantes por piso, tres objetivos obligatorios y una variante fijada al crear partida.
- [ ] Guardar variante con semilla e instrucciones consistentes en la antesala.
- [ ] Almacén ruidoso, archivo con desvío y atajo expuesto.
- [ ] Ningún objetivo/recurso imprescindible en salas opcionales; riesgo anunciado e inventario respetado.
- [ ] Validar 1.000 semillas por piso, variante y dificultad soportada.
- [ ] Recorrer cinco partidas individuales por variante de piso y documentar resultados.
- [ ] Registrar evidencia y aceptar H8.

### H9 — Descubrimientos y desafíos

- [ ] Dieciséis entradas: dos pistas y dos piezas narrativas por criatura.
- [ ] Registro de campaña y distinción entre descubrir pistas y encontrar criaturas.
- [ ] Perfil persistente separado del checkpoint; conocimientos persisten tras morir.
- [ ] Códigos con semilla, versión, dificultad y variantes; rechazo explícito de incompatibilidad.
- [ ] Desafíos: campaña sin reintentos y piso sin distractores; no añaden condiciones de derrota.
- [ ] Sin mejoras permanentes, monedas, tiendas o ventajas estadísticas.
- [ ] Probar guardado/reintento sin duplicaciones ni conservación indebida del progreso de piso.
- [ ] Registrar evidencia y aceptar H9.

### H10 — Balance y consolidación

- [ ] Registros locales de duración, encuentros, persecución, muertes, objetivos y variantes.
- [ ] Analizar muertes sin aviso, habitaciones evitadas y objetivos lentos.
- [ ] Ajustar pistas, espacios y respuesta antes de dificultad; preservar identidad de criaturas.
- [ ] Regresión completa de primera etapa y pruebas de H7–H9.
- [ ] Campañas cooperativas completas de dos y cuatro jugadores; mismos eventos y sin duplicaciones al desconectar.
- [ ] Campaña completable, variaciones comprensibles, descansos respetados y rendimiento aceptado.
- [ ] Preparar/publicar versión estable antes de nuevos pisos o enemigos.
- [ ] Registrar evidencia y aceptar H10.

## Registro de cierres

H1: 16/09/2026. 37 comprobaciones funcionales, 18 de regresión y 2 de audio; diez ciclos de victoria/derrota y recorrido físico automatizado sin teletransporte. Revisión y evidencias en [H1_VALIDATION.md](../H1_VALIDATION.md). H2–H10 no tienen cierres registrados. Las partidas humanas y pruebas de campaña de hitos posteriores siguen pendientes.
