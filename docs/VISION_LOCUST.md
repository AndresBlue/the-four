# Visión de The Locust — ecolocalización acústica

Cómo ve la pantalla el jugador que lleva a The Locust en versus. No ve el hotel: lo reconstruye. Este documento describe lo que hay implementado y lo que queda a juicio humano.

Código: `game/enemies/locust/echo_view.gd` (el controlador), `echo_body.gd` (siluetas), `shaders/echo_field.gdshader`, `shaders/echo_points.gdshader`, `shaders/echo_self.gdshader`. Lo crea `locust_player.setup()` y lo enciende y apaga `hotel_locust.set_control()`.

## El pulso

Chasquea **dos veces por segundo**, y **no se acelera al correr**: una lectura que se apretara al echar a correr se leería como los propios pasos volviendo, que no es lo que esto es. Lento a propósito: a quince por segundo la imagen sale abarrotada, casi psicodélica, y a dos cada barrido es un acontecimiento que se espera. Lo que llena el medio segundo entre uno y otro es la memoria del anterior apagándose.

Cada clic lanza su presupuesto de rayos desde la cabeza de la criatura y siembra puntos en el mundo. La cadencia no es un metrónomo: cada intervalo se estira o se aprieta al azar (±22 %) y respira lentamente por debajo. La onda viaja a **16 m/s**, lo bastante despacio para verla cruzar una sala y volver: un frente tarda unos dos segundos y medio en llegar al límite de su oído, así que hay cinco o seis en vuelo a radios distintos.

**Una captura fija no puede mostrar esto.** Medio segundo de cada ciclo la sala está barrida por el frente y el resto está a oscuras, así que un fotograma la pilla encendida o apagada, y ninguna de las dos es lo que se ve. Para eso está la hoja de contactos: `./tools/godot.ps1 rehearsal` con `-- --strip` reparte un clic entero en ocho fotogramas (`evidence/rehearsal_pulse.png`).

**La imagen se dibuja cada fotograma, no cada clic.** Los puntos están anclados en el mundo, no en la pantalla: moverse es fluido, las formas no se deforman, y lo que pulsa es la información, no el framerate.

## Todo lo que tiene forma son granos

Esto es la regla, y es la que costó aprender: **nada se dibuja a partir del búfer de profundidad**. Una imagen calculada de la profundidad cada fotograma es la geometría con las texturas quitadas, y se actualiza en cuanto algo se mueve, así que un superviviente cruzando la sala se veía de forma continua en vez de leerse una vez por clic. Las bandas de profundidad, los bordes y el frente barriendo las superficies hacían justo eso y están fuera.

Lo único que queda del paso a pantalla completa es **el negro sobre el que se apoya todo**, más las dos cosas que no son geometría: el grano de su propio oído y la interferencia de una linterna encendida. Sigue devolviendo `ALPHA = 1` para tapar el hotel iluminado, y la profundidad que el hotel escribió sigue ahí para que los granos se comparen con ella.

Todo lo demás —suelo, paredes, techo, muebles, puertas y cuerpos— **son granos sellados en el mundo cuando un clic los alcanza, y quietos hasta el siguiente**. Se dibujan en este orden, todos por encima de los transparentes del hotel (que están en prioridad 0):

| Prioridad | Lectura | De dónde sale | Atraviesa paredes |
|---|---|---|---|
| 120 | **La oscuridad** | nada con forma: negro, grano y la linterna | — |
| 121 | **Hitos** | las puertas y armarios del piso | sí, tenue |
| 122 | **Memoria** | rayos de cada clic, acumulados | sí, muy atenuada, **solo arquitectura** |
| 123 | **Reflectores fuertes** | rayos dirigidos a puertas y armarios | apenas |
| 124 | **Nubes de sonido** | cada ruido que oye | sí: es sonido |
| 125 | **Lo que halló el chillido** | los supervivientes que encontró | sí, y dura |
| 126 | **Cuerpos** | la superficie del superviviente | **no, nunca** |
| 127 | **Su cuerpo** | sus propias mallas | — |

### Memoria de la sala

