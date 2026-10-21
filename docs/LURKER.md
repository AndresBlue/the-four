# The Lurker

La bestia de **las oficinas secretas**, el piso 2. Qué es, cómo se comporta y cómo se llama lo decidió el autor el 21 de octubre de 2026 ([LORE.md](LORE.md)); este documento cuenta el modelo, sus animaciones, la oscuridad que lleva encima y cómo trepa, y lo que falta para que exista en el juego. En los archivos es `lurker`.

**Está hecha la criatura que se ve, no la que juega:** un modelo con esqueleto y ocho animaciones, una escena de Godot que la planta en paredes y techos y la envuelve en oscuridad, y capturas dentro del hotel. Nada la hace aparecer en una partida: no hay IA, ni quien la mueva, ni sonidos.

## De dónde sale

De una imagen de terror analógico que aportó el autor (`art/lurker/referencia.webp`), que la da por de libre uso; su autoría no se conoce ([ASSETS.md](ASSETS.md)). El primer modelo la leyó como un humanoide de seis brazos y dos piernas, con pelo; **el autor lo corrigió el mismo día** y es lo que hay ahora:

- **No es humanoide.** Un cuerpo de araña, sin tronco: una masa delantera de la que salen los brazos, una cintura y un bulbo detrás. **No tiene piernas.**
- **Ocho brazos, todos de la misma forma y de cuatro tamaños**, de delante atrás: el par de las manos enormes de la imagen, uno pequeño, uno mediano y otro algo menor. Cinco dedos largos en cada mano y **garras grandes** en gancho.
- **Liso, como The Locust, sin pelo.** El pelo hacía de ella un monstruo corriente.
- **Negro de verdad, sin luz ninguna**: el cuerpo no recibe iluminación (`lurker_body.tres`, sin sombreado). Lo que queda a la vista es la cara.
- **El cuerpo es una zona sin forma que se mezcla con la oscuridad.** Sin pelo se veía escuálido; lo que el pelo intentaba lo hace ahora una niebla negra que lo envuelve y apaga lo que tiene cerca (abajo).
- **Púas grandes como injertos**: cinco en el lomo y el abdomen y una en el codo de cada brazo grande, con el cuello hinchado donde entran en la carne.
- **La cara:** una calavera pálida con cuencas enormes y negras, la nariz como el agujero de un cráneo, las mejillas tensas en cordones verticales y **la mandíbula en triángulo, con el mentón en punta**: la boca es una V larga de dientes como agujas, ancha bajo la nariz y estrecha hacia el mentón (ovalada cambiaba la emoción). Los ojos **solo tienen pupila**, grande y negra sobre el blanco, sin iris.

## El modelo

Todo sale de los scripts de `tools/art/lurker/`, que se pueden volver a ejecutar y dan siempre el mismo resultado (Blender 5.2):

```
blender -b --factory-startup -P tools/art/lurker/make.py -- --blend art/lurker/lurker.blend --glb assets/enemies/lurker/lurker.glb
blender -b art/lurker/lurker.blend -P tools/art/lurker/scene.py -- --out <carpeta> --save
```

El primero hace el modelo, el esqueleto, las animaciones, el `.blend` y el GLB del juego; el segundo añade al `.blend` la escalera de la imagen con su cámara, su luz y una niebla negra como la del juego (colección «Reference staircase»), deja la criatura en esa pose (acción `reference_pose`) y saca el render de comparación. `preview.py`, `poses.py` y `beauty.py` sacan vistas de estudio, las poses de cada animación y primeros planos; `grade.py` les da el aspecto de la foto y `compare.py` pone una captura del juego al lado de la imagen.

