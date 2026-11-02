# El rediseño del piso 2: nota de diseño

Nota del director, 25 de octubre de 2026, versión 2 (corregida con tres críticos: factibilidad y The Lurker, fidelidad a las referencias, proceso y assets). Es la base de los encargos del rediseño visual y ambiental de las oficinas. La guía visual obligatoria son las quince imágenes de `docs/referencias/` (una por sala) y las tres referencias generales descritas en `docs/referencias/oficinas/LEEME.md`. Lo que aquí no se diga sigue como en `docs/OFICINAS.md`.

## 0. El encargo y lo que decidió el autor

**Sus palabras (mandan):** reconstruir arquitectura, materiales, luz, mobiliario, equipamiento, proporciones y atmósfera siguiendo las referencias como base directa; oficina corporativa tecnológica de finales de los 80 y principios de los 90 con el realismo de la foto analógica (colores apagados, fluorescente cálido, texturas gastadas, imperfecciones); nada moderno, ni efectos de cine, ni terror evidente; coherencia estricta entre salas (alturas de techo, revestimientos, pavimentos, marcos, luz y criterios constructivos comunes); cada sala conserva su función y lo que la caracteriza con mejor geometría, detalle, proporciones y composición; un único piso continuo sin escaleras visibles ni cambios de nivel; un edificio corporativo real, no salas sueltas; atmósfera cotidiana, silenciosa, ligeramente opresiva y sutilmente inquietante; un rediseño integral.

**Decisiones del autor (25 de octubre de 2026, por el chat):**

| # | Pregunta | Decisión |
|---|---|---|
| R1 | «Un único piso continuo» | Se quedan las tres plantas unidas por el montacargas. Dentro de cada planta, un solo nivel |
| R2 | Pasillos y salones | Pasillos de 3 a 3,6 m (algún carril de 2,4) y naves abiertas de varios módulos con pasillo central amplio |
| R3 | Columnas | Exentas en las naves, en hilera a los lados del pasillo central; The Lurker las rodea |
| R4 | Ventanas | Solo interiores |
| R5 | Franjas de color | Se quitan: rótulos de época y un friso de madera igual en todos los pasillos |
| R6 | Sketchfab | Con la sesión del autor ya abierta en su Chrome (sin escribir contraseñas) |
| R7 | Cuota | Esta tarea para al 60 % semanal, con la nota de relevo escrita |
| R8 | Exportación | Una sola, al final |
| R9 | Puertas | Se quedan en 2,65 m bajo el falso techo a 2,95 m |
| R10 | Abandono | A medias (papeles, sillas caídas, cajones abiertos, cables, placas caídas), sin terror evidente |

**Lo que decide el director:**
- Fluorescente cálido (manda lo último del autor sobre la luz fría de OFICINAS 8).
- La sala de juntas baja a 2,95 m con pantallas fluorescentes (sin globos). Se acepta que `lurker_capture` deje de tratarla como sala alta.
- Regla de los 2,2 m intacta. Excepciones: las columnas, y lo pegado a la pared a menos de 0,2 m (tubos de la central neumática, conducciones del cuarto eléctrico, rótulos). Nada cuelga del techo a más de 0,2 m de una pared: **no hay cables colgando de los huecos del techo** (se cruzan con sus salidas); los cables del abandono van por el suelo y las mesas.
- **La moqueta acústica de Dirección se queda** (planta 3, salas 5, 16, 24, por el sonido de OFICINAS), pero se ve como en las referencias: una alfombra grande (persa en dirección y secretaría, lisa en juntas) que cubre casi toda la sala, con un borde de suelo duro pulido a la vista. **Las naves de la planta 1 llevan moqueta de verdad, con su sonido** (ruido 20/52 m en vez de 25/64, pasos de ella amortiguados): se mira en el lote de bots de 3f y en `lurker_fairness`.
- Las columnas no proyectan sombra (con una luz por celda dibujarían estrellas); se revisa en las capturas.

## 1. Qué está mal hoy

- Materiales planos (`PLAIN`, `STAND_INS` en `office_geometry.gd`): colores lisos y materiales del hotel; cartón de terciopelo.
- Paredes casi blancas, franja de color, y paredes desnudas (el `MODULE_SET` de oficinas no casa con `room_dressing.SETS`).
- Troffers a 4.100 K con lente cálida; **techo negro** en las capturas: luz ambiente 0, SDFGI apagado y rebote solo en pantalla.
- Salas vacías: solo escritorio metálico y silla escolar; las esquinas `desk`, `filing`, `copier`, `reader`, `sorter`, `vending`, `armchair` y `chairs` no se construyen.
- Pasillos de 2,4 a 3 m y salones de hasta tres módulos.
- Nada distingue un departamento de otro.

