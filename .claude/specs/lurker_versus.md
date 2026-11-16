# The Lurker en Versus: diseño y plan de implementación

Nota del director, 16 de noviembre de 2026, segunda versión, tras la crítica. **Aprobada por el autor el 16 de noviembre con las propuestas de las decisiones A a J** (sección 12), y con un cambio suyo que manda sobre todo lo demás:

> **Sin aura.** «Es NECESARIO que deje de hacer ruidos del tipo dread aura, ya que te pone en estado de alerta [...] penaliza mucho a la bestia, revelando siempre cuándo está cerca, la idea es que menos es más, si el jugador no sabe, siempre se va a sentir perseguido. Cambiemos eso de forma global [...]. Seguirá haciendo sonidos de tubería y similares, pero haremos que la cordura disminuyendo sea tan macabra con las alucinaciones para hacer sentir que está cerca tuyo cuando no lo está.»

En consecuencia: The Lurker no tiene aura en ningún modo (ni zumbido, ni ambiente apagado, ni chasquidos por la ruta, ni latido por su distancia, ni bucle de presencia), y la música no sigue su distancia oculta. Siguen los ruidos de su cuerpo donde está (tuberías, ductos, placas, golpes, polvo), las luces que tiemblan y el aviso de la espalda. Lo que hace sentirla cerca sin estarlo son las alucinaciones de la cordura. En la sección 6, «su respiración a menos de 3 m» deja de delatarla acechando.

- Hechos del código: `.claude/specs/fichas/versus_locust.md`, `lurker_ia.md`, `lurker_vista.md`, `oficinas_acecho.md` (levantadas por Haiku: comprobarlas al usarlas).
- Las objeciones de tres críticos, con sus pruebas en el código: `.claude/specs/fichas/criticas_lurker_versus.md`. Lo que cambió por ellas está marcado **[crítica]**.
- Cuando el autor la apruebe, sustituye a `docs/OFICINAS.md` §7 y cambia §11.6 (vista en grises, `lurker_view.gd`, «cualquier superficie»).

## 1. Lo que pide el autor

- Que **no se sienta como un escondite**, como The Locust. La bestia no puede limitarse a perseguir: tiene que **esperar en sitios estratégicos** (el reborde de una puerta, una esquina oscura) y **saltar**. Y que quien la lleva **lo descubra solo**.
- **Vista «eléctrica»** con el mapa de color plasma: oscuridad en morado y azul; lo amarillo y blanco, la electricidad, y sobre todo las linternas.
- **El fogonazo:** alumbrada de frente, la pantalla se le va a blanco unos segundos y el personaje **se esconde solo**.
- **Habilidades:** el parpadeo automático de las luces al pasar; **beber la luz** con el chillido, que apaga del todo la sala y las linternas unos segundos, con el juego de reencenderla a pulsaciones.
- **Ajustar a la IA** del cooperativo para que apague de verdad sin ser brutal.
- Lo demás, de mi cosecha, y proponer cambios si veo algo mejor.

## 2. La regla de oro y cómo se impone sin decirla

**Quien acecha, caza. Quien persigue, pierde.** No sale en ningún texto: sale de seis reglas que quien la lleva nota en las manos.

| # | Regla | Qué siente quien la lleva |
|---|---|---|
| 1 | **Vista, es lenta.** Si un superviviente la tiene en su campo de visión, va a ráfagas (1,8 m/s de media; ellos andan a 3,8). Ya es así con la IA. | Seguir a alguien que mira atrás no lleva a nada. |
| 2 | **Arriba o nada. [crítica]** No tiene suelo: vive en el techo, las bandas de pared y de puerta, los canales y los ductos. «Bajar» es descolgarse. | No puede correr detrás de nadie por un pasillo. |
| 3 | **Solo coge por la espalda, y avisa.** El contrato de `docs/OFICINAS.md` §1 no cambia por llevarla una persona. | Hay que elegir el momento en que la presa no puede girarse. |
| 4 | **El acecho se carga vigilando. [crítica]** Asentada en un sitio de acecho y con la presa a la vista sin que la vean, en 2 s gana alcance para empezar el aviso: de 2,5 m (y solo desde encima) pasa a 7 m. | Un buen sitio es el que tiene vista. Esperar es vigilar, no estar quieta. |
| 5 | **Mirada con luz, huye; alumbrada, se ciega.** Las dos reglas de la IA, iguales. | Ir de frente es lo peor que se puede hacer. |
| 6 | **Su paso se nota, a oscuras también. [crítica]** Las lámparas tiemblan cuando se mueve cerca, y el haz de una linterna encendida a menos de 4,5 m titila. Quieta 1 s, deja de temblar (la lámpara sigue baja). | Moverse delata; asentarse, no. |

Durante la ventana del aviso no pasa de 3,8 m/s (el `CUE_FOLLOW` de hoy): **correr siempre salva**, así que la emboscada rinde donde la presa no puede correr.

## 3. El perfil del Versus del piso 2 [crítica]

Hoy Versus fuerza la dificultad de referencia (Desafiante, `net_session.gd:431`): ventana de 0,9 s, el 90 % de la planta 1 a oscuras, linterna bebida 10 s y apagada para siempre el 60 % de las veces. Con eso el modo no es el que se quiere. Versus del piso 2 lleva **perfil propio**:

| Cifra | Valor de partida |
|---|---|
| Ventana del aviso de la espalda | 1,2 s más la latencia de quien lo sufre (0,5 s como mucho); regla de partida con mínimo 0,9 |
| Oscuridad de la planta 1 | la del manifiesto, como en Equilibrada |
| Linterna bebida tras cegarla | 4 s |
| Linterna apagada para siempre | nunca |
| Quieta tras una captura | el `sated` de hoy, sin texto de lore |

## 4. Cómo ve: la vista eléctrica

### 4.1 Lo que se ve
- **La geometría, en plasma oscuro:** morado y azul, legible sin luz. No depende de las lámparas de la escena.
- **La electricidad es calor**, pintado encima como halos: salas encendidas (magenta a naranja), luminarias y aparatos con corriente (naranja a amarillo), **linternas** (amarillo a blanco, con un halo que nada más tiene).
- **Los objetivos brillan porque son eléctricos:** la máquina de escribir, la estación que espera una cápsula, el cuadro y sus zonas, la consola, la climatizadora. Ella ve adónde tienen que ir. Es su ventaja de estratega.
- **El ruido se ve** como anillos, con la lectura acústica que ya tiene The Locust: pasos a la carrera, puertas, el tecleo, un timbre, y **el clic de una linterna** a 8 m. **[crítica]**
- **Una sala encendida la deslumbra:** dentro no distingue nada más allá de 4 m (lo que hoy ve la IA).
- **En los ductos:** el plano esquemático de la red con sus salidas.

### 4.2 A los supervivientes (decisión A: afina lo que pide el autor)
El autor dice «siempre sabrá dónde están». Propongo:

- **Linterna encendida: baliza a través de las paredes** hasta 30 m. Da dirección y distancia aproximada, no silueta. No con una placa cerrada delante ni desde un ducto oculto; nunca una linterna bebida.
- **Linterna apagada: no se la ve a través de las paredes.** En línea de vista, lo que le den sus sentidos (`sees()`, como la IA).
- **Linterna fría [crítica]:** encendida hace menos de 0,5 s, ni salva ni ciega. Sin esto, lo óptimo sería ir a oscuras y encenderla al oír el aviso, y la decisión no existiría.
- **Sin cordura, a la vista [crítica]:** quien llega a cordura 0 se ve a través de las paredes como silueta fría (ya existe para The Locust). Es el precio de ir a oscuras mucho rato.