- **Cómo se esculpe** (`sdf.py`, `anatomy.py`): cada pieza es un campo de distancias (conos redondeados para huesos y dedos, elipsoides para el cráneo y el cuerpo, prismas triangulares para el mentón y la boca, uniones suaves para que un dedo nazca de la palma y no esté pegado, restas suaves para cuencas, boca y nariz, ruido para la piel) que se convierte en malla con *surface nets* y se diezma a un presupuesto de juego (`build.py`). Las manos llevan nudillos óseos, cordones en el dorso y pliegues en cada articulación; el cuerpo, bultos bajo la piel para que no tenga una forma limpia.
- **Medidas:** el cuerpo mide unos 55 cm de largo y anda a 20 o 30 cm del suelo; la cara, 27 cm de la coronilla al mentón. Un brazo grande alcanza 84 cm del hombro a la muñeca, y su mano, unos 36 cm más; los pequeños, el 62 %.
- **Esqueleto:** 160 huesos (159 deforman; `root` no): cuerpo, abdomen, cuello, cabeza, mandíbula, ojos y, por brazo, clavícula, brazo, antebrazo, mano y quince falanges. Los ejes X son los de doblar: cabeceo de la cabeza, cierre de los dedos, bisagra de la mandíbula (girar en +X la abre).
- **Una malla**, `lurker_body`, con una superficie por material: cara, cuerpo, ojos, dientes y garras (las púas van con las garras).
- **Triángulos:** 91.149; la cara, unos 17.000. Godot genera LOD al importar. **No se ha medido lo que cuesta en una partida.**
- **Color:** la cara, una textura de 1024 px horneada texel a texel (`bake_face` en `build.py`), porque por vértice no había resolución para el trazo de la imagen; el resto, por vértice.

## Las animaciones

Se resuelven fotograma a fotograma: cada una es una función del tiempo que dice dónde va el cuerpo, cómo se doblan el cuello y la cabeza, dónde apoya cada mano y cuánto se cierran los dedos; un solver de dos huesos coloca los codos y todo se escribe como rotaciones de hueso, una clave por fotograma (`animate.py`). El GLB lleva solo rotaciones: no necesita ninguna restricción en Godot. Son **en el sitio** (el juego mueve el cuerpo), a 30 fps, y las de andar caminan con dos juegos de cuatro manos que se turnan.

| Nombre | Dura | Bucle | Qué es |
|---|---|---|---|
| `idle` | 4 s | sí | Acecho agazapado: respira, gira la cabeza despacio y la ladea de más, con dos tirones; un brazo pequeño en el aire moviendo los dedos y una mano grande tamborileando. |
| `crawl` | 1 s | sí | Reptar como una araña. El cuerpo avanza a **1 m/s**. |
| `crawl_fast` | 0,5 s | sí | Escabullirse: más baja y más rápida, **2,6 m/s**. |
| `vent_crawl` | 1,4 s | sí | Por un ducto de medio metro: plana, codos a los lados y nunca arriba, el par pequeño apretado contra el techo del ducto. **0,55 m/s**. |
| `retreat` | 0,6 s | sí | Huir hacia atrás sin dejar de mirar, **1,5 m/s**. |
| `loom` | 3 s | sí | La pose de la imagen: erguida, las manos grandes arriba en V, las pequeñas junto a la cabeza, el abdomen plegado detrás; respira, ladea la cabeza, las manos tiemblan. |
| `scare` | 2 s | no | El susto: de agachada a la pose de la imagen en medio segundo, con la mandíbula desencajándose y temblando. La cara no deja de mirar a quien tiene delante. |
| `peek` | 4 s | no | Asomarse por una esquina a su izquierda: la cabeza sale muy ladeada, una mano grande se cierra sobre el canto, mira, y desaparece de golpe. |

`SPEEDS` en `animate.py` tiene las velocidades. La importación de Godot marca como bucle las seis que lo son.

## En Godot

`game/enemies/lurker/lurker.tscn` es la criatura que se ve. Quien la mueva solo tiene que poner su transformación: su +Y es la superficie a la que se agarra (el suelo, una pared, el techo) y su +Z hacia dónde va. Es solo presentación, como `locust_visual.gd`: no tiene colisión ni cambia lo que nadie percibe.