## 2. El edificio: un mismo lenguaje constructivo

- **Techo:** placas de 60 × 60 crema envejecido (variación: algunas más amarillas, cercos de agua más abajo, alguna fisurada), perfilería blanco roto, a 2,95 m. Difusores cuadrados de impulsión y rejillas de retorno, detectores de humo, rociadores donde ya hay.
- **Luminarias por familia** (repetición con variación): pantalla empotrada 60 × 120 prismática (general); estrecha 30 × 120 con rejilla (recepción, juntas); parabólica de cuatro tubos (secretaría); de superficie envolvente (dirección); regleta de tubos desnudos (cuarto eléctrico, climatización); empotrada 60 × 60 (archivo, sobre los pasillos, en las posiciones de hoy).
- **Paredes:** revestimiento vinílico con textura fina en greige cálido (entre `b5a993` y `bfb39c`), nunca blanco, algo más sucio abajo y junto a los marcos. Reprografía: mampara desmontable pintada con juntas verticales cada 1,2 m. Bloque de hormigón pintado crema en lo técnico. Azulejo en aseos.
- **Friso** (pasillos, vestíbulos, recepción): dos tonos (taupe abajo hasta 1,0 m, greige arriba) con moldura de nogal de 6 cm.
- **Zócalo alto de nogal** (1,0 a 1,1 m) que **da la vuelta a toda la sala** en despacho, juntas y seguridad, y en una pared de secretaría.
- **Rodapié** de goma marrón casi negra de 10 cm en todo el edificio.
- **Dos maderas:** nogal oscuro (marcos, paneles, zócalos, mobiliario de dirección) y roble o teca color miel (hojas de puerta, casilleros, armarios de cocina, paneles del montacargas).
- **Acero verde gris institucional** (el color que une el edificio): cuadro eléctrico, climatizadora, lector de fichas, mesa de seguridad, archivadores de correo y ventanilla (verde menta grisáceo), puertas de servicio.
- **Suelos, dos familias:** terrazo oscuro sal y pimienta pulido (pasillos, vestíbulos 10 y 19, correo, archivo) y vinilo claro beige con dibujo menudo pulido (recepción, despacho, descanso, aseos, seguridad, juntas de la planta 1, ventanilla, reprografía, climatización). Más la moqueta (naves, Dirección bajo su alfombra), baldosa con relieve (cuarto eléctrico) y hormigón sellado (almacén, depósito, pasillo de servicio). Todos con brillo de cera.
- **Umbrales:** cambio de suelo con perfil metálico en cada vano; marco de nogal en todos.
- **Puertas** (2,65 m): marco de nogal (jambas de 9 cm con 2 cm de resalte), hoja de roble color miel con pomo o manilla de latón gastado, algunas con ventanuco estrecho. Servicio y etapa: acero verde gris con barra antipánico. Placa de número negra junto al marco.
- **Cristaleras** (solo interiores): marco de nogal, antepecho a 0,95 m sobre zócalo de madera o pared pintada según la sala, persiana veneciana beige a medio bajar; vidrio claro algo sucio (despachos, dirección, secretaría, ventanilla), armado solo en seguridad.
- **Columnas:** 60 × 60, yeso crema, rodapié de goma, remate oscuro de 8 cm bajo el techo; en algunas un pulsador de alarma, un reloj o un extintor.
- **Rótulos** (R5): placas negras de letras claras. La de zona conserva lo de hoy: una por celda de pasillo, en su primer tramo de 3 m o más, a 1,6 m, texto de `zone_label()` (en la planta 2, el código del cuadro), con un cuadradito de `stripe_color()`; se lee con la linterna. Carteles de normas de OFICINAS 9.
- **Mobiliario de pasillo, con repetición regular** (como un edificio, no sorteado): pulsador de alarma, señal de salida, armario de manguera, termostato, interruptores y enchufes, directorio de letras blancas sobre fieltro, plano de evacuación, extintor, fuente de pared, banco, papelera de acero, planta, láminas, reloj.
- **Nada moderno, saturado o de cine.** Sin sangre ni pintadas más allá de lo que ya existe.

## 3. Arquitectura

### 3.1 Plantas y niveles
Tres plantas a 0, −6 y −12 m unidas por el montacargas; ningún desnivel. Las salas técnicas de 4,4 m se quedan.

