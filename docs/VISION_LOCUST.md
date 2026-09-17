# Visión de The Locust — ecolocalización acústica

Cómo ve la pantalla el jugador que lleva a The Locust en versus. No ve el hotel: lo reconstruye. Este documento describe lo que hay implementado y lo que queda a juicio humano.

Código: `game/enemies/locust/echo_view.gd` (el controlador), `echo_body.gd` (siluetas), `shaders/echo_field.gdshader`, `shaders/echo_points.gdshader`, `shaders/echo_self.gdshader`. Lo crea `locust_player.setup()` y lo enciende y apaga `hotel_locust.set_control()`.

## El pulso

Chasquea **dos veces por segundo**. Lento a propósito: a quince por segundo la imagen sale abarrotada, casi psicodélica, y a dos cada barrido es un acontecimiento que se espera. Lo que llena el medio segundo entre uno y otro es la memoria del anterior apagándose.

Cada clic lanza su presupuesto de rayos desde la cabeza de la criatura y siembra puntos en el mundo. La cadencia no es un metrónomo: cada intervalo se estira o se aprieta al azar (±22 %), respira lentamente por debajo, y se aprieta mientras caza. La onda viaja a **16 m/s**, lo bastante despacio para verla cruzar una sala y volver: un frente tarda unos dos segundos y medio en llegar al límite de su oído, así que hay cinco o seis en vuelo a radios distintos.

**Una captura fija no puede mostrar esto.** Medio segundo de cada ciclo la sala está barrida por el frente y el resto está a oscuras, así que un fotograma la pilla encendida o apagada, y ninguna de las dos es lo que se ve. Para eso está la hoja de contactos: `./tools/godot.ps1 rehearsal` con `-- --strip` reparte un clic entero en ocho fotogramas (`evidence/rehearsal_pulse.png`).

**La imagen se dibuja cada fotograma, no cada clic.** Los puntos están anclados en el mundo, no en la pantalla: moverse es fluido, las formas no se deforman, y lo que pulsa es la información, no el framerate.

## Las cinco lecturas

Se dibujan en este orden, todas por encima de los transparentes del hotel (que están en prioridad 0):

| Prioridad | Lectura | De dónde sale | Atraviesa paredes |
|---|---|---|---|
| 120 | **Campo de eco** | el búfer de profundidad real | no |
| 121 | **Hitos** | las puertas y armarios del piso | sí, tenue |
| 122 | **Memoria** | rayos de cada clic, acumulados | sí, muy atenuada, **solo arquitectura** |
| 123 | **Cuerpos** | la pose del superviviente | **no, nunca** |
| 124 | **Su cuerpo** | sus propias mallas | — |

### Campo de eco

Un quad a pantalla completa hijo de la cámara devuelve `ALPHA = 1.0`: tapa la imagen iluminada y deja intacta su profundidad, que es lo que hace posible todo lo demás. Con esa profundidad reconstruye la posición en el mundo de cada píxel y compone:

- bandas de profundidad cada 1,5 m: la distancia se lee de un vistazo;
- una banda por cada frente en vuelo, con caída **asimétrica** (ajustada delante, cola corta detrás). Esa asimetría es lo que hace que sea un eco y no una cámara de profundidad;
- **respuesta por incidencia**: una superficie de frente al clic devuelve el eco de vuelta, una vista de canto lo dispersa. Por eso lo que mira es lo que lee, y el suelo y el techo que se alejan bajo sus pies quedan oscuros;
- bordes por **curvatura** de la profundidad, no por pendiente: una pared plana devuelve cero por muy inclinada que se aleje, y solo contestan las aristas y las siluetas. Midiendo la pendiente se encendía cada muro en diagonal y la sala entera quedaba hecha de paneles claros;
- los anillos de los contactos de sonido pintados sobre esas mismas superficies. **Aquí el ruido y la geometría se vuelven una sola imagen.**

### Memoria y cuerpos

Dos anillos de puntos en el mundo. La arquitectura se recuerda unos segundos; un cuerpo, apenas un suspiro (0,6 s), porque un superviviente es una lectura viva y no un rastro que seguir.

El desvanecido **no está fijado a mano**: se mide la tasa de escritura y se ajusta para que un punto siempre acabe de apagarse antes de que el anillo lo pise. Así no hay saltos con ninguna calidad ni en ningún mapa.

Casi toda la luz de un punto viene del instante en que el frente lo cruza; lo que queda después es un residuo mínimo. Tiene que ser mínimo: en una sala pequeña todos los puntos recordados caen sobre los mismos pocos metros cuadrados, y un residuo generoso se suma hasta convertir la pared en un panel iluminado en vez de un granulado. Por lo mismo, solo la mitad de los rayos van a un cono frontal amplio y el resto se reparten por toda la esfera: más estrechos, y la pared que mira acumula tantos puntos que se fusionan en una lámina.

La memoria de los muros se intuye a través de los muros, atenuada, con una comparación de profundidad suave hecha a mano en el fragmento. Un cuerpo usa la misma comparación con atenuación cero, así que una pared lo corta por completo.

### Siluetas

Un superviviente se muestrea de su propia pose: unos sesenta puntos interpolados a lo largo de los huesos que expone `avatar_visual.gd`, con caída a anillos sobre la cápsula para el personaje sin esqueleto. Quieto se lee nítido; corriendo se desdibuja.

**Solo cuando `creature.sees(body)`.** Esa función ya aplica su cono de visión, su línea de vista y la regla del armario (`ajar()`), así que la imagen no puede mostrar más de lo que su propia percepción concede. Es la regla que protege el diseño, y hay una prueba dedicada a ella.

### Su propio cuerpo