El superviviente elige: **la luz lo protege y lo delata; la oscuridad lo esconde, lo deja medio segundo tarde y le come la cordura.** Alternativa si el autor lo prefiere: siempre visibles hasta 30 m.

### 4.3 El fogonazo y la huida
Las dos reglas de la IA, tal cual, decididas por el anfitrión: **[crítica]**

- **Linterna sin beber en la cara** (20 m y 20°, el haz 0,15 s seguidos): **fogonazo**.
  1. la pantalla sube a blanco en 0,15 s y vuelve en unos 2,5 s; el blanco nace del lado de la linterna que la cegó;
  2. **el personaje se esconde solo**: el cuerpo sale disparado a la salida oscura más cercana (es `motion.bolt()`, lo que ya hace la IA);
  3. el aviso y la bebida, en espera 6 s;
  4. la linterna que la cegó queda bebida 4 s (no puede encadenar; un compañero, sí);
  5. inmune a otro fogonazo mientras dura y 1 s más.
- **Mirada en una sala con luz:** huida forzada de 0,3 a 0,4 s, sin blanco y sin espera.
- **Efectos reducidos:** el blanco se queda en la mitad, sin parpadeo.

### 4.4 Cómo se hace [crítica]
- Su máquina solo dibuja su vista: **todo es local**, sin capas de render nuevas (las 20 están ocupadas).
- Su asiento de presentación pone `echo_view = true`, que ya apaga lámparas, decals, polvo y niebla en las dos geometrías; encima, luz ambiente plana y un shader de pantalla que pinta plasma por profundidad y normal, con un uniforme de fogonazo.
- **El calor sale de los registros**, no de la luminancia: `troffer_lamps` según `lit()` y lo bebido, `emergency`, `landmark_lamps`, las lucecitas de los objetivos y las linternas, como halos aditivos sin profundidad. Es barato, no pide sombras y no depende de que la sala esté dibujada.
- Su cámara no dibuja su propia tinta (capa 4).
- **Sin filtro en el anfitrión:** las posiciones viajan como hoy (los pasos se oyen por ellas); qué se dibuja lo decide su máquina, como el eco de The Locust.

### 4.5 La estética de una grabación térmica (pedido del autor, 16 de noviembre; hecha, estado en la sección 11)

El autor: «la idea es que se vea bien realista como la grabación de una cámara infrarroja»; y después: «me refiero a la estética, no función real térmica, obviamente esto es eléctrico». **Lo que brilla sigue siendo la electricidad** (luminarias, aparatos, objetivos y, sobre todo, las linternas), y lo que ve de los supervivientes no cambia (decisión A). Cambia el aspecto: tiene que parecer grabado con una cámara térmica. La vista de la fase 2 es estilizada (degradado por profundidad, bolas difusas, anillos). A construir cuando termine la fase 3:

1. **Ganancia automática (AGC):** la imagen se estira cada momento entre lo más oscuro y lo más «caliente» (eléctrico) a la vista, con la reacción lenta de una cámara real. Sin nada eléctrico delante, las paredes salen texturadas, moteadas y con ruido; si entra una linterna o una luminaria, todo lo demás se hunde a oscuro y la fuente se quema a blanco. **El fogonazo pasa a ser eso:** la cámara saturada.
2. **Formas, no bolas:** lo eléctrico brilla con su forma (el tubo y la caja de la luminaria, el cuerpo del aparato, la cabeza de la linterna), con el halo blando que deja una fuente caliente en una cámara térmica, y su calor «manchando» un poco las superficies de alrededor (el techo junto a cada luminaria).
3. **Superficies con textura térmica:** nada de un degradado liso por distancia; paredes, suelo y techo en tonos bajos y casi parejos, con manchas suaves, esquinas y juntas algo distintas, y **los cables de la red eléctrica** como líneas tenues tras el falso techo y las paredes, de cada luminaria a su interruptor y al cuadro.
4. **El sensor:** poca resolución reescalada, ruido de patrón fijo (rayas verticales tenues) y temporal, viñeta, bordes realzados, una pizca de retardo, y de vez en cuando la congelación con chasquido de la calibración (NUC), sobre todo tras saturarse.
5. **A través de las paredes** (decisión A, se mantiene): la linterna tras un muro se dibuja como una mancha templada en la cara del muro, como una fuente detrás del yeso en una grabación térmica, en vez de un punto flotando en el aire.
6. **La interfaz de la cámara,** mínima: la retícula central y la barra de la paleta en un lado, como en una grabación térmica; sin cifras ni textos.
7. **Paleta:** plasma, como pidió el autor (la más cercana de las reales es la «Ironbow» o «Lava»).

## 5. Cómo se mueve [crítica]

- **El cuerpo de la IA con mando híbrido.** Las intenciones del cerebro son órdenes con planificador de rutas: con un mando se sentirían blandas. Se añade a `lurker_motion.gd` un tramo **libre**: el mando fija rumbo y velocidad y avanza con `shell.advance`, que ya cruza juntas abiertas y para en muros y columnas, conservando ráfagas y rampas. Las transiciones (banda de puerta, canal, rejilla, placa, salto) son órdenes de contexto al planificador de hoy y corren solas.
- **Sin suelo.** Techo, bandas, canales, ductos y plénum. Una acción la **descuelga** (hasta 1,5 m, la pose del aviso). El suelo solo existe como final del salto de la captura.
- **No abre puertas.** Una puerta cerrada la manda a los ductos.
- **No entra** en vestíbulos de montacargas ni refugios.
- **Cámara en sus ojos, con el «arriba» del mundo**, aparte del cuerpo: el rumbo del cuerpo sigue al giro de la cámara. La cara queda a unos 2,15 a 2,45 m. Al pasar por una rejilla o una placa y durante la huida, corte al plano de ductos; durante el salto de la captura, la cámara se queda en el sitio. (Decisión C; alternativa, tercera persona.)

## 6. El acecho

- **Sitios de acecho**, de datos que ya existen en `lurker_shell.gd`: **[crítica]** la banda de puerta por el lado de la sala (el dintel; quedan 0,30 m sobre el marco), las esquinas de bandeja, la boca de un canal de archivo y encima de una taquilla. Fuera los que caen junto a una lámpara y los de salas prohibidas. La pose es la de sujetarse con las manos procedurales: no hacen falta animaciones.
- **Acechar:** una acción la pega al sitio más cercano (a menos de 3 m). Los cercanos se marcan en su vista.
- **Asentada** (quieta 1 s): deja de temblar la luz, oye 1,5 veces más lejos y puede **cargar** (regla 4).
- **La carga pide la cara fuera.** Dentro del plénum, tras una placa cerrada o en la boca de una rejilla no se carga: ahí nadie puede alumbrarla. Abrir una placa cruje, suelta polvo y reinicia el asentarse.
- **Lo que la delata acechando:** la lámpara que sigue baja; la linterna de quien mira arriba. (Su respiración ya no: sin aura.) **Mirar arriba al entrar** pasa a ser la habilidad del superviviente.
- **Dónde rinde:** donde hay que dar la espalda. La ventanilla (5 s tecleando), una estación del tubo, el cuadro, los ventiladores, leer un papel, salir de una taquilla. Como esos sitios brillan en su vista, acaba esperando ahí.
- **Las salas de hito no se pueden beber** (ventanilla, cuarto eléctrico, seguridad, climatización: nunca a oscuras). Allí solo cae quien va solo o a quien nadie mira. Se acepta: son el terreno de ellos.

