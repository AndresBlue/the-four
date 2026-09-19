# The Four — TODO v0.4

Estado: juego **0.4-S1**, diseño **0.4**. Las casillas describen implementación comprobada, no intención. [Diseño](GAME_DESIGN.md), [ruta](ROADMAP.md), [evidencias](SURVIVAL_VALIDATION.md).

## P0 — Cierre del Early Access (prioridad alta)

Pedido del 19/09/2026 tras las pruebas con amigos. Es lo que cierra la etapa de Early Access y va por delante del resto de pendientes. Nada de esta sección está implementado todavía.

### El piso de The Locust en tres etapas

- [ ] **Tres etapas encadenadas**, cada una cerrada por una condición. Al cumplirla se desbloquea una puerta cerrada con llave que da paso a la etapa siguiente; ya no se termina en la habitación de refugio (decidir qué papel le queda al refugio).
- [ ] **Etapa 1:** la condición de salida actual (llegar al refugio con la cuota de supervivientes y mantener), pero lo que abre es la puerta de la etapa 2.
- [ ] **Etapa 2: encender televisores**, tantos como jugadores haya; se generan 2 teles más de las exigidas.
- [ ] **The Locust usa las teles:** desde una tele encendida puede teletransportarse a otra tele encendida con una interfaz propia. Esa interfaz es un «mapa» que solo muestra la posición relativa entre las teles, coherente con la distribución real, sin salas, paredes ni números.
- [ ] **Etapa 3:** además de las teles, encontrar **4 números** para abrir una cerradura de código. Se esconden en cajones o libreros de las habitaciones.
- [ ] **Apagón final:** cuando solo queda por encender la última tele, se apagan todas las luces del piso y la criatura caza sin límite de resistencia. Se le avisa de forma no textual (sonido y señal en su visión) y tiene que entender que ocurrió.
- [ ] **Revivir entre etapas:** los supervivientes muertos vuelven al pasar a la etapa siguiente.
- [ ] **Aviso a la criatura al cambiar de etapa:** una señal simbólica que reconozca (sobre todo en versus) y, en su visión de partículas, el camino marcado hasta la puerta de la nueva etapa, para que no pierda tiempo en una etapa ya vacía.
- [ ] **En red:** el anfitrión decide y sincroniza todo lo anterior (teles, números, cerradura, puertas con llave, apagón, revivir), con pruebas en `verify.ps1` para cooperativo y versus.

### Mapa y ritmo

- [ ] **La generación es sólida técnicamente pero floja como juego.** Tanto novatos como expertos siguen la numeración de las puertas hacia arriba hasta la salida, sin estrategia. Hubo partidas terminadas en 1 min 30 s y a menudo sin cruzarse con la criatura. No es culpa de su IA, que está equilibrada (casi un poco injusta, y está bien), sino de que los recorridos nunca se cruzan. Hace falta que la numeración no delate la dirección, que los objetivos de las tres etapas obliguen a recorrer el piso y a atravesar el territorio de la criatura, y medirlo con partidas humanas (ver también el pendiente de P1 sobre la duración).

### The Locust

- [ ] **Gruñidos al ver y perseguir:** los jugadores no oyen `grunts.ogg` cuando la criatura los ve y los persigue. Revisarlo con la IA (cooperativo e individual) y en versus, donde hoy el cazador humano solo suena al chillar, y comprobar que se oye en todas las máquinas.
- [ ] **El chillido depende mucho de la distancia:** hoy suena casi como un sonido global y no dice si está cerca. A 10, 20 y 40 m tiene que oírse claramente distinto (volumen, filtrado, reverberación, por dónde llega), y no debe oírse mucho más allá del alcance de lo que el chillido ofrece (26 m de escucha).
- [ ] **Nueva ejecución**, en este orden:
  1. **El screamer salta al agarrarte:** en el instante en que la criatura atrapa a la víctima, un sonido muy feo que asuste de verdad, como un screamer de FNAF.
  2. La sostiene varios segundos acercándole la cara despacio.
  3. La mata enterrándole el brazo en la cara.
  4. Estática como la de la escena de entrada.
  5. Transición a la pantalla de SEÑAL PERDIDA.

  Sustituye la ejecución actual (2,9 s y tres estocadas) y resuelve el pendiente de P4b sobre su animación.

### Supervivientes

