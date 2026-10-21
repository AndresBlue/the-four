# The Lurker

La bestia de **las oficinas secretas**, el piso 2. Qué es, cómo se comporta y cómo se llama lo decidió el autor el 21 de octubre de 2026 ([LORE.md](LORE.md)); este documento cuenta el modelo que se hizo ese día, sus animaciones y lo que falta para que exista en el juego. En los archivos es `lurker`.

**Está hecho el modelo, no la criatura:** hay un modelo 3D con esqueleto y ocho animaciones que Godot importa bien, y se ha mirado dentro del hotel. No hay escena de juego, ni IA, ni sonidos, ni nada que la haga aparecer en una partida.

## De dónde sale

De una imagen de terror analógico que aportó el autor (`art/lurker/referencia.webp`), que la da por de libre uso; su autoría no se conoce ([ASSETS.md](ASSETS.md)). Lo que se leyó en ella y se modeló:

- **La cara:** una calavera pálida y alargada, con cuencas enormes y negras, un ojo pequeño y blanco al fondo de cada una, la nariz como el agujero de un cráneo con el puente en una línea clara, las mejillas tensas en cordones verticales y la mandíbula desencajada en un óvalo largo de dientes como agujas. Hundida en una capucha de pelo negro.
- **El cuerpo:** pequeño y peludo, casi todo sombra.
- **Seis brazos y dos piernas**, como una araña: el par de arriba con manos enormes de dedos largos y en gancho; un par fino que sale de los omóplatos, con manos pequeñas; un par bajo bajo las costillas; y dos piernas largas cuyos pies también son manos.
- **Negra y mate del todo**, para que se pierda en las sombras.

## El modelo

Todo sale de un script, `tools/art/lurker/`, que se puede volver a ejecutar y da siempre el mismo resultado:

```
blender -b --factory-startup -P tools/art/lurker/make.py -- --blend art/lurker/lurker.blend --glb assets/enemies/lurker/lurker.glb
blender -b art/lurker/lurker.blend -P tools/art/lurker/scene.py -- --out <carpeta> --save
```

El primero hace el modelo, el esqueleto, las animaciones, el `.blend` y el GLB del juego; el segundo añade al `.blend` la escalera de la imagen con su cámara y su luz (`scene.py`, colección «Reference staircase»), deja la criatura en esa pose (acción `reference_pose`) y saca el render de comparación. Blender 5.2.

- **Cómo se esculpe** (`sdf.py`, `anatomy.py`): cada pieza es un campo de distancias (conos redondeados para huesos y dedos, elipsoides para el cráneo, uniones suaves para que un dedo nazca de la palma y no esté pegado, restas suaves para cuencas, boca y nariz, ruido para la piel) que se convierte en malla con *surface nets* y se diezma a un presupuesto de juego (`build.py`). Las manos llevan nudillos óseos, cordones en el dorso, eminencia del pulgar y pliegues en el dorso de cada articulación; la cara, surcos verticales en las mejillas.
- **Medidas:** de pie mediría algo más de 1,7 m; agazapada, la cabeza queda a menos de un metro del suelo. La cara mide 27 cm de la coronilla al mentón. Las manos grandes, unos 36 cm de la muñeca a la punta del dedo corazón; los dedos son largos sin ser gruesos.
- **Esqueleto:** 146 huesos (145 deforman; `root` no). Los ejes X de los huesos son los de doblar: cabeceo de columna y cabeza, cierre de los dedos, bisagra de la mandíbula (girar en +X la abre). Los ojos tienen hueso propio, para mirar.
- **Mallas:** dos. `lurker_body` (piel, cara, ojos, dientes y garras, una superficie por material) y `lurker_fur`, el pelo, aparte para poder quitarlo o aligerarlo (`--fur 0.5` genera la mitad).
- **Triángulos:** 165.441, de los que 73.000 son pelo; la piel, 67.559; la cara, 16.992. Godot genera LOD al importar. **No se ha medido lo que cuesta en una partida.**
- **Color:** el cuerpo, por vértice; la cara, una textura de 1024 px horneada texel a texel con el mismo sombreado (`bake_face` en `build.py`), porque por vértice no había resolución para el trazo de la imagen: los cordones claros y oscuros de las mejillas, el borde pálido de las cuencas.
- **Materiales:** piel y pelo negros (albedo 0,006 lineal), rugosidad 1 y **sin especular**: con especular, los bordes de las extremidades finas reflejaban la luz de las paredes y la criatura se veía marrón. Ojos húmedos (rugosidad 0,18), dientes y garras oscuros.

## Las animaciones

Se resuelven fotograma a fotograma: cada una es una función del tiempo que dice dónde va el cuerpo, cómo se doblan columna y cabeza, dónde apoya cada mano y cada pie y cuánto se cierran los dedos; un solver de dos huesos coloca codos y rodillas y todo se escribe como rotaciones de hueso, una clave por fotograma (`animate.py`). El GLB lleva solo rotaciones: no necesita ninguna restricción en Godot.