## 7. El aviso y la captura [crítica]

Es el código de hoy, con una persona eligiendo el momento:

1. **Soltar** desde el acecho: se descuelga a la pose del aviso y **empieza el aviso de la espalda**. Solo si se cumple lo que hoy pide la IA: detrás o encima, nadie mirándola, ninguna linterna en su cara, presa no protegida ni escondida, y a distancia (hasta 2,5 m sin carga; hasta 7 m con ella).
2. La presa tiene **su ventana** (sección 3).
3. **Si se gira y la alumbra, o la mira con luz:** fogonazo o huida. **Si corre** y sale del alcance: se salva. **Si no:** la captura es el salto que ya existe.
4. La misma presa no recibe otro aviso en 4 s.

- **Asomarse** (ya aprobado en §7; sustituye al amago que propuse): dejarse ver al borde de la vista de alguien, sin el sonido del aviso. Baja la cordura de quien la ve, una vez cada 10 s por persona como mucho. **No hay avisos falsos:** el aviso de la espalda nunca miente.
- **Autoridad:** el anfitrión juzga el aviso, la mirada, el fogonazo, las esperas y `may_snuff`; la víctima puede reclamar «la estaba mirando» (§11.6).

## 8. Habilidades

| Habilidad | Qué hace | Límites |
|---|---|---|
| **Parpadeo** (pasiva) | Las lámparas a 3 a 4,5 m bajan y tiemblan al moverse; el haz de una linterna cercana titila. | Automático. Quieta 1 s, el temblor cesa y la lámpara sigue baja. |
| **Beber** | Un chillido propio, distinto del de espantarse. La sala queda **a oscuras del todo** en 0,2 s y unos 6 s; **las linternas de dentro se apagan**. | Espera de 25 s y 45 s para repetir sala. Se localiza por el sonido. **No puede empezar un aviso hasta 1,5 s después.** Solo salas que pueden estar a oscuras (`may_snuff`): nunca hitos, vestíbulos ni refugios; no apaga apliques de hito ni la emergencia. Encender la luz de la sala la echa. |
| **Reencender** (superviviente) | La linterna apagada por una bebida **no queda bebida**: vuelve **a la tercera pulsación, nunca antes de 1,0 s**. Cifra fija, nunca azar. | Es el juego de pulsaciones que pide el autor, con número cerrado. |
| **Acechar y soltar** | Secciones 6 y 7. | Espera de 6 s tras un fogonazo. |
| **Asomarse** | Sección 7. | Una vez cada 10 s por persona. |
| **Señuelo** (mío, decisión D) | Hace sonar un aparato que ya imitan las alucinaciones (teléfono, máquina de escribir, fotocopiadora) a menos de 25 m, 4 s. | Dos cargas por planta. Nunca estaciones, cuadro, tictac ni ventiladores, que no mienten. Opcional. |

La cuenta de beber y soltar: chillido en 0; la linterna vuelve, como pronto, en 1,0 s; el aviso no empieza antes de 1,5 s; la ventana dura 1,2 s. Quien reacciona tiene linterna antes del aviso. Gana ella cuando la presa está ocupada, sola o ya sin linterna.

## 9. Cada planta, con ella jugada

- **Planta 1:** con el perfil de la sección 3, casi toda con luz. Las salas encendidas protegen y su vista se deslumbra. Sus bazas: las estaciones del tubo (ve cuál se enciende), beber la sala de quien recoge, los ductos. Es la planta donde los dos lados aprenden.
- **Planta 2:** el camino encendido desde el cuadro es su obstáculo; las zonas a oscuras, su terreno. No toca el cuadro. El cruce final a oscuras es su ocasión.
- **Planta 3:** las linternas son las únicas luces y el titileo del haz es lo único que avisa de su paso. Los ventiladores la echan de los ductos y le quitan el oído. **El ducto principal (decisión I):** hoy no puede avisar desde dentro de un ducto. Propongo que allí pueda, solo a quien no mira atrás y con 0,5 s más de ventana; si no, en el ducto solo asusta.

Se gana y se pierde como hoy. Quien cae vuelve al cambiar de planta, como en cooperativo (sin comprobar en el código).

## 10. La IA en cooperativo: beber de verdad sin ser brutal [crítica]

La IA usa el mismo beber. Los frenos, por dificultad:

| Freno | Apacible | Equilibrada | Desafiante | Pesadilla |
|---|---|---|---|---|
| Bebe salas | no | sí | sí | sí |
| Preaviso (las lámparas bajan y sube un siseo) | n/a | 1,0 s | 0,8 s | 0,6 s |
| Apagón | n/a | 4 s | 5 s | 6 s |
| Primer aviso tras el chillido | n/a | 1,5 s | 1,2 s | 1,0 s |
| Espera entre bebidas | n/a | 60 s | 45 s | 35 s |

Iguales en las tres que beben:
- las linternas se apagan **sin quedar bebidas** y vuelven con el reencendido de la sección 8;
- un intento de captura por apagón;
- nunca contra una presa con la linterna ya bebida, ni en los 10 s siguientes a un susto suyo;
- nunca con un aviso en marcha;
- solo con `may_snuff`, y solo tras acechar a alguien el tiempo de su dificultad, como hoy: se nota venir.

Así sigue valiendo el contrato: tras beber, **siguen salvando la linterna reencendida, la de un compañero y correr.** Los bots de prueba reaccionan al apagón con su tiempo de reacción más dos pulsaciones humanas, para que la medida valga.

## 11. Plan de implementación [crítica]

Cada fase termina con su prueba de aceptación y `verify.ps1` en verde. El piso 1 y The Locust no cambian.

| Fase | Tamaño | Qué se construye | Prueba de aceptación |
|---|---|---|---|
| **0. Su cuerpo, sin red** | mediana | Rama de jugador en `step_physics`; «ai» pasa a «no réplica» donde toca al cuerpo; tramo libre con `shell.advance` y transiciones por el planificador; cámara en sus ojos; sin suelo; `--bots-hunt` en el piso 2 y un conductor guionizado sin interfaz. | El conductor recorre bandeja, puerta, canal, rejilla y placa y vuelve; `lurker_shell_test` y `lurker_motion_test` en verde. |
| **1. El aviso en red y el juez** | grande | Hoy el aviso no viaja por la red: el anfitrión tiene la criatura como réplica y nadie lo juzga ni lo manda a la víctima. RPC del aviso con su plazo, latencia medida, percepción y juicio en el anfitrión sobre la réplica, la captura ordenada por el anfitrión, la reclamación de la mirada. **Sirve también al cooperativo con invitados.** | `net_test` en el piso 2 con un invitado de víctima: oye su aviso; el registro sale limpio con 150 ms de latencia simulada; quien se gira, la ciega. |
| **2. La vista** | mediana | Asiento de presentación, plasma por profundidad, halos de los registros, anillos de ruido, balizas, fogonazo, plano de ductos. | Capturas en las tres plantas; banco del asiento en Alto dentro del presupuesto. |
| **3. Acecho y juego** | mediana | Sitios de acecho, asentarse, carga por presa vigilada, soltar, asomarse, huida automática, perfil del Versus, esperas validadas por el anfitrión. | Variante de `lurker_fairness_test` con conductor: coge a quien da la espalda; el que se gira la ciega; nunca coge sin aviso; a quien corre no lo alcanza. |
| **4. Beber** | pequeña | Beber en Versus (subida rápida del evento que ya existe, linternas que vuelven en la máquina a cargo, validación), parpadeo ligado al movimiento, titileo del haz, linterna fría, reencendido; **la IA con sus frenos**. | En red, sala y linternas se apagan y vuelven en todas las máquinas; `lurker_fairness_test` y bots en las cuatro dificultades dentro de la banda que se fije. |
| **5. La partida** | mediana | Versus admite el piso 2; reglas de partida de ella; sala (quién la lleva); final; informe; logros; el escenario `versus` del piso 2 en `verify`. | Una partida entera de las tres plantas con bots y conductor. |
| **6. Señuelo** | pequeña | Solo si el autor lo quiere. | Sesiones de juego. |