Los rayos de cada clic son ahora el único dibujante de la arquitectura: **3.600 por clic** de rociada general en calidad alta más **1.200 apuntados a puertas y armarios**, repartidos entre los treinta fotogramas de física que caben entre dos clics (unos 160 por paso). Los apuntados se lanzan primero, así que si un intervalo corto corta el clic, lo que se pierde es sala genérica y nunca una puerta. Se recuerdan hasta 46.000 granos, que a esa tasa son unos seis segundos de sala. Entre frentes los granos conservan una parte de su luz —tienen que hacerlo, o la sala sería negra medio segundo de cada uno— y el resto lo trae el frente al pasar.

Ese presupuesto es lo caro de toda la vista, y es el primer mando que tocar si un PC va justo: `RAY_BUDGET` y `POINT_BUDGET` en `echo_view.gd`, o directamente bajar la calidad.

### Reflectores fuertes

Un marco de puerta y un armario son aristas duras y caras planas grandes: en ecolocalización real, lo que más devuelve. Y es lo que necesita encontrar mientras caza. Así que cada clic gasta **un presupuesto de rayos propio apuntado directamente a ellos** (1.200 en calidad alta), además de la rociada general, que a cambio baja a 3.600.

Cada rayo va desde la cabeza hasta un punto de muestra del marco o del armario. **Si aterriza a menos de 25 cm del punto al que apuntaba, estaba a la vista** y se sella como grano de reflector; si algo se interpuso, se descarta. La línea de vista la da el propio rayo, así que un marco detrás de una pared no devuelve nada, y hay una prueba que pone una pared en medio para comprobarlo.

- **Puertas:** el final del muro a cada lado del vano, la banda de pared alrededor en las dos caras y el techo del vano. Los puntos van sobre superficies con colisión, porque la moldura decorativa no la tiene. Si la puerta está **cerrada**, además la hoja entera: una puerta abierta es un marco vacío, una cerrada es un bloque encendido.
- **Armarios:** el frente entero, no solo el contorno, así que un armario es un bloque claramente iluminado.
- **Puntos sorteados, no una rejilla.** Cada superficie guarda solo su rectángulo y cuántos puntos le tocan por clic; en cada clic se sortean posiciones nuevas por toda ella (`reflector_spots`). Con una rejilla fija, clic tras clic los granos se amontonaban en los mismos sitios y el armario se veía como una matriz de puntos gordos. Los cuerpos (`echo_body.gd`) y los hitos siguen la misma regla: nada de anillos ni cuentas en fila.
- Se apuntan primero los más cercanos y los que no quedan a la espalda, hasta agotar el presupuesto. Los lejanos los sigue marcando la capa de hitos.

Van en su propia nube, más brillante que la sala, con el grano algo más grande y más luz entre frentes. **El resto de la sala se echó un poco hacia atrás** a propósito: son las puertas y los armarios lo que importa; lo demás solo es un sitio donde estar.

### Nubes de sonido

Cada ruido que el oído confirma deja **una nube de granos colgando donde se oyó**, que florece hacia fuera desde ese punto y se apaga en un par de segundos. Y si el ruido se hizo cerca, **dentro de esa nube aparece densamente la forma de quien lo hizo**: un sonido no dice solo «por ahí», sale de un cuerpo, y el cuerpo vuelve con él. Solo con un ruido oído de cerca, donde el sitio exacto ya forma parte de lo que la máquina que manda envió, así que revela una forma y nunca una posición que la criatura no se hubiera ganado. Es la misma maquinaria de la nube de puntos con una onda lenta y un cuerpo propio, así que el grano no solo destella al pasar el frente: se queda.

