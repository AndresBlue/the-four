# Visión de The Locust — ecolocalización acústica

Cómo ve la pantalla el jugador que lleva a The Locust en versus. No ve el hotel: lo reconstruye. Este documento describe lo que hay implementado y lo que queda a juicio humano.

Código: `game/enemies/locust/echo_view.gd` (el controlador), `echo_body.gd` (siluetas), `shaders/echo_field.gdshader`, `shaders/echo_points.gdshader`, `shaders/echo_self.gdshader`. Lo crea `locust_player.setup()` y lo enciende y apaga `hotel_locust.set_control()`.

## El pulso

Chasquea unas **15 veces por segundo**. Esa es la tasa a la que se refresca la información: cada clic lanza un presupuesto de rayos desde su cabeza y siembra puntos en el mundo.

La cadencia no es un metrónomo: cada intervalo se estira o se aprieta al azar (±22 %), respira lentamente por debajo, y se aprieta mientras caza. Uno de cada cuatro clics vuelve como un barrido fuerte, así que lo que se siente es un temblor constante con un oleaje marcado cada pocas décimas. Hay hasta seis frentes en vuelo a la vez, a unos 42 m/s, así que nunca hay un instante muerto.

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
- bordes por discontinuidad de profundidad: los vanos, los muebles y las siluetas siguen legibles entre clic y clic;
- los anillos de los contactos de sonido pintados sobre esas mismas superficies. **Aquí el ruido y la geometría se vuelven una sola imagen.**

### Memoria y cuerpos

Dos anillos de puntos en el mundo. La arquitectura se recuerda unos segundos; un cuerpo, apenas un suspiro (0,6 s), porque un superviviente es una lectura viva y no un rastro que seguir.

El desvanecido **no está fijado a mano**: se mide la tasa de escritura y se ajusta para que un punto siempre acabe de apagarse antes de que el anillo lo pise. Así no hay saltos con ninguna calidad ni en ningún mapa.

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

Presupuestos por calidad (0/1/2): rayos por clic `[0, 128, 224]`, puntos recordados `[0, 8000, 16000]`, puntos de cuerpo `[0, 256, 512]`. No hay ajuste guardado nuevo. Con 224 rayos a 15 clics por segundo son 56 rayos por paso de física, repartidos entre los fotogramas de cada clic, con una sola consulta reutilizada.

`reduced` **no deja la pantalla negra**: quita el temblor, la respiración y el grano, baja el contraste de los frentes y sube el término base y los hitos. Cambia el pulso por una imagen más plana y quieta, pero igual de navegable. Hay una prueba que comprueba justo eso, para que «reducido = pantalla negra» no pueda colarse como regresión.

**Solo Forward+ está probado.** El lanzador `compatibility` no se ha validado con esta vista.

## Verificar

- `tests/hotel/echo_test.gd` (en `verify.ps1`): cadencia, presupuesto de rayos, anillos de puntos, caducidad, cuerpo a la vista y cuerpo tras la pared, contactos con clase y ruta, chillido, hitos, orden de dibujo, modo reducido, calidad 0, que el eco no consume el azar del mapa, y que salir del asiento no deja rastro.
- `tools/dev/check_shaders.gd`: **necesita ventana**. Con `--headless` el rasterizador ficticio hace de `shader_set_code` una función vacía y un shader roto se carga sin una sola queja. `verify.ps1` lo ejecuta con ventana y juzga por el log; en una máquina sin GPU informa `SHADERS_SKIPPED` y no cuenta como fallo.
- `tools/capture/echo_capture.gd`: las evidencias `evidence/echo_*.png`. Hay que lanzarlo con `--automation` o el arranque VCR se sienta encima de cada fotograma.
- Mirarlo en movimiento: `./tools/godot.ps1 locust -Seed 81` abre el piso con la criatura en tus manos y un superviviente quieto como blanco, sin necesidad de nadie conectado.

## Pendiente de juicio humano

Los números de la imagen se ajustan jugando, no sobre el papel:

- **El término base.** Una imagen de bordes derivada de la profundidad cada fotograma *es* vista. Si ese término sube, la criatura simplemente ve y se cae toda la ficción. Está bajo a propósito.
- **La separación de los frentes.** A 42 m/s los cascarones quedan a unos 3 m. Demasiado juntos hacen moiré de pana.
- **La legibilidad en un salón grande**, con memoria e hitos a través de los muros y doce anillos de contacto a la vez. Lo esperable es bajar las transparencias, no subirlas.
- **El equilibrio de la caza** con esta información nueva, junto al chillido y la resistencia.