**El informe del piso** de quien la llevó no explica la regla: da «capturas» y «aviso más largo» (en metros), y la cifra habla sola.

**Los tres riesgos:**
1. Que el contrato justo aguante en red con dos saltos (cazadora y víctima invitadas, el anfitrión en medio).
2. Que el manejo se sienta bien sobre un movimiento pensado para una IA.
3. Que «acechar gana» salga de verdad con personas: ningún test lo prueba; hay que jugarlo tras la fase 3.

### Estado de la fase 0 (16 de noviembre de 2026)

Hecha, sin red. Se prueba con `./tools/godot.ps1 lurker-hunt` (piso 2, 3 bots, semilla 81, perfil de pruebas; `-Bots` y `-Seed` como en `hunt`).

- **Cuerpo:** `lurker.gd` tiene rama `"player"` en `step_physics` (el cerebro no corre; su conductor, sí) y lo que toca al cuerpo pasa a `!= "puppet"` (`view`, `transit_phase`, `show_body`, la vigilancia de puertas de `routes`). `hunter_camera()` da su cámara.
- **Tramo libre** (`lurker_motion.follow_free`): el stick fija rumbo y ritmo y avanza con `shell.advance` por bandejas (cruza lados abiertos, para en muros y columnas) y a lo largo de un canal. Rampas y ráfagas de siempre: vista, va a ráfagas. Su ritmo máximo es el `unseen_speed` de la dificultad.
- **Transiciones** (`lurker_player.gd`), órdenes al planificador que corren enteras con el stick ignorado: empujar hacia una puerta abierta la pasa por el dintel (cerrada, no pasa); empujar a lo largo de un canal en su boca la mete, agarrada a la estantería a 1,8 m; `lurker_enter` entra en la rejilla o la placa más a la vista a menos de 3 m, y dentro de los ductos sale por la salida más a la vista a menos de 25 m (solo por ductos hasta ella). `lurker_drop` la descuelga hasta 1,5 m (lo que deje el rayo) y la sube.
- **Cámara:** en su cara con el arriba del mundo, giro por ratón o stick, sin su capa 4. Si algo se mete entre su anclaje y su cara (la estantería de enfrente en un pasillo estrecho), la cámara se queda 12 cm antes. Al pasar una rejilla, una placa o un ducto: negro; quieta en la boca de una rejilla, mira desde ella.
- **Teclas y mando:** mover WASD / stick izquierdo; mirar ratón / stick derecho; entrar y salir E / botón izquierdo (X en Xbox); descolgarse Ctrl / botón derecho (B). Declaradas sin efecto: `lurker_stalk` (Q / Y), `lurker_peek` (F / A), `lurker_release` (clic izquierdo / gatillo derecho), `lurker_drink` (clic derecho / gatillo izquierdo).
- **Aceptación:** `tests/office/lurker_player_test.gd` (el conductor) 26/26 en las tres plantas: techo, puerta (y cerrada no pasa), canal (solo hay archivo con pasillo en la planta 2 con la semilla 81), rejilla, placa, ducto y vuelta, descolgada; sin muros atravesados ni ojo dentro de un muro. Registro y capturas en `evidence/versus/f0/`. `lurker_shell_test`, `lurker_motion_test`, `creature_contract_test`, `lurker_fairness_test`, `lurker_bots_test`, `office_bots_test` y `manifest_golden_test` en verde.
- **Lo que no convence aún:** en Desafiante las plantas 2 y 3 están a oscuras y su cámara no ve nada (lo resuelve su vista, fase 2). Dentro de los ductos va a ciegas y elige la salida por dónde mira sin verla (el plano es de la fase 2). Arranca en 1,1 s hasta 4,5 m/s: se siente blanda. Empujar hacia una puerta sin querer la cruza, y alinearse con el dintel la frena un momento. Sobre un dintel una hoja abierta tapa media vista.

### Estado de la fase 1 (16 de noviembre de 2026)

Hecha. Se prueba con `tools/net_test.ps1 -Scenario lurker_coop -Port 24660` y `-Scenario lurker_versus -Port 24670`: piso 2, semilla 81, y la víctima entra por una línea lenta que abre su propio proceso (puerto + 5) y retiene cada datagrama 75 ms en cada sentido. No están en `verify.ps1`.

- **El error del cooperativo (1.4.0), medido:** el aviso solo sonaba en el anfitrión. A un invitado, la IA lo avisaba, él no lo oía y lo cogía igual al vencer el plazo; su ventana no llevaba latencia (`latency_for` solo lo rellenan las pruebas). Registro antes del arreglo en `evidence/versus/f1/coop_before_*`. Arreglado: el aviso viaja.
- **Lo que viaja** (`match_net.gd`, todo fiable salvo el ping):
  - `cue_rpc`: del anfitrión a todos, con asiento, id, punto, plazo (ventana más latencia) y si viene de arriba. La víctima lo oye en binaural con su subtítulo y empieza su ventana; los demás, por la planta.
  - `cue_heard`: la víctima avisa de que lo oyó; entra en `heard_after` del registro.
  - `cue_over_rpc`: el fin del aviso, en todas las máquinas.
  - `claim_rpc`: la víctima reclama «la estaba mirando».
  - `request_release`: quien la lleva pide soltar.
  - `cue_take`: el anfitrión le ordena el salto.
  - `ping` y `pong`: la latencia.
