# The Four — TODO v0.4

Estado: juego **0.4-P1**, diseño **0.4**. Las casillas describen implementación comprobada, no intención. [Diseño](GAME_DESIGN.md), [ruta](ROADMAP.md), [evidencias](V04_VALIDATION.md).

## P1 — Niveles y base de presentación

- [x] Hotel como escena principal; prototipo de fusibles conservado aparte.
- [x] Menú, Continuar condicionado, ajustes, créditos y salida.
- [x] Ajustes gráficos, imagen, controles reasignables y buses de audio persistentes.
- [x] Confirmación/reversión de pantalla y restauración de controles.
- [x] Veinte definiciones de módulos y más de quince tipos de props originales provisionales.
- [x] Generador reproducible de 100–132 módulos y cinco sectores, ciclos y salida distante.
- [x] Decoración en posiciones reservadas, validación de conectividad, colisiones y navegación.
- [x] Respaldo fijo; rechazo de mapas que no superen la validación.
- [x] Puertas convencionales normales/lentas, protección del umbral y linterna ilimitada.
- [x] Salida libre, refugio reversible, confirmación de 3 s y victoria de primer piso.
- [x] Checkpoint al inicio, reintento de misma distribución y aviso de incompatibilidad.
- [x] Forward+ y alternativa Compatibility; iluminación, ambiente y filtro iniciales.
- [ ] Completar veinte recorridos manuales y cinco partidas de exploración para aceptar duración y orientación. No sustituirlos por el lote automático.
- [ ] Ajustar tamaño y referencias a partir de esas partidas; meta de 25–40 min todavía no validada.

## P2 — Atmósfera analógica

- [x] Inventario técnico de los cinco audios y conservación de originales.
- [x] Ambiente inicial, mezcla, bucle y control de volumen.
- [ ] Escucha y selección definitiva de los cinco audios; edición de copias y procedencia documentada.
- [ ] Fuentes espaciales fijas, acústica por recinto, pasos, conductos, tuberías y silencio contextual.
- [ ] Materiales PBR terminados, reflejos y composición de escenas de referencia.
- [ ] Polvo, aire, cortinas animadas y niebla localizada.
- [ ] Sustitución gradual del mobiliario provisional por assets adecuados y acreditados.
- [ ] Accesibilidad, mezcla y rendimiento sostenido en la escena más exigente.

## P3 — Cooperativo y hoja paranormal

- [x] Separación de estado global/individual y regla matemática de supervivientes en sesión local.
- [ ] ENet LAN/IP para 2–4: sala, preparación y manifiesto común.
- [ ] Autoridad del anfitrión para jugadores, puertas, muerte y transición.
- [ ] Hoja vacía: Tab, izquierdo dibuja, derecho borra; acciones simultáneas ordenadas.
- [ ] Hoja detiene movimiento sin pausar; sin mapa ni posiciones automáticas.
- [ ] Sincronización, tráfico limitado y restauración de hoja al reconectar.
- [ ] Refugio con regreso: todos los vivos deben llegar, mínimos 1/2, 2/3 y 2/4.
- [ ] Reconexión de 60 s sin reducir cuota; recuperación tras caída del anfitrión.
- [ ] Observación de compañero vivo tras muerte, sin cámara libre ni edición.
- [ ] Evidencias de sesiones reales de 2, 3 y 4 jugadores.

## P4 — Escondite y The Locust

- [ ] Agacharse, resistencia, ruido y escondites interactivos.
- [ ] Percepción real, investigación, persecución y búsqueda; memoria de entrada observada.
- [ ] Navegación de búsqueda dentro de habitaciones y tratamiento de puertas cerradas.
- [ ] Ataques con alcance, visibilidad y anticipación; permisos/animaciones adecuados.
- [ ] Validar acompañamiento y regreso desde el refugio; muertes comprensibles.

## P5 — Campaña

- [ ] Sunman en atrios y galerías; cobertura y barridos anunciados.
- [ ] Boiled One en habitaciones/salones con pantallas; exposición comprobada.
- [ ] Guilt con señales contrastables; nunca falsifica hoja ni interfaz esencial.
- [ ] Tres conjuntos procedurales adicionales y 1.000 semillas validadas por conjunto.
- [ ] Checkpoints entre cuatro pisos, reaparición de fallecidos y victoria final.
- [ ] Campañas completas de dos y cuatro jugadores sin bloqueos.

## P6 — Consolidación

- [ ] Director: descanso 30 s, separación 45 s y un evento jugable activo.
- [ ] Doce eventos con requisitos y cancelación; estar quieto no dispara ataques.
- [ ] Dieciséis descubrimientos, registro y códigos compatibles; sin progresión de poder.
- [ ] Desafíos opcionales sin condiciones ocultas de derrota.
- [ ] Balance basado en datos locales; objetivo 60 FPS/1080p y perfiles reducidos.
- [ ] Permisos de criaturas/modelos/canción, créditos y exportaciones sin editor.

## Historial

H1 v0.3 validó fusibles y sesión fija. Permanece en [H1_VALIDATION.md](H1_VALIDATION.md), pero sus resultados no acreditan el hotel, la IA ni el cooperativo. Cierre técnico y limitaciones de P1 en [V04_VALIDATION.md](V04_VALIDATION.md).