Un superviviente andando deja una nube por zancada, y esa hilera de nubes apagándose **es el rastro**. **Cada tipo de ruido pesa distinto** (`PUFF_DENSITY` y `PUFF_SIZE` en `echo_view.gd`, por tipo de `noise_kinds.gd`): un paso deja un rastro ligero (×1,5 granos), correr uno mucho más cargado (×3,4 y más ancho), y una puerta es un estallido que no se puede pasar por alto (×6; un portazo ×7). Un armario, al entrar o salir, **se oye tan lejos como una puerta** (45 m de ruta para el cazador humano, así que llega desde las habitaciones vecinas; la IA solo lo oye hasta 12 m; ambos en `HEARD`, `noise_kinds.gd`) y su nube es igual de grande, **colgada delante de sus puertas a la altura del pecho** (dentro del mueble la tapaba el propio armario). **Cada tipo dura lo suyo** (`PUFF_LIVES`): pasos, carrera y saltos 2,2 s; puertas y portazos 4 s, así que una puerta abierta se sigue viendo un buen rato; un armario 2,5 s, más que un paso pero menos que una puerta: es la ventaja de esconderse (con menos de 1 s no se llegaba a ver, porque la nube nace en el pulso siguiente al ruido y ya llega algo gastada). Cada grano lleva su propia vida en el canal de tipo, codificada como dos por décima de segundo sobre el tono, y el shader la descodifica. **Puertas y armarios no llenan una esfera uniforme sino una campana gaussiana** centrada en el origen del sonido (`PUFF_BELL`, 0,22 del radio, recortada a 1,6 radios), con muchos más granos que un paso (×6 una puerta o un armario, ×7 un portazo) y un núcleo que además brilla hasta 2,6 veces más que el halo (`PUFF_CORE_GAIN`): un punto denso y brillante que se distingue desde lejos. Oídas de lejos casi no se ensanchan (`BELL_BLUR`, frente a `PUFF_BLUR` de los pasos): repartir los mismos granos en una bola del tamaño de una puerta dejaba la nube invisible, y era justo cuando más hacía falta verla. Pasos y carreras siguen siendo una bola pareja.

**Un ruido tiene que destacar sobre la arquitectura**, y eso costaba justo donde más importa: un ruido lejano cuelga en la abertura por la que llega, que es donde los marcos de puerta brillan más, y la opacidad de cada grano tiene un tope, así que subir la ganancia no bastaba. Por eso los granos de sonido:

- tienen un blanco por encima de uno (`PUFF_WHITE`, 2,2 veces: la imagen es luz lineal, y el rojo del chillido ya lo sobrepasa), así que se ven más claros que un marco;
- son algo más gruesos (`PUFF_PIXELS`, 3,2 px frente a 2) y con más ganancia (`PUFF_GAIN`);
- **titilan**: cada grano cambia de brillo por su cuenta doce veces por segundo (`PUFF_TWINKLE`, uniforme `twinkle` del shader). La arquitectura está quieta; el sonido nunca. En una imagen solo de grises, ese hormigueo es lo que distingue un ruido de la puerta en la que cuelga;
- un ruido lejano se separa 1,1 m de la abertura hacia la criatura (`PUFF_STAND_OFF`), para quedar en el aire delante del marco y no encima;
- un ruido oído tras una esquina nunca se coloca a menos de 3,5 m de la criatura (`APPARENT_NEAREST` en `hotel_locust.gd`): cuando no veía ni el primer tramo de la ruta, la nube se ponía sobre su propia cabeza y envolvía la cámara.

La cámara va además un metro al lado del hombro (`SHOULDER` en `locust_player.gd`, antes 0,45 m), comprobado contra las paredes para no meterse en ellas: al girarse hacia un ruido, lo que queda en el centro de la pantalla es el ruido y no su propia cabeza. Además, cuanto más fuerte y más brusco el ruido, más ancha y más densa la nube; cuanto más lejos ha viajado el sonido, algo más difuso el sitio donde cuelga (hasta un 40 % más ancha, `PUFF_BLUR`). **Ninguna nube pasa de 1,8 m de radio** (`PUFF_MAX_RADIUS`, en `puff_radius()`): antes una carrera oída de lejos se ensanchaba 2,6 veces y colgaba una bola rala de casi 12 m de diámetro a unos metros de la criatura, con nadie dentro, que en partida parecía información falsa o restos de la partida anterior. Y como cada zancada renueva esa nube en la misma abertura, mientras alguien corre fuera de su vista la nube sigue ahí, quieta, todo el rato, y se lee como un objeto. Por eso **un paso o una carrera oídos solo por dónde llegan se encogen** hasta 0,9 m de radio y conservan menos de la mitad de sus granos (`FAR_STEP_RADIUS`, `FAR_STEP_GRAINS`): «algo por ahí», no una cosa. Puertas y armarios conservan su núcleo brillante, porque esos sí tienen que leerse desde lejos. Los tubos fluorescentes que zumban dejan la suya, tenue, cada segundo y pico.