- **Latencia:** el anfitrión mide la ida y vuelta con cada invitado cada 0,5 s y la suaviza; sube despacio y baja deprisa, para olvidar el atasco de construir el piso. Entra en la ventana, hasta 0,5 s. Con la línea de 150 ms mide unos 0,20 s: los fotogramas de las dos máquinas también cuentan.
- **El juez:** con The Lurker llevada por una persona, la máquina a cargo (el anfitrión, o la única sin red) juzga sobre su copia (`lurker.judge()`): `senses.perceive` y `warning.check` en cada tick del aviso. `in_network_duct`, `duct_node` y `at_exit` leen las banderas de red en la réplica, no un movimiento parado.
- **Soltar** (`judge_release()`): empieza el aviso detrás del superviviente más cercano que cumpla lo que hoy pide la IA (`lurker_brain.cue_allowed`, el `cue_ready` sin su estado ni su presa). Rechaza la petición que llega antes de 0,5 s de la anterior, a la misma presa antes de 4 s, en la gracia y en tránsito.
- **La captura** la ordena el anfitrión al vencer el plazo: `order_take` manda el salto a quien la lleva y el anfitrión captura en ese mismo tick, por la puerta de siempre (`may_capture`).
- **La reclamación:** en la máquina de la víctima, el primer tick de su ventana en que su jugador la mira como contaría allí, la reclama, una vez. El anfitrión la acepta si su propia mirada a ese cuerpo coincide en los 0,15 s siguientes: desde la vista más nueva que le llegó (no la dibujada 0,1 s atrás) y con 15° más de cono. Una linterna bebida no cuenta.
- **El contrato** (`creature.gd`) suma `cue_heard_by`, `claim_look`, `judge_release` y `take_leap`, vacíos salvo en ella; `play_cue` lleva `above`.
- **Versus en el piso 2, para probar:** el escenario pone `options.floor = 2` después de elegir Versus; el menú de la sala sigue forzando el piso 1 (fase 5). La orden de soltar es `match_net.lurker_release()`; la acción `lurker_release` del mando sigue sin efecto (vive en `lurker_player.gd`). La ventana es la de Desafiante (0,9 s); el perfil propio es de la fase 3.
- **Aceptación:** `lurker_coop`: el invitado oye sus dos avisos con su ventana y su latencia; girarse con la linterna lo salva (lo juzga el anfitrión) y quedarse de espaldas lo deja coger al vencer el plazo; el registro pasa `audit()` con la línea de 150 ms. `lurker_versus`: la cazadora invitada pide soltar; delante de la víctima o dos veces seguidas, el anfitrión dice que no; detrás, empieza el aviso; la víctima invitada se gira y se salva, o no y la coge; nadie capturado sin aviso. Registros en `evidence/versus/f1/`. En verde, una por una: `creature_contract_test`, `lurker_fairness_test`, `lurker_senses_test`, `lurker_capture_test`, `lurker_bots_test`, `office_bots_test`, `lurker_player_test`, `manifest_golden_test`, y los escenarios de red `coop`, `versus`, `late`, `observer` y `office_coop`.
- **Lo que no convence aún:**
  - Sin la reclamación, el anfitrión ve el giro de un invitado 0,1 s tarde (`remote_player.DELAY`), y la latencia que se suma no lo cubre. Con ella, el giro llega a tiempo; si la mirada propia no confirma en 0,15 s, no cuenta.
  - Si quien la lleva se cae a media ventana, el anfitrión pasa a la IA, la recoloca y el aviso se cancela («movida»). No está probado.
  - Mientras dura el aviso, en la máquina de quien la lleva solo se pone `cue` (la postura del aviso que ya da el movimiento). No se ha mirado cómo se siente con el mando.
  - El primer intento tras el arreglo falló una vez en la segunda ronda del cooperativo: la IA no empezó el aviso en 20 s. No se repitió en tres pasadas y no sé por qué fue. La prueba lo deja en el detalle del fallo si vuelve a pasar.

### Estado de la fase 2 (16 de noviembre de 2026)

Hecha la vista, sin red (todo es local de su máquina).

- **Asiento:** `presentation_rig.lurker_seat()`; su asiento es el de eco (`hotel.echo_view = true`: sin lámparas, calcomanías, polvo ni niebla; sin lente, SSAO, SSIL, glow ni AA), con tonemap lineal y sin ajustes de color, para que los colores sean los del mapa. De la cinta queda un tercio del grano y una viñeta suave; sin VHS, líneas ni franjas de color.
- **La vista** (`game/enemies/lurker/lurker_view.gd`, `game/presentation/shaders/lurker_sight.gdshader`): un quad sobre su cámara pinta el mapa plasma de matplotlib solo con la profundidad: la geometría en el extremo bajo (azul muy oscuro a morado), más clara cerca y de frente, hundida lejos, con bordes por la ruptura de la profundidad. El calor sale de los registros, como halos sin prueba de profundidad (detrás de una superficie, al 55 %): las salas con luz según `lit()` y lo bebido (el aire de la sala y cada troffer), la emergencia de las salas a oscuras, las lámparas de hito, las de mueble, los usables eléctricos de los objetivos (máquina de escribir, estaciones, palancas, cuadro y zonas, lector, consola), la lucecita de una estación que espera y los pilotos en marcha, los rotores de la climatizadora en marcha. Las linternas, lo más caliente (pasan a blanco), con un halo propio en cruz.
- **Supervivientes:** linterna encendida y no bebida, baliza a través de las paredes hasta 30 m (ninguna con la cara tras una placa cerrada o dentro de un ducto, por `senses.eye_point()`); un cuerpo solo si `senses.sees()`; cordura 0 (`sanity.burnt_survivors()`), contorno frío azulado a través de las paredes.
- **Deslumbre:** dentro de una sala con `lit()`, más allá de unos 4 m todo se quema a magenta.
- **Anillos de ruido** donde ella los oiría (`hear_route()`; cerca, en el sitio; lejos, por donde llega): carrera, puertas (su señal `noise`), tecleo (alguien quieto ante la máquina de escribir), timbres (cambios de `files.requests`) y el clic de una linterna.
- **Fogonazo:** `lurker_view.flash(desde)` sube a blanco amarillento en 0,15 s y vuelve en 2,5 s, nace del lado de la linterna, inmune mientras dura y 1 s más; con «Efectos reducidos», a la mitad y sin parpadeo. Orden de prueba: F8 en una versión con herramientas de depuración (desde el superviviente más cercano).
- **Ductos:** sin ojos (rejilla, placa, ducto), el plano de la red de su planta girado con su mirada: ductos, placas huecas, rejillas llenas, la salida que tomaría `lurker_enter` (`lurker_player.way_out()`) en amarillo, y ella.
- **Manejo:** aceleración propia de 14 m/s² y frenada de 18 (de parada a 4,5 m/s en 0,3 s; antes 1,1). Una puerta solo se cruza mirando hacia el otro lado (coseno 0,5) y empujando; rozarla a lo largo de la pared no la cruza. Al cruzar se alinea al momento y no frena (4,5 m/s mínimo en la orden). Sobre un dintel la cámara se aparta hasta 0,35 m de una hoja, un marco o una pared. Contra una columna desliza por su cara (en `lurker_motion.follow_free`, sin tocar `lurker_shell.gd`).
- **Aceptación:** `tools/capture/lurker_sight_capture.gd` (con ventana, `--bots-hunt --floor=2 --bots=3 --seed=81 --test-profile`): hojas `evidence/versus/f2/hoja_p1.png` a `hoja_p3.png` (pasillo, sala encendida, objetivos, plano de ductos, fogonazo a mitad, y la rampa plasma: arriba su tabla, abajo el ajuste del shader), capturas sueltas, `capturas.txt` y `banco.json`. Banco en Alto, 1280×720, RTX 4060 Ti, en el mismo pasillo: su asiento 3,3 / 4,1 / 3,9 ms de GPU (plantas 1 a 3) frente a 4,7 / 4,7 / 5,2 de un superviviente. `lurker_player_test` 26/26, `lurker_motion_test` 22/22, `lurker_shell_test` 61/61, `creature_contract_test` 180/180, `echo_test` 67/67, `manifest_golden_test` 513/513.
- **Lo que no convence aún:** en Desafiante la planta 2 no tiene ninguna sala encendida con techo para ella: la captura enciende una oficina. Los ruidos se oyen desde lo que tiene su máquina, no desde el anfitrión: sin `lurker.hunter_contact()` (no existe; la de `creature.gd` no hace nada) no le llegan los contactos que `match_net.tell_hunter` ya envía. El tecleo se deduce de alguien quieto ante la máquina. Muchas lámparas tras las paredes se ven como puntos sueltos en el aire. No se ha comprobado en una captura que el blanco nazca del lado de la linterna (la captura llega al pico), ni el dintel ni el deslizar en columnas.

### Estado de la fase 3 (16 de noviembre de 2026)

Hecha: el acecho y el juego de los dos lados. Juzga la máquina a cargo (el anfitrión, o la única sin red).

