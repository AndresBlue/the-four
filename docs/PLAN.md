# The Four — Plan de trabajo

**Lo que falta, en el orden en que hay que hacerlo.** Nada de lo ya hecho vive
aquí: el juego que existe se describe en [el diseño](GAME_DESIGN.md), cómo está
montado en [la guía de desarrollo](DEVELOPMENT.md), y el registro de cómo se
llegó hasta aquí —con todo lo comprobado, medido y fechado— quedó en
[history/PLAN_2026-09-21.md](history/PLAN_2026-09-21.md).

Estado: juego **0.5**, generador de mapas **v3**, protocolo de red
**the-four-net-3**, Godot 4.7.2. Cada casilla es trabajo por hacer; se marca
cuando está **comprobado**, no cuando está escrito. Lo que se comprueba con
`./tools/verify.ps1` y las demás herramientas está en la guía de desarrollo.

## Dónde estamos (21 de septiembre de 2026)

Hay un piso jugable de principio a fin, solo o acompañado: hotel procedural de
tres alas y tres etapas, The Locust con su IA y su versus, supervivencia,
cordura, ascensores, cuatro presets gráficos y un ejecutable de Windows de 432
MB que funciona. Se ha jugado con gente real, en LAN y por Internet.

Los **cinco fallos** que dejó la última partida están arreglados y medidos: la
cámara que acababa en negro, la linterna que se perdía al revivir, las lámparas
que seguían brillando con la corriente cortada, la luz que cruzaba las paredes y
la linterna que rayaba las texturas en Compatibilidad. Lo que hicieron y cómo se
comprobó está en la guía de desarrollo y en [REALISM.md](REALISM.md).

Y con ellos lo que **nadie entendía jugando**: el aviso de auriculares antes de
la cinta, volver donde estabas después de una caída, el corte entre alas y la
hoja compartida rehecha con las notas colgando de ella.

Lo que sigue sin estar bien, que es de donde sale el orden de abajo:

- Lo que debía arreglar que las partidas duraran cinco minutos en vez de
  treinta ya está puesto y medido, pero **nadie lo ha vuelto a jugar**.
- Solo existe **un piso de los cuatro**: Sunman, The Boiled One y Guilt no
  están.

## El orden

**Primero se deja fino lo que ya se puede tocar, y solo después se añade nada.**
Dentro de eso: lo que rompe una partida antes que lo que molesta y lo que no se
entiende antes que lo que no se ve —de esos dos ya no queda ninguno—; lo que
solo se decide jugando antes que lo que se puede pulir a solas; y la deuda
técnica antes de que crezca. El acabado
—sonido, materiales, mobiliario— va después, porque afina algo que ya funciona.
Los otros tres pisos van al final: son el doble de juego, y montarlos sobre un
piso que todavía falla es multiplicar los fallos por cuatro.

---

## 1 · Lo que solo se decide jugando

No es trabajo de código: es tuyo, y sin ello no se cierra el Early Access. Las
herramientas para mirarlo están en la guía de desarrollo.

### Las partidas que cierran la etapa

- [ ] **Partidas con amigos en individual, cooperativo y versus**, midiendo
  duración, encuentros con la criatura y si se entienden las etapas. Es la
  única forma de saber si el problema de origen —partidas de 5 a 8 minutos
  frente a la meta de 25–40— está resuelto de verdad. Incluye los veinte
  recorridos y las cinco partidas de exploración que P1 dejó pendientes: no los
  sustituye el lote automático.
- [ ] **El ritmo de las tres alas:** cuánto se tarda en cada una, si se entiende
  que la puerta se abrió, y si la criatura llega demasiado pronto o demasiado
  tarde al ala nueva ahora que cruza andando (13,9–50,6 s medidos, mediana 26).
- [ ] **El bloque de etapas entero:** si el apagón asusta o solo estorba, si el
  reinicio de etapa perdona demasiado, y si el camino marcado en la lectura de
  la criatura le da demasiada ventaja.
- [ ] **Si el piso se siente un hotel explorable** o un laberinto arbitrario, y
  si hay que ajustar tamaño y referencias. Lo medido dice que la numeración ya
  no lleva a ninguna parte y que ir pegado a la pared no encuentra ningún
  refugio; lo que no dice es cómo se siente.
