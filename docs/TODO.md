# The Four — TODO v0.4

Estado: juego **0.4-S1**, diseño **0.4**. Las casillas describen implementación comprobada, no intención. [Diseño](GAME_DESIGN.md), [ruta](ROADMAP.md), [evidencias](SURVIVAL_VALIDATION.md).

## P1 — Niveles y base de presentación

- [x] Hotel como escena principal; prototipo de fusibles conservado aparte.
- [x] Menú, Continuar condicionado, ajustes, créditos y salida.
- [x] Subtítulos desactivados por defecto (activables en Ajustes > Audio).
- [x] Ejecutable de Windows con `./tools/godot.ps1 export`.
- [x] Ajustes gráficos, imagen, controles reasignables y buses de audio persistentes.
- [x] Confirmación/reversión de pantalla y restauración de controles.
- [x] Arranque en pantalla completa; ventana ajustada y centrada; ajustes gráficos que no redimensionan la ventana.
- [x] Veinte definiciones de módulos y más de quince tipos de props originales provisionales.
- [x] Generador reproducible de 100–132 módulos y cinco sectores, ciclos y salida distante.
- [x] Decoración en posiciones reservadas, validación de conectividad, colisiones y navegación.
- [x] Respaldo fijo; rechazo de mapas que no superen la validación.
- [x] Puertas convencionales normales/lentas, protección del umbral y linterna ilimitada.
- [x] Salida libre, refugio reversible, confirmación de 3 s y victoria de primer piso.
- [x] Checkpoint al inicio, reintento de misma distribución y aviso de incompatibilidad.
- [x] Forward+ y alternativa Compatibility; iluminación, ambiente y filtro iniciales.
- [x] Dimensiones rectangulares variables, salones unidos de dos/tres módulos y cuatro variantes de particiones interiores; generador v3.
- [x] Navegación derivada de colisiones; accesos físicos a escondites.
- [ ] Completar veinte recorridos manuales y cinco partidas de exploración para aceptar duración y orientación. No sustituirlos por el lote automático.
- [ ] Ajustar tamaño y referencias a partir de esas partidas; meta de 25–40 min todavía no validada.

## P2 — Atmósfera analógica

- [x] Catalogar 33 archivos de sfx y conservar originales; preparar copias de trabajo.
- [x] Puertas con grupos cercanos/lejanos y apertura lenta, sin repetición inmediata; cierres solo al completarse.
- [x] Sonidos de entrada/salida de escondite y límite de efectos simultáneos.
- [x] Ambiente nuevo y perfil espacial de Locust, oclusión aproximada, mezcla y subtítulos.
- [x] Curva de volumen con referencia al 50 %, limitador y mezcla recalibrada con mediciones.
- [x] Aura espacial de The Locust por ruta caminable (dron, respiración, chasquidos, crecida, latidos, ambiente amortiguado) sin subtítulo (retirado a petición).
- [x] Reverberación según la sala del oyente, zumbido de fluorescentes.
- [ ] Escucha crítica y balance humano de las nuevas asignaciones y del aura; eventos ambientales en salones.
- [ ] Perfiles sonoros distintos para las otras tres criaturas al incorporarlas.


- [x] Inventario técnico de los cinco audios y conservación de originales.
- [x] Ambiente inicial, mezcla, bucle y control de volumen.
- [ ] Escucha y selección definitiva de los cinco audios; edición de copias y procedencia documentada.
- [ ] Fuentes espaciales fijas, acústica por recinto, pasos, conductos, tuberías y silencio contextual.
- [ ] Materiales PBR terminados, reflejos y composición de escenas de referencia.
- [x] Polvo suspendido, cortinas animadas y niebla localizada, con perfiles reducidos.
- [x] Material procedural de madera y sondas de reflexión en espacios comunes.
- [x] Materiales procedurales con relieve y desgaste (papel pintado, moqueta estampada, techo, madera barnizada, azulejo, tela, metal, cuadros) y carga automática de texturas fotográficas desde `assets/textures/`.
- [x] Filtro de videocámara/VHS ampliado con líneas de barrido regulables y marcas REC/fecha opcionales; tonemapping AgX, SSIL (SDFGI desactivado por fugas de luz), linterna con patrón de reflector, lámparas que iluminan y fluorescentes con parpadeo.
- [x] Detalle geométrico sin colisión: molduras, rodapiés, marcos de puerta, puertas con cuarterones y muebles con cojines, cajones, libros, patas y plantas.
- [x] Luces con sombra y desvanecimiento por distancia (sin fugas a través de muros ni encendidos bruscos); lámparas atenuadas; manchas continuas sin cortes rectangulares.
- [x] Efectos arrancan sin silencio inicial y los cierres coinciden con el impacto; portazos al abrir o cerrar corriendo.
- [x] HUD de videocámara: corchetes de enfoque, medidor de resistencia, mensajes breves; sin listas de controles en pantalla. Menús, intro y pantallas finales con el mismo estilo.
- [x] Linterna en mano con retraso, balanceo y calentamiento.
- [ ] Texturas fotográficas CC0 seleccionadas e importadas, con licencia registrada; revisión visual humana de la nueva iluminación y de la legibilidad en zonas oscuras.
- [ ] Acabado PBR definitivo, efectos de conductos y variedad artística adicional.
- [ ] Sustitución gradual del mobiliario provisional por assets adecuados y acreditados.
- [ ] Accesibilidad, mezcla y rendimiento sostenido en la escena más exigente.