- [ ] **Cordura (medidor interno de oscuridad):** baja con el tiempo pasado a oscuras (armarios, salas apagadas). La linterna encendida no la detiene: solo hace que baje más despacio. También baja de golpe al ver a la criatura. Se recupera en salas iluminadas. Con la cordura baja, alucinaciones sonoras alrededor del jugador, de modo que la criatura parezca venir de direcciones contradictorias y no se distinga bien de dónde viene. Encajarla con el aura (`dread_aura.gd`) y la escucha binaural, y decidir cuánto se permite engañar.
- [ ] **Revisión completa de las animaciones con esqueleto:** hoy son malísimas o no existen. Caminar, correr, saltar, agacharse quieto y moverse agachado tienen que verse naturales y realistas, con detalles como quedarse en cuclillas apoyando una mano en el suelo y levantarla al avanzar agachado. Aplica a todos los movimientos, al propio cuerpo y a los compañeros en red.

### Cierre

- [ ] **Partidas de prueba con amigos** (individual, cooperativo y versus) midiendo duración, encuentros con la criatura y comprensión de las etapas antes de dar por cerrado el Early Access.

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
- [ ] **Individual demasiado corto y tranquilo (pruebas con amigos, septiembre de 2026).** La mayoría encontró la salida de forma consistente y casi sin tener que huir de la criatura: desde 1 min 30 s, con una media de 5 a 8 min, muy lejos de la meta de 25–40 min. Hay que revisar a la vez lo fácil que es orientarse hasta la salida (tamaño del piso, referencias, colocación de la salida) y la presión de The Locust (cuánto patrulla cerca, lo pronto que encuentra al jugador, eventos del director), y volver a medir con partidas humanas. Se aborda en P0 (etapas, y Mapa y ritmo).

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
- [x] Oscuridad y fugas de luz (septiembre de 2026): linternas de compañeros que se veían a través de paredes, lámparas que alumbraban tras paredes y puertas cerradas, salas apagadas con número de puerta, pantallas y paredes visibles; más salas oscuras y en tramos; puerta de madera antigua con marco. Ver `docs/DEVELOPMENT.md` (Luces) y `tools/capture/darkness_capture.gd`.
- [ ] Juzgar en partida la oscuridad nueva: sin luz ambiente, los rincones en sombra de las salas iluminadas también son negros. Si resulta excesivo, no conviene subir `ambient_light_energy` (aclara también las salas apagadas); mejor dar relleno propio a las salas iluminadas.
- [ ] Revisar a mano las puertas nuevas (escala del modelo, número en el panel superior, rendija de 1,2 cm) y las del dormitorio y la portada, que usan la misma hoja.
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
- [x] Auditoría de rendimiento (septiembre de 2026), medida con el benchmark nuevo a 1080p: sombras que ya no se redibujan en cada fotograma, lotes por sala, paredes compartidas dibujadas una vez, occlusion culling, LOD en muebles de modelo, texturas de puerta y personajes comprimidas, filtro de sombras por preset y tirones de CPU (visión de eco, rutas de sonido). GPU entre −30 % y −55 % según calidad y vista en el PC de desarrollo. Ver [PERFORMANCE.md](PERFORMANCE.md).
- [x] Cuadros y apliques de las paredes oeste y norte colgaban en la cara de la sala vecina (marcos superpuestos, paredes desnudas); ahora cada pared tiene los suyos.
- [ ] Revisar en partida lo que las capturas fijas no enseñan: cuadros y apliques nuevos, sombras con el filtro más barato en Baja y Media en movimiento, salas que aparezcan tarde al girar en un vano (oclusión).
- [ ] Medir `tools/benchmarks/run_bench.ps1` en un PC modesto (los de las pruebas con amigos) y anotarlo en PERFORMANCE.md.

## P3 — Cooperativo y hoja paranormal

- [x] Separación de estado global/individual y regla matemática de supervivientes en sesión local.
- [x] ENet LAN/IP para 2–5: sala con plazas, nombres y personajes, opciones del anfitrión y piso común comprobado por huella.
- [x] Tipos de partida: cooperativo contra IA y versus (The Locust elegido o al azar).
- [x] Autoridad del anfitrión para puertas, armarios, criatura, muertes, salida y final.
- [x] Reproducir `paper/paper.ogg` una vez al abrir la hoja.
- [x] Hoja vacía: Tab, izquierdo dibuja, derecho borra; acciones simultáneas ordenadas por el anfitrión.
- [x] Hoja detiene movimiento sin pausar; sin mapa ni posiciones automáticas.
- [x] Sincronización, tráfico limitado y restauración de hoja al reconectar.
- [x] Refugio con regreso: todos los vivos deben llegar, mínimo `ceil(N/2)`.
- [x] Reconexión de 60 s sin reducir cuota; aviso y checkpoint en línea si cae el anfitrión.
- [x] Observación de compañero vivo tras muerte, sin cámara libre ni edición.
- [x] Versus: control de The Locust, estocada juzgada por el anfitrión, anillos de ruido.
- [x] Prueba en red automática con procesos reales (cooperativo de tres y versus de dos) dentro de `verify.ps1`.
- [x] Los cuerpos de los jugadores no frenan a la criatura; los muertos desaparecen y no bloquean puertas ni pasillos.
- [x] Observación en tercera persona tras morir, con brazo de cámara que no atraviesa paredes ni armarios.
- [x] Ritual del armario: se planta, abre hoja a hoja y mira dentro (unos 2,5 s inmóvil), en individual y en red.
- [x] Ejecución de tres estocadas en el aire en vez de muerte instantánea.
- [x] Chillido útil: revela supervivientes cercanos unos segundos y da caza libre; los demás lo oyen desde su propia copia de la criatura.
- [x] Caza de The Locust más larga y con recuperación rápida: escapar corriendo no es viable.
- [x] Pasos de los compañeros más bajos y ruta de sonido calculada desde la cámara que escucha.
- [ ] Evidencias de sesiones reales de 2, 3, 4 y 5 jugadores en LAN y por Internet.
- [ ] Balance humano del ritual del armario, la ejecución y el chillido.
- [ ] Balance humano del versus (velocidades, resistencia de caza, alcance de la estocada, contactos de sonido).
- [ ] Revisar en partida el volumen de los pasos de los compañeros.