### Siluetas

Un superviviente se muestrea de **la superficie de su cuerpo**, no de sus huesos: cada hueso es una manga cónica del grosor que le toca (pecho hondo, cuello, brazos que se afinan hacia la mano) y los granos van sobre esa manga. Recorrer las líneas de los huesos dibujaba un esqueleto colgado en el aire, que no es ni lo que parece un cuerpo ni lo que devolvería un eco.

**Solo se queda la mitad que mira al que escucha:** el sonido vuelve de la superficie encarada, nunca del otro lado de un pecho. Y cada grano se sella con el instante del clic y su propia distancia al punto de donde salió, así que el frente **barre el cuerpo** igual que barre las paredes, en vez de encenderse la figura entera de golpe. Un cuerpo vivo conserva algo de retorno entre frentes, para que siga siendo localizable en el medio segundo en que la sala se queda callada.

**Solo cuando `creature.sees(body)`.** Esa función ya aplica su cono de visión, su línea de vista y la regla del armario (`ajar()`), así que la imagen no puede mostrar más de lo que su propia percepción concede. Es la regla que protege el diseño, y hay una prueba dedicada a ella.

### Su propio cuerpo

Sus mallas reciben un material aditivo propio mientras conduce, y se restaura el anterior al salir. Como no escribe profundidad, no aporta nada al búfer: el campo reconstruye la pared de detrás y sus brazos quedan como un fantasma de rayos X de sí misma. Por eso el quad no le tapa los brazos: el problema no llega a existir.

### Hitos

Vive aquí. Las puertas y los armarios del piso se dibujan tenues y para siempre, atenuándose entre 14 y 28 m, construidos una vez por piso y sin coste por fotograma. Es lo que le permite seguir orientándose entre clics.

**El marco de una puerta va deliberadamente cargado de granos**: las dos jambas y el dintel, en las dos caras del vano, con una pizca de dispersión para que se lea como algo que la sala devuelve y no como una línea dibujada. Una puerta es lo que necesita reconocer de un vistazo mientras caza, así que es el único sitio donde la densidad se agrupa a propósito. Los armarios llevan su propio contorno, más sobrio. Son unos ciento setenta granos por puerta y unos setenta por armario, sobre el frente real del armario, todos estáticos: no cuestan nada por fotograma. Ubican una puerta aunque todavía no se haya barrido; los reflectores fuertes son los que la encienden cuando la tiene delante.

## El sonido

El ruido lo confirma la máquina que manda, con la misma medición que usa el oído de la criatura: `hotel_locust.hear_route()` devuelve si lo oye, el punto aparente, los metros de ruta y cuánto llega amortiguado. `can_hear()` es ahora esa misma función, así que el oído tiene un solo dueño y se hace una sola consulta de navegación por ruido.

El contacto viaja con la posición real **y** la aparente (`match_net.heard_contact`), y el dibujo se desliza de una a otra entre **8 y 14 m de ruta**, con el borrón creciendo con los metros: cerca sabes *dónde*, lejos sabes *por dónde*. Un portazo al otro lado de una pared se pinta en la puerta por la que entra, no encima del superviviente.

Cada ruido lleva su clase (`game/audio/noise_kinds.gd`: paso, carrera, salto, puerta, portazo, armario, rendija, zumbido), que cambia lo ancho que se abre el anillo. Un paso es un punto; un portazo inunda la sala.