- [ ] **Si se entiende quién murió y por qué** en cooperativo, ahora que no hay
  avisos de texto.

### Lo que hay que oír

- [ ] **Los gruñidos:** nivel y frecuencia, sobre todo los del propio cazador
  (se oyen 6 dB más bajos para quien lleva la criatura).
- [ ] **Las distancias con auriculares:** si 10, 20 y 40 m se distinguen de
  verdad, si las puertas lejanas se siguen leyendo con la absorción nueva, y si
  la dirección de la criatura se acierta en esquinas y con dos puertas.
- [ ] **La ejecución:** el grito (¿asusta o solo molesta?), los 4,2 s, y si la
  estática se entiende como «te mataron» sin leer nada.
- [ ] **Los pasos grabados y el zumbido de fondo**, en partida y no en una
  prueba.
- [ ] **Escucha crítica del reparto de buses y del aura**, con los eventos
  ambientales de los salones.

### Lo que hay que mirar

- [ ] **Cómo se ven las animaciones de los supervivientes** ahora que van por
  pies plantados e IK.
- [ ] **La vista de la criatura:** término base, separación de los frentes,
  legibilidad en salones grandes (ver [VISION_LOCUST.md](VISION_LOCUST.md)) y
  el peso de cada tipo de ruido en la imagen, con `./tools/godot.ps1 rehearsal`.
- [ ] **La oscuridad nueva:** sin luz ambiente, los rincones en sombra de las
  salas iluminadas también son negros. Si resulta excesivo, no conviene subir
  `ambient_light_energy` (aclara también las salas apagadas): mejor dar relleno
  propio a las salas iluminadas.
- [ ] **El armario:** comodidad del efecto de asomarse en partidas humanas y a
  distintas resoluciones.
- [ ] **La escena de entrada:** ritmo y cámara.
- [ ] **Las puertas nuevas** a mano: escala del modelo, número en el panel
  superior, rendija de 1,2 cm, y las del dormitorio y la portada, que usan la
  misma hoja.
- [ ] **Los presets en partida**, que las capturas fijas no enseñan: TAA de
  Medio en movimiento, penumbras de Ultra, eco de Bajo, halo de Ultra, sombras
  con el filtro más barato en Baja y Media andando, y salas que aparezcan tarde
  al girar en un vano.

### Números que salen del diseño y no de jugar

- [ ] **La cordura:** dos minutos de armario, dos y medio a oscuras, cuatro de
  luz para recuperarse, y la frecuencia de las alucinaciones. Decidir además si
  el aura (`dread_aura.gd`) debe mentir con la cordura baja, como las
  alucinaciones sueltas.
- [ ] **La criatura:** balance de su alerta, de su agresividad y de la
  propagación del ruido, en partidas humanas.
- [ ] **Rendimiento en un PC modesto:** medir `tools/benchmarks/run_bench.ps1`
  en uno de los de las pruebas con amigos, en Forward+ y en Compatibilidad, y
  anotarlo en [PERFORMANCE.md](PERFORMANCE.md).

## 2 · Deuda técnica

Nada de esto se ve jugando, y todo cuesta caro más adelante.

- [ ] **La cordura y el «quemado» los calcula cada máquina y el anfitrión se los
  cree.** El estado quemado viaja como un bit de banderas del cliente
  (`match_net.pack_local()`). Todo lo demás de las etapas lo juzga el anfitrión
  —el código de la cerradura a propósito—; esto no, así que un cliente
  modificado no se quema nunca y la criatura no lo huele. Decidir si se acepta
  (la oscuridad se mide en la cámara local, y moverlo al anfitrión no es
  gratis) o se comprueba desde fuera.
- [ ] **El piso de respaldo no pasa por la garantía de la pared.** Si las veinte
  tentativas fallan, `map_generator.generate()` devuelve el piso fijo 404, que
  solo pasa el validador: ni mano en la pared ni recorrido mínimo. En mil
  semillas no se usa nunca, pero si se usara, el contrato grande del mapa se
  caería sin avisar.
- [ ] **`hotel_main.gd` pasa de 2.200 líneas.** Cordura, ascensores, etapas,
  apagón, documentos, observación, alucinaciones y red en un archivo. Sale
  barato partir cordura y ascensores en los suyos.