## P3 — Cooperativo y hoja paranormal

- [x] Separación de estado global/individual y regla matemática de supervivientes en sesión local.
- [ ] ENet LAN/IP para 2–4: sala, preparación y manifiesto común.
- [ ] Autoridad del anfitrión para jugadores, puertas, muerte y transición.
- [ ] Reproducir `paper/paper.ogg` una vez al abrir la hoja; sonido local, sin alterar oído de la IA. Copia preparada; disparador pendiente.
- [ ] Hoja vacía: Tab, izquierdo dibuja, derecho borra; acciones simultáneas ordenadas.
- [ ] Hoja detiene movimiento sin pausar; sin mapa ni posiciones automáticas.
- [ ] Sincronización, tráfico limitado y restauración de hoja al reconectar.
- [ ] Refugio con regreso: todos los vivos deben llegar, mínimos 1/2, 2/3 y 2/4.
- [ ] Reconexión de 60 s sin reducir cuota; recuperación tras caída del anfitrión.
- [ ] Observación de compañero vivo tras muerte, sin cámara libre ni edición.
- [ ] Evidencias de sesiones reales de 2, 3 y 4 jugadores.

## P4 — Escondite y The Locust

- [ ] Armario con puertas: ocultación física exterior del jugador y abertura frontal estrecha visible desde dentro.
- [ ] Efecto gradual de claustrofobia: periferia oscurecida y distorsión de ojo de pez que amplíe la abertura sin permitir ver a través de madera/paredes.
- [ ] Conservar mirada parcial hacia delante, señales de presencia y control del jugador; salida revierte el efecto sin saltos.
- [ ] Ajuste reducido/sin distorsión; comprobar comodidad, nitidez, diferentes resoluciones y señales con música desactivada.
- [ ] Verificar desde dentro y fuera, entrada observada por Locust y futura visibilidad entre clientes. No convertir el armario en invulnerabilidad.


- [x] Agacharse, resistencia, ruido de pasos/saltos/puertas y escondites interactivos en individual.
- [x] Percepción con paredes/puertas, investigación, persecución, búsqueda y memoria de entrada observada, en individual.
- [x] Navegación física dentro de habitaciones; la criatura abre lentamente y espera a las puertas.
- [x] Ataque de 0,7 s con alcance <1,2 m y línea de visión; fallar permite escapar; captura real y reintento.
- [x] Pasos/aviso originales en bus de peligro; movimiento y preparación procedural provisional del modelo.
- [x] Locust orientado hacia su avance, animación procedural con pies anclados al suelo (IK de dos huesos), brazos-cuchilla por estado, cabeza que sigue al objetivo y pasos sincronizados con cada pisada.
- [x] Sospecha gradual por distancia, linterna, carrera y agacharse; reacción a linterna lejana; velocidad variable y pérdida de rastro al romper la línea de visión.
- [x] Pasos del jugador por distancia recorrida y balanceo de cámara ligado a cada pisada.
- [ ] Animación final, permisos del personaje/modelo y balance de persecución en partidas humanas.
- [x] Refugio bloquea percepción/captura; reintento restablece amenaza, postura, resistencia y escondite.
- [ ] Validar acompañamiento y regreso en cooperativo cuando exista red; evaluar comprensión de muertes con jugadores.

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

Esta ampliación adelanta supervivencia individual por petición del usuario; no acredita P3 ni cierra toda la atmósfera. Ver [validación S1](SURVIVAL_VALIDATION.md) y [protocolo humano](PLAYTEST_HOTEL.md). Los muebles externos siguen pendientes expresamente.
