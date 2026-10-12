# The Four — La captura: sobresalto, ejecución y cinta

**Diseño cerrado el 12 de octubre de 2026, con las once decisiones del autor (sección 19), y construido ese mismo día: la tabla de fases (sección 18) dice qué está hecho, con qué se comprobó y qué queda —lo que queda es del autor y de gente jugando—.** Rehace entero el plan de partida del autor («rediseño de jumpscares y ejecuciones»): conserva su dirección —primero el sobresalto, después la cámara caída, al final la cinta— y la apoya en tres cosas que aquel plan no tenía: lo que hacen los juegos y las películas que mejor matan, lo que se sabe de por qué un cuerpo salta, y lo que el juego hace hoy por dentro. Qué se conserva y qué cambia está en la sección 2; lo que decidió el autor, en la 19.

La escena construida está resumida en [el diseño](GAME_DESIGN.md) («Ejecución») y en [AUDIO.md](AUDIO.md); este documento es su porqué y su detalle. La criatura es The Locust; todo vale para la IA y, donde se indica, para el cazador de versus.

**Cómo leerlo.** Donde el texto dice «hoy» habla del juego de antes de esta obra: es el punto de partida del diseño, y se deja como se escribió. Donde lo construido se apartó de lo propuesto, el texto dice lo construido. Los tiempos, distancias y porcentajes son los del prototipo: se afinan mirando y jugando, no aquí; los que manda el código están en `game/app/capture_score.gd`.

## 1 · En una página

Morir ante The Locust son nueve tiempos en cuatro segundos y medio. La bestia sigue quieta 4,2 s, como hoy, así que nada del equilibrio se mueve; lo que cambia es **lo que ve y oye quien muere**.

| Tiempo | Segundos | Qué pasa |
|---|---|---|
| **El hueco** | los 2 s de antes | Nada nuevo. La caza suena como venía sonando; en el último medio segundo no se añade nada, ni a la imagen ni al sonido |
| **El golpe** | 0,00 | El grito arranca de golpe y la imagen ya es otra: no hay fotograma intermedio que avise |
| **El rostro** | 0,00–0,55 | La máscara a un palmo de la lente, más de medio cuadro, quieta salvo un temblor y un ladeo. No se ve otra cosa |
| **El arrebato** | 0,55–0,90 | Un manotazo: la cámara sale de las manos. Barrido, peine del entrelazado, nada legible |
| **El suelo** | 0,90–1,05 | Golpe, rebote, la cámara queda tumbada. La cinta se resiente y el micrófono se cierra |
| **Lo que la cinta ve** | 1,05–2,58 | Desde el suelo, torcida y medio tapada: las patas de la bestia y tu propio cuerpo, que sube |
| **El remate** | 2,58–3,10 | El golpe —se oye; se ve a medias o no se ve— y el cuerpo, que cae junto a la cámara |
| **El después** | 3,10–4,20 | La cinta, tocada por la caída del cuerpo, se va rompiendo mientras la bestia se va o se vuelve hacia la lente |
| **El corte** | 4,20 | La grabación se acaba: nieve y SEÑAL PERDIDA |

Lo que lo hace distinto cada vez: **por dónde te coge** (de frente, por la espalda, de lado, desde arriba, con las manos ocupadas, en un armario), **dónde cae la cámara** (lo calcula el sitio: ve, ve a medias o queda boca abajo y solo se oye), **qué luz hay** (la sala, la linterna rodando por el suelo, o solo el piloto rojo de grabación) y **cómo acaba**.

Lo que no cambia nunca: la captura es definitiva, la decide el anfitrión, mata una vez, y ninguna regla de sigilo se toca.

## 2 · Qué se conserva del plan de partida y qué cambia

| Del plan de partida | Aquí |
|---|---|
| Tres momentos: sobresalto, ejecución, pérdida de señal | **Se conserva**, con uno antes (el hueco: lo que *no* se hace en los dos segundos previos) y uno después (el silencio con la cámara en el suelo) |
| Irrupción en 0,00–0,25 s | **Cambia: 3 a 5 fotogramas** (0,05–0,08 s). El reflejo de sobresalto se dispara en unos 35 ms y pide un arranque abrupto; en los sustos de FNAF la cara ya llena la pantalla en el primer fotograma. Un cuarto de segundo de aproximación es tiempo de sobra para verla venir |
| El rostro ocupa el 70–90 % de la altura | **Se matiza.** Medida sobre el modelo (`tools/dev/mask_probe.gd`), la parte pálida de la máscara son 12 cm de ancho por 14 de alto: para llenar el 55 % de la altura hay que ponerla a 15 cm de la lente, y a esa distancia aguanta (`tools/capture/mask_capture.gd`). Objetivo: 50–65 % a 13–17 cm; la cabeza entera llena el cuadro |
| Captura frontal como ejecución principal | **Se amplía.** La mayoría de las capturas de una caza son por la espalda, con la cámara mirando hacia otro lado. Hay siete entradas según cómo te coge (sección 7) |
| Pérdida del control con trayectoria prediseñada | **Se conserva**, con causa: el brazo que no sujeta aparta la cámara de un manotazo |
| Cámara caída que registra a medias, 30–60 % tapado | **Se conserva** (25–55 %), y lo que registra es **la ejecución de hoy** —levantar, sostener, estocada, soltar—, que no se tira: se ve desde el suelo. La estocada, la caída y el final siguen a su hora para todos; solo el levantamiento se retrasa y se alarga, para que la cámara ya esté en el suelo cuando los pies lo dejan |
| Degradación de la grabación y estática | **Se conserva, con causa y con final seco.** La cinta se rompe porque el cuerpo cae junto a la cámara; no se funde: se corta, como se corta una grabación |
| Unos 4,2 s en total; sin mecánica de escape | **Se conserva** |
| Armarios: ritual intacto, emboscada solo con conocimiento confirmado, falsa retirada física | **Se conserva el ritual y la emboscada con certeza; la retirada cambia** por decisión del autor (19.4): no se va a ninguna parte ni finge sus pasos. Se aparta, se queda quieta y lo que se apaga es su presencia; de ella se escapa esperando (13.3) |
| Oscuridad total: una luz de ejecución muy localizada, o una luz del propio equipo | **Se le da cuerpo a la primera con la segunda:** el piloto rojo de grabación, que las videocámaras de 1988 llevaban delante. Aprobado (19.1): apenas se nota jugando y se aviva en la captura |
| Lista de lo que no se hace con la oscuridad | **Se conserva entera** |
| Sonido orgánico, sin el grito como capa constante | **Se conserva**, y se añade un cambio de punto de escucha: de tu cabeza al micrófono de la cámara |
| Autoridad del anfitrión, perspectivas de víctima, testigos y cazador | **Se conserva**, con el dato que viaja, un solo reloj y la tabla de interrupciones (sección 16) |
| Máquina de estados | **Se conserva**, separada en dos capas: lo que pasa en el mundo (todos) y lo que graba la cinta (solo la víctima) |
| Seis fases, empezando por la irrupción | **Se conserva el orden**, con un banco de pruebas antes |

Añadidos que no estaban: la regla del medio segundo previo (5.3), las recetas por contexto (7), los finales (7.4), la linterna que cae y el teatro de sombras (9), qué hacer cuando la cámara no puede caer en un buen sitio (8.3), la política de repetición (14) y la opción de sobresaltos suaves (14.3).

## 3 · Lo que había, medido

La ejecución anterior, tal como estaba antes de esta obra. De `game/app/executions.gd`, `hotel_locust.gd`, `locust_visual.gd` y `presentation_rig.gd`, y de las capturas de `tools/capture/execution_capture.gd`.

| Segundo | Qué pasa hoy |
|---|---|
| Antes | La embestida (`WINDUP`): dura de 0,25 a 0,6 s según la dificultad y acaba en la captura. Si pasa a menos de 10 m, **la imagen se rasga** mientras dura (`threat_glitch`) |
| 0,00 | Captura. El grito, plano y a 0 dB para la víctima. Se le quita el control, se cierran hoja, teclado y documento, sale del armario |
| 0,0–0,5 | La levanta un metro, ensartada en el brazo izquierdo. La cámara es forzada a mirar a la cabeza |
| 0,5–2,58 | La acerca despacio (de 1,15 a 0,6 m) |
| 2,58–2,80 | El brazo derecho viene a la lente: un negro que crece desde su mano |
| 2,80 / 2,92 / 3,10 | El golpe; la estática y SEÑAL PERDIDA; el cuerpo cae, en silencio |
| 4,20 / 4,50 | La bestia vuelve a moverse; se registra la baja |

Lo que funciona y se queda: **el grito** (2,14 s; arranca en 0 ms, que es lo que pide un sobresalto; pico −0,1 dBFS), que la baja se registre al final, que solo haya una ejecución a la vez, las guardas (ni en refugio ni en ascensor), que el estado se suelte limpio si la etapa se cierra debajo, y el canal muerto.

Lo que falla:

- **En el instante del grito no hay nada que ver.** En las capturas, la imagen está rasgada por el aviso de la embestida y la bestia es un borrón de un 7 % de la altura del cuadro, a metro y medio. El sonido asusta; la imagen, no.
- **La máscara nunca llega.** En toda la ejecución ocupa entre el 7 y el 16 % de la altura. Es una cara humana, pálida, de ojos huecos: lo mejor que tiene la criatura, y no se usa.
- **Dos segundos sin que pase nada.** De 0,5 a 2,58 s la composición no cambia: da tiempo a entender que estás muerto y a esperar el golpe.
- **El aviso llega en el peor momento.** El desgarro de la embestida cae entre 250 y 600 ms antes del golpe: justo la ventana en la que un estímulo débil *reduce* el sobresalto (5.3).
- **Es siempre la misma**, venga de donde venga, y en una sala a oscuras no se ve.
- **El grito dura toda la escena.** Dos segundos a −3 dBFS de media: tapa todo lo demás y cansa.