- [ ] **El tercer ascensor no tiene viaje.** Los dos primeros hacen su segundo y
  medio a oscuras; el último termina el piso en el acto (`ride_lifts()`).
- [ ] **El recorte de blend shapes va enganchado a mano en cada `.import`.** Si
  se reemplaza o reimporta un modelo se pierde el enganche en silencio y el
  paquete vuelve a engordar 50 MB sin que nada se ponga rojo.
- [ ] **Pruebas que no corre nadie:** `tests/legacy/walkthrough_test.gd`,
  `audio_test.gd` y `h1_test.gd` no están en `verify.ps1`. O se corren o se
  archivan como registro histórico.
- [ ] **Comprobaciones de red que fallan de vez en cuando** («Una puerta cambia
  a petición de un invitado»; en el versus, «Los ruidos de los supervivientes
  le llegan como contactos», que depende de un único ruido lanzado un segundo
  después del gruñido): no llegan a tiempo y al repetir el escenario pasan
  enteras. Hay que darles arranque con reintento en vez de un
  plazo fijo, para no acostumbrarse a repetir la verificación.
- [ ] **La vista de la criatura solo está validada en Forward+.** En
  Compatibilidad no la ha mirado nadie, y es el renderizador de las máquinas
  modestas, donde ya apareció el fallo de la linterna.

## 3 · Acabado de lo que ya existe

Afina algo que funciona: va después de que funcione bien.

- [ ] **Sonido del hotel:** fuentes espaciales fijas, acústica por recinto,
  pasos, conductos, tuberías y silencio contextual.
- [ ] **Los cinco audios aportados:** escucha y selección definitiva, edición de
  las copias y procedencia documentada.
- [ ] **Materiales PBR terminados**, reflejos y composición de las escenas de
  referencia; efectos de conductos y variedad artística.
- [ ] **Texturas fotográficas CC0** seleccionadas e importadas con su licencia
  registrada, y revisión visual de la legibilidad en las zonas oscuras.
- [ ] **Sustituir el mobiliario provisional** por assets adecuados y
  acreditados, poco a poco.
- [ ] **Accesibilidad, mezcla y rendimiento sostenido** en la escena más
  exigente.

## 4 · Assets que faltan (tuyos)

- [ ] **El sonido propio del ascensor**: motor y hojas. Hoy solo se oye la
  puerta que ya existía.
- [ ] **Arte para las motas** de la cordura quemada: hoy son partículas
  aditivas.
- [ ] **Un detective masculino con esqueleto.** El de ahora es un OBJ sin
  huesos: se queda con su movimiento viejo hasta que se reemplace, y la mano
  que se apoya en el suelo al agacharse llega al suelo pero no reparte el peso.

## 5 · Lo nuevo: los otros tres pisos

No empieza hasta que lo de arriba esté cerrado.

- [ ] **Sunman** en atrios y galerías: cobertura y barridos anunciados.
- [ ] **The Boiled One** en habitaciones y salones con pantallas, con su
  exposición comprobada.
- [ ] **Guilt** con señales contrastables; nunca falsifica la hoja ni la
  interfaz esencial.
- [ ] **Perfiles sonoros propios** para las tres.
- [ ] **Tres conjuntos procedurales más**, con mil semillas validadas cada uno.
- [ ] **La campaña de cuatro pisos:** checkpoints entre ellos, reaparición de
  los caídos y victoria final.
- [ ] **Campañas completas de dos y cuatro jugadores sin bloqueos.**

## 6 · Consolidación y cierre

- [ ] **Los nueve eventos** de las otras criaturas.
- [ ] **Los doce descubrimientos restantes**, registro de partidas y códigos
  compatibles, sin progresión de poder.
- [ ] **Balance del director** (frecuencia y distancia de los eventos) y
  revisión de los textos de los documentos.
- [ ] **Desafíos opcionales** sin condiciones ocultas de derrota.
- [ ] **Balance con datos locales:** objetivo 60 FPS a 1080p y perfiles
  reducidos que se sostengan.
- [ ] **Permisos** de criaturas, modelos y canción, créditos, y exportaciones
  sin editor.