### 3.2 Pasillos
`LANE_WIDTHS` de la paleta de oficinas pasa a `[3.0, 3.0, 3.2, 3.2, 3.4, 3.6, 2.4]` (el sorteo es uniforme: repetir da el peso). El número de salas no depende de los carriles. Nada en el generador del hotel.

### 3.3 Naves
- En la planta 1 (`laying == 0`), `office_generator.gd` **sobrescribe `make_halls`** (como hace con `place_specials` y `furnish`) para formar naves de la oficina abierta (1) y los cubículos (2): **bloques de 2 × 2 o 2 × 3 módulos**, y también en línea o en L (hasta 5 módulos de 9 m o menos, por `open_runs`). La primera nave se reserva antes que los demás salones; nunca se lleva la única sala de juntas posible (módulo de 10 m o más).
- **Pasillo central y columnas solo en las naves de dos celdas de ancho:** el pasillo de 3 m va sobre la junta entre las dos filas; las columnas, en las juntas entre módulos a lo largo del eje, a 2,1 m de la línea del pasillo (separación de 8 a 12 m). Las naves en línea o en L van sin columnas.
- `room.nave_axis` en el manifiesto (lo necesita `lay_lattice`).
- En las plantas 2 y 3, los salones de tipo 1 y 2 que salgan de `HALL_MIX` son salones normales, sin columnas.
- El generador del hotel no cambia; `make_halls` del hotel no se toca.

### 3.4 Columnas
- `room.columns`: lista de `{x, z}` **locales a la celda**, repetida en cada celda que la columna toca; lado `OFFICE.COLUMN = 0.6`.
- Se colocan contra las zonas de `LAYOUT.blocked` (más 0,3 m), nunca en el tramo en planta de cada salida de techo a su centro de sala, a 1,3 m de muebles y barridos de puerta, a 0,9 m o más del centro de una lámpara.
- Detrás de una bandera de paleta `COLUMNS := false`, que solo enciende el área de The Lurker cuando ella sabe rodearlas.
- Colisión de 0 a 2,95 m en la capa de colisionadores estáticos (máscara 1): la vista de ella, la de los jugadores y la malla las tienen en cuenta solas. El techo se recorta alrededor.
- `validate_physics`: la banda de techo resta el rectángulo de cada columna con margen (`LAYOUT.rect_minus`, como el conducto principal). `physics_checks` de `office_test` prueba semillas con nave.

### 3.5 Alturas
Falso techo a 2,95 en todas las salas que lo tienen (juntas también). Puertas de 2,65. Losa a 4,4.

### 3.6 Cristaleras y vecindad
- `GLAZED_TYPES` suma seguridad (21) hacia pasillo o galería (lo que `glazable` y `glazed_ok` ya admiten).
- Reglas de vecindad (las que el generador pueda cumplir sin piso de respaldo): secretaría junto a un despacho de dirección con puerta entre los dos; ventanilla y despachos acristalados hacia pasillo.
- Un porcentaje fijo de puertas abiertas en las salas con luz, para que haya vistas a salas vecinas encendidas.

## 4. Luz

- **Fluorescente cálido, calibrado a través del filtro de cinta**, no en crudo: se ajusta el color de las luces midiendo pared, techo y suelo en la captura contra la referencia. Dos familias: ámbar (recepción, cuarto eléctrico, descanso) y neutra (dirección, juntas). Los pasillos, un poco más fríos (unos 3.500 K) que las salas (unos 3.000 K): a través de una cristalera se ve el contraste.
- **Luz difusa y de poco contraste:** varias pantallas que se solapan, caída suave a los rincones, paredes con degradado parejo. Nada de conos ni halos de foco.
- **El techo nunca más oscuro que la pared en una sala con luz, en todos los preajustes.** Mecanismo, a elegir en el área de luz con una prueba corta: (a) una `ReflectionProbe` interior por sala con ambiente de color constante, o (b) un halo emisivo en las placas junto a cada pantalla encendida. Sea cual sea, sigue la luz de la sala (0 apagada, con el drenaje y el parpadeo) y no toca `hotel_environment.tres`.
- **El reflejo de las pantallas en el suelo** (11 de 15 referencias): con SSR en Alto; en los demás preajustes, sondas de reflejo en naves y pasillos o brillo en el material, también siguiendo la luz.
- **Luces de acento** (flexos, focos de carril, apliques, la expendedora): un **registro propio por sala** (`office_accents.gd`), con `drain`, `set_room_power`, visibilidad y parpadeo sobrescritos en `office_geometry.gd`, y en `lurker_senses.lamp_points()` si ella las bebe. Flexos y focos como `SpotLight3D` con sombra (un hueco del atlas), dentro de la ronda de `practicals` y apagados más allá de `furniture_lamps`; apliques por `sconce_light()` y `SCONCES_LIT`. Como mucho tres por sala. En Bajo, Muy bajo y Compatibilidad, apagadas: solo su emisión. Emisivas sin luz: pantallas de los lectores de microfichas, lámparas de la central neumática, luz bajo los armarios de cocina.
- Emergencias, montacargas y baliza roja como hoy. `light_layers_scan` gana un modo de oficinas.