Dos límites de producción que el diseño respeta: **la criatura no tiene animaciones grabadas** —se posa hueso a hueso por código (`locust_visual`, `locust_poser`: columna, cuello, cabeza, brazos de dos huesos)—, y **uno de los tres supervivientes no tiene esqueleto** (el Detective Masculino). Por eso todo lo que sigue se apoya en pocas poses, en encuadre y en lo que se tapa.

## 4 · Lo que enseñan los que lo hacen bien

Resumen de la investigación (fuentes al final; lo que es estimación se dice).

**Alien: Isolation.** Muertes distintas según el contexto: de frente (agarre y mandíbula), por la espalda (la cola: *ves la punta ya saliendo de tu pecho*, caes de rodillas, miras arriba, negro), derribado al correr, sacado del escondite, desde un conducto. El Alien tiene en total unos 70–80 conjuntos de animación, y la música, unas 90 entradas solo para la muerte. **Se enseña la causa y se oculta el impacto.** Lo que el Alien aprende a hacer no depende de cuántas veces mueres. Lo que se le criticó, ya en las pruebas de prensa: hacia la muerte ochenta ha perdido el filo, y repetir se parece a trabajar.

**La objeción de Frictional** (Thomas Grip, 2014): la muerte *suelta* el miedo acumulado —«They're laughing, and feeling relief»— y después solo queda repetir. Sus remedios: aplazarla, cambiar el mundo tras cada muerte, o un estado peor que morir. Este juego ya hace lo segundo: un piso perdido no se repite, y el siguiente es otro mapa.

**Five Nights at Freddy's.** Lo visible dura alrededor de un segundo (estimado: nadie lo ha medido). **En el primer fotograma la cara ya ocupa toda la altura** (comprobado en los once fotogramas del susto de Bonnie); después abre la boca, ladea la cabeza y tiembla la pantalla. El grito se corta a un segundo. Se dispara con una acción del jugador —bajar el monitor—, no con un reloj: el susto llega cuando *vuelves* la mirada. Lo que lo mata, según sus críticos: aprenderse el disparador.

**El cuerpo.** El parpadeo de sobresalto empieza unos 35 ms después de un sonido de arranque brusco; con 24 ms de rampa ya es menor. Un ruido de arranque instantáneo sobresalta incluso a 60–70 dB: **el arranque puede sustituir al volumen**. Un estímulo débil entre 30 y 500 ms antes **reduce** el sobresalto hasta en dos tercios (inhibición por prepulso; también de la vista al oído); uno a 2–6 s lo aumenta. A oscuras se salta más, y más ante una amenaza impredecible que ante una anunciada. El espacio que el cuerpo defiende alrededor de la cara acaba a 20–40 cm. Y se gasta rápido: en un estudio con niños, con estímulos cada 15–25 s, respondían casi todos a los cuatro primeros y casi nadie a los cuatro siguientes.

**El cine.** El autobús de Lewton: quitar todo el sonido menos los pasos, y entonces el frenazo. El pasillo de *El exorcista III*: plano general quieto y casi mudo durante minutos, un falso susto, y el de verdad después de más quietud. En *Insidious*, el demonio detrás de quien habla, sin música. El oficio dice: desviar la atención, retrasar el golpe más allá del compás esperado, y silencio antes.

**El metraje encontrado.** En *The Blair Witch Project* la golpean, suelta la cámara, calla, negro; sus gritos están en otra grabadora, en otro sitio: imagen y sonido separados. En *[REC]* la cámara cae y sigue rodando; a ella la arrastran a lo oscuro, y el sonido entra y sale. En *Cloverfield* el operador cae a centímetros de su cámara, que sigue enfocando ahora la cara, ahora el fondo, y el monstruo se inclina hacia ese aparato diminuto. El susto del operador —su grito, su caída— asusta al que mira; lo que da miedo queda fuera de cuadro.

**Una videocámara de 1988** (manuales de la Panasonic PV-400 y de la Canon E77, y referencias de vídeo). Varias llevaban delante **un piloto rojo que parpadea mientras graba** (esas dos, por ejemplo; otras solo lo tenían en el visor). Daban imagen desde 7–10 lux; por debajo, grano y motas de color. El iris cierra rápido y abre despacio (así lo describe una patente; no se encontraron tiempos). El micrófono tiene control automático de ganancia, y es lento: un estruendo distorsiona primero, luego el nivel se queda bajo unos segundos y **el ruido de la sala vuelve hinchándose en las pausas**. La pista de audio es mono, de 100 Hz a 10 kHz. Cuando la tensión o la velocidad de la cinta se alteran, los errores son *horizontales*, campo a campo: la parte de arriba que se dobla, la de abajo que se tuerce, una banda de conmutación que rebota, rachas de puntos. Nunca bloques ni mosaico ni colores separados. (Está documentado el mecanismo y que los motores de un aparato portátil sufren con la vibración; que una caída concreta dé esa ráfaga es plausible, no un dato.)

**Multijugador.** En *Content Warning* la cámara cae donde mueres y se puede recuperar. En *Phasmophobia* el cuerpo y el equipo se quedan, y grabar una muerte se paga. En *Lethal Company* el Bracken se lleva el cadáver. Lo que queda en el mundo cuenta la muerte mejor que la escena.

**Lo que no se encontró:** ninguna cifra publicada de cuánto puede durar una muerte repetida antes de molestar, ni declaraciones de Creative Assembly sobre la duración de sus muertes. Las duraciones que se citan de otros juegos son estimaciones a partir de vídeos.

## 5 · Principios

1. **Primero el reflejo, después el horror.** El cuerpo salta en una décima; lo que se entiende viene después, y dura más. Son dos trabajos distintos y van en ese orden.
2. **El arranque, no el volumen.** Imagen y sonido cambian en el mismo fotograma, sin rampa. No se sube el nivel del grito: ya está arriba.
3. **Medio segundo limpio.** En los 500 ms anteriores al golpe no se añade ninguna señal nueva para la víctima, ni un desgarro ni un silencio repentino. Lo que avisa, avisa con dos segundos o no avisa. (El desgarro de la embestida era esa señal; se compara con y sin él en el banco, 19.2.)
4. **La cara, y que mire.** La máscara es lo primero que se reconoce, mira a la lente y se queda el tiempo justo para verla.
5. **Se enseña la causa, se oculta el impacto.** El brazo que sube, los pies que dejan el suelo, el cuerpo que cae: sí. El golpe: fuera de cuadro, tapado, o entre dos parpadeos de luz.
6. **Todo tiene una causa física.** La cámara vuela porque le dan; la cinta falla porque algo golpea el suelo a su lado; el sonido se hunde porque el micrófono se protege. Nada es «un efecto».
7. **La cámara abandonada no se mueve ni se corta.** Quieta, torcida, medio tapada. Un plano que no reacciona a lo que pasa delante es lo que da miedo.
8. **Nunca dos veces igual, nunca más largo de lo que dice algo.** La variedad sale del sitio y de cómo te cogieron, no de un catálogo que se colecciona.
9. **Lo que no se puede animar bien, no se enseña.** Oscuridad, obstrucción y fuera de cuadro tapan lo que una criatura posada por código y un cuerpo sin esqueleto no pueden hacer.
10. **Es una cinta.** Lo que se ve es lo que grabó una videocámara de 1988 y lo que quedó de ella.

## 6 · Anatomía de una captura

`T0` es el instante en que la captura queda confirmada en la máquina de quien muere. La columna del mundo es lo que ven todos los demás; es casi lo de hoy.

| Tiempo | La víctima ve | La víctima oye | En el mundo |
|---|---|---|---|
| **El hueco** (−2,0 a 0) | Lo que estuviera viendo. Sin desgarro | La caza, sin cambios | La bestia persigue y embiste |
| **El golpe** (0,00) | Corte de un fotograma a la composición del rostro: la máscara ya está en cuadro —un tercio de la altura o más— y acaba de llegar en 3 a 5 fotogramas. Por dónde entra depende de la entrada (7.2) | El grito, de golpe, plano, en la cabeza. Vibración del mando | La cabeza de la bestia cae sobre la víctima; el brazo izquierdo la ensarta |
| **El rostro** (0,00–0,55) | La máscara a 13–17 cm, 50–65 % de la altura, mirando a la lente. Temblor de 12–14 Hz; a 0,22 s, un ladeo seco de la cabeza y el último tirón, de 17 a 13 cm. Con linterna: el haz cruza la máscara uno o dos fotogramas y se va al suelo | El grito entero | La sujeta; la víctima queda a 0,6 m |
| **El arrebato** (0,55–0,90) | El brazo derecho cruza el cuadro. La cámara sale despedida: 180° o más de giro, estela y peine | El grito se va con la cámara: cae de tono, pierde agudos, pasa a estar *en la sala*. Viento en el micrófono | El manotazo. La víctima sigue ensartada y con los pies en el suelo. La linterna, si la hay, vuela y rueda |
| **El suelo** (0,90–1,05) | Parada en seco, dos rebotes, se asienta de lado. Una banda de ruido sube una vez, se dobla arriba, pierde el color cuatro fotogramas | El golpe de la carcasa, sordo y fuerte. El micrófono se cierra: todo baja de golpe | — |
| **Lo que la cinta ve** (1,05–2,58) | Plano fijo: moqueta desenfocada en el tercio de abajo, algo que tapa un lado, las patas de la bestia, y los pies de tu cuerpo, que dejan el suelo y suben. El reloj de la cámara sigue corriendo | El micrófono se va abriendo: el siseo de la cinta y el rumor de la sala vuelven hinchándose. Chasquidos de la bestia, roces, sus garras en el suelo —cada una hace temblar la imagen— | Se endereza y la levanta con ella, despacio: un metro, de 1,1 a 2,2 s (hoy la levanta en el primer medio segundo, cuando nadie mira desde fuera). La sostiene ante la cara, mirándola |
| **El remate** (2,58–3,10) | El brazo que se echa atrás, si entra en cuadro. El golpe, no. A 3,10 el cuerpo cae en cuadro: lo último que entra es una mano, cerca de la lente | El silbido y el golpe, ahora desde donde está la bestia. El cuerpo contra el suelo, pegado al micrófono, que vuelve a cerrarse | Estocada a 2,80. Suelta el cuerpo a 3,10 |
| **El después** (3,10–4,20) | El golpe del cuerpo ha tocado el mecanismo: bandas de ruido que suben, la parte de arriba que se dobla, el color que va y viene. Detrás, el final que toque (7.4) | Lloro en el tono (la cinta ya no corre pareja), cortes. Lo que haga la bestia | La bestia, de pie sobre el cuerpo; después, el final |
| **El corte** (4,20) | Último campo roto, y nieve. SEÑAL PERDIDA | El canal muerto, en el mismo instante | La bestia vuelve a moverse (4,2 + 0,35). La baja se registra a 4,5 |