Dos cosas no necesitan red: las poses de los supervivientes ya están en la máquina del cazador, y el **zumbido de las balastras** ya lo enruta `world_audio.update_ambient_sources()` desde su cámara, así que los tubos fluorescentes cercanos aparecen como contactos débiles permanentes. Textura gratis.

## El chillido

Su propio grito inunda la lectura de rojo durante unos cuatro segundos y suelta un frente enorme. **El grito suena exactamente lo mismo que el rojo** (`hotel_locust.howl()`, con `SHRIEK_HOLD` y `SHRIEK_FALL` de esta vista): gruñidos agresivos encadenados durante el rojo pleno y un desvanecido de volumen que sigue su misma caída; chillar de nuevo mientras dura empieza otro gruñido y alarga los dos, y se envía a las demás máquinas para que lo oigan desde su posición. Pero el rojo no es lo que vale: lo que vale es que **deja marcados** a los que encuentra con una nube densa sobre cada uno, que sigue ahí **más de tres segundos después de que el grito se haya apagado**, también a través de las paredes.

**Solo encuentra lo que se mueve y está a la vista.** Un superviviente quieto, o metido en un armario, no le devuelve nada. Se mide por el terreno que cubre entre dos lecturas del propio chillido (cinco por segundo), no por un campo de velocidad: lo que importa es si se movió. Quedarse helado al oír el grito es la respuesta, y cuesta segundos preciosos.

El intercambio sigue siendo el mismo: delata dónde está, y a cambio da información y caza libre.

El rojo hay que empujarlo mucho más allá de lo que parece razonable sobre el papel, porque el tonemapper AgX le quita buena parte del croma a un color saturado.

## La linterna

No ve luz. Pero una linterna encendida apuntándole mete una interferencia tenue en esa dirección, usando `lit_by_torch()`, la misma geometría que ya usa la IA. Apagarla frente a un cazador humano sigue siendo una decisión.

## Lo que cambia en el juego

- **La oscuridad ya no esconde de un cazador humano.** Una habitación con la luz fundida no le afecta: la única forma de perderlo es romperle la línea de visión o esconderse bien en un armario. Eso era ya el diseño declarado de la caza; ahora la vista lo cumple.
- **Un ruido lejano dice menos que antes.** Los anillos rojos que sustituye daban la posición real a través de las paredes. Ahora, de lejos, solo dan la dirección.
- **Un superviviente quieto y a la vista se lee mejor que antes**, porque es una silueta y no un modelo a oscuras.

## Presentación y rendimiento

Para el asiento del cazador, `hotel_main.apply_settings()` apaga SSAO, SSIL, glow, niebla volumétrica, las sombras y todas las luces de sala (bandera `echo_view` en `hotel_geometry.update_visibility`): nada de eso se ve bajo un `ALPHA = 1.0`, y ahí está el presupuesto del campo de eco. El paso opaco sigue escribiendo la profundidad que necesitamos, pero no paga un solo mapa de sombras. El fotograma del cazador debería salir **más barato** que el de un superviviente.

**TAA y FXAA se apagan, y eso no es optativo:** un vértice que escribe `POSITION` no produce vectores de movimiento, y una nube que se resiembra quince veces por segundo es el peor caso posible para acumulación temporal. El tinte cálido del filtro VHS se neutraliza y el fleco de color se reduce a la mitad, porque sobre una imagen gris es solo barro. Todo se vuelve a derivar llamando a `apply_settings()`, nunca recordando valores, porque el `Environment` es un recurso compartido.

También se apaga la **luz ambiental** para su asiento, que es la que alcanza cada superficie haya o no una lámpara: cualquier cosa que siga iluminada filtra el hotel visto dentro de una lectura que debe estar hecha de ecos.

Presupuestos por calidad (0/1/2): rayos por clic `[0, 2200, 4200]`, granos recordados `[0, 24000, 46000]`, granos de cuerpo `[0, 700, 1400]`, granos de sonido `[0, 2600, 5200]`. No hay ajuste guardado nuevo. El presupuesto por clic es grande porque hay treinta fotogramas de física para repartirlo: el coste por fotograma es el mismo que tendría un pulso rápido, y lo que se gana es una escena hecha de puntos. Una sola consulta de rayo reutilizada.