## 5. Mobiliario y equipamiento

### 5.1 Kit
- **Ya horneados en el proyecto (coste cero):** `potted_plant_02/04`, `cardboard_box_01`, `clipboard`, `stationery_supplies`, `office_notepads`, `wall_clock`, `WetFloorSign_01`, `metal_trash_can`, `steel_frame_shelves_01`, `book_encyclopedia_set_01`, `jug_01`, `GreenChair_01`, `ArmChair_01`, `metal_office_desk`, `SchoolChair_01`, `fire_alarm`.
- **Solo con modelo** (descarga; CC0, luego CC BY; nunca NC, ND ni SA): sillas de oficina con ruedas, sillón de dirección capitoneado, silla de confianza, butaca verde de recepción, sofá y butaca de terciopelo, silla apilable cromada, plantas (costilla de Adán, ficus, poto, drácena, pachira), teléfono, máquina de escribir, expendedora, fuente de garrafa, flexos (banquero, brazo), lámpara de pie, cafetera, microondas antiguo, nevera, globo, caballo de bronce, extintor, foco de obra, escalera de tijera. Fuentes: Poly Haven (sin cuenta), Sketchfab con la sesión del autor (los 44 de `source_assets/oficinas/RESUMEN.md` y lo que falte). Triángulos: pequeño < 5 k, grande < 20 k; lo que pase se diezma con Blender (como `tools/art/lurker`) o se descarta.
- **Hecho en código** (con biseles, tiradores, etiquetas, texturas reales; malla horneada una vez y en caché): mesas (nogal con cajoneras, en L de laminado claro con canto redondeado, de acero verde gris), aparadores, librerías y estanterías de madera hasta 2,2 m, estanterías de archivo con cajas y archivadores, archivadores de 2 y 4 cajones, fichero, archivo móvil, taquillas (ya), bancos de listones, casilleros, mostradores, mesa de clasificar, mamparas (1,2 y 1,5 m), muebles de cocina, mesas de comedor, pizarra con ruedas, pantalla enrollable, retroproyector, carro de lona «CORREO», carrito de dos baldas, fotocopiadora, impresora matricial, torre, CRT de reserva, monitores de vigilancia, teclado, calculadora, bandejas, archivadores de anillas, carpetas, cajas con etiqueta, libros (atlas de lomos), cabinas de aseo, lavabos, espejos, cuadro de llaves, armero, directorio, reloj cuadrado, persiana, cortina, rótulos, láminas, alfombras.
- **Imágenes** (láminas, plano de ciudad, alfombra persa): Art Institute of Chicago (CC0), por `ingest_dressing.py`.
- **Cada tipo de pieza tiene su pieza en código de reserva**: el área de mobiliario no espera a las descargas.

### 5.2 Quién decide qué
- **El generador** pone en `room.furniture` lo que ocupa suelo (choca, tapa, lo esquivan bots y ella): tabla `FURNITURE` con medidas, altura y colisión de cada pieza nueva; `furniture_ok` por sala; `DESKS_MOST`; recetas en `office_recipes.gd` con su propio stream de azar (no mueve los ductos). Presupuesto de tiempo del generador: recetas y columnas, unos 390 ms de mediana por piso sobre la base de 1b+2, cifra medida en 4b y aceptada por el director (la mediana total, unos 1.855 ms en reposo, sigue bajo los 2.000 ms del autor; si no cabe, se le pregunta).
- **La geometría** elige el modelo y pone lo menudo (`office_clutter.gd`), con `vary()` por sala, sin colisión, sin cuerpos con física, respetando una **función de huecos reservados por sala**: estaciones, lector, cuadro, minuteros, taquillas, salidas de ducto y rejillas, placas de salida de ella, `poster_spots`, barridos de puertas y la línea de la cámara a la mecanógrafa de la ventanilla (la foto de la ficha).

## 6. Cada sala según su referencia