- **Perfil del Versus** (`difficulty.versus_profile()`, `VERSUS` y `VERSUS_DARK`): la referencia con ventana 1,2 s, `torch_drunk` 4 s y `torch_kill` 0; la planta 1 se oscurece como en Equilibrada. Lo usa `hotel_main.tuning()` cuando una persona lleva a The Lurker (`versus_play()`: partida Versus o `--bots-hunt`); la IA de cooperativo no cambia. La ventana es una regla de la sala, `lurker_window` (1,2 / 0,9 / 1,5 / 2 s, nunca menos de 0,9), en el grupo nuevo «THE LURKER»; la pantalla de reglas aún no filtra por modo, así que en cooperativo del piso 2 se ve sin hacer nada (como «Vista del cazador» en el hotel). Quieta tras una captura: el `sated` de la referencia (20 s a 8 m de la captura), sin texto.
- **Sitios de acecho** (`game/enemies/lurker/lurker_stalk.gd`, del cascarón): el dintel de cada banda de puerta por cada lado (0,30 m sobre el marco), las esquinas de bandeja con las dos paredes cerradas, la boca de cada pasillo de archivo (en la estantería a 1,8 m) y el techo sobre cada taquilla; fuera los que caen a menos de 1 m de una lámpara o columna de su sala; las salas prohibidas no tienen techo para ella. Con la semilla 81: 321 dinteles, 720 esquinas, 12 pasillos, 57 taquillas. Su vista marca con un punto tenue los de menos de 8 m, y algo menos tenue el que tomaría.
- **Acechar** (Q / Y): al sitio más cercano a menos de 3 m sin puertas de por medio, como orden entera; en el dintel la deja una banda con parada (`stop` en el tramo de banda de `lurker_motion`). Quieta 1 s: **asentada** (`lurker.settled()`, que viaja en sus banderas; el otro agente lo lee para el parpadeo), oye 1,5 veces más lejos (`lurker_senses.SETTLED_EAR`). El stick la saca: del dintel, a su techo o por la puerta.
- **Carga** (`lurker.watch_prey()`): asentada, fuera de un ducto y sin que nadie le vea la cara ni la alumbre, cada superviviente que ve 2 s seguidos queda cargado mientras siga así.
- **Soltar** (clic izquierdo / gatillo derecho, `match_net.lurker_release()`): con carga sobre esa presa, hasta 7 m; sin carga, hasta 2,5 m y solo desde encima (`over_of`, unos 50°: en la práctica, casi en la vertical). Lo demás, lo de `cue_allowed()`. La misma presa, no antes de 4 s. Durante la ventana no pasa de 3,8 m/s y se descuelga en una bandeja.
- **Fogonazo y huida** (`lurker.judge_light()`, `scare_off()`): fuera de un aviso, una linterna sin beber en la cara 0,15 s seguidos la ciega; dentro de un aviso, lo salvado por linterna la ciega en el acto y lo salvado por mirada la manda fuera. Ciega: su chillido y el evento «scare» (la linterna queda bebida 4 s), inmune 3,65 s, aviso y bebida en espera 6 s (`lurker.stunned()`, para la validación de beber). Mirada con la cara visible: huida sin blanco ni espera. En los dos casos `match_net.lurker_scared()` (RPC `scared_rpc` a la cazadora) y su máquina la mete en el techo con `motion.bolt()` (o dentro, si no hay salida cerca); el stick no la lleva hasta que entra. El blanco sigue desvaneciéndose sobre el plano de ductos.
- **Asomarse** (F / A, `match_net.lurker_peek()`, RPC `request_peek`): pose «peek»; el anfitrión baja la cordura como una mirada a los ojos a quien la tiene al borde de su vista (`beside_view`) y la vería como la ve su mente, una vez cada 10 s por persona. Sin sonido de aviso.
- **Ruidos del anfitrión:** `lurker.hunter_contact()` pasa a su vista los contactos de `tell_hunter` (menos carrera y puertas, que su máquina ya pinta).
- **Informe:** «THE LURKER, N capturas, aviso más largo X m» (`creature.longest_warning()`, el aviso más largo que acabó en captura).
- **Aceptación:** `tests/office/lurker_stalk_test.gd` (conductor, sin interfaz, contra el superviviente local movido por la prueba) 23/23: a 6 m sin carga no avisa; asentada 2 s, sí; quien corre se salva; quien se gira con la linterna se salva, la ciega y ella huye sola; en espera no avisa; la linterna en la cara fuera de aviso la ciega; la mirada con luz la echa sin blanco; asomarse baja la cordura una vez; de espaldas, la coge al vencer el plazo; nunca sin aviso. `net_test` `lurker_versus`: la cazadora acecha en un sitio detrás de la víctima, carga y suelta; el fogonazo y la huida le llegan por la red. Capturas en Alto (`tools/capture/lurker_stalk_capture.gd`, con ventana, `--bots-hunt --floor=2 --bots=3 --seed=81 --test-profile`): asentada en un dintel con los sitios marcados, el fogonazo naciendo del lado de la linterna (0,40 de blanco) y desvaneciéndose sobre el plano. En verde, una por una: `lurker_player_test` 26/26, `lurker_fairness_test` 29/29, `lurker_senses_test` 38/38, `lurker_capture_test` 11/11, `lurker_bots_test` 7/7, `office_bots_test` 6/6, `manifest_golden_test` 513/513, `rules_test` 37/37, `lurker_motion_test` 22/22, `net_test` `lurker_coop` y `lurker_versus`. `creature_contract_test` 179/180: lo que falla es `judge_drink`, que `match_net` pide y aún no está en `creature.gd` (es del agente de beber). Registros en `evidence/versus/f3/`.
- **Lo que no convence aún:**
  - Sin carga, «desde encima» casi nunca se da: casi hay que estar en su vertical.
  - Los puntos de los sitios se confunden con las lámparas lejanas.
  - En el anfitrión, la réplica no miraba a ningún sitio (`net_look` no se usaba): ahora `gaze()` lo usa en la réplica, lo que también cambia la mirada de la réplica en cooperativo.
  - La prueba usa al superviviente local, no bots.
  - Al acechar se toma el sitio más cercano, que no siempre es el que se mira.
  - La carga sale del `sees()` del anfitrión, que va 0,1 s tarde con la cazadora invitada.

### Estado de la fase 4 (16 de noviembre de 2026)

Hecha: beber la luz, en Versus y en la IA del cooperativo. Juzga la máquina a cargo.