## P4 — Escondite y The Locust

- [x] Armario con puertas (modelo aportado): ocultación física exterior y rendija visible desde dentro.
- [x] Efecto gradual de claustrofobia: periferia oscurecida y ojo de pez leve que se abre al asomarse; las puertas siguen bloqueando la vista.
- [x] Asomarse abriendo lentamente las puertas para mirar a izquierda, delante y derecha; salir revierte el efecto.
- [x] Efectos reducidos desactivan encierro y distorsión.
- [ ] Comprobar comodidad del efecto en partidas humanas y a distintas resoluciones.
- [x] Verificado dentro y fuera: puertas cerradas ocultan, entreabiertas delatan, entrada observada o ruido cercano hacen que la criatura abra y ataque.
- [ ] Visibilidad del armario entre clientes cuando exista red.
- [x] Armarios solo en habitaciones (1–2 por módulo, ninguno en pasillos ni salones) y puertas de hotel más estrechas (vano 1,3 m).


- [x] Agacharse, resistencia, ruido de pasos/saltos/puertas y escondites interactivos en individual.
- [x] Percepción con paredes/puertas, investigación, persecución, búsqueda y memoria de entrada observada, en individual.
- [x] Navegación física dentro de habitaciones; la criatura abre lentamente y espera a las puertas.
- [x] Ataque de 0,7 s con alcance <1,2 m y línea de visión; fallar permite escapar; captura real y reintento.
- [x] Pasos/aviso originales en bus de peligro; movimiento y preparación procedural provisional del modelo.
- [x] Locust orientado hacia su avance, animación procedural con pies anclados al suelo (IK de dos huesos), brazos-cuchilla por estado, cabeza que sigue al objetivo y pasos sincronizados con cada pisada.
- [x] Sospecha gradual por distancia, linterna, carrera y agacharse; reacción a linterna lejana; velocidad variable y pérdida de rastro al romper la línea de visión.
- [x] Pasos del jugador por distancia recorrida y balanceo de cámara ligado a cada pisada.
- [x] Pasos grabados por superficie (moqueta/baldosa) con el golpe alineado a la pisada.
- [x] Puertas a 3,2 m, cierre a la espalda y umbral que solo bloquea dentro del marco.
- [x] Asomarse del armario por cada puerta según hacia dónde se mira; solo la primera apertura cruje.
- [x] Zumbido audible en todos los fluorescentes de servicio.
- [ ] Comprobar en partida el nivel de los pasos grabados y del zumbido.
- [x] Pasos más bajos y sin eco de salón (bus `Steps`).
- [x] Locust: alerta de 1,2 s y arranque progresivo antes de perseguir; sospecha más lenta.
- [ ] Balance de la alerta de Locust en partidas humanas.
- [x] Escena de entrada: dormitorio, tele con Locust golpeando el cristal, huida por el pasillo; saltable.
- [x] Tele de 80 cm con The Locust en 3D golpeando el cristal (grietas en el punto de impacto), estática y parpadeo más intensos, crujidos de cama, pasos marcados, cámara con muelles y balanceo, giro desesperado al cerrar, salida hacia la recepción con luz roja.
- [x] Aspecto de The Locust según la imagen de referencia (cuerpo negro, máscara pálida), en juego y escena.
- [ ] Revisar en partida el ritmo y la cámara de la escena de entrada.
- [x] Portada: habitación normal detrás del menú con The Locust asomándose por la rendija de la puerta entreabierta.
- [x] Menú Multijugador (en desarrollo) con Personaje dentro; Personaje sale del menú principal.
- [x] Audio binaural de The Locust (retardo y nivel por oído) y filtro para sonidos por detrás.
- [ ] Escuchar con auriculares la dirección de The Locust en partida (esquinas, dos puertas).
- [x] Texto pequeño «E  para saltar cinemática» arriba a la derecha.
- [x] Cama de la escena de entrada con la grabación aportada.
- [x] Apertura lenta sin ruido de micrófono, más baja y con final suave.
- [x] Números de puerta que indican la habitación de detrás; algunas habitaciones con la luz apagada.
- [x] Sofá, aplique de pared y monstera descargados integrados en el hotel (la dieffenbachia es `.blend` y queda fuera).
- [x] Locust agresivo: percepción de largo alcance, oído por rutas, persecución más rápida que el sprint, portazos, estocada casi inevitable, mayor tamaño y gruñidos.
- [x] Sonidos que no atraviesan muros: llegan desde la abertura de la ruta con eco (buses EffectsEcho/ThreatEcho).
- [x] Exploradora animada (esqueleto del cuerpo) y señal visual de la estocada sin texto.
- [ ] Balance de la nueva agresividad y de la propagación en partidas humanas.
- [x] Refugio bloquea percepción/captura; reintento restablece amenaza, postura, resistencia y escondite.
- [ ] Validar acompañamiento y regreso en cooperativo cuando exista red; evaluar comprensión de muertes con jugadores.