Encuadre de la captura: cámara a 1,5 m en el vano de la puerta, 55° de campo horizontal, mirando a la pared característica (no siempre a la esquina más honda); se ve el canto de la puerta. Cada receta lista de 5 a 8 elementos característicos que deben verse.

1. **Recepción** (0): vinilo claro pulido; mostrador recto con retorno, frente de nogal sobre zócalo negro rehundido, encimera negra, luz bajo el labio; sillón negro, flexo negro, teléfono, bandejas, poto; detrás archivador y carpetas. Focos en un nicho rehundido enmarcado en nogal sobre el mostrador. Pilastras en la pared. Felpudo oscuro. Fila de butacas verdes con mesita y revistas. El ascensor de llegada (puertas de acero, indicador) con marco de nogal y dos apliques. Lámina de ciudad, papelera de acero, plantas. Por un vano se ve una oficina con luz. *Lista:* mostrador, butacas verdes, ascensor con apliques, focos en nicho, plantas, felpudo.
2. **Ventanilla** (17): desde el pasillo, cristalera de mostrador con montante superior, marco de nogal, repisa de nogal que sobresale a los dos lados, pared pintada debajo, rótulo «PERSONAL» pegado encima; dentro, pared del fondo en paneles de madera con el mapa «RED DE TUBOS», mesa con la máquina de escribir, archivadores verde menta, tablón con papeles, estantes con carpetas. En el pasillo, un directorio de letras blancas, un sujetapapeles colgado, papelera, poto. Sin persiana.
3. **Correo** (14): terrazo oscuro; casilleros de roble altos en dos paredes con paquetes encima (hasta 2,2 m); mostrador central de casilleros; carros de lona «CORREO»; carrito metálico; cestas de alambre; archivadores verde gris; reloj; puerta con ventanuco; la central del correo neumático sobre una pilastra (panel verde gris con lámparas numeradas, tubos de vidrio y latón que suben pegados a la pared, «CORREO NEUMÁTICO»); mesa de clasificar con paquetes.
4. **Archivo** (6) y **archivo móvil** (13): terrazo oscuro pulido; filas de estanterías metálicas grises de 2,1 m con cajas beige etiquetadas y archivadores negros, número en el extremo; pantallas empotradas sobre los pasillos; carros con cajas en la espina; mesa de consulta junto a la puerta; puerta de madera al fondo iluminada con cartel; una sola fuga por la espina.
5. **Reprografía y microfichas** (7): mampara desmontable pintada; fotocopiadora beige grande; carrito con resmas; lectores de microfichas encendidos sobre mesas con sillas; fichero de muchos cajones; estantería de madera con cajas; mesa central grande con papel, bandeja de alambre, portalápices, cajas debajo; carteles «REPROGRAFÍA» (FOTOCOPIAS, PLANOS, MICROFICHAS, ENCUADERNACIÓN) y «USO LECTOR DE MICROFICHAS» con cuatro pasos; tablón; papelera.
6. **Despacho** (3): zócalo de nogal alrededor; mesa de nogal, sillón capitoneado, dos sillas de confianza, archivador gris de 4 cajones, perchero con abrigo, aparador con libros y planta, lámina grande y cuatro diplomas, flexo de latón, teléfono, bandeja; cristalera al pasillo con persiana.
7. **Despacho de dirección** (16): paneles de nogal; librerías empotradas hasta 2,2 m a los lados de un gran plano de ciudad; mesa grande de nogal, sillón de cuero, dos sillas de confianza, flexo de banquero, teléfono negro; credencia baja con globo y foto; rincón con sofá y butaca de terciopelo, mesa baja con cenicero y libros; lámpara de pie; planta alta; alfombra persa grande; cristalera interior con persiana, cortinas y una credencia delante.
8. **Secretaría** (24): puerta doble abierta a dirección con su placa «DIRECCIÓN»; mesa en L de nogal con placa «SECRETARÍA», teléfono negro, flexo de latón; impresora en carrito metálico; archivadores beige; casillero con papeles; tablón; reloj cuadrado de madera; láminas; sillas de espera con mesita y periódicos; alfombra persa; planta; paneles de nogal en una pared.
9. **Sala de juntas** (5): zócalo de nogal alrededor; dos filas de pantallas estrechas y rejilla de retorno; mesa larga de nogal con sillones de cuero de brazos de madera, papeles, jarra y vasos, cenicero, retroproyector; pantalla enrollable sobre el zócalo; pizarra con ruedas; aparador con termo y tazas; plano enmarcado; láminas; planta. Alfombra lisa en la planta 3.
10. **Sala de descanso** (15): expendedora encendida; fuente de garrafa; tablón; cocina de roble con fregadero, cafetera, microondas, armarios altos (hasta 2,2) con luz debajo; nevera blanca; mesas de laminado con cuatro sillas; servilleteros, ceniceros, tazas, periódico; reloj; lámina; planta.
11. **Aseos y vestuario** (4): vestuario pintado con las taquillas (escondites), banco de listones, perchero de pared con toalla y abrigo, papelera, cartel «MANTENGA EL ORDEN Y LA LIMPIEZA»; en un extremo, la zona húmeda alicatada entera hasta el techo con franja de azulejo oscuro abajo, dos lavabos con espejo y aplique, cabinas (hasta 2,2 m).
12. **Puesto de seguridad** (21): zócalo de nogal; mesa larga de acero verde gris con cuatro monitores negros sobre tarima, teclado de control, grabadores, teléfono beige, flexo verde, libro de registro; archivadores de acero; armero gris oscuro alto, abierto y vacío; cuadro de llaves; tablón con listas; reloj; cristalera de vidrio armado al pasillo.
13. **Cuarto eléctrico** (18): bloque crema; baldosa con relieve; el cuadro como fila de armarios verde gris con placas de zona, medidores y palancas, la roja «MONTACARGAS» aparte, placa general «TABLERO ELÉCTRICO»; colector horizontal de conductos sobre los armarios y conducciones al techo pegadas a la pared; caja «ALIMENTACIÓN PRINCIPAL» con tres medidores; cajas auxiliares; aplique de jaula; mesa con teléfono, flexo y registros; silla; estantería con cajas.
14. **Sala de climatización** (22, 23): vinilo claro pulido y pared en dos tonos de pintura; conductos galvanizados a la vista; climatizadora verde gris con manómetros y «CLIMATIZADORA AH-1»; la compuerta con volante rojo, «DUCTO PRINCIPAL AIRE DE IMPULSIÓN» y «COMPUERTA DUCTO PRINCIPAL»; tuberías; cuadros de control; rejilla de pared; mesa metálica con papeles y taburete.
15. **Vestíbulo y salida del montacargas** (19, 10): terrazo oscuro; la cabina con reja de tijera y marco de acero; pulsadores; el lector de fichas verde gris sin marca con «1. INSERTE FICHA 2. ESPERE SEÑAL 3. RETIRE FICHA»; «USO EXCLUSIVO DE PERSONAL»; tablón; archivador; planta en maceta de acero cilíndrica; paneles de roble en una pared; cristalera de oficina sobre panel de madera a la vista si hay sala al lado.