Sus mallas reciben un material aditivo propio mientras conduce, y se restaura el anterior al salir. Como no escribe profundidad, no aporta nada al búfer: el campo reconstruye la pared de detrás y sus brazos quedan como un fantasma de rayos X de sí misma. Por eso el quad no le tapa los brazos: el problema no llega a existir.

### Hitos

Vive aquí. Las puertas y los armarios del piso se dibujan tenues y para siempre, atenuándose entre 12 y 20 m, construidos una vez por piso y sin coste por fotograma. Es lo que le permite seguir orientándose entre clics.

## El sonido

El ruido lo confirma la máquina que manda, con la misma medición que usa el oído de la criatura: `hotel_locust.hear_route()` devuelve si lo oye, el punto aparente, los metros de ruta y cuánto llega amortiguado. `can_hear()` es ahora esa misma función, así que el oído tiene un solo dueño y se hace una sola consulta de navegación por ruido.

El contacto viaja con la posición real **y** la aparente (`match_net.heard_contact`), y el dibujo se desliza de una a otra entre **8 y 14 m de ruta**, con el borrón creciendo con los metros: cerca sabes *dónde*, lejos sabes *por dónde*. Un portazo al otro lado de una pared se pinta en la puerta por la que entra, no encima del superviviente.

Cada ruido lleva su clase (`game/audio/noise_kinds.gd`: paso, carrera, salto, puerta, portazo, armario, rendija, zumbido), que cambia lo ancho que se abre el anillo. Un paso es un punto; un portazo inunda la sala.

Dos cosas no necesitan red: las poses de los supervivientes ya están en la máquina del cazador, y el **zumbido de las balastras** ya lo enruta `world_audio.update_ambient_sources()` desde su cámara, así que los tubos fluorescentes cercanos aparecen como contactos débiles permanentes. Textura gratis.

## El chillido

Su propio grito inunda la lectura de rojo durante unos cuatro segundos y suelta un frente enorme. Los supervivientes que encuentra se archivan como contactos brillantes, que pintan anillos sobre las superficies a su alrededor **incluso a través de las paredes**: es la traducción correcta de «el chillido escucha». El intercambio sigue siendo el mismo de antes: delata dónde está, y a cambio da información y caza libre.

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

Presupuestos por calidad (0/1/2): rayos por clic `[0, 900, 1800]`, puntos recordados `[0, 7000, 11000]`, puntos de cuerpo `[0, 320, 640]`. No hay ajuste guardado nuevo. El presupuesto por clic es grande porque hay treinta fotogramas de física para repartirlo: el coste por fotograma es el mismo que tendría un pulso rápido, y lo que se gana es una escena hecha de puntos. Una sola consulta de rayo reutilizada.

`reduced` **no deja la pantalla negra**: quita el temblor, la respiración y el grano, baja el contraste de los frentes y sube el término base y los hitos. Cambia el pulso por una imagen más plana y quieta, pero igual de navegable. Hay una prueba que comprueba justo eso, para que «reducido = pantalla negra» no pueda colarse como regresión.

**Solo Forward+ está probado.** El lanzador `compatibility` no se ha validado con esta vista.

## Verificar

- `tests/hotel/echo_test.gd` (en `verify.ps1`): cadencia, presupuesto de rayos, anillos de puntos, caducidad, cuerpo a la vista y cuerpo tras la pared, contactos con clase y ruta, chillido, hitos, orden de dibujo, modo reducido, calidad 0, que el eco no consume el azar del mapa, y que salir del asiento no deja rastro.
- `tools/dev/check_shaders.gd`: **necesita ventana**. Con `--headless` el rasterizador ficticio hace de `shader_set_code` una función vacía y un shader roto se carga sin una sola queja. `verify.ps1` lo ejecuta con ventana y juzga por el log; en una máquina sin GPU informa `SHADERS_SKIPPED` y no cuenta como fallo.
- `tools/capture/echo_capture.gd`: las evidencias `evidence/echo_*.png`. Hay que lanzarlo con `--automation` o el arranque VCR se sienta encima de cada fotograma.
- Mirarlo en movimiento: `./tools/godot.ps1 locust -Seed 81` abre el piso con la criatura en tus manos y un superviviente quieto como blanco, sin necesidad de nadie conectado.
- **Con gente y ruido: `./tools/godot.ps1 rehearsal -Seed 81`** (`tools/dev/echo_rehearsal.gd`). Tres supervivientes recorren el piso solos, caminando, corriendo, agachándose, abriendo puertas, saltando, y uno de ellos metiéndose en armarios. Son los mismos cuerpos `remote_player` que construye una partida en red, así que sus pasos pasan por el enrutado real, sus poses alimentan el muestreo de siluetas y la criatura los ve y los oye exactamente como lo haría en versus. Es la forma de juzgar la imagen con algo pasando dentro. Con `-- --shots` toma unos fotogramas en `evidence/rehearsal_*.png` y sale, en vez de darte los mandos.

## Pendiente de juicio humano

Los números de la imagen se ajustan jugando, no sobre el papel:

- **El término base.** Una imagen de bordes derivada de la profundidad cada fotograma *es* vista. Si ese término sube, la criatura simplemente ve y se cae toda la ficción. Está bajo a propósito.
- **La separación de los frentes.** A 2 clics por segundo y 16 m/s los cascarones quedan a unos 8 m. Más juntos vuelven a abarrotar la imagen.
- **Las salas pequeñas son más claras que los pasillos**, y eso es acústicamente cierto: todo está cerca y devuelve mucho. Si molesta, el mando es la ganancia del barrido en `echo_field.gdshader`.
- **La legibilidad en un salón grande**, con memoria e hitos a través de los muros y doce anillos de contacto a la vez. Lo esperable es bajar las transparencias, no subirlas.
- **El equilibrio de la caza** con esta información nueva, junto al chillido y la resistencia.