## P4b — Visión de The Locust — implementada (pendiente de ajuste humano)

- [x] Revisión completa de la vista del jugador que lleva a The Locust: imagen monocroma con su propio grano y contraste, reconstruida de pulsos acústicos sobre la profundidad real.
- [x] Información sonora integrada en la imagen (dónde, a qué distancia, por dónde llega y qué lo produjo) en lugar de los anillos rojos, que quedan eliminados.
- [x] Legible qué es un superviviente, qué es un ruido y qué es memoria; los cuerpos solo aparecen cuando `sees()` los concede y nunca a través de una pared, y de lejos un ruido solo da la dirección.
- [x] Prueba en `verify.ps1` (`hotel/echo_test`), comprobación de shaders con ventana y capturas de evidencia.
- [ ] Ajuste humano de la imagen: término base, separación de los frentes, legibilidad en salones grandes (ver `docs/VISION_LOCUST.md`).
- [ ] Probar la vista en el lanzador `compatibility`; hoy solo está validada en Forward+.
- [ ] La animación de la ejecución vista desde el cazador todavía es floja: es lo único que le dice que atrapó a alguien (ya no hay aviso en texto). Se sustituye por la nueva ejecución de P0.
- [ ] Juzgar en partida el peso de cada tipo de ruido en la vista (paso, carrera, puerta, armario con apagado rápido) con `./tools/godot.ps1 rehearsal`.

## P5 — Campaña

- [ ] Sunman en atrios y galerías; cobertura y barridos anunciados.
- [ ] Boiled One en habitaciones/salones con pantallas; exposición comprobada.
- [ ] Guilt con señales contrastables; nunca falsifica hoja ni interfaz esencial.
- [ ] Tres conjuntos procedurales adicionales y 1.000 semillas validadas por conjunto.
- [ ] Checkpoints entre cuatro pisos, reaparición de fallecidos y victoria final.
- [ ] Campañas completas de dos y cuatro jugadores sin bloqueos.

## P6 — Consolidación

- [x] Director: descanso 30 s, separación 45 s y un evento jugable activo (piso de Locust).
- [x] Tres eventos de Locust (golpes, objeto caído, pasos) con requisitos y cancelación; estar quieto no dispara ataques.
- [ ] Los nueve eventos de las otras criaturas.
- [x] Cuatro descubrimientos de Locust: documentos legibles, archivo persistente en el menú.
- [ ] Los doce descubrimientos restantes, registro de partidas y códigos compatibles; sin progresión de poder.
- [ ] Balance humano del director (frecuencia y distancia de eventos) y revisión de los textos de los documentos.
- [ ] Desafíos opcionales sin condiciones ocultas de derrota.
- [ ] Balance basado en datos locales; objetivo 60 FPS/1080p y perfiles reducidos.
- [ ] Permisos de criaturas/modelos/canción, créditos y exportaciones sin editor.

## Historial

H1 v0.3 validó fusibles y sesión fija. Permanece en [H1_VALIDATION.md](H1_VALIDATION.md), pero sus resultados no acreditan el hotel, la IA ni el cooperativo. Cierre técnico y limitaciones de P1 en [V04_VALIDATION.md](V04_VALIDATION.md).

Esta ampliación adelanta supervivencia individual por petición del usuario; no acredita P3 ni cierra toda la atmósfera. Ver [validación S1](SURVIVAL_VALIDATION.md) y [protocolo humano](PLAYTEST_HOTEL.md). Los muebles externos siguen pendientes expresamente.