Sin referencia propia: 16. **Nave de oficina abierta** (1: moqueta, columnas, puestos de escritorios en L y rectos con cajoneras, sillas con ruedas, CRT, teléfono, bandejas, carpetas, mamparas bajas, archivadores bajos, fuente de agua, plantas junto a las columnas, lámpara de pie, impresora matricial). 17. **Nave de cubículos** (2: mamparas de 1,5 m en calles). 18. **Almacén y depósito** (8, 25: estanterías metálicas, cajas, carros, escalera, foco de obra). 19. **Pasillos** (11: sección 2). 20. **Pasillos de servicio** (12: como hoy, bloque y conductos).

## 7. El abandono (R10)

- Dice «se fueron de golpe», no ruina. Gradiente por planta (la 1, recién dejada; la 3, la peor).
- Sillas apartadas o caídas, cajones abiertos, carpetas abiertas, cajas volcadas, un teléfono descolgado, un folio en la máquina de escribir, tazas, abrigos en las perchas, cables por el suelo y las mesas, placas caídas (ya están).
- Papeles en montones con causa (junto a una silla caída, un rastro hacia el montacargas), nunca repartidos por igual; los pasillos casi limpios, para que se vea el reflejo.
- Como mucho un detalle raro por sala (una silla mirando a la pared).
- Ningún papel a menos de 2 m de la ruta ventanilla, estación y lector (la ficha caída no se confunde).

## 8. Lo que no cambia y dónde se puede escribir