- **El mecanismo** (`lurker.drink()`): su chillido propio (`assets/audio/sfx/lurker/drink_0.wav`, hecho con `tools/audio/prepare_lurker_drink.py` de su chillido de espantarse a 0,72 de velocidad con el golpe del cuadro debajo; no pasa por `frighten()` ni cambia su estado, así que no baja la cordura ni suelta la música), con subtítulo «[Un chillido ahogado]» a 12 m. La sala, a oscuras del todo (drenada al 100 %, `DEEP_RISE` 5/s: 0,2 s) y a oscuras para las reglas durante `drink_dark` (6 s en Versus); la devuelve la máquina a cargo con `snuff(-1)` (`deep_until`), en un segundo. Las linternas de quien está dentro se apagan con el interruptor (en la máquina de cada uno su jugador; un bot, con su mano) y un clic, sin quedar bebidas (`lurker.outed`, en `dead_torches` para todo lo demás). Viaja como evento «drink» [sala, asientos, punto] por `tell_all()`: `tell()` a las réplicas y `match_net.driver_event()` a quien la lleva (su copia no es réplica y `creature_event_rpc` no le aplica nada).
- **Decisión E:** `drain_emergency` no existe en ningún sitio (`grep` en `game/`): las llamadas eran muertas y la emergencia nunca se bebía. Se han quitado. La prueba comprueba que ni la emergencia ni las lámparas de hito cambian.
- **Reencender** (decisión G): la cuenta la máquina a cargo en `dead_torch_step()` (ahora con `in_charge_here()`, no solo con IA): vuelve al segundo encendido desde el apagón (la tercera pulsación, porque el apagón la deja apagada) y nunca antes de 1,0 s; antes, chispea. Los encendidos del interruptor se ven en la réplica (en red, por sus banderas).
- **Linterna fría** (`creature_sight.torch_cold()`, 0,5 s): cuenta por fotogramas de física desde que la linterna se hizo visible (`visibility_changed`, vigilado desde la primera pregunta; `lurker.flicker_step()` pregunta por todas en cada fotograma). La usan `torch_covers()` y `look_of()`, así que ni ciega, ni la ve, ni salva del aviso; y `lurker.claim_agrees()`. The Locust no llama a ninguna de las dos.
- **Versus:** `match_net.lurker_drink()` → `request_drink` → `lurker.judge_drink()`: la sala en la que tiene la cara, fuera de un ducto oculto, sin aviso en marcha ni otra sala suya a oscuras, `may_snuff()` (hitos, vestíbulos, refugios, protegidas, prohibidas y 45 s por sala) y 25 s entre dos (`VERSUS_EVERY`); las rechazadas cuentan en `drinks_refused`. Sin preaviso. Tras el chillido no hay aviso en 1,5 s: lo pone `brain.on_drank()` en `brain.cue_after`, que mira `cue_allowed()`, y así vale también para `judge_release()`. La tecla `lurker_drink` la conecta el otro carril.
- **Encender la luz la echa también llevada por una persona** (`lurker.lit_out()`, en la máquina a cargo cada `DRAIN_EVERY`): si se enciende la sala en la que tiene la cara y no es su bebida devuelta, evento «lit_out» → `motion.bolt()` en la máquina que la lleva.
- **El parpadeo:** las lámparas que bebe por cercanía tiemblan solo mientras se mueve; quieta 1 s (por su posición, en todas las máquinas: `still_time`), siguen bajas sin temblar. El haz de una linterna encendida a menos de 4,5 m titila mientras se mueve (`flicker_step()`, por `torch_dim`); con efectos reducidos solo baja al 75 %. No usa `settled()` del otro carril (que pide un sitio de acecho): la regla es «quieta 1 s», en la IA y en Versus.
- **La IA** (`snuff_step()`): tras acechar a su presa `snuff_time` en una sala con luz que puede beber, el preaviso (evento «warn»: las lámparas bajan temblando al 30 % y suena el siseo de los tubos, `office/tube_hiss.wav`, «[Zumban los tubos]»), `drink_warn`; si la presa sigue en la sala y todo vale (`drink_fair()`), bebe y va a por ella (`on_drank()`: de acechar a acercarse). Frenos en `difficulty.gd`: `drink_warn`, `drink_dark`, `drink_cue` y `drink_every`, los de la tabla de la sección 10; los demás, iguales en las tres: un intento por apagón (`brain.drink_spent()`), nunca a una presa con la linterna bebida o apagada, ni en los 10 s tras un susto suyo (`brain.scared_at`), ni con un aviso en marcha. Solo bebe salas con luz: no apaga a oscuras para quitar linternas.
- **Los bots** (`bot_threat_lurker.relight()`): una linterna apagada por ella (por la sala o la de H1) la pulsan como una persona: su reacción y luego una pulsación cada 0,15 s hasta que vuelve, también llevándola una persona (`--bots-hunt`).
- **Aceptación:**
  - `tests/office/lurker_drink_test.gd` (nueva) 28/28: a oscuras en 0,2 s, linterna apagada sin beber, chillido con subtítulo y sin susto, emergencia y hitos intactos, devuelta a los 4 s; tercera pulsación antes de 1,0 s solo chispea y la siguiente vuelve, y pasado 1,0 s vuelve a la tercera; linterna fría; nunca hitos y 45 s por sala; en Equilibrada, Desafiante y Pesadilla, el preaviso con su tiempo, la bebida, el primer aviso no antes de `drink_cue` y, sin hacer nada, la captura; y tras beber siguen salvando la linterna reencendida, la de un compañero y correr; Apacible nunca bebe; un intento por apagón; el registro pasa la auditoría.
  - `lurker_bots_test` 11/11: en las cuatro dificultades, tras beber la sala de un bot experto, el bot la reenciende a pulsaciones (no antes de 1 s) y su aviso acaba salvado, sin captura. `office_bots_test` 6/6 (sin ella, como antes).
  - `net_test lurker_versus`: la cazadora pide beber sobre una sala que nunca está a oscuras (la primera de la planta 1 con techo suyo) y el anfitrión dice que no; sobre el pasillo de la víctima, se apaga en las tres máquinas (relojes de pared del mismo equipo: anfitrión y cazadora a la vez, la víctima 0,1 s después por su línea lenta) y vuelve a los 6,0 s en las tres; la linterna de la víctima, apagada sin beber, vuelve pulsándola, nunca antes de 1,0 s; pedido otra vez en su espera sobre otra sala, no bebe. `net_test lurker_coop` en verde.
  - En verde, una por una: `lurker_fairness_test` 29/29, `office_dark_test` 6/6, `lurker_mood_audio_test` 5/5, `lurker_no_aura_test` 6/6, `lurker_senses_test` 38/38, `lurker_capture_test` 11/11, `creature_contract_test` 180/180 (con `request_drink`, `driver_rpc` y `creature.judge_drink()`), `manifest_golden_test` 513/513, `difficulty_test` 69/69.
  - **Medida** (`tools/dev/lurker_drink_measure.gd`, 3 bots oráculo, piso 2, semillas 81 y 7, `evidence/versus/f4/medida.json`): en Equilibrada, 1 bebida en dos partidas (446 y 664 s) y ningún aviso en su apagón; en Desafiante, ninguna bebida en dos partidas (las dos se cortan a los 600 s del nivel). **La tasa de capturas por apagón no se puede dar con partidas de bots: casi no bebe**, porque solo bebe una sala con luz donde ha acechado a su presa `snuff_time` seguido, y en Desafiante casi todo está a oscuras. Forzando la bebida sobre quien hace algo: 0 capturas de 13 apagones (los 9 de `lurker_drink_test` con persona guionizada y los 4 de `lurker_bots_test` con bot experto); sin hacer nada, la coge en las tres dificultades.
  - Capturas en Alto, vista de un superviviente: `evidence/versus/f4/antes.png`, `bebida.png` y `reencendida.png` (`tools/capture/lurker_drink_capture.gd`, semilla 81, Equilibrada). Se apaga el tramo de pasillo en el que está; el siguiente tramo es otra sala y sigue con luz al fondo.
- **Lo que no convence aún:**
  - Si se enciende a oscuras un segundo antes del aviso, la linterna fría lo deja a 0,5 s de no salvar: es lo buscado, pero el bot de `lurker_bots_test` que la enciende al girarse en Desafiante aún salva por poco (su reacción es 0,35 s); con más reacción no salvaría.
  - Los sentidos guardan a un superviviente que se fue (`senses.memory` y `looked`) como visto hasta que lo olvida: en la prueba un compañero quitado seguía siendo su presa. En partida pasaría con un invitado que se desconecta. No es de esta fase y no está tocado.
  - En red, la linterna fría se mide en el anfitrión desde que le llega el encendido: quien la encendió 0,5 s antes en su máquina aún puede estar fría allí unos 0,1 s más.
  - La IA solo bebe salas con luz: en la planta 3 y en Desafiante, casi todo a oscuras, apenas bebe.