Cinco notas:

- **El grito se acorta.** Entero durante el rostro (0,55 s); después ya no es una capa: es un sonido que se aleja con la cámara y se apaga antes de 1,1 s.
- **La cinta muere cuando cae el cuerpo.** Es la única causa nueva que hace falta, y coloca la rotura donde el plan de partida quería la degradación.
- **De 4,20 a 4,50 no hay nada que ver** más que nieve: es el colchón que absorbe el retraso de la red, para que el estado que manda el anfitrión nunca corte una imagen.
- **Por la espalda, el rostro llega tres décimas más tarde** (7.2): el golpe es otra cosa.
- **El primer segundo de la tabla es el de la entrada de frente.** Cada entrada tiene el suyo (7.2), y todas dejan la cámara asentada antes de 1,2 s; de ahí en adelante manda el reloj del mundo, igual para todas.

## 7 · El contexto: cuatro recetas, siete entradas, dos finales

### 7.1 Cuatro maneras de morir

No se asusta igual a quien lleva diez segundos corriendo que a quien estaba leyendo un papel.

| Receta | Cuándo | Qué sabe la víctima | Qué se le da |
|---|---|---|---|
| **Caza** | La persecución acaba | Que viene; no cuándo ni cómo de cerca | **Interrupción**: la carrera cortada a media zancada y la cara donde no estaba |
| **Sorpresa** | Te coge ocupado, o nada más notarte | Nada | **FNAF puro**: la cara, entera, en un fotograma. El mismo medio segundo de rostro que las demás —el manotazo lo ven todos, así que dura igual para todos—: lo que cambia es que antes no había nada |
| **Emboscada** | Sale a por ti cuando creías que se había ido (armario, 13) | Que se arriesgaba | **La puerta que revienta** |
| **Encierro** | El registro del armario; un rincón sin salida | Todo, desde hace segundos | **Pavor, no susto.** El ritual lento que ya existe; al final, lo rápido |

### 7.2 Las siete entradas

Cambian el primer segundo; del suelo en adelante, todas siguen la tabla de la sección 6.

| Entrada | Se elige cuando | Los primeros instantes |
|---|---|---|
| **De frente** | La víctima la tiene dentro de ±50° de su mirada | La de la tabla. La bestia mide más que tú: la máscara **baja** al cuadro desde arriba, ladeada |
| **Por la espalda** | La tiene a más de 130° (lo normal huyendo) | 0,00: la carrera se para en seco y **la punta del brazo asoma por abajo a la izquierda del cuadro**, ya atravesándote. 0,12–0,34: te gira sobre el brazo: un barrido de 180° hacia ese lado. 0,34–0,68: el rostro, que ya estaba ahí. Arrebato a 0,68 (construido doce centésimas más largo que lo propuesto: con el giro empezando a 0,06 no daba tiempo a ver el brazo) |
| **De lado** | Entre 50° y 130° | La máscara entra por ese borde del cuadro, con la inclinación de la pose de la portada; la cámara es arrastrada hacia ella (60–110°) |
| **Desde arriba** | La víctima está agachada | Viene de encima: la máscara cae al cuadro casi del revés. El arrebato es hacia abajo y corto: la cámara apenas cae 60 cm |
| **Con las manos ocupadas** | Leía un documento, tecleaba el código o tenía la hoja abierta | La cámara se reorienta **debajo** de lo que tapa la pantalla; el papel es arrancado de un tirón en dos fotogramas, y detrás la cara ya está entera. Es el monitor de FNAF. (Registrando un mueble no hay nada que tape: es «por la espalda») |
| **Armario, registro** | La encuentra al final del ritual | Las hojas ya están abiertas y la tiene a 80 cm: la máscara **entra** al armario. Rostro a oscuras (9.3). El arrebato la saca: la cámara cae fuera y mira hacia el armario abierto —y hacia quien siga dentro, si eran dos— |
| **Armario, emboscada** | Vuelve de una finta (13) | Vuelve a la carrera a plantarse ante las puertas —quien miraba por la rendija la ve entrar en cuadro—, las dos hojas revientan a la vez y 0,15 s después es `T0`: la máscara ya está en el hueco |

Quién elige: **el anfitrión**, con lo que ya conoce de cada jugador —posición, hacia dónde mira, si está agachado o escondido, dónde está la bestia—. Lo que solo sabe la máquina de la víctima (qué tenía abierto en pantalla, qué luz hay, dónde cae su cámara) lo decide ella y no cambia nada para los demás. Si valen varias, por este orden: armario, desde arriba, y después el ángulo. «Con las manos ocupadas» no la elige el anfitrión: la pone la máquina de la víctima sobre la entrada que él eligió, solo en su cinta y sin cambiar los tiempos.

### 7.3 Lo que es igual para todos y lo que es solo de la cinta

- **En el mundo**, la bestia no se mueve de donde capturó: estira columna y cuello y tira de la víctima hacia sí, como hoy. No atraviesa muebles porque no camina.
- **En la cinta**, la toma del rostro se compone **en el espacio de la máscara**: la cámara se coloca respecto a la cabeza de la bestia, no al cuerpo de la víctima. Así la composición es la misma en un pasillo que contra una pared, y no depende de lo que la red tarde en traer la posición.
- Siempre hay sitio: para capturar hace falta línea limpia entre la cabeza de la bestia y la cámara (`can_attack`), y sobre esa línea se compone.

### 7.4 Los finales

| Final | Qué pasa de 3,10 a 4,20 | Cuándo |
|---|---|---|
| **Se va** | De pie sobre el cuerpo; se gira; los primeros pasos. La cinta se rompe sola | El de siempre |
| **Mira la lente, y se va** | Antes de girarse vuelve la cabeza hacia la cámara caída y la ladea, sin acercarse: medio segundo quieta. Después se va igual | A solas, una de cada tres; en equipo, una de cada seis. Nunca dos veces seguidas a la misma persona, nunca en la versión breve (14), y solo si la cámara lo puede grabar: toma «ve» y con luz |

Decisión del autor (19.3): que mire sutilmente y se vaya de igual manera. No es un segundo susto: es saber que ha visto la cámara. Pesa más a solas, donde no queda nadie más a quien ir a buscar.

Queda para más adelante un tercer final, **«se lo lleva»** (no suelta el cuerpo; se va con él y los pies colgando salen de cuadro): pide que la bestia camine con un cuerpo puesto después de registrada la baja.

### 7.5 Que no se repita

La entrada la manda el contexto, no el azar: no se elige «por variar» una que no corresponde a cómo te cogieron. Lo que cambia de una captura a otra con la misma entrada sale de la semilla de cada una —el lado del manotazo (salvo «de lado», que es la mano por la que vino), dónde cae la cámara, dónde rueda la linterna— y del sitio. La cinta de cada jugador lleva la cuenta de las entradas que ya vio en el piso, y con eso decide la versión breve (14.2); «mira la lente» nunca toca dos veces seguidas a la misma persona.

No se hizo una regla aparte que prohíba repetir la misma combinación de entrada, final y caída: con la semilla y el sitio no ha hecho falta en lo que se ha mirado. Si jugando se ve repetirse, es aquí donde iría.

## 8 · La cámara

### 8.1 Tres tomas con la misma cámara

**No se cambia de cámara.** El iris, el enfoque y el desenfoque de movimiento guardan estado, y un cambio de cámara los reinicia (para eso existe `camera_cut()`). La cámara del jugador se suelta del cuerpo y sigue una ruta:

1. **En mano** (hasta `T0`): la de siempre.
2. **Arrancada** (rostro y arrebato): colocada respecto a la cabeza de la bestia. Sin el muelle de la mano. Invariantes, comprobados cada fotograma: la lente a no menos de 11 cm del centro de la máscara (la nariz sobresale tres); la máscara dentro de ±25° de mirar a la lente (nunca se le ve la nuca); si el objetivo estaba en teleobjetivo, vuelve a angular en 80 ms, dentro del sacudón.
3. **Caída** (de 0,90 en adelante): un punto de reposo en el suelo, elegido al capturar.

Durante el rostro no hay control. El temblor es de la cámara (0,4°, 12–14 Hz, se apaga en 0,3 s), no del mundo.

### 8.2 Dónde cae

Se resuelve en el fotograma de `T0`, en la máquina de la víctima, con unos cientos de rayos (una vez, no cada fotograma).