- **El hotel, ni un byte:** `manifest_golden_test`, `creature_contract_test`, galería normalizada, `room_light_test`, `light_layers_scan`, `palette_scan_test`. Ningún `.tres` compartido se toca.
- **Se puede escribir en:** `game/floors/palettes/office_palette.gd`, `game/world/generation/office_generator.gd`, `office_layout.gd`, `office_validator.gd`, `game/world/office/*` (y archivos nuevos: `office_finishes.gd`, `office_accents.gd`, `office_recipes.gd`, `office_clutter.gd`, piezas), `game/presentation/materials/office/*`, `game/floors/objectives/*` (aspecto de los equipos), `game/enemies/lurker/lurker_shell.gd`, `lurker_routes.gd`, `lurker_motion.gd`, `lurker_capture.gd`, `lurker_senses.gd`, `duct_graph.gd`, `game/ui/hotel_ui.gd` (CREDITS), `tests/office/*`, `tools/props/*`, `tools/textures/*`, `tools/capture/*`, `tools/benchmarks/*`, `tools/dev/*`, `assets/props/office/*`, `assets/textures/<sets nuevos>`, documentos. En `hotel_geometry.gd`, solo ganchos que por defecto hacen lo de hoy.
- Las tareas de las tres plantas y su función; las reglas de construcción; la cáscara, los canales, los ductos, el plénum y las placas de ella.
- Las persianas que no existen (ventanilla) y la cristalera de seguridad no entran en `panes` (la sombra tras la persiana).

## 9. The Lurker sobre la nueva geometría

- **Una bandeja por sala, como hoy.** Las columnas están en las juntas entre módulos de la nave, es decir, en los lados abiertos entre bandejas: cada lado abierto guarda sus **tramos bloqueados**. `advance_tray` los trata como pared; `tray_legs` sujeta el cruce dentro del hueco con margen (0,3 m más su radio) y pone puntos de paso antes y después de la junta; `clear_point` recibe las columnas como discos (la maquinaria de las lámparas); `free_tiles` excluye las placas a menos de 0,6 m de una columna (cubre huecos, salidas de techo, `add_plenum`, `room_tiles`, `emerge_point`); `leap` rechaza un salto que pase junto a una columna; `cue_pose` rechaza un punto de detrás tapado por una columna. Las aristas rectas del plénum ignoran las columnas (van por encima del techo).
- **Juntas:** se quita la rama `pendant` de `lamps_in` a la vez que los globos de la geometría; `LAMPS_12` y la mutación de altura de `office_test`, y `lurker_shell_test`, al día.
- **Pruebas:** `lurker_shell_test` (avances al azar en una nave, piernas, `clear_point`, `cue_pose`), `lurker_route_probe` («nunca dentro de una columna» en cada fotograma; la semilla 7 con nave), `lurker_fixture` con una nave, `body_clip_probe` (captura junto a una columna), `lurker_elbow_probe` (caso con columna), `lurker_tiles_test`, `lurker_fairness_test`.
- Más muebles con colisión: los codos ya los esquivan; lo menudo va sin colisión.

## 10. Rendimiento

- 60 FPS a 1080p en Alto. **Antes de tocar nada:** `hotel_benchmark.gd` gana `--floor=2 --seed=7` y se saca la línea base del piso 2 (frame time en vistas fijas, en Alto, Muy bajo y Compatibilidad, y tiempo de montaje del piso).
- Todo modelo por `place()` (un MultiMesh por sala y malla); lo pequeño sin sombra y oculto más allá de 16 m (`SMALL_REACH`); piezas en código horneadas una vez; pocos materiales (colores por instancia); sombra solo en muebles grandes de suelo; nada que se mueva junto a una lámpara.
- Topes: una luz de techo por celda (como hoy), tres acentos por sala, 150 k triángulos visibles por sala; en Compatibilidad, acentos apagados (8 luces por objeto, 32 visibles). Tope al tiempo de montaje del piso (la malla de navegación con más colisionadores tarda más).

## 11. Capturas junto a su referencia y criterio de aceptación

- `tools/capture/office_rooms_capture.gd` (con ventana; reutiliza lo de `office_capture.gd`): para cada sala con referencia, una sala de ese tipo con luz, el encuadre de la sección 6, y la captura **al lado de su referencia** en una imagen (`evidence/rediseno/<sala>.png`); también con el campo del juego, en Muy bajo, y las vistas de edificio (un recorrido de pasillo con tres salas a la vista; las vistas por vano o cristalera de seguridad, secretaría y montacargas).
- **Criterio del director** para dar una sala por buena: (a) reducidas a 64 px y difuminadas, las dos imágenes tienen la misma estructura de claros y oscuros; (b) muestras de pared, techo y suelo dentro de un margen de luminancia y tono de la referencia, techo nunca más oscuro que la pared; (c) se ven sus 5 a 8 elementos característicos; (d) reflejo de las pantallas en el suelo en Alto; (e) nada blanco puro fuera de las lámparas; (f) en Muy bajo no cae al negro. La herramienta escribe (a) y (b) como cifras.

## 12. Áreas, orden y cuota