### Estado de la vista térmica (16 de noviembre de 2026)

Hecha la 4.5. Lo que brilla no cambia (la electricidad y las linternas; los supervivientes, como en la decisión A); cambia cómo se dibuja. Todo local de su máquina.

- **Cómo:** `lurker_sight.gdshader` ya no pinta colores: reconstruye el punto del mundo bajo cada píxel (de la profundidad) y saca una lectura; `lurker_thermal_sensor.gdshader` (capa de lienzo 1, sobre el 3D y bajo lo demás) hace la grabación de esa lectura y le pone el plasma al final. Encima, las marcas del aparato (`lurker_view.Hud`, en su capa 90). Su asiento ya no pone grano ni viñeta de la cinta (`presentation_rig.gd`): los pone su sensor.
- **Ganancia automática:** la lectura se estira entre 0,06 y lo más caliente a la vista (en la CPU, de los registros: cada fuente con un rayo cada 0,1 s para saber si está a la vista o tapada), en 0,35 s. Lo visible manda la cima a 1/0,8 (se quema a blanco); una mancha de algo tapado, a 1/1,5 (tibia, naranja); nunca por debajo de 0,36, así que sin nada eléctrico las paredes quedan en la parte baja de la rampa.
- **Formas:** cada fuente es una forma en el mundo: el hueco de cada troffer (`office_palette.troffers()`), la caja de la unidad de emergencia, la de cada usable eléctrico, la cabeza de la linterna, una cápsula para el cuerpo que ve. El píxel que cae en la forma lee su calor; alrededor calienta la superficie (el techo junto a cada luminaria, hasta 1,6 m); a la vista deja un halo en el sensor que va un poco por detrás de la cámara (el retardo); tapada, una mancha en la cara de lo que la tapa, que se apaga con los metros de por medio (en 2,5 m una lámpara, en 40 m una linterna).
- **Superficies:** suelo, paredes (más tibias hacia arriba) y techo en tonos casi parejos, manchados con ruido sobre su plano, juntas y esquinas algo más tibias, un poco más frías a lo lejos. **Cables:** en cada sala con luz a menos de 16 m, una línea tenue de troffer a troffer por el techo, de ahí a su puerta y abajo al interruptor (a 1,15 m, junto al marco); es un trazado plausible, no el del generador.
- **Sensor:** 360 líneas reescaladas suaves (un mip del lienzo), realce de bordes, ruido por celda 30 veces por segundo (más cuanto más estira la ganancia), rayas verticales tenues, viñeta. **Calibración:** cada 25 a 55 s, y 0,25 s después de una saturación, la imagen se queda quieta 0,35 s (una lectura de la pantalla) con el arranque del motor del zoom de la cámara (`assets/audio/sfx/camera/zoom_in.wav`, sus primeros 80 ms) como clic.
- **Deslumbre:** más allá de 4 m, las superficies se ahogan en un lavado parejo que tiembla; lo caliente y los cables se ven a través.
- **Fogonazo:** `flash(desde)` con la misma firma y los mismos tiempos; ahora la cámara se satura: una mancha blanca que crece desde el lado de la linterna y el resto a negro, y vuelve en 2,5 s.
- **Interfaz:** retícula central y barra del plasma a la derecha, en blanco, sin cifras; anillos de ruido como círculos de trazos finos; los 8 sitios de acecho más cercanos como esquinas (el que tomaría, más brillante y mayor).
- **Efectos reducidos:** sin calibración ni parpadeo del fogonazo (que se queda a la mitad), con la mitad de ruido y rayas.
- **Aceptación:** `tools/capture/lurker_sight_capture.gd` (con ventana, `--bots-hunt --floor=2 --bots=3 --seed=81 --test-profile`): hojas `evidence/versus/f2b/hoja_p1.png` a `hoja_p3.png` (pasillo oscuro sin calor de los registros, pasillo con superviviente con linterna y otro sin ella, linterna tras un muro, sala encendida, objetivos, plano de ductos, fogonazo a mitad, rampa), y las de antes con la vista de la fase 2 en `evidence/versus/f2b/antes/` (`--sight-view=`, la copia en `antes/fase2/`). Que la imagen se queda quieta tras el fogonazo se vio en una pasada corta posterior (`--sight-quick`); en el `capturas.txt` de las hojas la comprobación aún miraba demasiado pronto y dice que no. Banco en Alto, 1280×720, en el mismo pasillo: su asiento 3,9 / 3,5 / 3,6 ms de GPU (plantas 1 a 3) frente a 4,5 / 3,8 / 4,5 de la vista de la fase 2 en la misma sesión (y 3,3 / 4,1 / 3,9 en `f2/banco.json`); un superviviente, 5,8 / 4,8 / 4,3. En verde: `lurker_player_test` 26/26, `lurker_stalk_test` 23/23, `echo_test` 67/67, `manifest_golden_test` 513/513.
- **Lo que no convence aún:**
  - La cabeza de la linterna se ve como una bola con halo; no tiene la forma de la linterna.
  - Lo tapado se decide con un rayo por fuente cada 0,1 s: al girar rápido, un halo puede tardar una décima en pasar de mancha a halo.
  - El fogonazo es un disco blanco bastante geométrico.
  - La calibración lee la pantalla (una parada de pocos milisegundos cada 25 a 55 s, tapada por la propia congelación) y congela también la interfaz.
  - En la planta 1 el pasillo de las capturas tiene luz, así que sale lavado más allá de 4 m; en esa toma el portador de la linterna apenas se ve (sus sentidos no lo dan por visto).
  - En la hoja de antes, la sala encendida sale roja: es el cambio de vista en caliente de la captura, no la fase 2 (la buena está en `evidence/versus/f2/`).
  - Las balizas de linternas de otra planta (a menos de 30 m) se ven como manchas en el suelo o el techo; ya pasaba en la fase 2.
  - No se ha oído el clic en partida ni se ha probado con «Efectos reducidos» en una captura.

## 12. Decisiones para el autor

| | Decisión | Mi propuesta |
|---|---|---|
| A | ¿Ve siempre a los supervivientes, o solo linternas encendidas a través de las paredes (con linterna fría y cordura 0 a la vista)? | Solo linternas. |
| B | ¿Se conserva el aviso de la espalda en Versus, con ventana de 1,2 s? | Sí. |
| C | ¿Cámara en sus ojos con el arriba del mundo, o tercera persona? | En sus ojos. |
| D | ¿El señuelo? | Sí, al final. |
| E | ¿Sin suelo: solo techo, bandas, canales y ductos? | Sí: refuerza la regla de oro y es lo que el cuerpo sabe hacer. |
| F | ¿La carga del acecho es vigilar a la presa 2 s sin ser vista, en vez de estar quieta? | Sí. |
| G | ¿Reencender a la tercera pulsación y nunca antes de 1,0 s? | Sí; el número se afina jugando. |
| H | ¿Se quita el amago (un aviso falso) y se deja «Asomarse»? | Sí: el aviso nunca miente. |
| I | ¿En el ducto principal de la planta 3 puede avisar desde dentro? | Sí, a quien no mira atrás, con 0,5 s más. |
| J | ¿Las salas de hito siguen sin poder beberse? | Sí. |