- **Candidatos:** 16 direcciones a 0,9, 1,5 y 2,2 m del punto medio entre víctima y bestia, a ras de suelo.
- **Se descartan** los que quedan a menos de 12 cm de una pared o de un mueble (el suelo no cuenta: es donde descansa), los que caen en otra planta, en el barrido de una puerta que se está moviendo o en una sala donde no se puede capturar. Si el camino desde la mano choca con algo, el candidato pasa a ser el punto del choque retirado esos 12 cm —la cámara queda **al pie** de lo que la paró— y se valida como cualquier otro.
- **Se puntúa** (`camera_fall.gd`): que desde ahí se vea dónde cae el cuerpo y, sostenido, sus piernas y su tronco; que algo cercano tape en torno al 40 % del cuadro; que quede cerca de donde irá a parar la cabeza y a lo largo de la caída, no de través; a oscuras, a menos de 1,05 m del cuerpo, que es lo que alcanza el piloto; con la linterna en el suelo, que mire a la pared donde da su sombra. Y nunca encima de donde va a caer el cuerpo, ni a menos de 45 cm de la bestia.
- **La pose:** el cuerpo de la videocámara tumbado sobre un costado —entre 56° y 78° sobre uno, entre 80° y 102° sobre el otro, que es más alto—, con la lente a 3,4 o 7,6 cm del suelo según el lado, y mirando 8–20° hacia arriba. Nunca nivelada: un horizonte recto se lee como una cámara de cinemática. Hacia dónde mira no es al centro: a un punto entre el cuerpo sostenido y donde va a caer, abierto hasta 26°.
- **La ruta:** un arco con 20–50 cm de subida y media vuelta o más sobre un eje inclinado, en 0,32–0,40 s; dos rebotes (6 y 2 cm).

### 8.3 Cuando no hay buen sitio

| Clase | Qué graba | Cuándo |
|---|---|---|
| **Ve** | El cuerpo sostenido y su caída | Hay un candidato con vista |
| **Ve a medias** | Solo patas, una pared, una sombra | Solo hay candidatos sin vista al cuerpo |
| **Boca abajo** | Negro con una rendija de moqueta. **Todo se oye** | No hay candidato válido: cae a plomo, a los pies de la víctima, que siempre es suelo |

«Boca abajo» no es un fallo: es *Blair Witch*. Es también la red de seguridad: **no existe un sitio del hotel donde la escena no pueda resolverse**, porque la peor salida es una toma válida. Y es la base de la versión breve (14).

### 8.4 Lo que el plano del suelo tiene que tener

- **Un momento legible.** La clase de la toma sale de la geometría: qué partes del cuerpo sostenido y de su caída se ven desde el sitio elegido, sin nada sólido en medio. No se comprueba que la silueta se recorte contra algo más claro, como se propuso: eso depende de la luz de cada sala y se juzga mirando (en las hojas del banco se recorta contra la lámpara o la pared en las salas con luz).
- **Quietud.** Nada de zoom, panorámica ni corte. Lo único que la mueve, una vez asentada, es la caída del cuerpo a su lado. (Se propuso que también la movieran las pisadas de la bestia; no pisa mientras dura la escena: está quieta hasta el corte.)
- **El enfoque equivocado.** Queda cerca, a menos de un metro, y lo de detrás es blando. No se corrige.
- **El reloj de la cámara sigue corriendo** en la esquina hasta el corte.

### 8.5 Tu propio cuerpo

Desde el suelo se ve al superviviente desde fuera: su avatar pasa a dibujarse para su propia cámara al empezar el arrebato. La escena se hace y se mira con la **Exploradora**, que es la que mejor esqueleto y malla tiene y pasa a ser el personaje por defecto (19.9): colgando, piernas sueltas, cabeza atrás. La pose se escribe sobre los huesos comunes, así que el Detective Femenino la hereda, y se le ajustará después. El Detective Masculino no tiene esqueleto: solo sube, se inclina y cae, como hoy.

### 8.6 Cómo cae el cuerpo

Lo decide el anfitrión con el sitio que hay donde lo suelta (`executions.fall_room`) y es igual en todas las máquinas:

| Hay sitio | Cómo queda |
|---|---|
| 1,9 m libres hacia atrás y a un lado | Tendido hacia ese lado, como se propuso |
| Solo hacia el otro lado | Tendido hacia el otro |
| Solo recto hacia atrás (un pasillo) | Tendido recto |
| Ninguno | **Sentado**: la cadera baja un poco por detrás de donde colgaba, la espalda contra lo que lo ha parado —o tumbado de espaldas con las rodillas arriba, si lo de detrás queda a más de lo que alcanza—, los pies en el suelo por delante |

Sin sitio, lo construido al principio inclinaba el cuerpo 52° hacia atrás fuese lo que fuese lo que había: a través del costado de un armario, o de una pared. Ahora cuánto baja la cadera y cuánto se recuesta salen de los metros libres que hay detrás (`capture_score.seat_back`, `seat_lean`).

## 9 · La luz

Las tres situaciones del plan de partida. La oscuridad del hotel no se toca.

### 9.1 Sala iluminada

La luz que hay. La máscara llenando el cuadro le sube la exposición a la cámara, el iris cierra (lo hace solo: `camcorder_effect`) y el fondo se oscurece alrededor de ella. Desde el suelo, una lámpara en cuadro deja a la bestia en silueta y, en los presets que lo tienen, una raya vertical de sensor quemado.

### 9.2 A oscuras con la linterna encendida

- **Durante el rostro, la linterna no apunta a la máscara.** Una máscara blanca a 20 cm bajo el haz recibe unas doscientas veces más luz que una pared a 3 m, y el iris de la cámara solo puede cerrar paso y medio: un blanco sin rasgos, que es lo que el plan de partida prohíbe con razón. El agarre aparta la mano de la linterna: el haz cruza la máscara uno o dos fotogramas —el único fogonazo— y se queda en el suelo o en la pared de al lado. La máscara se lee con esa luz rebotada, de lado y dura.
- **La linterna cae y rueda**, por su cuenta, y se para iluminando a ras de suelo. Su sitio lo saca cada máquina de la semilla de la captura, igual en todas (16.3): más allá del cuerpo y a un lado, a 2,1–2,9 m de donde va a caer —lo bastante lejos para que el haz, a ras de suelo, se haya abierto hasta la altura de unas piernas—, o al pie de la pared que encuentre antes; y apuntando hacia donde la bestia sostiene el cuerpo, con unos grados de error. Además del haz lleva un resplandor corto alrededor del cristal, que es lo que llega a la máscara cuando el haz ya no la mira. La cámara se resuelve después, y sabe dónde quedó la linterna.
- **El teatro de sombras.** Con la linterna en el suelo, la bestia levantando el cuerpo es una sombra enorme en la pared. Es la imagen más fuerte que este sistema puede dar y no pide ni una pose más: si la cámara puede caer mirando a esa pared, se prefiere a mirar a la bestia.
- Los demás ven esa linterna caer y girar desde donde estén, incluso por una puerta: es la señal de que han cogido a alguien.

### 9.3 A oscuras sin linterna (y dentro de un armario)

Una cámara no graba sin luz, y aquí no hay ninguna. El plan de partida pide una luz de ejecución muy localizada, y admite que no puede parecer una linterna salida de la nada. **Esa luz es el piloto de grabación.**

- **Qué es.** El diodo rojo que una videocámara de 1988 llevaba delante y que **parpadea mientras graba**. El juego ya lo tiene en pantalla: el punto rojo junto a REC.
- **Cómo es.** Rojo y sin sombras. **Jugando apenas se nota** (19.1): tiñe lo que tienes a un palmo —la hoja del armario desde dentro, una puerta a punto de abrirse— y solo en negro total; en una sala a oscuras, sin nada cerca, no se ve nada de él. **En la captura se aviva**: alcanza 1,15 m y a 20 cm de una máscara blanca da una cara roja reconocible; a un metro, casi nada; a dos, nada. No ilumina una sala en ningún caso. Son cinco perfiles de la misma luz (`death_tape.gd`, `hotel_player.gd`): llevada (apenas, 70 cm); en el rostro a oscuras o dentro de un armario; en el rostro con linterna (menos, que ya hay luz); en el suelo a oscuras (la más fuerte: es todo lo que hay); y en el suelo con luz, una mancha roja bajo la lente. En una sala iluminada el piloto no toca la máscara: sería una luz salida de la nada.
- **Por qué no alumbra normalmente.** Sí alumbra: lo que está al alcance del brazo, en negro total. Con cualquier otra luz no se nota.
- **No cambia ninguna regla.** Solo existe en la máquina de quien graba: ni la bestia ni los compañeros ni un cazador lo ven.
- **Parpadea a 1 Hz, y el parpadeo cuenta la muerte.** Enganchado a `T0`, siete décimas encendido y tres apagado, cae así sobre los tiempos que ya existen:

| Segundos | Piloto | Qué coincide |
|---|---|---|
| 0,0–0,7 | Encendido | El rostro, en rojo, entero en todas las entradas; el manotazo |
| 0,7–1,0 | Apagado | El vuelo y el golpe contra el suelo, a ciegas |
| 1,0–1,7 | Encendido | La primera imagen desde el suelo: los pies, que suben |
| 1,7–2,0 | Apagado | — |
| 2,0–2,7 | Encendido | Lo que cuelga, en el borde de la luz |
| 2,7–3,0 | **Apagado** | **La estocada (2,8): se oye, no se ve** |
| 3,0–3,7 | Encendido | El cuerpo, que cae dentro de la luz (3,1) |
| 3,7–4,0 | Apagado | — |
| 4,0–4,5 | Encendido | El final |

  El golpe queda entre dos parpadeos. La cabeza de la bestia, de pie, queda fuera del alcance del piloto: a oscuras y sin linterna no se elige «mira la lente», porque no se vería.
- **Para que el cuerpo caiga en la luz**, a oscuras el sitio de la cámara se busca a menos de un metro de donde va a caer.
- **Dentro de un armario siempre hace falta**: la linterna se apaga al entrar y la máscara que se mete queda a contraluz de la sala.

### 9.4 Jerarquía y lo que no se hace

Se reconoce primero la máscara; el cuerpo negro puede no verse nunca; las patas, solo al cruzar luz. **Criterio:** quien lo ve por primera vez reconoce la cara y entiende que ha habido una muerte, también sin luz ambiente. No se hace nada de la lista del plan de partida: ni subir la luz ambiente, ni quitar el negro, ni ganancia extrema, ni visión nocturna, ni destello blanco a pantalla completa.

## 10 · La cinta