| Orden | Área | Qué | Aceptación |
|---|---|---|---|
| 0 | Herramientas y líneas base | `office_rooms_capture.gd` con sus cifras; banco del piso 2 y línea base; herramientas de assets (Python): `ingest_models.py` con `--set=office`/`--only`, origen `source_assets/oficinas/<grupo>/<slug>/`, destino `assets/props/office/<id>/`, `info.json` desde `registro.json`, bloque `OFFICE_MODELS` en ASSETS.md, `KHR_materials_pbrSpecularGlossiness`; `build_catalogue.gd` con origen y destino por argumento y tabla de escala y giro; `ingest_pbr.py` con `--only`, `oficinas/materiales/` y cgbookcase; herramienta de `asset_hashes.json`; guion de Blender para diezmar; `recoger_descarga.py` sin vigilar `assets/`; `light_layers_scan` con oficinas | Capturas «antes» junto a sus referencias; cifras base de rendimiento; un modelo de prueba ingerido en `assets/props/office/` sin tocar `assets/props/hotel/` |
| A (fondo) | Descargas | Poly Haven, ambientCG, Art Institute of Chicago, Sketchfab cuando Chrome esté conectado (un agente a la vez). Solo a `source_assets/`; la ingesta en `assets/` la hace el director entre frentes, con `--import` | Registro con licencia y hash de cada pieza |
| 3a | Kit constructivo | Materiales (`materials/office/`, las claves `PLAIN` buscadas allí), suelos, paredes, friso, zócalos, rodapié, maderas, acero, puertas, marcos, cristaleras, techo con variación, umbrales, rótulos en lugar de franjas | Capturas de pasillo, recepción y una sala de cada familia; el hotel idéntico |
| 3b | Luz | Calibración cálida, familias de luminaria, relleno del techo, reflejo del suelo, acentos con su registro, preajustes | Criterios (a), (b), (d), (f) en cinco salas; `light_layers_scan` de oficinas |
| 1a | Pasillos y juntas | `LANE_WIDTHS`, juntas a 2,95 con troffers (con `lamps_in` en la misma unidad), seguridad acristalada | `office_test` en verde (con `office_bots_test` nombrado aparte); `office_metrics -- 100` sin contar el p99, que ya falla |
| 1b+2 | Naves, columnas y The Lurker | `make_halls` de oficinas, columnas en manifiesto, validador, geometría, la cáscara y sus pruebas; `COLUMNS` encendida al final | Pruebas de la sección 9; captura de una nave |
| 4a | Piezas en código | Archivos nuevos de piezas, con caché | Hoja de piezas |
| 4b | Recetas | `FURNITURE`, `furniture_ok`, recetas de las 20 salas, vecindad, puertas abiertas | `office_test`, `office_walk_test`, `office_bots_test` |
| 4c | Modelos, lo menudo, mobiliario de pasillo y abandono | Mapa de modelos con reserva en código, huecos reservados, `office_clutter.gd` | Las 15 capturas con sus criterios |
| 5 | Equipos | Ventanilla, central neumática, estaciones, lector y montacargas, cuadro, seguridad, climatizadora y compuerta | Sus capturas; `office_walk_test`, `office_coop` |
| 6 | Cierre | Ajuste final, rendimiento contra la base, capturas finales, documentos, exportación | `verify.ps1` en verde; capturas; documentos; `exports/TheFour.zip` con `Probar piso 2.bat` |

- Frentes en serie (todos ejecutan Godot). Los `encargos` del área siguiente corren durante el frente actual si no se cruzan los archivos. Las descargas, en cualquier momento.
- **Cuota:** quedan unos 46 puntos (del 14 al 60 %). Se lee el uso en cada frontera de flujo, y tras 1a se recalibra. Si no da, se corta primero el abandono de 4c y después la mitad del área 5.
- **Contexto del director:** al acercarse al 60 %, nota de relevo y sesión nueva.

## 13. Riesgos

- El hotel: todo va por la paleta de oficinas, `office_generator.gd` y ganchos con el comportamiento de hoy.
- Las columnas: si los tramos bloqueados complican sus rutas más de lo previsto, se quedan solo en las naves de 2 × 3 o se apaga `COLUMNS`.
- El tiempo del generador (2.523 a 2.568 ms con la máquina ocupada contra 2.750 de tope): recetas y columnas tienen 150 ms.
- El rendimiento: más modelos y luces; se mide contra la base.
- Las descargas de Sketchfab: zip glTF, comprobar al recibir, reintentar una vez; texturas a 2k.