- **Trepa como una araña** (`lurker_limbs.gd`, un `SkeletonModifier3D` que corre después del reproductor de animaciones, así que el clip sigue moviendo cuerpo, cabeza y mandíbula). Cada mano se queda **plantada en el mundo** y solo se mueve en un paso, como los pies de The Locust; pero busca su apoyo con once rayos en abanico alrededor de su hombro, de debajo del cuerpo a encima de él, y se queda con el que cae más cerca del 82 % de su alcance. Así, en un pasillo las manos toman la pared y el techo en cuanto los tienen a mano, igual que el suelo. Da el paso cuando el brazo se estira de más o cuando hay un apoyo mucho mejor; las ocho se turnan en dos juegos de cuatro. Codos levantados, la palma plana sobre lo que agarra y los dedos clavados, que se cierran mientras la mano viaja. Emite `footfall` en cada apoyo, para los pasos que suenen.
- **La oscuridad** (`lurker_darkness.gdshader`): una niebla negra que se integra a lo largo de cada rayo de vista dentro de una esfera, cortada por lo primero que el rayo toca, con bultos que se mueven para que el contorno no se asiente nunca y un hueco donde está la cara. Dos capas: una densa de 62 cm alrededor del cuerpo y otra tenue de 2,1 m que apaga lo que hay detrás en un par de metros, para que la criatura parezca tragarse la luz. Al principio esa segunda capa era una luz negativa: los filtros de la cámara se rompían con los valores negativos que dejaba, en motas de colores.
- **Capa de render 3**, propia de la criatura (la 2 es el cuerpo del jugador; de la 5 a la 20, las habitaciones en la calidad más baja).
- La importación sustituye dos materiales por los de la carpeta: `lurker_body.tres` (negro, sin sombreado) y `lurker_face.tres` (la textura de la cara, mate). Godot dejaba sin color por vértice algunos materiales y no lee el especular del GLB.
- `tools/capture/lurker_materials_probe.gd` dice cómo se importó cada material y qué animaciones van en bucle.
- `tools/capture/lurker_capture.gd` la pone **dentro del hotel solo para mirarla**, en un pasillo iluminado de la planta 81: la pose de la imagen contra una pared, con la luz del pasillo y con la linterna, en crudo y como se juega; y con `--walk` (y `--fixed-fps 30`) la hace cruzar el suelo, subir la pared del pasillo y recorrer el techo con una cámara que la sigue, fotograma a fotograma. `--no-dark` quita la oscuridad para ver los brazos.

```
godot --path . --rendering-method forward_plus --script res://tools/capture/lurker_capture.gd -- --automation --test-profile --no-enemy --silent
godot --path . --rendering-method forward_plus --fixed-fps 30 --script res://tools/capture/lurker_capture.gd -- --automation --test-profile --no-enemy --silent --walk
```

## Comparada con la imagen

En `art/lurker/renders/`: `comparacion_escalera.jpg` (la escalera rehecha en Blender, con el etalonado de `grade.py`), `comparacion_hotel_linterna.jpg` y `comparacion_hotel_luz_del_pasillo.jpg` (dentro del hotel, como se juega), `trepa_pared_y_techo.gif` (la caminata, con la oscuridad), los primeros planos de la cara y las manos, y `animaciones.png`.

Cómo se llegó, en dos rondas. La primera, más de una docena de vueltas de comparar y corregir en la escalera y en el hotel (ojos hundidos, mandíbula, manos grandes sin dedos gordos, brazos de arriba en V, la cara clara para la luz tenue del hotel, su textura). Dos fallos de verdad salieron de ahí: el material marrón por el especular, y los dedos del lado derecho, que al abrirse se cruzaban (la rotación en Z va al revés en los huesos reflejados). La segunda, el rediseño del autor: fuera piernas, pelo y tronco, cuerpo de araña, mandíbula en triángulo, pupilas, púas, garras y la oscuridad. En la pose de la imagen el abdomen se pliega hacia atrás, porque colgando bajo la cabeza volvía a parecer un tronco.

Lo que sigue siendo distinto: la imagen es una pintura y esto es un modelo, con la cara más limpia que el trazo a mano y los brazos más finos que los manchones de la pintura; en el hotel no hay escaleras ni pasillos de un metro, así que allí la pose se ve en suelo plano y contra una sola pared.

## Lo que falta

- **Que exista en el juego:** quien la mueva (una IA que la lleve por suelos, paredes y techos, fuera de la vista y por el rabillo del ojo), el susto por la espalda, los ductos de ventilación de las oficinas, las alucinaciones visuales y auditivas, y sus sonidos (`footfall` ya está). Todo es del piso 2, que no ha empezado (`four-7ly.2`).
- **Medir su coste** en una partida: la niebla hace siete muestras de ruido por píxel que cubre, y las manos lanzan unos 22 rayos por fotograma.
- **La calidad más baja:** allí las lámparas solo alumbran la capa de su habitación, y la criatura está en la suya; su cara no recibiría la luz de la sala.
- **Por decidir:** si los ojos devuelven la luz de la linterna (como los de un animal) para delatarla en la oscuridad o si se queda del todo en la sombra.