Todas son **en el sitio**: el juego mueve el cuerpo. 30 fps.

| Nombre | Dura | Bucle | Qué es |
|---|---|---|---|
| `idle` | 4 s | sí | Acecho agazapado: respira, gira la cabeza despacio y la ladea de más, con dos tirones; un brazo fino en el aire moviendo los dedos y una mano grande tamborileando en el suelo. |
| `crawl` | 1 s | sí | Reptar como una araña, cuatro apoyos y cuatro en el aire, alternando. El cuerpo avanza a **1 m/s**. |
| `crawl_fast` | 0,5 s | sí | Escabullirse: más baja y más rápida, **2,6 m/s**. |
| `vent_crawl` | 1,4 s | sí | Por un ducto de medio metro: plana, codos a los lados y nunca arriba, el par fino apretado contra el techo del ducto. **0,55 m/s**. |
| `retreat` | 0,6 s | sí | Huir hacia atrás sin dejar de mirar, **1,5 m/s**. |
| `loom` | 3 s | sí | La pose de la imagen, sostenida: respira, ladea la cabeza, las manos tiemblan. |
| `scare` | 2 s | no | El susto: de agachada a la pose de la imagen en medio segundo. Se recoge, se alza, lanza los brazos, el cuello se adelanta y la mandíbula se desencaja, y tiembla. La cara no deja de mirar a quien tiene delante. |
| `peek` | 4 s | no | Asomarse por una esquina a su izquierda: la cabeza sale muy ladeada, una mano grande se cierra sobre el canto, mira, y desaparece de golpe. |

`SPEEDS` en `animate.py` tiene las velocidades. La importación de Godot marca como bucle las seis que lo son (`lurker.glb.import`).

## En Godot

- `assets/enemies/lurker/lurker.glb` y su importación. Godot dejaba sin activar el color por vértice justo en la piel y el pelo (salían **blancos**) e ignora el especular del GLB, así que la importación sustituye tres materiales por los de la carpeta: `lurker_skin.tres`, `lurker_fur.tres` (a doble cara) y `lurker_face.tres` (con la textura que Godot extrae, `lurker_lurker_face.png`), los tres mates.
- `tools/capture/lurker_materials_probe.gd` dice cómo se importó cada material y qué animaciones van en bucle.
- `tools/capture/lurker_capture.gd` la pone **dentro del hotel solo para mirarla**: la planta 81, un pasillo iluminado, la espalda contra la pared, la pose de la imagen, la cámara baja y cerca como en la foto; un plano con la luz del pasillo y otro con la linterna, cada uno en crudo y como se juega (`evidence/lurker/`). `--clip=` y `--at=` eligen otra animación y otro instante.

```
godot --path . --rendering-method forward_plus --script res://tools/capture/lurker_capture.gd -- --automation --test-profile --no-enemy --silent
```

## Comparada con la imagen

En `art/lurker/renders/`: `comparacion_escalera.jpg` (la escalera rehecha en Blender, con el etalonado de `grade.py`: sepia, grano y viñeta), `comparacion_hotel_linterna.jpg` y `comparacion_hotel_luz_del_pasillo.jpg` (dentro del hotel, como se juega), los primeros planos de la cara y las manos, y `animaciones.png`.

Cómo se llegó: más de una docena de vueltas de comparar y corregir, primero en la escalera y luego en el hotel. Lo que cambió por mirar la imagen al lado: ojos más pequeños y hundidos en cuencas negras; boca en forma de huevo, que se estrecha hacia el mentón; mandíbula más estrecha; nada de cejas ni pómulos abultados; manos grandes un 30 % mayores sin engordar los dedos; brazos de arriba en V, gruesos y peludos junto al cuerpo; pelo fino en vez de púas, como una capucha y no como una cúpula; la cara más clara para que en la luz tenue del hotel siga siendo el punto pálido de la imagen; y la textura de la cara para su trazo. Y dos fallos de verdad: el material marrón por el especular, y los dedos del lado derecho, que al abrirse se cruzaban (la rotación en Z va al revés en los huesos reflejados).

Lo que sigue siendo distinto: la imagen es una pintura y esto es un modelo, con la cara más limpia que el trazo a mano; en el hotel no hay escaleras ni pasillos de un metro, así que allí la pose se ve en suelo plano y contra una sola pared.

## Lo que falta

- **Que exista en el juego:** su escena, su IA de acecho (fuera de la vista, por el rabillo del ojo, entre las sombras), el susto por la espalda, los ductos de ventilación de las oficinas, las alucinaciones visuales y auditivas, y sus sonidos. Todo está por diseñar y es del piso 2, que no ha empezado (`four-7ly.2`).
- **Medir su coste** en una partida y decidir si el pelo se aligera o se quita en las calidades bajas.
- **Por decidir:** si los ojos devuelven la luz de la linterna (como los de un animal) para delatarla en la oscuridad o si se queda del todo en la sombra.