Cada fallo de imagen tiene una causa, dura lo que dura esa causa, y es **horizontal y por campos** —nunca bloques, mosaico ni canales separados—.

| Causa | Qué le pasa a la imagen | Cuánto |
|---|---|---|
| El agarre (`T0`) | Uno o dos campos doblados arriba y una racha de puntos. **Sin tapar la máscara** | 30–50 ms |
| La máscara llena el cuadro | El iris cierra; el fondo cae a negro | Lo hace ya el iris simulado |
| El arrebato | Estela y peine del entrelazado | Lo hacen ya el desenfoque y el entrelazado: a esa velocidad de giro salen solos |
| El golpe contra el suelo | Una banda de ruido sube una vez; arriba se dobla; cuatro fotogramas sin color; la banda de abajo rebota | 0,25 s, y se asienta |
| En el suelo | **Nada.** Imagen estable, blanda y con grano. Que funcione es lo que da miedo | — |
| El cuerpo cae al lado | Lo mismo que el primer golpe, y ya no se asienta: bandas que suben cada vez más seguidas, sincronismo que resbala, color que va y viene | Desde que toca el suelo (lo sueltan a 3,10 y llega a 3,46) hasta el corte |
| El corte | El último campo, roto; nieve | Instantáneo |

- **No se funde a estática: se corta.** Una grabación que se interrumpe no se desvanece. La nieve es cinta sin grabar.
- SEÑAL PERDIDA sigue donde está, sobre la nieve.
- Con «Efectos reducidos» no hay bandas ni peine: el arrebato es un corte seco del rostro a la cámara ya en el suelo, y la nieve es fija y de poco contraste.

## 11 · El sonido

### 11.1 De tu cabeza al micrófono

Hasta el arrebato oyes como persona. Cuando la cámara sale de tus manos, **lo que oyes es lo que graba la cámara**: su micrófono, en el suelo, sin graves ni agudos (de 120 Hz a 6,5 kHz), con su siseo. No se anuncia: pasa. Es el equivalente en sonido de ver tu cuerpo desde fuera.

### 11.2 El micrófono se protege

Un estruendo lo satura un instante y el nivel se hunde de golpe unos 14 dB; después sube despacio, durante un par de segundos, y con él suben el siseo de la cinta y el rumor de la sala. Pasa dos veces: al caer la cámara y al caer el cuerpo. El resultado es que tras cada golpe hay un silencio que se va llenando de ruido de fondo, y en él los sonidos pequeños —un roce, una garra— llegan enormes.

### 11.3 Capas y momentos

| Segundo | Sonido | De dónde sale |
|---|---|---|
| 0,00 | El grito, entero durante el rostro | `execution_scream.wav`, recortado |
| 0,55–1,10 | El mismo grito alejándose: tono abajo, agudos fuera, ya en la sala | Lo mismo, tratado |
| 0,90 | La carcasa contra el suelo | De los que ya hay: el objeto que cae (`object_fall_*`), más grave y más seco |
| 1,05–2,58 | Chasquidos de la bestia, sus garras, roces de ropa | Los chasquidos y las garras existen; los roces, de los de la cama de la escena de entrada (`bed_*`) |
| 2,58–2,80 | Silbido y golpe, desde la bestia | `execution_hit.wav` |
| 3,46 | El cuerpo contra el suelo (lo sueltan a 3,10), pegado al micrófono | De los que ya hay: un golpe sordo de la escena de entrada (`stomp_*`), bajado de tono. Hoy cae en silencio porque con la pantalla en negro sonaba a segunda estocada; viéndolo caer, hace falta |
| 3,46–4,20 | Cortes: al sonido le faltan trozos, de cuatro centésimas, cada vez más seguidos hasta el final, a la vez que la imagen se deshace | Tratamiento sobre el micrófono (`death_tape.dropout`). El lloro en el tono que se propuso no se hizo: pediría un cambio de tono sobre toda la mezcla |
| 4,20 | El canal muerto, con la nieve | `execution_static.ogg`, como hoy |

### 11.4 Volumen

- No se sube nada: el grito ya está a fondo de escala. Lo que hace saltar es que arranca de golpe sobre lo que había.
- El limitador y la mezcla por buses, como están. **Medido** en las cuatro películas del banco (`tools/capture/film_check.py`, sonoridad de programa BS.1770, con los volúmenes por defecto): la persecución que precede a la captura está en torno a −14 LUFS; la captura entera (4,2 s), entre −7,7 y −9,2; su primer medio segundo —el grito— entre −1,9 y −2,8, con el pico en −0,5 dBFS (el limitador); y desde que la cámara está en el suelo hasta el golpe, entre −18 y −23. Es decir: el grito queda unos 11 LU por encima de una caza que ya suena fuerte, y la escena cae después 16 LU por debajo de él. Lo primero es lo que hay que escuchar con auriculares (18.2): el nivel del grito es el que tenía antes de esta obra, y no se ha tocado.
- No hay voz humana de la víctima, y no se sintetiza ninguna (19.8): ni gritos ni sonidos humanos generados. Se trabaja con los sonidos que ya hay; grabar los que faltan queda pendiente.

## 12 · Lo que ven los demás

- **Los testigos** ven la escena en tercera persona, sin que nadie les mueva la cámara: la cabeza de la bestia que cae sobre su compañero, el brazo que lo ensarta, el manotazo, el cuerpo que sube, la estocada, la caída. Es lo de hoy con un principio violento y el levantamiento más lento.
- **El grito se oye en todo el piso**, como hoy: nadie debe perderse que han cogido a alguien.
- **La linterna de la víctima cae y rueda** para todos: una luz que se va al suelo y gira dice dónde ha sido.
- **La cámara se queda** (19.5): una videocámara en el suelo donde cayó, hasta que cambie la etapa o se devuelva (sin piloto: apagada). Quien pasa por ahí sabe qué pasó. El modelo es el que eligió el autor ([ASSETS.md](ASSETS.md)), horneado en el espacio de la lente: se coloca con la misma transformación con la que la cámara quedó grabando.
- **Quien muere** pasa, como hoy, a mirar por encima del hombro de un compañero tras 2,6 s de señal perdida.
- **El cazador de versus** no recibe nada de esto: sigue en su lectura acústica y queda parado los mismos 4,2 s. Para él hay ritual de armario, no finta.
- **El observador y los bots** ven la tercera persona; las pruebas automáticas saltan el trabajo de cámara.

## 13 · Armarios

### 13.1 El ritual se queda

Una hoja, la otra, el brazo dentro: 2,5 s en Desafiante (3,2 en Apacible, 2,8 en Equilibrada, 2,0 en Pesadilla). Es la receta de encierro y funciona porque es lento. Lo nuevo es cómo acaba (entrada «armario, registro»), que desde dentro, a oscuras, cada hoja que se abre deja entrar luz y la máscara se asoma al hueco antes de entrar, y **desde dónde lo hace**: mientras mira las puertas se planta justo delante de ellas (`hotel_locust.settle_before`). Antes lo abría desde donde hubiera parado, hasta a un paso de lado: la hoja de ese lado se abría atravesándola y sacaba a su víctima a través de la hoja.

### 13.2 Qué sabe la bestia

El código ya distingue casi todo; falta separar una cosa.

| Saber | Qué es hoy | Qué puede hacer |
|---|---|---|
| **Nada** | No hay pista | Nada. Al rato sin pistas se rinde y se va (regla del diseño) |
| **Sospecha** | Un armario ocupado junto a donde te perdió o te oyó (`suspect_hide`), o uno abierto «por si acaso» (`peek_chance`) | El ritual |
| **Certeza** | **Te vio entrar**, o te ve por una hoja entreabierta | El ritual o, nuevo, la finta |

Hoy sospecha y certeza se guardan en el mismo sitio (`observed_hide`). Hace falta que la certeza sea solo la de haberte visto, y que caduque: perdida la pista, no recuerda el armario.

### 13.3 La finta

Como la quiere el autor (19.4): **la bestia se queda esperando, y lo que finge es su presencia.** No se va a ninguna parte: se aparta, se queda quieta y calla, y el sonido que dice que está cerca —el zumbido, la respiración, los latidos (`dread_aura`)— se apaga como si se hubiera ido. Quien se fía y sale, sale delante de ella.

Solo la IA, solo con certeza, nunca en Apacible, **y solo algunas veces** (una de cada cuatro en Equilibrada, dos de cada cinco en Desafiante, tres de cada cinco en Pesadilla): si pasara siempre, se aprendería en dos muertes. El resto de las veces, con certeza hace el ritual, como hoy.

| Fase | Qué hace | Qué puedes hacer |
|---|---|---|
| **Llega y mira** (1–1,4 s) | Se para ante las puertas, a un paso, las mira y chasquea una vez | Nada: salir ahora es salir delante de ella |
| **Se aparta** (hasta 2,5 s) | Dos o tres pasos hasta un sitio desde donde vea las puertas: contra la pared del armario, a metro y medio de su costado, fuera de lo que deja ver una rendija; si ahí no cabe o hay algo en medio (los armarios grandes están en un hueco), a un lado por delante, y si tampoco, de frente. Se oyen: son sus pasos de verdad | Nada todavía |
| **Espera** (8–11 s en Equilibrada, 9–13 en Desafiante, 11–15 en Pesadilla) | Quieta, vuelta hacia el armario, sin un sonido. Desde los 2,4 s de haber llegado su presencia se apaga: la respiración en menos de dos segundos, el zumbido en unos cinco, hasta quedarse en casi nada | **Esperar.** Salir es que te coja en la puerta. Abrir una hoja lo bastante para que se te vea (tres décimas con una hoja abierta de verdad; una rendija no la mueve) es la emboscada: vuelve a la carrera, revienta las puertas y te saca |
| **Se va** | Si has aguantado, se cansa: se va andando, se le oye irse, y pierde la certeza | Ahora sí: sal |