`reduced` **no deja la pantalla negra**: quita el temblor, la respiración y el grano, baja el contraste de los frentes y sube el término base y los hitos. Cambia el pulso por una imagen más plana y quieta, pero igual de navegable. Hay una prueba que comprueba justo eso, para que «reducido = pantalla negra» no pueda colarse como regresión.

**Solo Forward+ está probado.** El lanzador `compatibility` no se ha validado con esta vista.

## Verificar

- `tests/hotel/echo_test.gd` (en `verify.ps1`): cadencia, presupuesto de rayos, anillos de puntos, caducidad, cuerpo a la vista y cuerpo tras la pared, contactos con clase y ruta, chillido, hitos, orden de dibujo, modo reducido, calidad 0, que el eco no consume el azar del mapa, y que salir del asiento no deja rastro.
- `tools/dev/check_shaders.gd`: **necesita ventana**. Con `--headless` el rasterizador ficticio hace de `shader_set_code` una función vacía y un shader roto se carga sin una sola queja. `verify.ps1` lo ejecuta con ventana y juzga por el log; en una máquina sin GPU informa `SHADERS_SKIPPED` y no cuenta como fallo.
- `tools/capture/echo_capture.gd`: las evidencias `evidence/echo_*.png`. Hay que lanzarlo con `--automation` o el arranque VCR se sienta encima de cada fotograma.
- Mirarlo en movimiento: `./tools/godot.ps1 locust -Seed 81` abre el piso con la criatura en tus manos y un superviviente quieto como blanco, sin necesidad de nadie conectado.
- **Con gente y ruido: `./tools/godot.ps1 rehearsal -Seed 81`** (`tools/dev/echo_rehearsal.gd`). Tres supervivientes recorren el piso solos, caminando, corriendo, agachándose, abriendo puertas, saltando, y uno de ellos metiéndose en armarios. Son los mismos cuerpos `remote_player` que construye una partida en red, así que sus pasos pasan por el enrutado real, sus poses alimentan el muestreo de siluetas y la criatura los ve y los oye exactamente como lo haría en versus. Es la forma de juzgar la imagen con algo pasando dentro. Van por el piso a su aire y, cada 8 a 26 s cada uno, alguno camina hasta el armario libre más cercano, se mete (con su ruido de armario), se queda entre 4 y 14 s y sale. Se les puede matar: la estocada los ejecuta como en versus (el cuerpo queda colgado delante de la criatura), sin ningún aviso en pantalla, y el muerto vuelve a andar 6 s después en otra parte, así que el ensayo no se acaba nunca por falta de supervivientes. Con `-- --shots` toma unos fotogramas en `evidence/rehearsal_*.png` y sale, en vez de darte los mandos (y sin ratón: un clic suelto en la ventana no mata a nadie).

## Pendiente de juicio humano

Los números de la imagen se ajustan jugando, no sobre el papel:

- **`presence`.** Es el único término que aún toca la profundidad: una insinuación plana de que hay algo sólido, sin bordes ni forma. Si sube, la sala vuelve a dibujarse en vez de ser clicada, y se cae toda la ficción. Está casi a cero a propósito.
- **La densidad del granulado.** Es lo único que describe la sala, así que si no se puede navegar, el mando es `RAY_BUDGET` hacia arriba (y el coste en CPU con él) o `residue` del material de los muros.
- **La separación de los frentes.** A 2 clics por segundo y 16 m/s los cascarones quedan a unos 8 m. Más juntos vuelven a abarrotar la imagen.
- **Las salas pequeñas son más claras que los pasillos**, y eso es acústicamente cierto: todo está cerca y devuelve mucho. Si molesta, el mando es la ganancia del barrido en `echo_field.gdshader`.
- **La legibilidad en un salón grande**, con memoria e hitos a través de los muros y doce anillos de contacto a la vez. Lo esperable es bajar las transparencias, no subirlas.
- **El equilibrio de la caza** con esta información nueva, junto al chillido y la resistencia.