La regla que se puede aprender es una sola, y es de oído: **si no la has oído irse, no se ha ido.** Sus pasos no mienten nunca; lo único que calla es lo que no pisa. La manera de escapar es la que pidió el autor: esperar un tiempo prudente.

Hoy, con esa certeza, va derecha al ritual y no hay nada que hacer: la finta cambia una muerte segura por una prueba de paciencia. Es más clemente que lo que hay, no menos.

Para los demás no cambia nada que no sea verdad: está donde se la ve, y quien la mira desde fuera la ve esperar. El cazador de versus no finge: para él no hay nada de esto.

### 13.4 Dos dentro

Como hoy: se lleva a quien entró primero. El otro se queda en un armario abierto, a medio metro, y es el testigo mejor colocado de todo el juego: la cámara de la víctima cae fuera mirando hacia él.

### 13.5 Salir sin ruido

Decisión del autor (19.4). Hoy salir de un armario se oye siempre igual (a 12 m por su oído). Ahora hay dos maneras:

| Cómo | Cuánto tarda | A cuánto se oye |
|---|---|---|
| **Un toque** | Lo de siempre | 12 m por su oído, como hoy |
| **Mantener** la tecla tres segundos | Las hojas se abren despacio mientras se mantiene; si se suelta antes, se cierran y no ha pasado nada | **Un 25 % menos: 9 m por su oído** (6,8 m en Equilibrada, 9 en Desafiante, 10,8 en Pesadilla). Para un cazador humano, lo mismo: un 25 % menos |

No hace invisible a nadie: si está mirando, te ve salir igual. Sirve cuando anda cerca y no mira.

### 13.6 Entrar y salir, de verdad

Hoy el cuerpo aparece dentro y aparece fuera de un fotograma al siguiente. Pasa a ser un movimiento: las hojas se abren, el cuerpo cruza el hueco y la cámara con él, y las hojas se cierran detrás. Lo mismo al salir, deprisa o despacio. Y enlaza con la captura: si la bestia te coge a medio salir, la escena empieza desde donde estés —no hay un salto previo al sitio de fuera—, y si te saca ella, las hojas ya están abiertas cuando la máscara entra.

**Dónde queda el cuerpo.** Sacado de un armario no hay sitio para tenderlo: el cuerpo se dobla donde lo suelta y queda sentado en la boca del armario, la espalda contra el fondo y las piernas fuera. Las puertas se quedan abiertas sobre él —antes volvían a cerrarse a través del cuerpo— y en ese armario no entra nadie hasta que la etapa cambia o se devuelve. Es la misma regla que en cualquier otro sitio (8.6).

## 14 · Repetición, duración y opciones

### 14.1 Cuánto dura

| Caso | Hoy | Queda |
|---|---|---|
| Hasta que la bestia se mueve | 4,2 s | Igual |
| Hasta que se registra la baja | 4,5 s | Igual |
| En equipo, hasta mirar a un compañero | 4,5 + 2,6 s | Igual |
| A solas con clemencia, hasta volver a jugar | 4,5 + 4,0 s | La primera vez, igual. Las siguientes en el mismo piso, 4,5 + 2,0 s |

### 14.2 La versión breve

La primera muerte de cada jugador en un piso se ve entera. **De la segunda en adelante, si esa entrada ya la vio, la imagen se va cuando la cámara se asienta** (hacia 1,05 s): nieve, y el resto se oye a través de ella. Es la toma «boca abajo» elegida a propósito. La bestia tarda lo mismo, los demás ven lo mismo, y quien muere por cuarta vez no vuelve a mirar cuatro segundos que ya conoce.

Una entrada que no había visto se ve siempre entera.

### 14.3 Opciones

- **«Sobresaltos: completos / suaves».** En suaves no hay rostro: la captura corta directamente a la cámara en el suelo, y el grito entra con 30 ms de rampa y 8 dB menos. La muerte se entiende igual.
- **«Efectos reducidos»**, que ya existe: sin temblor, sin bandas, sin peine; el piloto, fijo.
- **Destellos:** nunca más de tres cambios grandes de luz por segundo; el piloto va a 1 Hz; el fogonazo de la linterna es uno solo; la nieve no parpadea en conjunto.

### 14.4 La cinta que se rebobina

En las dificultades con clemencia, tras el corte la etapa vuelve a empezar. Aprobado (19.7): se ve **rebobinar** —la nieve, la marca de rebobinado en lugar de REC y el reloj de la cámara corriendo hacia atrás hasta la hora en que empezó el sector—, y desde ahí el reloj de la cinta sigue. El tiempo del piso que se anota en Records es el de verdad, con los intentos perdidos dentro: la cinta se regraba, el reloj del juego no.

## 15 · Reglas que no se rompen

Además de las del [diseño](GAME_DESIGN.md), que valen todas:

1. **Una captura, una muerte.** La decide el anfitrión; la escena es su consecuencia y nunca al revés.
2. **Nada de lo que se ve cambia lo que se puede hacer.** El piloto, la cámara caída y la cinta son de quien muere: no los percibe la bestia ni dan ni quitan nada a nadie.
3. **No hay muerte por guion.** La finta existe solo donde se puede escapar de ella, y solo con una certeza ganada mirando.
4. **El sonido no miente.** Si se aleja es que se aleja.
5. **La interfaz no se falsea.** Lo que tenías abierto se cierra porque te han cogido, como hoy; nada finge un menú ni un aviso.
6. **Siempre se puede resolver.** No hay sitio, luz ni estado del juego en el que la escena no tenga una salida válida (8.3, 16.4).
7. **La calidad gráfica no da ventaja ni quita la escena.** Lo que hace legible la muerte está en todos los presets.

## 16 · Cómo se construye

### 16.1 Dos capas

| Capa | Dónde corre | Qué lleva |
|---|---|---|
| **El mundo** | Todas las máquinas | Las poses de la bestia, el cuerpo de la víctima, la linterna que cae, la videocámara que queda en el suelo, las hojas del armario, los sonidos en la sala. Es `executions.gd` más las poses de `locust_visual` y de `avatar_visual` |
| **La cinta** | Solo la de la víctima | La cámara, el piloto, los fallos de imagen, el micrófono, la versión breve. Es `death_tape.gd`; lo único que dice por la red es dónde quedó su cámara |

Si la cinta falla o se salta, el mundo sigue entero y la muerte se registra igual.

### 16.2 Un solo reloj

Todo —poses, cámara, sonido, fallos— lee `execution.time`. Hoy la bestia se posa con su propio contador de estado, que en un invitado empieza cuando llega el cambio de modo, hasta una décima después del aviso de ejecución: en una escena cuyos primeros cinco fotogramas lo son todo, eso no vale. **Durante una ejecución la bestia es una pieza de la escena en todas las máquinas:** posición y giro, los del aviso; pose, la del reloj; los estados de red se ignoran hasta que acaba.

Las animaciones se evalúan por tiempo y en cada fotograma dibujado, no en el paso de física: a 30 FPS la irrupción son dos fotogramas, y siguen siendo los correctos.

### 16.3 Lo que viaja

El aviso (`execute_start`: plaza, punto, giro) lleva además un diccionario con lo que decide el anfitrión (`executions.stage_capture`): **entrada**, **lado**, cómo cae el cuerpo (**recto**, **doblado** y los **metros libres** detrás), a qué distancia se le sujeta, de dónde venía, hacia dónde miraba, si estaba **agachado**, si llevaba la **linterna** encendida, de qué **armario** se le saca, si la bestia querría **mirar la lente**, la **semilla** y el **identificador** de la captura. Una máquina que recibiera menos que eso juega la escena igual, con los valores por omisión. El protocolo es `the-four-net-17`.

Con la semilla, cada máquina saca lo mismo: el sitio de la linterna y cómo rueda (se resuelve contra la geometría fija, que es igual en todas). El sitio de la cámara es solo de la víctima, y se lo dice al anfitrión al resolverlo (`tell_lens`): el anfitrión solo lo acepta de quien está siendo ejecutado y cerca de donde lo cogieron, deja con él la videocámara en el suelo para todos y, si quería el final «mira la lente» y la cámara lo puede grabar, lo pone; si no llega antes del segundo 2, el final es «se va».

### 16.4 Estados y salidas

| Estado | Entra | Sale |
|---|---|---|
| `CONFIRMADA` | El anfitrión captura | Mismo fotograma: el anfitrión elige entrada y final. La máquina de la víctima, al recibirlo, resuelve la caída |
| `ROSTRO` | 0,00 | 0,55 (0,68 por la espalda) |
| `ARREBATO` | Manotazo | La cámara toca el suelo |
| `SUELO` | Impacto (0,94–1,02 de frente; hasta 1,15 por la espalda) | 0,15 s después |
| `TESTIGO` | La cámara asentada (antes de 1,1, que es cuando empieza a subir el cuerpo; por la espalda, un instante después) | 2,58 |
| `REMATE` | 2,58 | 3,10 |
| `DESPUES` | 3,10 | 4,20 |
| `CORTE` | 4,20 | La baja (4,50) o la versión breve |

Cada cosa que puede interrumpirla, y qué pasa:

| Qué ocurre | Resultado |
|---|---|
| Pausa (a solas) | El reloj de la escena se para y con él la cámara, la imagen y los golpes que faltan; al volver sigue donde estaba. Lo que ya estaba sonando (el grito, un golpe) termina de sonar bajo el menú, como cualquier otro sonido del juego |
| La etapa se cierra o el piso acaba con la escena a medias | Como hoy: se suelta a la víctima viva. La cámara vuelve a la mano con un corte; avatar, linterna, videocámara, piloto y sonido, a su sitio, y el armario del que la sacaban se cierra (comprobado cortándola a seis segundos distintos, 18.1) |
| La víctima se desconecta | El mundo acaba la escena con su cuerpo y la baja se registra |
| El cazador se desconecta a media ejecución | La máquina del anfitrión la termina, como ya hace con la caza |
| La bestia deja de existir (piso nuevo) | La cinta se da cuenta de que su escena ya no está y devuelve la cámara a la mano; no queda nada del piso anterior |
| Llega la etapa devuelta | Lo de hoy: en pie en la entrada, con todo restaurado |
| Otra captura a la vez | No puede: una ejecución en todo el piso, como hoy |
| El objetivo estaba en teleobjetivo | Vuelve a angular en 80 ms |
| La víctima estaba en el aire, asomada o a medio abrir una puerta | Cuenta como de pie; la puerta sigue su recorrido |
| Una puerta barre el sitio de la cámara | No puede: esos sitios se descartan; si aun así pasa, la hoja tapa el plano y es obstrucción |
| Alguien se une con la escena en marcha | Ve a la bestia y al cuerpo como estén; no hay cinta para él |
| Guardado (Continuar) | No se guarda durante la escena, como hoy |
| Menos de 15 FPS | Todo va por tiempo; el rostro dura lo mismo en segundos |

### 16.5 Dónde toca

- `game/app/capture_score.gd`: todos los tiempos de la escena y todas las curvas que dependen solo de su reloj. Lo leen los demás.
- `game/app/executions.gd`: lo que decide el anfitrión, el reloj único, dónde está cada cuerpo, la linterna y la videocámara que caen, cómo cae el cuerpo, los armarios que quedan abiertos.
- `game/app/death_tape.gd`: la cinta de quien muere —cámara, piloto, fallos de imagen, micrófono, versión breve, sobresaltos suaves—. `game/app/camera_fall.gd`: dónde cae la cámara, sin estado.
- `game/enemies/locust/locust_visual.gd`: las poses (la cabeza que cae, el ladeo, el manotazo, el brazo que ensarta y el que remata, volverse a la lente) con el reloj de la escena.
- `game/player/avatars/avatar_visual.gd`: mostrarse a su propia cámara y las poses del cuerpo (sujeto, colgando, tendido, sentado).
- `game/enemies/locust/hotel_locust.gd`: certeza separada de sospecha, la finta (`LURK`), plantarse ante las puertas.
- `game/world/interactables/hiding_place.gd`, `game/player/hotel_player.gd`, `game/app/interaction.gd`: entrar y salir como movimiento, la salida callada, las puertas que se quedan abiertas.
- `game/app/presentation_rig.gd` y `analog.gdshader`: los fallos por causa, el rebobinado; el desgarro de la embestida detrás de un interruptor (19.2).
- `game/app/hotel_main.gd`, `revival.gd`, `floor_save.gd`, `game_session.gd`: el reloj de la cinta, el rebobinado, la espera más corta.
- `game/net/match_net.gd`: el aviso ampliado y el sitio de la cámara.
- `game/ui/hotel_ui.gd`: «Sobresaltos suaves», lo que va por encima de la nieve, el papel arrancado.
- `game/presentation/shader_warmup.gd`: ver más abajo.

### 16.6 Que no dé un tirón

El primer fotograma de la escena es el peor momento posible para compilar nada. Al cargar el piso el calentamiento que ya existía dibuja una vez lo que una captura trae al cuadro y nadie había dibujado: el cuerpo propio visto desde fuera, la videocámara y la linterna en el suelo, con la luz de la sala y con la de la linterna. Y la bestia, que el calentamiento quería dibujar y nunca dibujaba: el piso se dibuja antes de ponerle la suya, así que ahora la sustituye una figura con su misma malla y su mismo material. Los sonidos son los que el juego ya tenía cargados. Lo que sí se crea en el momento son los tres efectos del micrófono, al salir la cámara de la mano (no en `T0`): son filtros de bus, sin nada que cargar.

## 17 · Lo que puede salir mal

| Riesgo | Cómo se cubre |
|---|---|
| La máscara no aguanta de cerca (textura, polígonos) | Probado antes de empezar: a 15 cm, con la imagen entera de la cámara encima, se lee como una cara y no como un modelo (`evidence/mask_015.png`). A 12 cm empieza a verse la malla |
| La cámara cae dentro de una pared o de un mueble | Los candidatos se validan; lo que no vale, no se usa; la última salida es «boca abajo» |
| El cuerpo sin esqueleto se ve rígido | La escena se hace con la Exploradora (19.9). Para el Detective Masculino: encuadre que lo corta, silueta, sombra |
| El susto se gasta | Raro por diseño (se muere poco y con minutos de por medio), entradas por contexto, versión breve, y «mira la lente» en reserva |
| Molesta en vez de asustar a la quinta muerte | Versión breve y espera más corta |
| El piloto se lee como truco | Está en pantalla desde el primer minuto (el punto de REC) y tiñe siempre, apenas, lo que tienes a un palmo |
| Quitar el desgarro de la embestida deja la estocada sin aviso | Se prueba A/B (19.2). El aviso puede ser de la bestia —su postura, su voz— y no de la imagen |
| Desincronía entre máquinas | Un reloj, un dato con semilla, y los últimos 0,3 s solo nieve |
| Volumen | No se sube nada. Medido (11.4): el grito queda 11 LU por encima de la caza que lo precede, a −2 LUFS en su medio segundo. **Falta escucharlo** con auriculares y decidir si se baja; «Sobresaltos suaves» ya lo baja 8 dB |
| Destellos | Tres por segundo como mucho. Se pasa a cada película del banco un cedazo según WCAG 2.3.1 (`tools/capture/film_check.py`: no es un análisis certificado; cuenta de más antes que de menos). Encontró uno: las barras del rebobinado, que como se hicieron al principio encendían cada punto de la imagen 5,5 veces por segundo. Ahora son dos barras a 1,9 pasadas por segundo, y con «Efectos reducidos» no hay barras. La escena de la captura queda dentro del límite |
| El cuerpo atraviesa lo que tiene detrás | Cómo cae sale del sitio que hay (8.6); la prueba lo comprueba de espaldas a una pared |
| Coge a su víctima a través de una hoja del armario | Se planta ante las puertas antes de abrirlas (13.1, 13.3); la prueba comprueba desde dónde la coge |

## 18 · Fases y pruebas

**Estado el 12 de octubre de 2026.** «Hecho» quiere decir construido, mirado en las hojas y las películas del banco y cubierto por la batería (`tools/verify.ps1`, con `tests/hotel/capture_test.gd` dentro). No quiere decir afinado: ninguna fase se ha jugado todavía con gente, y eso es lo que pide la columna de la derecha.

| Fase | Qué se hizo | Estado | Falta para darla por buena |
|---|---|---|---|
| **0 · Banco** | `tools/dev/capture_bench.gd`: jugado (`Banco de capturas.cmd`), filmado (`bench-films`) y en hojas de fotogramas | Hecho | — |
| **1 · El golpe y el rostro** | La composición en el espacio de la máscara, la irrupción en cuatro fotogramas, el temblor, el ladeo, el grito recortado. El desgarro de la embestida, detrás de un interruptor | Hecho | Que quien no lo ha visto salte y diga que vio una cara. **El veredicto del autor sobre el desgarro (19.2)** |
| **2 · La cámara cae** | Dónde cae y cómo, el plano del suelo, el cuerpo propio, los fallos de cinta por causa, el micrófono, los cortes del final. Final «se va» | Hecho | Mirarla en muchos sitios jugando: la prueba la resuelve en 135 (45 salas, tres puntos en cada una; «ve» en 128, «a medias» en 7, «boca abajo» en ninguno) |
| **3 · La luz** | La linterna que cae, rueda y se queda encendida; el piloto en sus cinco perfiles | Hecho | Que se entienda la muerte en las tres luces, con gente. El teatro de sombras depende del sitio: se prefiere, no se garantiza |
| **4 · Contextos** | Por la espalda, de lado, desde arriba, manos ocupadas (el papel arrancado); «mira la lente» | Hecho | — |
| **5 · Armarios** | Certeza y sospecha; la finta y la emboscada; el registro desde delante de las puertas; salir sin ruido; entrar y salir como movimiento; el cuerpo que queda sentado y las puertas abiertas | Hecho | Jugarlo: que esconderse bien siga funcionando y que de la finta se escape por paciencia y no por suerte. Los números de la espera y de cuántas veces finge son los de la tabla de dificultades y están sin medir |
| **6 · Red y versus** | El aviso ampliado, el sitio de la cámara, la linterna y la videocámara para todos, el protocolo 17 | Hecho | Los cuatro escenarios de red pasan, y uno de ellos ejecuta a alguien sacándolo de un armario; **no hay** una prueba que mire la escena desde la máquina de un testigo fotograma a fotograma. Verla con dos personas |
| **7 · Repetición, opciones y mezcla** | Versión breve, espera más corta, la cinta que se rebobina, «Sobresaltos suaves»; la sonoridad medida y el cedazo de destellos pasado (17) | Hecho lo que es código | Escuchar el grito con auriculares, y todo 18.2 |

### 18.1 Pruebas automáticas

`tests/hotel/capture_test.gd` (86 comprobaciones, medio minuto):

- **La partitura:** los golpes en su orden; el cuerpo no sube hasta que la cámara está en el suelo; las curvas no retroceden ni se salen de 0 a 1; sentado, la cadera y el respaldo caben en lo que hay detrás.
- **La elección:** de frente, por la espalda, de cada lado por su mano, desde arriba, en un armario y tras la finta salen de dónde está cada uno. Lo que decide el anfitrión va entero; con menos datos, la escena se juega igual.
- **La escena**, por tres entradas: empieza en el acto y una sola vez aunque la toquen dos; la cámara nunca tiene un valor no finito; la máscara, del derecho y a un palmo —también en el primer fotograma, con la cabeza de la bestia encima de su víctima: sin ese arreglo la comprobación falla—; la cámara en el suelo antes de que suba el cuerpo; el golpe y la caída a su segundo; una muerte; la etapa devuelta con la cinta rebobinada y el tiempo del piso corriendo; y nada de ella después.
- **Las interrupciones:** cortada a los 0,05, 0,4, 0,8, 1,7, 2,9 y 3,3 s, y con el piso reconstruido debajo: limpio cada vez (cámara en la mano, piloto como se lleva, cuerpo sin posar, linterna devuelta, imagen sin romper, ningún armario abierto).
- **La caída de la cámara:** en 45 salas y tres puntos de cada una, siempre en el suelo y cerca; «ve» en siete de cada diez o más; «boca abajo» en una de cada diez o menos.
- **La caída del cuerpo:** con sitio, tendido; de espaldas a una pared, doblado y dentro de la sala.
- **Armarios:** sin haberle visto entrar no hay finta; el registro desde delante de las puertas; las puertas abiertas sobre el cuerpo y cerradas al devolverse la etapa; la finta —apartada, quieta, con las puertas a la vista y la presencia apagada—; la rendija que no la mueve y la hoja que sí; quien sale mientras espera; quien aguanta. Apacible no finta y las demás cada vez más.
- **Salir sin ruido:** tres cuartos de la distancia; soltar a medias no saca a nadie; mantenida hasta el final sale callado; un toque sale como siempre.
- **La repetición:** la segunda vez de una entrada pierde la imagen al caer la cámara, otra entrada sigue siendo nueva, y los sobresaltos suaves.

Lo que se propuso y no está en la prueba: las 300 capturas por semilla en 10 semillas (son 135 en una); que la misma semilla dé lo mismo en dos máquinas (lo da por construcción —todo sale de la semilla y de la geometría fija—, pero no se compara); y de red, que los datos nuevos lleguen iguales y que un aviso repetido no mate dos veces (`tests/net/net_test.gd` pasa en sus cuatro escenarios con el protocolo nuevo, sin mirar eso en concreto).

### 18.2 Pruebas con gente

Ninguna hecha todavía.

- **Primera vez** (quien no ha visto el juego): ¿saltó? —lo apunta quien mira, no quien juega—. ¿Qué vio? ¿Sabe decir qué le mató y dónde quedó la cámara?
- **Repetición** (tercera y quinta muerte): ¿molesta? ¿Mira o aparta la vista? ¿Nota que no es igual?
- **A/B del desgarro:** la mitad con el aviso de la embestida en la imagen y la mitad sin él. El autor puede empezar por sí mismo, en el banco (19.2).
- **A oscuras:** con y sin piloto.
- **Auriculares, a volumen normal:** si el grito hace quitárselos.
- **De testigo:** si ver caer a otro da miedo o da información, y cuál de las dos cosas se quiere.
- **La finta:** si se entiende que se escapa esperando, y cuántas muertes cuesta aprenderlo.

No se da por acabado porque los estados funcionen: se da por acabado cuando alguien que no lo esperaba suelta el ratón.

## 19 · Lo que decidió el autor

El 12 de octubre de 2026, sobre las once preguntas con las que se cerró la propuesta.

1. **El piloto rojo de grabación:** sí. Que jugando se note sutilmente y que sea más activo sobre todo en el momento de la ejecución (9.3).
2. **El desgarro de la imagen durante la embestida:** hay que probarlo. **Sigue abierto, y ya se puede juzgar** de las dos maneras que pidió el autor. Jugando: `Banco de capturas.cmd`, la tecla `T` alterna A (sin desgarro) y B (con él) y `G` hace venir a la bestia. Mirando: `evidence/captura_frente_A_sin_desgarro.avi`, `…_frente_B_con_desgarro.avi` y las dos `…_espalda_…`, grabadas con su sonido (se regraban con `./tools/godot.ps1 bench-films`). Mientras tanto el juego va en A —sin desgarro ni bajada del ambiente en la embestida, el medio segundo limpio de 5.3—; para jugar una partida en B, `-- --windup-tear`. En B la imagen se limpia igualmente en `T0`. Lo que se ve al compararlas: de frente, la bestia se ve venir igual y el desgarro añade unas cuatro décimas de imagen rota antes de la cara; por la espalda no se ve venir: en A avisan su voz y, si hay una luz detrás, su sombra en la pared de delante; en B, además, la imagen rota.
3. **«Mira la lente»:** que mire sutilmente y se vaya de igual manera; puede funcionar mejor a solas que en equipo (7.4).
4. **La finta:** que se quede esperando un tiempo y que lo que finja sea su presencia, bajando ese sonido para que el jugador se confíe; que la manera real de escapar sea esperar un tiempo prudente; y que no sea obvio: solo algunas veces (13.3). **Salir del armario sin ruido:** manteniendo la tecla varios segundos, un 25 % menos de distancia de escucha (13.5). **Entrar y salir animados**, y que enlacen con la ejecución (13.6).
5. **La cámara que se queda en el suelo:** de los dos modelos que propuso el autor vale la Panasonic NV-A3 de Arthur Vanneste (CC-BY 4.0, descargable); la otra no se puede descargar ni tiene licencia. También la cinta VHS de Terizmeh (CC-BY 4.0), para más adelante. El autor los descargó ese mismo día y **están ya en el proyecto**, con las marcas de la cámara tapadas ([ASSETS.md](ASSETS.md)).
6. **Versión breve** en muertes repetidas y espera de 4 a 2 s: sí (14).
7. **La cinta que se rebobina:** le parece bien (14.4).
8. **Sonidos nuevos:** queda pendiente. Se trabaja con los sonidos que ya hay, y **no se generan sintéticamente gritos ni sonidos humanos** (11).
9. **El cuerpo:** la Exploradora por defecto, que es la que mejor esqueleto y malla tiene; la estética se analiza con ella y después se adaptan a eso los demás personajes con esqueleto (8.5).
10. **«Sobresaltos: completos / suaves»:** sí (14.3).
11. **Los 4,2 s de la bestia quieta:** se revisan después. Siguen como estaban.

No entra, porque es historia sin confirmar ([LORE.md](LORE.md)): quién recoge la cámara.

## Fuentes

Juegos:
- *Alien: Isolation*, cómo piensa el Alien: gamedeveloper.com/design/the-perfect-organism-the-ai-of-alien-isolation · lo que contó el equipo: mcvuk.com/development-news/18-things-we-learned-about-alien-isolation-last-night/ · la cola por la espalda, contada por quien la probó: gameinformer.com/b/news/archive/2014/06/11/oculus-powered-alien-isolation-stabbed-me-through-my-own-chest · la muerte ochenta: gamesbeat.com/why-alien-isolation-is-so-freaking-hard-and-why-this-may-deaden-its-scares-hands-on-preview/ · las noventa entradas de música: gamespot.com/articles/10-years-later-alien-isolation-still-benefits-from-one-vital-design-decision/1100-6528385/
- Thomas Grip (Frictional) sobre la muerte en el terror: frictionalgames.blogspot.com/2014/05/alien-isolation-and-two-hardest_5.html
- *Five Nights at Freddy's*, sustos (wikis de aficionados): freddy-fazbears-pizza.fandom.com/wiki/Jumpscares_(FNaF1) · technicalfnaf.fandom.com/wiki/Freddy_Fazbear_(Fnaf_1) · por qué se gastan: gamedeveloper.com/design/a-lack-of-fright-examining-jump-scare-horror-game-design
- Creadores sobre los sustos: pcgamer.com/what-horror-game-creators-think-about-jump-scares/
- *Content Warning*, la cámara rota: contentwarning.wiki.gg/wiki/Broken_Camera · *Phasmophobia*: phasmophobia.fandom.com/wiki/Death · *Lethal Company*, Bracken: lethal.miraheze.org/wiki/Bracken

El sobresalto:
- Latencia del reflejo: pmc.ncbi.nlm.nih.gov/articles/PMC5298047 · arranque y duración: jstage.jst.go.jp/article/jjppp1983/1/0/1_11/_article/-char/ja · a 60–70 dB: pubmed.ncbi.nlm.nih.gov/1946895
- Inhibición por prepulso: en.wikipedia.org/wiki/Prepulse_inhibition · wjgnet.com/2220-3206/full/v15/i8/107791.htm
- Oscuridad: doi.org/10.1016/S0006-3223(96)00466-0 · amenaza impredecible: pmc.ncbi.nlm.nih.gov/articles/PMC5507715
- Espacio defendido alrededor de la cara: pubmed.ncbi.nlm.nih.gov/23986256 · habituación: frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2014.01288/full
- Gritos y aspereza: pmc.ncbi.nlm.nih.gov/articles/PMC4562283 · sonidos no lineales en el cine: pmc.ncbi.nlm.nih.gov/articles/PMC3001365

Cine:
- El autobús de Lewton: nofilmschool.com/how-cat-people-created-the-first-jump-scare · *El exorcista III*: slashfilm.com/572812/exorcist-iii-jump-scare/ · *Insidious*: slashfilm.com/1338810/scariest-scene-ever-insidious
- *[REC]*: slashfilm.com/580380/rec-ending/ · *Cloverfield*: offscreen.com/view/cloverfield_apocalypse · *Blair Witch*, imagen y sonido separados: reverseshot.org/reviews/entry/2236/blair_witch

La videocámara:
- Panasonic PV-400 (1988), manual: archive.org/details/panasonic-omnimovie-vhs-camcorder-pv-400 · Canon E77 (1988), manual: archive.org/details/canon-e77-8mm-video-camcorder-user-manual-french_202603
- Control automático de ganancia del micrófono: videomaker.com/article/c4/14108-automatic-gain-control-aka-the-agc-conspiracy
- Fallos de cinta: avartifactatlas.com/artifacts/time_base_error.html · avartifactatlas.com/artifacts/head_switching_noise.html · avartifactatlas.com/artifacts/video_dropout.html

Comodidad:
- Destellos (WCAG 2.3.1): w3.org/WAI/WCAG22/Understanding/three-flashes-or-below-threshold.html
- Niveles de mezcla en juegos: audiogang.org/wp-content/uploads/2015/04/IESD-Mix-Ref-Levels-v03.02.pdf
