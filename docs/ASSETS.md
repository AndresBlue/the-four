# Assets y créditos

Procedencia, licencias y permisos pendientes de todo lo que entra en el juego. Mientras queden permisos sin resolver, no se distribuye.

**Para el piso 2** los agentes pueden buscar y descargar assets por su cuenta (autorizado por el autor el 22 de octubre de 2026): CC0 o dominio público primero, luego CC BY con su crédito, luego licencias libres de regalías con uso comercial; **nunca NC, ND ni SA**. Cada uno entra con su fuente, autor, licencia y enlace en este documento. El criterio y la lista de lo que hace falta están en [OFICINAS.md](OFICINAS.md) (sección 12).

## Hotel actual

- **GodotSteam 4.22.1** (GDExtension, `addons/godotsteam/`): © 2015-actualidad GP Garcia, Chris Ridenour y colaboradores, licencia MIT (`addons/godotsteam/license.md`). Descargado el 25/09/2026 de la [Asset Library de Godot (ficha 2445)](https://godotengine.org/asset-library/asset/2445), que remite al [repositorio en Codeberg](https://codeberg.org/godotsteam/godotsteam); zip de 32.104.325 bytes, SHA-256 `aa31d7208c651f80ef1fccf1be96a4e476c1abf0fb018dd72d9db7bc2929971d`. Solo se conservan los binarios de Windows 64 bits, sin el actualizador del editor. Incluye `steam_api64.dll` de Valve (Steamworks SDK 1.65), redistribuible con el juego según el acuerdo del Steamworks SDK.
- Cartel de salida del refugio: lámina, luminaria y grabado originales. Las letras y la flecha las dibuja `tools/textures/make_exit_sign.py` como contornos propios en `assets/props/exit_sign/engraving.png`; no se usa ni se embarca ningún archivo de fuente. Los carteles de los pasillos (`way_ahead`, `way_left`, `way_right`, `way_back.png`, la figura que sale corriendo por una puerta y su flecha) los dibuja el mismo script, también con formas propias.
- **El impreso del hotel** (`assets/nota-hotel.png`): diseño del autor (21/10/2026), el papel de los documentos que son del propio hotel. `assets/textures/nota-hotel-lejos.png` sale de él (`tools/textures/bake_hotel_note.py`). Lo escrito a máquina es la Courier New que trae el sistema (Windows y Mac): no se embarca ningún archivo de fuente; en la textura de lejos va ya dibujado.
- **La carta, la libreta y la hoja mapa** (`assets/carta.png`, `assets/libreta.png`, `assets/papel-mapa.png`): del autor (22/10/2026), el papel de la carta sin enviar, del registro del vigilante y de las indicaciones, y de la hoja de otro. `assets/textures/carta-lejos.png` y `libreta-lejos.png` salen de ellas (`tools/textures/bake_hotel_note.py`), y también `carta-trozo.png`, el trozo de la carta rota que asoma de los muebles.
- **La tarjeta de «No molestar»** (`assets/textures/no-molestar.png` y su dorso, `no-molestar-reverso.png`): original, de `tools/textures/bake_do_not_disturb.py`, con el crema y el granate del impreso y su logotipo recortado de `assets/nota-hotel.png`. La letra es la Georgia del sistema al hornearla; no se embarca ningún archivo de fuente.
- Arquitectura modular, veinte definiciones espaciales y mobiliario provisional: geometría original creada para este proyecto. No se atribuye a Sketchfab.
- Materiales: shaders procedurales propios (motivo del papel, medallones de la moqueta, desgaste y suciedad) sobre materiales escaneados CC0, listados abajo en «Materiales escaneados». Las cortinas siguen siendo solo procedurales.
- Pasos de la criatura: síntesis original en ejecución, sin muestras externas. La señal de preparación de ataque ya no se sintetiza: es un trozo corto de la grabación de gruñidos aportada. Los golpes de puerta y el objeto que cae (`tools/audio/generate_event_sfx.py`) son síntesis propia y determinista; la ejecución entera, en cambio, son grabaciones de Freesound, abajo. Polvo, cortinas, niebla localizada y sondas de reflexión creados dentro de Godot. No se añadieron muebles externos.
- Copia utilizada: `assets/audio/hotel/ambience.wav`, idéntica al original `ambience.wav` de la raíz. SHA-256: `7f873c02a389c4da33befb3da559d613a98aa4cc051f91c805a7782c4d72adb1`.
- Ambiente: 410,46 s, estéreo, 11.025 Hz, PCM de 8 bits. Se reproduce en bucle y a volumen reducido; el original no se modifica. Autoría/licencia pendientes de verificar.
- Los otros cuatro audios nuevos quedan conservados para la selección de la etapa 2. Detalles técnicos en `hotel_audio_inventory.json`. La voz tiene un nivel notablemente mayor que el ambiente y requiere edición/mezcla antes de incorporarla.
- `deep_ambiance.flac`: conservar original; preparar copia en formato admitido por el importador al integrarlo. Todavía no se carga en el juego.
- La música anterior sigue en su bus separado. Su estado de permisos no cambia.

## Aportado por el usuario, con su ficha (revisado el 19/09/2026)

Assets que el usuario descargó e incorporó al juego. Cada ficha se abrió y se anotó tal cual la publica su autor. **Los que piden atribución, y los que tienen la licencia por resolver, se acreditan en la pantalla de créditos del juego** (`game/ui/hotel_ui.gd`, `CREDITS`); lo que es CC0 o de dominio público consta solo en este registro (desde el 19/10/2026).

### Personajes jugables (`assets/players/`)

| Carpeta | Modelo | Autoría | Licencia | Ficha |
|---|---|---|---|---|
| `detective` | detective | haider706 | CC Attribution 4.0 | [Sketchfab](https://sketchfab.com/3d-models/detective-b1de47c043314837a844698f2380daad) |
| `detective_woman` | Debra — Detective Woman (Game Model) | Zukomazi | CC Attribution 4.0 | [Sketchfab](https://sketchfab.com/3d-models/debra-detective-woman-game-model-208e5cf748404521894bf30c95f25c12) |
| `realistic_female` | Realistic Female | Biviyt | **CC Attribution-ShareAlike 4.0** | [Sketchfab](https://sketchfab.com/3d-models/realistic-female-b0cc2a6c26114da184252e433cf75d23) |

**El esqueleto del detective** no venía con el modelo: es el del autorrigger de Mixamo (Adobe), hecho el 18 de octubre de 2026 con la cuenta del autor a partir de `detective/model.obj`, y es `detective/model.fbx` (mallas, UV, esqueleto de 65 huesos y pesos; los materiales y texturas siguen siendo los del OBJ). La licencia del modelo, CC BY 4.0, permite modificarlo.

**Cómo se mueven los tres: clips de Mixamo** (Adobe), descargados ese mismo día con la cuenta del autor para el esqueleto del detective, en el sitio, a 30 FPS y sin malla. Mixamo permite usar sus personajes y animaciones en proyectos propios, comerciales o no, juegos incluidos, sin pagar derechos; lo que no permite es redistribuir los archivos tal cual, como animaciones sueltas. Por eso los FBX están en `models/mixamo/`, fuera de git y del juego, y lo que va en el juego es lo que `tools/avatars/bake_survivor_clips.gd` hace con ellos sobre cada esqueleto (`<carpeta>/clips.res`). Los que usa: Breathing Idle, Male Standard Walk, Male Hurried Walk, Running Forward Quickly, Male Walk Backwards, Backwards Running, Strafe Walking y Running Strafe (izquierda y derecha; los de correr, desde el 18 de octubre por la noche), Low Crouching Idle, Crouched Walk, Crouch Walk Back, Crouched Cover Sneaking Right (también reflejado, para la izquierda) y, desde el 18 de octubre por la tarde, Jumping Forward para el salto. Se bajaron también, y no se usan, Falling Idle (el salto de antes: brazos arriba y rodillas recogidas, de dibujo animado), Forward Running Jump (demasiado atlético), Jogging, Standing Jump, los «Standing» de caminar, correr y esprintar, y Crouch Idle y los «Crouch Walk» hacia delante y de lado, del mismo paquete (encorvados, con los brazos adelantados como quien lleva algo) y Crouched Cover Sneaking Left (va de espaldas a la cobertura).

Los zips originales de los tres personajes están en `models/`, fuera de git. Sus SHA-256 son:
- `detective.zip`: `bf72aab06b55c72fea28155555b0ef957aac14341eb598d96fef6f312c9eeb78`
- `detective-woman.zip`: `48ed7d1ca1febffbf0ad36ad456c1e6b24201e5b93ff3913ae6a71030dfa1cf2`
- `realistic-female.zip`: `80616970bab72215b7d7e9e592794711f187851e0a2ba4f6968966564bfc4c60`

De los personajes se versionan el modelo y las imágenes que su importación extrae. Las carpetas `textures/` sueltas que traían los zips se retiraron porque nada las cargaba, salvo los mapas normales del detective, que usa el tráiler.

### Mobiliario (`assets/props/`)

| Carpeta | Modelo | Autoría | Licencia | Ficha |
|---|---|---|---|---|
| `sofa` | Sofa (Game Ready / 2K PBR) | Meerschaum Digital, sobre «Old Sofa (FREE)» de VISJA FILIP RUMIN | CC Attribution | [Sketchfab](https://sketchfab.com/3d-models/sofa-game-ready-2k-pbr-959bc21f62964c068e441622e8d1103a) |
| `monstera` | Monstera Deliciosa Potted Mid-Century plant | Giora (ChubbyPanda) | CC Attribution | [Sketchfab](https://sketchfab.com/3d-models/monstera-deliciosa-potted-mid-century-plant-1ab9bf841df04c07b1819be596327629) |
| `wall_lamp` | Wall Lamp — 2048px² | Mark Peters | CC Attribution | [Sketchfab](https://sketchfab.com/3d-models/wall-lamp-2048px2-487c69d1748c46d2b3cc433fe6885a5e) |
| `elevator` | Elevator with Animation LOWPOLY | EFX | CC Attribution | Sketchfab |
| `camcorder` | Panasonic VHS-C MOVIE CAMERA NV-A3 | Arthur Vanneste | CC Attribution 4.0 | [Sketchfab](https://sketchfab.com/3d-models/panasonic-vhs-c-movie-camera-nv-a3-64bc8b9060f24d72848307ef9be1b9bd) |
| `vhs_tape` | VHS | Terizmeh | CC Attribution 4.0 | [Sketchfab](https://sketchfab.com/3d-models/vhs-c11a8596c3314677a8b9321e141de275) |
| `key` | Key Chain | Inside Out Art (@ranajitdas) | CC Attribution | [Sketchfab](https://sketchfab.com/3d-models/key-chain-e258f14fb7874f299ebef320f7aee4ee) |

El ascensor se usa entero, salvo la pared empapelada que trae alrededor, porque el coche va detrás de una pared del propio hotel. Su FBX está en `assets/props/elevator/elevator.fbx` y sus texturas en la misma carpeta (madera, suelo, metal, botonera con sus mapas de emisión y de metal, y botones de llamada), con los materiales `lift_*.tres` en `game/presentation/materials/`. `tools/props/build_elevator.gd` lo hornea a 0,8 de su tamaño en cinco piezas, todas en el espacio del coche:
- `lift_car.res`: el coche con la botonera interior completa;
- `lift_door_a.res` y `lift_door_b.res`: las dos hojas;
- `lift_call.res`: los botones de llamada;
- `lift_screen.res`: la pantalla de fuera.

El archivo descargado y lo que traía están en `source_assets/elevator/`, fuera de git.

**La videocámara y la cinta** (descargadas por el usuario el 12/10/2026; fichas abiertas ese día: las dos descargables y con licencia CC Attribution 4.0, uso comercial permitido, hay que citar al autor). La videocámara es la que queda en el suelo donde la criatura coge a alguien ([EXECUTION.md](EXECUTION.md)); la cinta está guardada para más adelante y todavía no se coloca en ningún sitio.
- Los zips están en `models/`, fuera de git: `panasonic-vhs-c-movie-camera-nv-a3.zip` (22.952.391 bytes, SHA-256 `eae64a0b1700b3968c9db9de6331348d9081d7336b5f28f9d1350d1f1ddb37e5`) y `vhs.zip` (4.296.221 bytes, SHA-256 `eea4af04b6037b8f2f361eac10085f6d8c720c9944a367e93867ea99b58c5aa5`). `tools/props/ingest_camcorder.py` los desempaqueta en `source_assets/camcorder/` y `source_assets/vhs_tape/` y deja en `assets/props/` lo que se versiona: el modelo y sus mapas a 1024 px.
- **Modificaciones** (la licencia las permite y pide decirlas): el OBJ de la videocámara se parte en dos por sus grupos —nombra un solo material para todo, y los tres cristales del objetivo son otro—; los mapas se reducen de 2048 y 4096 px a 1024; y en el color y la rugosidad de la cámara **se tapan la marca del fabricante (cuatro sitios), la insignia y el logotipo del formato de cinta, la placa de características y las iniciales a rotulador de su dueño**, que el autor del modelo cuenta que son las de su abuelo. Lo que queda es una videocámara, no esa. El cristal del objetivo se dibuja opaco: el modelo no tiene nada detrás.
- `tools/props/build_camcorder.gd` los hornea: `camcorder.res` en el espacio de la lente (el cristal delantero en el origen, mirando a −Z como una cámara de Godot, 27 cm de largo: la transformación de una cámara es la del objeto) y `vhs_tape.res` tumbada, con la etiqueta arriba (187 mm, el tamaño de una cinta VHS). Cómo quedan: `tools/capture/camcorder_capture.gd`.
- No se trajo el segundo modelo de videocámara que se miró («VHS-C Camcorder», creativecipher): su ficha no permite descargarlo ni publica licencia.

Siguen sin ficha, y por tanto sin licencia comprobada: el televisor de la escena de entrada (que ahora es también el de todas las teles del hotel), el dormitorio de esa misma escena, la puerta de madera y el armario.

### Sonido (Freesound)

El usuario aportó estos. De los seis primeros, el reparto archivo por archivo dentro de `assets/audio/` todavía no está anotado (pendiente de que el usuario diga cuál es cuál); los demás se saben exactamente.

| Sonido | Autoría | Licencia | Ficha |
|---|---|---|---|
| Bed sheets (SoundAction 104) | alexarje | CC BY 4.0 | [863082](https://freesound.org/people/alexarje/sounds/863082/) |
| men_sneaker_shoes_walking_sound_09262024 | Artninja | CC BY 4.0 | [757366](https://freesound.org/people/Artninja/sounds/757366/) |
| Open letter and reading | dersuperanton | CC BY 4.0 | [434466](https://freesound.org/people/dersuperanton/sounds/434466/) |
| horror ambience 161101_1038 | klankbeeld | CC BY 4.0 | [535780](https://freesound.org/people/klankbeeld/sounds/535780/) |
| Door Opening | AUDACITIER | CC BY 4.0 | [632128](https://freesound.org/people/AUDACITIER/sounds/632128/) |
| Atmosphere 2 | oldaccount | CC BY 3.0 | [316800](https://freesound.org/people/oldaccount/sounds/316800/) |
| Jumpscare sound | EnclosureX_Studios | CC BY 4.0 | [865842](https://freesound.org/people/EnclosureX_Studios/sounds/865842/) |
| toaster oven or lift/elevator bell | azumarill | CC BY 3.0 | Freesound |
| custom_heavy_whoosh_punch_kick_thud_impact_sound_10022025 | Artninja | CC BY 4.0 | [829590](https://freesound.org/people/Artninja/sounds/829590/) |
| Radio Music — A MakeNoise Morphagene Reel | nlux | CC0 | [624412](https://freesound.org/people/nlux/sounds/624412/) |
| Flashlight Clicking On and Off | deleted_user_7146007 | CC0 | [383659](https://freesound.org/people/deleted_user_7146007/sounds/383659/) |
| camera lens zooming | CorneRoose | CC0 | [654182](https://freesound.org/people/CorneRoose/sounds/654182/) |
| creaky door | CaptainYulef | CC0 | [638608](https://freesound.org/people/CaptainYulef/sounds/638608/) |
| Creaky bedroom door close; long .WAV | thomasanthony321 | CC0 | [682754](https://freesound.org/people/thomasanthony321/sounds/682754/) |
| glass - baby food jar - smashed on concrete.wav | Anthousai | CC0 | [447699](https://freesound.org/people/Anthousai/sounds/447699/) |
| Teak Nightstand Open and Close | Filmscore | CC0 | [828784](https://freesound.org/people/Filmscore/sounds/828784/) |
| Drawer Opening & Closing | quantumriver | CC0 | [552153](https://freesound.org/people/quantumriver/sounds/552153/) |
| cajon.wav | ANFEGORES108 | CC0 | [626414](https://freesound.org/people/ANFEGORES108/sounds/626414/) |
| open-cardboard-box-compartment.wav | newagesoup | CC0 | [364740](https://freesound.org/people/newagesoup/sounds/364740/) |

Los dos últimos, aportados el 18 de octubre de 2026 (en `sfx/flashlight/on-off-x3.ogg` y `sfx/cam/zoom-in-and-out.mp3`, recortes del autor de las grabaciones de Freesound), son el interruptor de la linterna y el motor del zoom: `tools/audio/prepare_camera_sfx.py` los corta en `assets/audio/sfx/flashlight/` y `assets/audio/sfx/camera/` (AUDIO.md).

Los dos de la puerta lenta, aportados el 19 de octubre de 2026 en `sfx/door-new/` (`door-slow-opening.ogg` y `door-slow-closing.ogg`, fichas abiertas ese día), son abrir y cerrar despacio: `tools/audio/clean_recordings.py` los prepara en `assets/audio/sfx/door/` (AUDIO.md, «Puerta lenta»). El último, aportado el mismo día en `sfx/glass/glass-break.wav` (ficha abierta ese día), es la pantalla de la tele rompiéndose en la escena de entrada: la misma herramienta lo prepara en `assets/audio/glass/shatter.wav` (AUDIO.md, «Escena de entrada»). Los cuatro siguientes, aportados también ese día en `sfx/drawer/` (fichas abiertas ese día), son lo que suena al registrar un mueble: `wooden-drawer.wav` es el de Filmscore, `big-drawer.wav` el de quantumriver, `soft-drawer.wav` el de ANFEGORES108 y `box.wav` el de newagesoup (se distinguen por su duración); `tools/audio/prepare_search_sfx.py` los corta en `assets/audio/sfx/search/` (AUDIO.md, «Registrar muebles»).

**Salieron del juego el 19 de octubre de 2026**, por no comerciales, «DOOR creak — multiple creaks wooden door» (mickfire, CC BY-NC 4.0, [326416](https://freesound.org/people/mickfire/sounds/326416/)), que era `sfx/door/opening/creaky-wooden-door-slow-opening.mp3`, y «Sub Riser» (deleted_user_3277771 / Josh Mclelland, CC BY-NC 3.0, [185372](https://freesound.org/people/deleted_user_3277771/sounds/185372/)), que era `sfx/ambience/presence/sub-riser-presence.wav`. Los originales siguen en `sfx/`; en el proyecto no queda copia ni nada que los use.

Los tres de la ejecución: el grito del agarre (`execution_scream.wav`), el golpe del brazo (`execution_hit.wav`) y la estática del canal muerto (`execution_static.ogg`). El cuerpo al caer no suena. Los originales están en `sfx/screamer/`, `sfx/hit/` y `sfx/static/` (esa carpeta no se versiona: son los másteres del usuario); las copias que usa el juego las prepara `tools/audio/prepare_execution_sfx.py` (mono a 44,1 kHz; del archivo de impactos, que trae tres tomas, solo se usa la primera, cortada para que el impacto caiga a 0,22 s).

### Lo que esto impide

- **No comercial:** el modelo de The Locust (CC BY-NC-ND) prohíbe el uso comercial. Mientras siga en el juego, no se puede vender ni monetizar. Desde el 19/10/2026 es lo único no comercial: los dos sonidos que también lo eran salieron.
- **Sin obra derivada:** la licencia de The Locust es además NoDerivs, y el hotel lo escala y le mueve los huesos. Hay que resolverlo con el autor o sustituirlo antes de publicar.
- **CompartirIgual:** «Realistic Female» obliga a distribuir bajo la misma licencia cualquier obra derivada del modelo.
- **Atribución:** todos los CC BY exigen crédito, y ya lo tienen en la pantalla de créditos. Los CC0 (ambientCG, Poly Haven, los sonidos CC0 de Freesound) y el dominio público (Art Institute of Chicago) no lo exigen: desde el 19/10/2026 no salen en los créditos, solo en este registro.

<!-- SCANS: generado por tools/textures/ingest_pbr.py, no editar a mano -->
## Materiales escaneados (fase 3 de REALISM.md)

Todos CC0 (dominio público): no exigen atribución: constan aquí y no en los créditos del juego. Descargas originales en `source_assets/textures/` (fuera de git); en `assets/textures/<set>/` quedan color, normal (OpenGL) y ORM a 2048 px y a 1024 px (`_1k`, preset Bajo).

| Set | Asset | Autoría | Fuente | Licencia | Uso |
|---|---|---|---|---|---|
| `carpet016` | [Carpet016](https://ambientcg.com/view?id=Carpet016) | Lennart Demes (ambientCG) | ambientCG | CC0 1.0 | pelo de la moqueta, bajo el medallón procedural |
| `wallpaper001a` | [Wallpaper001A](https://ambientcg.com/view?id=Wallpaper001A) | Lennart Demes (ambientCG) | ambientCG | CC0 1.0 | papel de las paredes, bajo el motivo procedural |
| `decrepit_wallpaper` | [Decrepit Wallpaper](https://polyhaven.com/a/decrepit_wallpaper) | Rob Tuytel | Poly Haven | CC0 1.0 | paredes de salones vacíos y almacenes |
| `ceiling_interior` | [Ceiling Interior](https://polyhaven.com/a/ceiling_interior) | Dimitrios Savva | Poly Haven | CC0 1.0 | techo de estuco |
| `officeceiling001` | [OfficeCeiling001](https://ambientcg.com/view?id=OfficeCeiling001) | Lennart Demes (ambientCG) | ambientCG | CC0 1.0 | falso techo de lavandería, almacén, mantenimiento y oficina |
| `lacquered_cherry_wood` | [Lacquered Cherry Wood](https://polyhaven.com/a/lacquered_cherry_wood) | Jenelle van Heerden, Rico Cilliers | Poly Haven | CC0 1.0 | muebles de madera |
| `dark_wood` | [Dark Wood](https://polyhaven.com/a/dark_wood) | Dario Barresi, Dimitrios Savva, Rico Cilliers | Poly Haven | CC0 1.0 | arrimaderos y molduras |
| `tiles036` | [Tiles036](https://ambientcg.com/view?id=Tiles036) | Lennart Demes (ambientCG) | ambientCG | CC0 1.0 | azulejo de baños y zonas de servicio |
| `metal048b` | [Metal048B](https://ambientcg.com/view?id=Metal048B) | Lennart Demes (ambientCG) | ambientCG | CC0 1.0 | latón |
| `velour_velvet` | [Velour Velvet](https://polyhaven.com/a/velour_velvet) | colormass, Rico Cilliers | Poly Haven | CC0 1.0 | tapicería |
| `quatrefoil_jacquard_fabric` | [Quatrefoil Jacquard Fabric](https://polyhaven.com/a/quatrefoil_jacquard_fabric) | colormass, Rico Cilliers | Poly Haven | CC0 1.0 | colchas |
| `brown_leather` | [Brown Leather](https://polyhaven.com/a/brown_leather) | Rob Tuytel | Poly Haven | CC0 1.0 | maletas |
<!-- /SCANS -->

## Pendiente: modelos CC-BY de Sketchfab (fase 4)

Requieren cuenta; los descarga el usuario en `source_assets/props/`. Si entran, van en los créditos del juego:
- **SFM Telephone**, de G= (ge);
- **Old Dirty Pedestal Sink**, de Renend Studio;
- **Dirty Public Toilet**, de lucianofgatto;
- **Bathroom Urinal Game-Ready**, de CurlyFryWhy;
- **Lave linge vintage**, de maxipub;
- **Cleaning Cart**, de crow.bite;
- **Table Bell**, de gla_bot;
- **Vintage Metal Ashtray**, de Mattyew;
- **Towel**, de andree.

<!-- MODELS: generado por tools/props/ingest_models.py, no editar a mano -->
## Mobiliario y objetos (fase 4 de REALISM.md)

Poly Haven, CC0 (dominio público): no exigen atribución: constan aquí y no en los créditos del juego. Descargas originales en `source_assets/props/` (fuera de git); en `assets/props/hotel/<id>/` quedan las texturas (1024 px, 2048 en los muebles grandes) y los materiales, y `tools/props/build_catalogue.gd` hornea `assets/props/hotel/<id>.res`.

| Modelo | Autoría | Licencia |
|---|---|---|
| [Arm Chair 01](https://polyhaven.com/a/ArmChair_01) | Kirill Sannikov | CC0 1.0 |
| [Cash Register 01](https://polyhaven.com/a/CashRegister_01) | Joe Seabuhr | CC0 1.0 |
| [Chandelier 02](https://polyhaven.com/a/Chandelier_02) | Kirill Sannikov | CC0 1.0 |
| [Classic Console 01](https://polyhaven.com/a/ClassicConsole_01) | Kirill Sannikov | CC0 1.0 |
| [Classic Nightstand 01](https://polyhaven.com/a/ClassicNightstand_01) | Kirill Sannikov | CC0 1.0 |
| [Gothic Bed 01](https://polyhaven.com/a/GothicBed_01) | Kirill Sannikov | CC0 1.0 |
| [Gothic Commode 01](https://polyhaven.com/a/GothicCommode_01) | Kirill Sannikov | CC0 1.0 |
| [Green Chair 01](https://polyhaven.com/a/GreenChair_01) | Kirill Sannikov | CC0 1.0 |
| [School Chair 01](https://polyhaven.com/a/SchoolChair_01) | Ethan Place | CC0 1.0 |
| [Sofa 01](https://polyhaven.com/a/Sofa_01) | Kirill Sannikov | CC0 1.0 |
| [Wet Floor Sign 01](https://polyhaven.com/a/WetFloorSign_01) | Fran Calvente | CC0 1.0 |
| [Alarm Clock 01](https://polyhaven.com/a/alarm_clock_01) | Yann Kervran, James Ray Cock | CC0 1.0 |
| [Antique Ceramic Vase 01](https://polyhaven.com/a/antique_ceramic_vase_01) | James Ray Cock | CC0 1.0 |
| [Bleach Bottle](https://polyhaven.com/a/bleach_bottle) | James Ray Cock | CC0 1.0 |
| [Book Encyclopedia Set 01](https://polyhaven.com/a/book_encyclopedia_set_01) | John Malcolm | CC0 1.0 |
| [Brass Vase 02](https://polyhaven.com/a/brass_vase_02) | Rico Cilliers | CC0 1.0 |
| [Cardboard Box 01](https://polyhaven.com/a/cardboard_box_01) | Rahul Chaudhary | CC0 1.0 |
| [Ceiling Fan](https://polyhaven.com/a/ceiling_fan) | Ulan Cabanilla | CC0 1.0 |
| [Ceramic Vase 01](https://polyhaven.com/a/ceramic_vase_01) | James Ray Cock | CC0 1.0 |
| [Cigarette Pack](https://polyhaven.com/a/cigarette_pack) | Ulrich Büch | CC0 1.0 |
| [Clipboard](https://polyhaven.com/a/clipboard) | ProgrammerOnCoffee | CC0 1.0 |
| [Dining Chair 02](https://polyhaven.com/a/dining_chair_02) | James Ray Cock | CC0 1.0 |
| [Drawer Cabinet](https://polyhaven.com/a/drawer_cabinet) | Ulan Cabanilla | CC0 1.0 |
| [Fancy Picture Frame 01](https://polyhaven.com/a/fancy_picture_frame_01) | Rob Tuytel, Rico Cilliers | CC0 1.0 |
| [Fire Alarm](https://polyhaven.com/a/fire_alarm) | Slinc | CC0 1.0 |
| [Industrial Storage Cart](https://polyhaven.com/a/industrial_storage_cart) | Jule Bielitz | CC0 1.0 |
| [Jug 01](https://polyhaven.com/a/jug_01) | Kuutti Siitonen | CC0 1.0 |
| [Mantel Clock 01](https://polyhaven.com/a/mantel_clock_01) | Yann Kervran, Rico Cilliers | CC0 1.0 |
| [Metal Office Desk](https://polyhaven.com/a/metal_office_desk) | Ulan Cabanilla | CC0 1.0 |
| [Metal Trash Can](https://polyhaven.com/a/metal_trash_can) | GurJas Studios | CC0 1.0 |
| [Modular Airduct Circular 01](https://polyhaven.com/a/modular_airduct_circular_01) | Riley Queen | CC0 1.0 |
| [Modular Fire Escape](https://polyhaven.com/a/modular_fire_escape) | Juniix | CC0 1.0 |
| [Modular Pipes](https://polyhaven.com/a/modular_pipes) | Kuutti Siitonen | CC0 1.0 |
| [Mounted Fluorescent Lights](https://polyhaven.com/a/mounted_fluorescent_lights) | Ulan Cabanilla | CC0 1.0 |
| [Multi Cleaner Bottle](https://polyhaven.com/a/multi_cleaner_bottle) | James Ray Cock | CC0 1.0 |
| [Office Notepads](https://polyhaven.com/a/office_notepads) | Ulan Cabanilla | CC0 1.0 |
| [Ornate Mirror 01](https://polyhaven.com/a/ornate_mirror_01) | James Ray Cock | CC0 1.0 |
| [Painted Wooden Cabinet](https://polyhaven.com/a/painted_wooden_cabinet) | Kirill Sannikov | CC0 1.0 |
| [Plastic Crate 02](https://polyhaven.com/a/plastic_crate_02) | Fabi_G | CC0 1.0 |
| [Potted Plant 02](https://polyhaven.com/a/potted_plant_02) | Rico Cilliers | CC0 1.0 |
| [Potted Plant 04](https://polyhaven.com/a/potted_plant_04) | James Ray Cock | CC0 1.0 |
| [Power Box 01](https://polyhaven.com/a/power_box_01) | Rico Cilliers, Yann Kervran | CC0 1.0 |
| [Side Table Tall 01](https://polyhaven.com/a/side_table_tall_01) | James Ray Cock | CC0 1.0 |
| [Sofa 03](https://polyhaven.com/a/sofa_03) | Fran Calvente | CC0 1.0 |
| [Stationery Supplies](https://polyhaven.com/a/stationery_supplies) | Mateusz Sadek | CC0 1.0 |
| [Steel Frame Shelves 01](https://polyhaven.com/a/steel_frame_shelves_01) | James Ray Cock | CC0 1.0 |
| [Trashbag](https://polyhaven.com/a/trashbag) | Benny Weimer | CC0 1.0 |
| [Vintage Cabinet 01](https://polyhaven.com/a/vintage_cabinet_01) | Rico Cilliers | CC0 1.0 |
| [Vintage Grandfather Clock 01](https://polyhaven.com/a/vintage_grandfather_clock_01) | Yann Kervran, James Ray Cock | CC0 1.0 |
| [Vintage Suitcase](https://polyhaven.com/a/vintage_suitcase) | Maximilian Schuster | CC0 1.0 |
| [Wall Clock](https://polyhaven.com/a/wall_clock) | PierreB3D | CC0 1.0 |
| [Wicker Basket 02](https://polyhaven.com/a/wicker_basket_02) | Kuutti Siitonen | CC0 1.0 |
| [Wine Bottles 01](https://polyhaven.com/a/wine_bottles_01) | Rico Cilliers, Jurita Burger | CC0 1.0 |
| [Wooden Bookshelf Worn](https://polyhaven.com/a/wooden_bookshelf_worn) | Ulan Cabanilla | CC0 1.0 |
| [Worn Metal Rack](https://polyhaven.com/a/worn_metal_rack) | Luca B | CC0 1.0 |
<!-- /MODELS -->

<!-- DRESSING: generado por tools/textures/ingest_dressing.py, no editar a mano -->
## Decals y cuadros (fase 4 de REALISM.md)

Decals de ambientCG (Lennart Demes), CC0 1.0, en `assets/decals/` (512 px); originales en `source_assets/decals/`.

| Decal | Uso |
|---|---|
| [Leaking001](https://ambientcg.com/view?id=Leaking001) | humedad que baja por la pared |
| [Leaking003](https://ambientcg.com/view?id=Leaking003) | humedad que baja por la pared |
| [Leaking005](https://ambientcg.com/view?id=Leaking005) | humedad que baja por la pared |
| [Leaking008](https://ambientcg.com/view?id=Leaking008) | gotera bajo el techo |
| [Leaking009](https://ambientcg.com/view?id=Leaking009) | gotera bajo el techo |
| [ChewingGum001](https://ambientcg.com/view?id=ChewingGum001) | chicles pegados al suelo |
| [Fingerprints002](https://ambientcg.com/view?id=Fingerprints002) | huellas de dedos junto a las puertas |
| [Fingerprints004](https://ambientcg.com/view?id=Fingerprints004) | huellas de dedos junto a las puertas |
| [Smear003](https://ambientcg.com/view?id=Smear003) | manchas en espejos y azulejo |
| [Footsteps003](https://ambientcg.com/view?id=Footsteps003) | pisadas en el suelo |
| [SurfaceImperfections001](https://ambientcg.com/view?id=SurfaceImperfections001) | manchas en suelos y paredes |
| [SurfaceImperfections013](https://ambientcg.com/view?id=SurfaceImperfections013) | manchas en suelos y paredes |
| [SurfaceImperfections017](https://ambientcg.com/view?id=SurfaceImperfections017) | manchas en suelos y paredes |

Cuadros: imágenes de dominio público del Art Institute of Chicago (CC0, open access), en `assets/paintings/` (1024 px); originales en `source_assets/paintings/`.

| Obra | Autor | Fecha |
|---|---|---|
| [River Landscape with a View of Naarden](https://www.artic.edu/artworks/238272) | Salomon van Ruysdael (Dutch, about 1602–1670) | 1642 |
| [The Watermill with the Great Red Roof](https://www.artic.edu/artworks/869) | Meindert Hobbema (Dutch, 1638–1709) | c. 1665 |
| [Coast Scene](https://www.artic.edu/artworks/495) | Attributed to Reinier Nooms (Reinier Zeeman; Dutch, c. 1623-c. 1668) | c. 1655 |
| [Douarnenez in Sunshine](https://www.artic.edu/artworks/111632) | Maxime Maufra (French, 1861–1918) | 1897 |
| [Portrait of a Man with Gray Hair](https://www.artic.edu/artworks/15708) | Henry Raeburn (Scottish, 1756–1823) | 1810–20 |
| [Portrait of a Woman](https://www.artic.edu/artworks/79765) | John Wollaston (American, born England, c. 1710–c. 1775) | 1749–52 |
| [Portrait of a Man](https://www.artic.edu/artworks/75409) | Arthur Devis (English, 1712–1787) | 1763 |
| [Mountain Brook](https://www.artic.edu/artworks/146701) | Albert Bierstadt (American, born Solingen, Prussia, now Germany, 1830–1902) | 1863 |
| [Icebound](https://www.artic.edu/artworks/72801) | John Henry Twachtman (American, 1853–1902) | c. 1889 |
| [On the Road](https://www.artic.edu/artworks/890) | Jules Dupré (French, 1811–1889) | 1856 |
| [Landscape](https://www.artic.edu/artworks/874) | Jean Charles Cazin (French, 1841–1901) | c. 1895 |
| [York Harbor, Coast of Maine](https://www.artic.edu/artworks/152747) | Martin Johnson Heade (American, 1819–1904) | 1877 |
| [Italian Landscape with Travelers](https://www.artic.edu/artworks/69041) | Jan Both (Dutch, c. 1618–1652) | c. 1650 |
| [Bouquet of Flowers in an Earthenware Vase](https://www.artic.edu/artworks/64029) | Attributed to Jan Brueghel the Elder (Flemish, 1568–1625) | c. 1610 |

Láminas del piso 2 (grabados, fotografías antiguas y planos que cuelgan en las oficinas): del mismo museo y con la misma licencia, en `assets/paintings/office/` (843 px); originales en `source_assets/paintings/office/`. Las cuelga `game/world/office/office_pictures.gd`.

| Obra | Autor | Fecha |
|---|---|---|
| [Plan of the Center of the City, the 1909 Plan of Chicago](https://www.artic.edu/artworks/196352) | Daniel Hudson Burnham, American, 1846-1912 | 1909 |
| [The City of Ambitions](https://www.artic.edu/artworks/66711) | Alfred Stieglitz | 1910 |
| [Plate 110 from The Plan of Chicago, 1909: Chicago. Plan of the Complete System of Street Circulation (...)](https://www.artic.edu/artworks/196350) | Daniel Hudson Burnham, American, 1846-1912 | 1909 |
| [Rue de la Montagne-Sainte-Geneviève near the Intersection of Rue LaPlace (Rue de la Montagne-Sainte-Geneviève prés de carrefour de la rue LaPlace)](https://www.artic.edu/artworks/181558) | Charles Marville | 1865/69 |
| [Plan of Chicago, Chicago, Illinois, Diagram Showing City Growth](https://www.artic.edu/artworks/196347) | Daniel Hudson Burnham (American, 1846-1912) | 1909 |
| [Stewart–Bentley Building, Chicago, Illinois, Elevation and Exterior Wall Section](https://www.artic.edu/artworks/90267) | Carter, Drake and Wight (American, 1871–1873) | 1872 |
| [Market of the Patriarchs (Marché des Patriarches)](https://www.artic.edu/artworks/212159) | Charles Marville | c. 1862 |
| [Plan of Chicago, Plate 63, Plan of a Proposed Park](https://www.artic.edu/artworks/196328) | Daniel Hudson Burnham, American, 1846–1912 | 1909 |
| [Rue Mouffetard, Paris](https://www.artic.edu/artworks/11766) | Donald Shaw MacLaughlan | 1900 |
| [Plan of Chicago, Chicago, Illinois, Railroad Circuits Diagram](https://www.artic.edu/artworks/196332) | Daniel Hudson Burnham (American, 1846-1912) | 1909 |
| [View of Ponte Lugano on the Anio, from Views of Rome](https://www.artic.edu/artworks/19) | Giovanni Battista Piranesi (Italian, 1720-1778) | 1763, published 1800–07 |
| [Montmartre](https://www.artic.edu/artworks/92231) | Artist unknown  | 1870 |
| [Ships in the Harbor at Sète](https://www.artic.edu/artworks/126487) | Gustave Le Gray | 1857 |
| [Villa Pamphili outside Porta S. Pancrazio, from Views of Rome](https://www.artic.edu/artworks/22) | Giovanni Battista Piranesi (Italian, 1720-1778) | 1776, published 1800–07 |
| [Bridge, Amsterdam](https://www.artic.edu/artworks/19853) | James McNeill Whistler | 1889 |
| [Harbor Scene with a Lighthouse](https://www.artic.edu/artworks/133358) | Claude Lorrain | 1638–41 |
| [Fishing Craft near the Cliffs at Collioure](https://www.artic.edu/artworks/65) | Adolphe Appian | 1878 |
<!-- /DRESSING -->

<!-- OFFICE_MODELS: generado por tools/props/ingest_models.py --set=office, no editar a mano -->
## Mobiliario y equipos de las oficinas (piso 2)

Descargas originales en `source_assets/oficinas/<grupo>/<slug>/` y `source_assets/props/<slug>/` (fuera de git), con su registro (`registro.json`, `registro_polyhaven_modelos.json`); en `assets/props/office/<slug>/` quedan las texturas y los materiales, y `tools/props/build_catalogue.gd` hornea `assets/props/office/<slug>.res`. Las que no son CC0 piden su línea en los créditos del juego (`CREDITS` de `game/ui/hotel_ui.gd`).

| Modelo | Id | Autoría | Fuente | Licencia |
|---|---|---|---|---|
| [televisor CRT de sobremesa con caja de madera](https://polyhaven.com/a/Television_01) | `Television_01` | Gabriel Radić | Poly Haven | CC0 1.0 |
| [alargador](https://sketchfab.com/3d-models/extension-cord-scan-medpoly-c651f47533c8421f91954d0c9653278a) | `alargador_evan4129` | EFX | Sketchfab | CC BY 4.0 |
| [planta de hoja ancha y brillante, tipo anthurium o espatifilo (sin maceta)](https://polyhaven.com/a/anthurium_botany_01) | `anthurium_botany_01` | Rob Tuytel, Rico Cilliers | Poly Haven | CC0 1.0 |
| [archivadores grises de 4 y 2 cajones](https://sketchfab.com/3d-models/filing-cabinet-16mb-ac5d883bec4549508aa579f792d59954) | `archivador_gris_ahmagh2e` | Mehdi Shahsavan | Sketchfab | CC BY 4.0 |
| [archivadores de palanca](https://sketchfab.com/3d-models/several-folders-1a493b49ef954985ab8057ca66c387d5) | `archivadores_palanca_janexx` | janexx | Sketchfab | CC BY 4.0 |
| [armario de manguera contra incendios](https://sketchfab.com/3d-models/fire-hose-cabinet-befe18817b094900ad2290654f655cb8) | `armario_manguera_red2000` | RED2000 | Sketchfab | CC BY 4.0 |
| [bandeja de documentos de tres pisos](https://sketchfab.com/3d-models/document-letter-tray-documents-organizer-f5c4c6638ea844fa936d43e60b83073f) | `bandeja_sinnervoncrawsz` | YouniqueĪdeaStudio | Sketchfab | CC BY 4.0 |
| [bisagras de pala](https://sketchfab.com/3d-models/door-hinge-1mb-2108070af696477b91b66a5c40c733d6) | `bisagra_ahmagh2e` | Mehdi Shahsavan | Sketchfab | CC BY 4.0 |
| [radiocasete portátil de los 80](https://polyhaven.com/a/boombox) | `boombox` | Thomas Paul Mouilleron | Poly Haven | CC0 1.0 |
| [butaca de madera](https://sketchfab.com/3d-models/vintage-wooden-armchair-low-poly-game-ready-2b7ae6f828844ee4a64c7417a7b78486) | `butaca_madera_renend` | Renend Studio | Sketchfab | CC BY 4.0 |
| [caja de cartón sucia](https://sketchfab.com/3d-models/dirty-damaged-fatigued-cardboard-box-6ff34ec5021440bd90ef18179002bc18) | `caja_carton_krolzuzanna` | SusanKing | Sketchfab | CC BY 4.0 |
| [cajas de archivo](https://sketchfab.com/3d-models/2-boxes-3f920e8fd10c4664b5bd1dea3cf7606e) | `cajas_archivo_cozmoth` | Cozmoth | Sketchfab | CC BY 4.0 |
| [calathea, planta de interior sin maceta](https://polyhaven.com/a/calathea_orbifolia_01) | `calathea_orbifolia_01` | Rob Tuytel, Rico Cilliers | Poly Haven | CC0 1.0 |
| [cámara de vigilancia en su carcasa](https://sketchfab.com/3d-models/cctv-camera-e69d5eb37ffb4f188e4d3c84a5d79cdc) | `camara_cctv_smoggybeard` | Smoggybeard | Sketchfab | CC BY 4.0 |
| [cenicero de vidrio](https://sketchfab.com/3d-models/glass-ashtray-8c9deaa3f4b84e01b186eec4c1269b60) | `cenicero_vidrio_red2000` | RED2000 | Sketchfab | CC BY 4.0 |
| [terminal de pantalla verde de los 80, sin teclado](https://sketchfab.com/3d-models/b0470478089a4462afb4d5c4dd827b22) | `crt_terminal_ibm3278_sketchfab` | maxdragonn (sketchfab.com/maxdragon) | Sketchfab | CC BY 4.0 |
| [detector de humo](https://sketchfab.com/3d-models/simple-smoke-detector-8db756d4c1564f3197f2415ec2ef7fec) | `detector_humo_sousinho` | Sousinho | Sketchfab | CC BY 4.0 |
| [recogedor de chapa verde gastado](https://polyhaven.com/a/dustpan) | `dustpan` | Balen | Poly Haven | CC0 1.0 |
| [escritorio de madera](https://sketchfab.com/3d-models/antique-desk-c491f647da5947978ba8113951ee2efc) | `escritorio_madera_collings` | Matthew Collings | Sketchfab | CC BY 4.0 |
| [escritorio metálico tanker](https://sketchfab.com/3d-models/steelcase-tanker-desk-99877819505c44a4b7e2b72a61f68b34) | `escritorio_tanker_lenawachs` | lena-wachs | Sketchfab | CC BY 4.0 |
| [máquina expendedora](https://sketchfab.com/3d-models/vending-machine-af792a359ab24c6eaf1e8d98640f05a8) | `expendedora_attheseedof` | AtTheSpeedOf | Sketchfab | CC BY 4.0 |
| [extintor](https://sketchfab.com/3d-models/fire-extinguisher-5676b179b3b744c0aaae53a3dcea2300) | `extintor_loic` | Loïc | Sketchfab | CC BY 4.0 |
| [archivador de madera de 6 cajones](https://polyhaven.com/a/vintage_wooden_drawer_01) | `fichero_vintage_wooden_drawer_01` | James Ray Cock | Poly Haven | CC0 1.0 |
| [flexo](https://sketchfab.com/3d-models/old-lamp-1ec5e59201094883b780a32ff4e61637) | `flexo_sousinho` | Sousinho | Sketchfab | CC BY 4.0 |
| [globo terráqueo](https://sketchfab.com/3d-models/antique-globe-78b47132c6be42bcb664545a69b380d9) | `globo_collings` | mtcollings | Sketchfab | CC BY 4.0 |
| [impresora matricial](https://sketchfab.com/3d-models/okidata-microline-320-turbo-f7bf859023544e91ab622a8f18862ecf) | `impresora_okidata_papaj` | Remik.Papaj | Sketchfab | CC BY 4.0 |
| [lámpara de banquero verde](https://sketchfab.com/3d-models/old-vintage-desk-lamp-0fd07d3289ac4b9cbf59465b937ba9a0) | `lampara_banquero_meunier` | Jeff Meunier | Sketchfab | CC BY 4.0 |
| [lavabo de pie](https://sketchfab.com/3d-models/sink-901084912a1b41758dc8b892b25ac46d) | `lavabo_juang3d` | JuanG3D | Sketchfab | CC BY 4.0 |
| [librerías de madera con libros](https://sketchfab.com/3d-models/wooden-bookcases-with-books-d0618ac16b2a4a87b9b6c7d5e6765626) | `libreria_libros_collings` | Matthew Collings | Sketchfab | CC BY 4.0 |
| [libros sueltos](https://sketchfab.com/3d-models/antique-book-set-a7e1164cca004a65ab53ce0e8553586c) | `libros_frodoundead` | FrodoUndead | Sketchfab | CC BY 4.0 |
| [foco de emergencia de dos cabezas](https://sketchfab.com/3d-models/rusty-twin-spot-emergency-light-4ec589e8bed94cf1b2a44b767e858ccc) | `luz_emergencia_sousinho` | Sousinho | Sketchfab | CC BY 4.0 |
| [lupa de mango negro](https://polyhaven.com/a/magnifying_glass_01) | `magnifying_glass_01` | Nazar Borodavka | Poly Haven | CC0 1.0 |
| [taburete redondo de cuero sobre base metálica industrial](https://polyhaven.com/a/metal_stool_01) | `metal_stool_01` | Ulan Cabanilla | Poly Haven | CC0 1.0 |
| [caja de herramientas de chapa verde gris con bandeja, desconchada](https://polyhaven.com/a/metal_toolbox) | `metal_toolbox` | Mateusz Sadek | Poly Haven | CC0 1.0 |
| [lector de microfichas](https://sketchfab.com/3d-models/microfiche-reader-840847ca755e4ecda2a16759f11654dd) | `microfichas_maxdragonn` | maxdragonn | Sketchfab | CC BY 4.0 |
| [sillón de dirección de cuero marrón y madera curvada, base giratoria](https://polyhaven.com/a/mid_century_lounge_chair) | `mid_century_lounge_chair` | Kuutti Siitonen | Poly Haven | CC0 1.0 |
| [ratonera de madera y alambre, oxidada, con cebo](https://polyhaven.com/a/mousetrap) | `mousetrap` | GreenPixel | Poly Haven | CC0 1.0 |
| [nevera antigua](https://sketchfab.com/3d-models/old-fridge-68d173f205344455933f861042b99fe3) | `nevera_dylanheyes` | dylanheyes | Sketchfab | CC BY 4.0 |
| [pachira, planta de interior (cuatro ejemplares sin maceta)](https://polyhaven.com/a/pachira_aquatica_01) | `pachira_aquatica_01` | Rob Tuytel, Rico Cilliers | Poly Haven | CC0 1.0 |
| [perchero de pie de madera curvada](https://sketchfab.com/3d-models/coat-rack-72e821fc75d9473183a63d548959693b) | `perchero_coat_rack_whostea` | Whostea | Sketchfab | CC BY 4.0 |
| [perchero de pared con ganchos](https://sketchfab.com/3d-models/old-coat-rack-f7125e65dd004381aa3e9882ef74e963) | `perchero_pared_ehnri` | Ehnri | Sketchfab | CC BY 4.0 |
| [termo de plástico verde oliva y crema con asa, de los 70](https://polyhaven.com/a/plastic_thermos) | `plastic_thermos` | PierreB3D | Poly Haven | CC0 1.0 |
| [portalápices](https://sketchfab.com/3d-models/pencils-w-holder-820166ed87564a3389c549735075657d) | `portalapices_aspectstudio` | AspectStudios | Sketchfab | CC BY 4.0 |
| [planta de interior en maceta de terracota](https://polyhaven.com/a/potted_plant_01) | `potted_plant_01` | Rico Cilliers | Poly Haven | CC0 1.0 |
| [pantalla de proyección portátil sobre trípode](https://polyhaven.com/a/projector_screen) | `projector_screen` | PeterM | Poly Haven | CC0 1.0 |
| [puerta lisa de chapa](https://sketchfab.com/3d-models/toilet-exit-door-9eff9a6ca32742839b438e07c018c9bf) | `puerta_lisa_sousinho` | Sousinho | Sketchfab | CC BY 4.0 |
| [puerta metálica gris con marco](https://sketchfab.com/3d-models/metal-door-2-4da6b538427244aaababe36d3e228a40) | `puerta_metal_tboiston` | tboiston | Sketchfab | CC BY 4.0 |
| [puerta de despacho de chapa de madera con mirilla](https://sketchfab.com/3d-models/office-doors-6515d00b831b461695d01591a5b732fd) | `puerta_oficina_sousinho` | Sousinho | Sketchfab | CC BY 4.0 |
| [reloj de mesa](https://sketchfab.com/3d-models/retro-antique-desk-clock-0e09a2d7fdf34f4487e2646b435b3b78) | `reloj_mesa_sousinho` | Sousinho | Sketchfab | CC BY 4.0 |
| [escritorio verde y silla cromada](https://sketchfab.com/3d-models/retro-office-props-65e47619f5114df89fd26db1fa7f9d7f) | `retro_oficina_yj` | YJ_ | Sketchfab | CC BY 4.0 |
| [rociador de techo](https://sketchfab.com/3d-models/fire-alarm-system-sprinkler-9416e1a971524b1a89b89cfcf7c2d33f) | `rociador_tashakosaykina` | tasha.kosaykina | Sketchfab | CC BY 4.0 |
| [teléfono negro de disco](https://sketchfab.com/3d-models/dd6cd63f0bec4c41b5cba2855d22b29b) | `rotary_phone_black_sketchfab` | jacques_3D (sketchfab.com/jacques_3D) | Sketchfab | CC BY 4.0 |
| [gafas redondas de montura metálica](https://polyhaven.com/a/round_spectacles) | `round_spectacles` | Sean Buckley | Poly Haven | CC0 1.0 |
| [mesa redonda de madera oscura y pulida](https://polyhaven.com/a/round_wooden_table_01) | `round_wooden_table_01` | Ulan Cabanilla | Poly Haven | CC0 1.0 |
| [secamanos de pared](https://sketchfab.com/3d-models/hand-dryer-clean-9a1e606c238540798c48b0ed79d6325a) | `secamanos_ladylionstudios` | LordSamueliSolo | Sketchfab | CC BY 4.0 |
| [silla de banquero de madera](https://sketchfab.com/3d-models/wooden-office-chair-f415e04f4bb24221854198727b8f0352) | `silla_banquero_zamzam` | Zamzam2003 | Sketchfab | CC BY 4.0 |
| [silla giratoria de oficina de los 70 (1970s swivel office chair)](https://sketchfab.com/3d-models/old-computer-chair-a311529b1ec349c48f789bf4e1f99e89) | `silla_giratoria_old_computer_chair` | Slava Izvekov (guantanamera) | Sketchfab | CC BY 4.0 |
| [silla giratoria de tela](https://sketchfab.com/3d-models/a81b0c8cbe3248328652d9cd9b8c8b86) | `silla_tela_projectkaizen` | projectkaizen | Sketchfab | CC BY 4.0 |
| [sillón de dirección (MireyGroup)](https://sketchfab.com/3d-models/8f66d9053c1940da82e21523649e32f9) | `sillon_mirey_a` | Мирэй Групп | Sketchfab | CC BY 4.0 |
| [mesa pequeña de madera, vintage](https://polyhaven.com/a/small_wooden_table_01) | `small_wooden_table_01` | Ulan Cabanilla | Poly Haven | CC0 1.0 |
| [sofá de cuero capitoné con marco de madera tallada](https://polyhaven.com/a/sofa_02) | `sofa_02` | Kirill Sannikov | Poly Haven | CC0 1.0 |
| [marco de pie de madera con lámina de playa](https://polyhaven.com/a/standing_picture_frame_02) | `standing_picture_frame_02` | James Ray Cock | Poly Haven | CC0 1.0 |
| [estantería de estructura de acero con baldas de madera, comercial](https://polyhaven.com/a/steel_frame_shelves_02) | `steel_frame_shelves_02` | James Ray Cock | Poly Haven | CC0 1.0 |
| [taquilla gris](https://sketchfab.com/3d-models/locker-3ebc5746b7784253bb0ebd151022757b) | `taquilla_zambur` | Zambur | Sketchfab | CC BY 4.0 |
| [termostato de esfera](https://sketchfab.com/3d-models/thermostat-fire-alarm-v11-fbx-low-poly-free-d928ff87322f455ebb3c631b63937578) | `termostato_alarma_ladylionstudios` | LordSamueliSolo | Sketchfab | CC BY 4.0 |
| [toalla colgada](https://sketchfab.com/3d-models/hanging-towel-2fbb8f56b1ba47bdb6746d95b6fc2242) | `toalla_aprilpolubiec` | aprilpolubiec | Sketchfab | CC BY 4.0 |
| [máquina de escribir manual de los años 30](https://sketchfab.com/3d-models/1d6009449fe84fd79454c4081eb743bf) | `typewriter_1930s_unbranded_sketchfab` | Kuba Wójcik | Sketchfab | CC BY 4.0 |
| [unidad de climatización](https://sketchfab.com/3d-models/hvac-unit-0bf1acaa6f1d4a9bb38cfc91fd115f9c) | `unidad_hvac_kubassa` | kubassa | Sketchfab | CC BY 4.0 |
| [difusores cuadrados de techo](https://sketchfab.com/3d-models/ventilator-vent-valve-14mb-3-part-93ff5077029b4d60a2fc0434610eeb1c) | `ventila_techo_ahmagh2e` | Mehdi Shahsavan | Sketchfab | CC BY 4.0 |
| [ventilador de mesa](https://sketchfab.com/3d-models/vintage-fan-36eaf8bb14eb48b1ac2b5fbf9368dfe2) | `ventilador_joshsmith` | Josh Smith | Sketchfab | CC BY 4.0 |
| [grapadora de sobremesa de chapa esmaltada turquesa, de los 50 a los 70](https://polyhaven.com/a/vintage_stapler) | `vintage_stapler` | Mateusz Sadek | Poly Haven | CC0 1.0 |
| [fuente de agua con garrafa](https://sketchfab.com/3d-models/water-cooler-4b88c4c4e94c497ca39f831f374e89fc) | `water_cooler_bottle_tboiston` | tboiston | Sketchfab | CC BY 4.0 |
| [cepillo de barrer de mango de madera con restos de pintura azul](https://polyhaven.com/a/wooden_broom) | `wooden_broom` | Balen | Poly Haven | CC0 1.0 |
| [escalera de tijera de madera con herrajes](https://polyhaven.com/a/wooden_ladder_02) | `wooden_ladder_02` | JN_3DPRINTINGNERD | Poly Haven | CC0 1.0 |
| [zapato oxford](https://sketchfab.com/3d-models/old-oxford-shoe-29a5ed053eab46a7af308215600985a2) | `zapato_inciprocal` | inciprocal | Sketchfab | CC BY 4.0 |
<!-- /OFFICE_MODELS -->

<!-- OFFICE_SCANS: generado por tools/textures/ingest_pbr.py --set=office, no editar a mano -->
## Materiales escaneados de las oficinas (piso 2)

Descargas originales en `source_assets/oficinas/materiales/` (fuera de git), con sus registros (`materiales/registro.json` y `registro_materiales_2.json`); en `assets/textures/<set>/` quedan color, normal (OpenGL) y ORM con el lado mayor a 2048 px (al de la descarga si es menor), con la proporción de la descarga, y a 1024 px (`_1k`).

| Set | Asset | Autoría | Licencia | Uso |
|---|---|---|---|---|
| `office_anti_skid_tiles` | [Poly Haven](https://polyhaven.com/a/anti_skid_tiles) | Amal Kumar (Poly Haven) | CC0 1.0 | Baldosa con relieve (cuarto electrico) |
| `office_bricks019` | [ambientCG Bricks019](https://ambientcg.com/a/Bricks019) | ambientCG (Lennart Demes) | CC0 1.0 | Bloque de hormigon pintado |
| `office_cardboard004` | [ambientCG Cardboard004](https://ambientcg.com/a/Cardboard004) | ambientCG (Lennart Demes) | CC0 1.0 | Carton y papel de carpeta (manila) |
| `office_concrete_wall_008` | [Poly Haven concrete_wall_008](https://polyhaven.com/a/concrete_wall_008) | Charlotte Baglioni (fotografia), Dario Barresi (procesado) | CC0 1.0 | Losa de hormigon visto (cara inferior, plenum) |
| `office_cork003` | [ambientCG Cork003](https://ambientcg.com/a/Cork003) | ambientCG (Lennart Demes) | CC0 1.0 | Corcho de tablon de anuncios |
| `office_dark_paneled_wood` | [Poly Haven](https://polyhaven.com/a/dark_paneled_wood) | Dimitrios Savva (Poly Haven) | CC0 1.0 | Sin uso desde el area 4d (salia como casetones) |
| `office_fabric026` | [ambientCG](https://ambientcg.com/a/Fabric026) | ambientCG | CC0 1.0 | Moqueta de pelo corto granate apagado (naves, planta 1) |
| `office_fabric028` | [ambientCG](https://ambientcg.com/a/Fabric028) | ambientCG | CC0 1.0 | Moqueta de pelo corto gris pardo (Dirección, planta 3) |
| `office_galvanizedsteel02` | [cgbookcase Galvanized Steel 02](https://www.cgbookcase.com/textures/galvanized-steel-02) | cgbookcase.com (Dorian Zgraggen) | CC0 1.0 | Chapa galvanizada (ductos) |
| `office_hessian_380` | [Poly Haven hessian_380](https://polyhaven.com/a/hessian_380) | colormass (fotografia), Rico Cilliers (procesado) | CC0 1.0 | Tela de mampara de cubiculo |
| `office_painted_concrete_02` | [Poly Haven](https://polyhaven.com/a/painted_concrete_02) | Rob Tuytel (Poly Haven) | CC0 1.0 | Hormigon sellado (almacen, deposito, pasillo de servicio) |
| `office_paintedmetal006` | [ambientCG](https://ambientcg.com/a/PaintedMetal006) | ambientCG | CC0 1.0 | Pintura de acero gastada, como detalle sobre su color (steel_olive, steel_mint, steel_grey y steel_dark: armarios, muebles de acero, puertas de servicio, cuadro) |
| `office_teak_veneer` | [Poly Haven](https://polyhaven.com/a/teak_veneer) | Jenelle van Heerden (Poly Haven) | CC0 1.0 | Teca color miel en chapa (mobiliario, hojas de puerta, casilleros, arrimadero de los pasillos) |
| `office_terrazzo003` | [ambientCG](https://ambientcg.com/a/Terrazzo003) | ambientCG | CC0 1.0 | Terrazo oscuro sal y pimienta pulido (pasillos, vestibulos, archivo) |
| `office_tiles032` | [ambientCG](https://ambientcg.com/a/Tiles032) | ambientCG | CC0 1.0 | Azulejo oscuro para la franja (aseos) |
| `office_tiles043` | [ambientCG](https://ambientcg.com/a/Tiles043) | ambientCG | CC0 1.0 | Baldosa de terrazo claro conservada para pruebas de material. La recepción usa Tiles110. |
| `office_tiles110` | [ambientCG Tiles110](https://ambientcg.com/a/Tiles110) | ambientCG (Lennart Demes) | CC0 1.0 | Loseta vinilica (VCT) beige con motas |
| `office_walnut_veneer` | [Poly Haven walnut_veneer](https://polyhaven.com/a/walnut_veneer) | Jenelle van Heerden | CC0 1.0 | Paneles de chapa de nogal (direccion, secretaria, aparadores) |
<!-- /OFFICE_SCANS -->

## Alfombra oriental de las oficinas

| Imagen | Id | Fuente | Licencia |
|---|---|---|---|
| [Carpet, Turquía, s. XVIII (objeto 452567)](https://www.metmuseum.org/art/collection/search/452567) | `office_rug_met452567` | The Metropolitan Museum of Art, Open Access (Bequest of Joseph V. McMullan, 1973) | Dominio público (CC0) |

La foto original está en `source_assets/oficinas/alfombras/met_452567/`; en `assets/textures/office_rug_met452567/` queda recortada con su fleco, a 1024 px, con el color apagado y oscurecida para que se lea gastada (`office_fittings.rug()`).

## Modelos aportados por el usuario

Paquetes descargados por el usuario en `assets/props/*/*.zip` (fuera de git). Se extrajeron los FBX y las texturas necesarias, reducidas a 1024–2048 px; las mallas se hornean con `tools/props/build_model_props.gd`. El sofá, el aplique y la monstera ya tienen ficha y licencia (arriba); el resto sigue por verificar antes de cualquier distribución.

- `tv/sony-trinitron-prl.zip`: televisor CRT de la escena de entrada (carcasa y pantalla separadas); desde octubre de 2026 es también el de las teles del hotel, como en el tráiler, sobre la cómoda `GothicCommode_01` de Poly Haven (CC0).
- `bedroom/bedroom-furniture-set.zip`: cama con escritorio y silla, escena de entrada.
- `other/sofa-pbr.zip`: sofá; sustituye al sofá provisional en todo el hotel. Ficha y licencia arriba (Meerschaum Digital, CC BY).
- `other/wall-lamp-2048px2.zip`: aplique de pared con pantalla de tela; dos junto a cada cuadro en recepción, vestíbulos, pasillos y galerías. Ficha y licencia arriba (Mark Peters, CC BY).
- `plants/monstera-indoor.zip`: monstera en maceta con soporte; sustituye a la planta provisional. Ficha y licencia arriba (Giora, CC BY).
- `plants/indoor-plant-dieffenbachia.zip`: sin usar (solo `.blend`, que Godot no importa sin Blender).
- `door/door-wooden-old-9mb.zip`: puerta de madera antigua con marco, pomo y bisagras (el archivo trae dos copias, cerrada y entreabierta; se usa la cerrada, nodo `01`). FBX en `assets/props/door/door.fbx` y texturas de 1024 px (`leaf_*` para la hoja, `frame_*` para marco y herrajes), materiales `door_leaf.tres` y `door_frame.tres`. `tools/props/build_door.gd` hornea `door_leaf.res` (hoja con pomo, bisagra en el origen) y `door_frame.res` (marco centrado en el vano), ajustados al vano del hotel (1,30 × 2,65 m) y no a su tamaño original (1,01 × 2,30 m de hoja). Sustituye a la hoja de caja y a las molduras de caja de todas las puertas; la colisión sigue siendo la caja de siempre.

## Candidatos y paquetes conservados

- [Hotel bed — Alex Jung](https://sketchfab.com/3d-models/hotel-bed-41ec871d6fd64719b8231ba6ecde6279): ficha revisada, CC Attribution, 738.300 triángulos aproximadamente. Descartada para instancias repetidas por su coste. No se descargó ni incorporó. El navegador accesible mostraba LOGIN, sin compartir la sesión del navegador del usuario.
- `the-sunmandoctor-nowhere.zip`: contiene `source/model (1).gltf` y una textura externa. Conservado para el piso de Sunman; no se ha incorporado todavía al hotel.
- `the-boy-and-the-bath-v2-doctor-nowhere-old.zip`: contiene otro ZIP en `source/` y texturas. Se conserva como material adicional en evaluación, sin sustituir a un enemigo del diseño.
- No se extrajeron ni modificaron esos paquetes durante P1. Su licencia y autoría deben verificarse antes de integrarlos/distribuirlos.

## Assets del prototipo histórico

Las secciones siguientes conservan la procedencia del H1 anterior. El mismo GLB de Locust sigue activo en el hotel; los originales no se modificaron.

## The Locust

- Archivo recibido del usuario: `source_assets/locust.zip`.
- Fuente del archivo incorporado: `source/locust.glb` dentro del ZIP.
- Archivo en uso: `assets/enemies/locust.glb` (15.303.916 bytes).
- Creador del modelo: Doumty, identificado en los nombres de texturas `locust_by-doumty_*` y en la ficha correspondiente.
- Personaje original: Doctor Nowhere.
- Ficha: https://sketchfab.com/3d-models/toe-locust-by-doumty-cd344df3cdc04fb5b8d1ca73a8a26c37
- Ficha original de Workshop enlazada por el autor: https://steamcommunity.com/sharedfiles/filedetails/?id=3544392594
- Licencia comprobada de nuevo el 19/10/2026 en la API pública de Sketchfab (ficha «T.O.E Locust - By Doumty», publicada el 18/10/2025): sigue siendo **CC BY-NC-ND 4.0**.
- Licencia anunciada en la ficha consultada el 16/09/2026: **CC Attribution-NonCommercial-NoDerivs**. El archivo suministrado no incluye un documento de licencia. La apertura directa de la ficha devolvió 403, pero el índice consultado muestra explícitamente esta licencia; comprobar la versión y sus condiciones con el autor antes de distribuir.
- Adaptación local: H1 conserva escala 1,9× y pose estática. El hotel usa 1,65× (altura medida 2,46 m), oscilación procedural de huesos y preparación visual de ataque. Es animación provisional, no un paquete final de animaciones. El GLB y sus texturas originales se mantienen sin modificar; los permisos pendientes de distribución no cambian.

No atribuir este modelo a xerio3900 ni aplicar la licencia CC BY del candidato anterior: se trata de un modelo distinto. No presentar el asset como oficial de Doctor Nowhere ni suponer autorización comercial. Resolver el permiso de distribución de esta integración y sus adaptaciones, o sustituirla, antes de una entrega pública.

## The Lurker (la criatura del piso 2)

- **Modelo, esqueleto, animaciones y textura de la cara: hechos para este proyecto** el 21/10/2026, generados por los scripts de `tools/art/lurker/` (Blender 5.2). No contienen nada descargado.
- **Se modeló a partir de una imagen** que aportó el autor ese día (`art/lurker/referencia.webp`, una pintura de terror analógico de una bestia en una escalera): el autor la da por de libre uso, sin licencia ni condiciones. No se sabe quién la pintó ni se ha comprobado de dónde sale; el modelo no incluye la imagen, pero su diseño es el de esa criatura. Conviene confirmar su origen antes de una entrega pública.
- Archivos: `art/lurker/lurker.blend` (fuente, con la escena de comparación), `assets/enemies/lurker/lurker.glb` (lo que importa Godot), sus tres materiales `.tres` (cuerpo, cara, ojos y dientes) y la textura que Godot extrae del GLB, y en `game/enemies/lurker/` la escena que la planta en paredes y techos y la niebla que la envuelve (hechas para el proyecto). Cómo se hace, en [LURKER.md](LURKER.md).

## Sonidos de las oficinas (piso 2)

`tools/audio/prepare_office_sfx.py` saca copias de trabajo en `assets/audio/sfx/office/` de grabaciones descargadas en `source_assets/oficinas/` (cada una con su ficha en el `registro.json` de su grupo, en estado «ok»). Los originales no se tocan; los tramos de los bucles los eligió el director sin escucharlos y el autor debería oírlos.

| Copia | Original | Autor y fuente | Licencia |
|---|---|---|---|
| `typing.wav` (bucle), `typing_bell.wav` | `bsb_2835_typewriter_2.wav`, `bsb_2844_typewriter_bell_1.wav` | Joseph SARDIN, BigSoundBank | CC0 |
| `tube_hiss.wav` (bucle), `tube_bell.wav` | `bsb_0138_compressed_air.wav`, `bsb_1922_industrial_bell_2.wav` | BigSoundBank | CC0 |
| `lever_1..3.wav`, `breaker.wav` | `bsb_3061..3063_industrial_switch_*.flac`, `bsb_1092_electric_circuit_breaker.flac` | BigSoundBank | CC0 |
| `tick.wav` (bucle) | `bsb_0082_timer_2_kitchen.flac` | BigSoundBank | CC0 |
| `lift_motor.wav` | `bsb_1712_elevator_6_floors.flac` | BigSoundBank | CC0 |
| `fans.wav` (bucle) | `bsb_3598_ventilation_5.flac` | BigSoundBank | CC0 |
| `hatch.wav` | `bsb_0773_metal_filing_cabinet.wav` | BigSoundBank | CC0 |
| `crawl_1.wav`, `crawl_2.wav` | `pixabay_83044_heater_vent_hit_lower_evdawg.mp3`, `pixabay_103305_heater_vent_hit_higher_evdawg.mp3` | Ev-Dawg, Pixabay | Pixabay Content License |
| `phone_ring.wav` (bucle: un timbrazo y su pausa; para las mentiras de The Lurker) | `bsb_3532_socotel_discreet_rings.wav` | Joseph SARDIN, BigSoundBank | CC0 |
| `copier.wav` (sus primeros 4 s) | `soundbible_2169_photocopy_machine.wav` | Daniel Simion, [SoundBible.com](https://soundbible.com/2169-Photocopy-Machine.html), en los créditos del juego | CC BY 3.0 |
| `chair_roll.wav` | `oga_nicolemariet_office_chair_roll.wav` | Nicole Marie T, [OpenGameArt](https://opengameart.org/content/office-chair-roll-sfx-sound-effect), en los créditos del juego (conviene confirmar la licencia en su propia página antes de publicar) | CC BY 4.0 |
| `starter.wav` (sus primeros 3 s) | `pixabay_61228_faulty_fluorescent_starter_hum_everydaysounds.mp3` | EverydaySounds, Freesound (CC0), en Pixabay | Pixabay Content License |
| `ladder.wav` | `pixabay_76052_ladder_aluminum_erik90.mp3` | erik90, Pixabay | Pixabay Content License |

## Sonidos de The Lurker (piso 2)

`tools/audio/prepare_lurker_sfx.py` hace su aviso y su chillido en `assets/audio/sfx/lurker/` con grabaciones de animales descargadas en `source_assets/oficinas/audio_criatura/` (fichas en estado «ok»): nada sintetizado y nada humano. Cada aviso es una exhalación entera de caballo desde su primer sonido y dos chasquidos de hueso o nudillo pasados por un filtro paso alto a 2 kHz; el primero a 0,70 s. El aviso cuenta su ventana desde que suena, así que el guion falla si una copia tarda más de 20 ms en empezar (empiezan a unos 16 ms). En Pesadilla, con 1,2 s de ventana, quedan unos 0,5 s tras el primer chasquido.

| Copia | Original | Autor y fuente | Licencia |
|---|---|---|---|
| `cue_0.wav`, `cue_2.wav` (respiración) | `bsb_0285_breath_of_a_horse_1.mp3` | DenisChardonnet, BigSoundBank | CC0 |
| `cue_1.wav` (respiración) | `bsb_1543_breath_horse_4.mp3` | Joseph SARDIN, BigSoundBank | CC0 |
| `cue_short_0..2.wav` (el mismo aviso, más corto: medio segundo de respiración y los dos chasquidos detrás; para las ventanas de menos de 1,2 s) | los de `cue_0..2.wav` | los de `cue_0..2.wav` | CC0; Pixabay Content License |
| `cue_0..2.wav` (chasquidos) | `bsb_0596_bones_cracking_1.mp3`; `freesound_community-knuckles-cracking-98331.mp3` | Joseph SARDIN, BigSoundBank; borq1, Freesound, por freesound_community en Pixabay | CC0; Pixabay Content License |
| `scare_0.wav`, `scare_1.wav` | `bsb_1400_barn_owl_1.mp3`, `bsb_1403_barn_owl_2.mp3` | Joseph SARDIN, BigSoundBank | CC0 |

El mismo guion hace sus sonidos en el piso (fase 3): las garras según lo que hay bajo cada mano, los golpes dentro de un ducto, el falso techo que cruje, su presencia y su mordisco. Cada copia es un tramo de su original elegido por el guion sin escucharlo (los picos más fuertes, o la ventana más fuerte), a veces más grave y con un filtro; el autor debería oírlos. Todos los de Pixabay son grabaciones de Freesound que freesound_community subió a Pixabay.

| Copia | Original | Autor y fuente | Licencia |
|---|---|---|---|
| `tile_1..6.wav` (garras en una placa) | `freesound_community-scratching-on-box-40160.mp3` | MrTeeXD, Freesound, en Pixabay | Pixabay Content License |
| `tile_creak_1..3.wav` (la perfilería) | `freesound_community-air-conditioner-vent-metal-ring-clank-26871.mp3` | rsellick, Freesound, en Pixabay | Pixabay Content License |
| `tile_grind.wav` | `freesound_community-grinding-styrofoam-46849.mp3` | lurpsis, Freesound, en Pixabay | Pixabay Content License |
| `dust_1.wav` | `freesound_community-sandfall5-83468.mp3` | Wagna (sobre una grabación de lolamadeus), Freesound, en Pixabay | Pixabay Content License |
| `dust_2.wav` | `freesound_community-gravel-stone-dirt-debris-falling-small-1-3-36216.mp3` | Sheyvan, Freesound, en Pixabay | Pixabay Content License |
| `metal_1..4.wav`, `scrape_1.wav` (chapa) | `freesound_community-20131209_fingernail-on-elevator-ceiling_olympusls10_xy-87239.mp3` | Soundscape_Leuphana, Freesound, en Pixabay | Pixabay Content License |
| `knock_1..6.wav` (dentro del ducto) | `freesound_community-duct-impacts-76170.mp3` | j1987, Freesound, en Pixabay | Pixabay Content License |
| `knock_7.wav`, `knock_8.wav` | `freesound_community-heater-vent-hit-lower-part-83044.mp3`, `freesound_community-heater-vent-hit-higher-part-103305.mp3` | Ev-Dawg, Freesound, en Pixabay | Pixabay Content License |
| `hard_1..8.wav` (yeso, bloque y suelos duros) | `freesound_community-claws-on-smooth-rock-65642.mp3` | magzlurban, Freesound, en Pixabay | Pixabay Content License |
| `drag_1.wav`, `drag_2.wav` | `freesound_community-plaster-screaming-55526.mp3` | tlipfert, Freesound, en Pixabay | Pixabay Content License |
| `wood_1..8.wav` (chapa de madera) | `freesound_community-skittering-dog-33523.mp3` | sittingmonkeyanim, Freesound, en Pixabay | Pixabay Content License |
| `wood_scratch_1.wav`, `wood_scratch_2.wav` | `freesound_community-scratching-with-fingernails-79478.mp3` | danthaiwang, Freesound, en Pixabay | Pixabay Content License |
| `presence.wav` (bucle de 20 s) | `freesound_community-breath-of-cow-78843.mp3` | bodot, Freesound, en Pixabay | Pixabay Content License |
| `bite_1.wav`, `bite_2.wav` | `bsb_1408_bones_cracking_2.mp3`, `bsb_1409_bones_cracking_3.mp3`; un chasquido de `freesound_community-knuckles-cracking-98331.mp3` | Joseph SARDIN, BigSoundBank; borq1, Freesound, en Pixabay | CC0; Pixabay Content License |

## Modelos de las oficinas (piso 2)

- **Cráneo de los restos del ducto principal:** OpenGameArt «Human Skull», de CDmir, CC0 (`source_assets/oficinas/equipos/human_skull_oga/`, con su ficha en el `registro.json`). En `assets/props/office/skull/`: el OBJ sin su biblioteca de materiales y tres texturas reducidas a 512 px (color, normal y rugosidad). `main_duct_geometry.gd` lo pone a 0,073 de su tamaño (unos 0,14 m de ancho).
- La mesa metálica y la silla apilable de Poly Haven (CC0) van con el resto de modelos de Poly Haven, arriba.

## Música

- Archivo recibido: `source_assets/song.mp3`.
- Archivo en uso: `assets/audio/the_four_theme.mp3`.
- Tamaño: 6.154.797 bytes. Duración medida por Godot: 384,63 s (6:24,63).
- Copia idéntica al original, comprobada por SHA-256.
- La cabecera ID3v2.4 no aporta título, artista, álbum ni copyright. No se deducen del nombre de archivo ni de otras aplicaciones abiertas.
- Autor, título y licencia: pendientes de aportar/verificar. Uso actual en prototipo local a petición del usuario; no se asume que sea música libre para distribuir.
- Cambios de reproducción: bucle completo, entrada gradual, bus Music, volumen inicial −22 dB, tecla M para silenciar y −/+ para ajustar. No se ha recortado ni alterado el MP3.

## Resto del prototipo

Mapa, materiales planos, luces y lógica: creados para este proyecto. El modelo geométrico provisional de la primera versión permanece únicamente como alternativa en el generador si falta el GLB; la escena actual utiliza el modelo importado.

El ZIP contiene cinco PNG externos adicionales. El GLB incorpora sus propias imágenes y no necesita copiar esos PNG al árbol de recursos. Se conservan íntegros dentro del ZIP original.

## Conservación

`docs/asset_hashes.json` registra tamaño y huellas SHA-256 de los originales y las copias usadas. Los originales están en `source_assets/`, carpeta local ignorada por Git y Godot. Los recursos efectivos del juego sí están versionados en el repositorio local. No se ha publicado ni subido el proyecto a un servicio externo.

## Organización posterior de originales

Los cinco audios nuevos ahora están en `source_assets/audio/`; Sunman y The Boy and The Bath están en `source_assets/characters/`. El ambiente activo sigue en `assets/audio/hotel/ambience.wav`. Se conservaron todos los bytes originales; `docs/assets/originals_manifest.json` registra sus nuevas rutas y SHA-256. No se cambiaron permisos ni se incorporaron assets nuevos.

## Paquete sfx

**La sangre** (`sfx/blood/` → `assets/audio/sfx/blood/`, copiados tal cual): cinco archivos que el autor descargó y cortó el 13 de octubre de 2026 de dos grabaciones de Freesound, las dos **Creative Commons 0** (comprobado en su página): «Blood Gush», de FlaxGod (https://freesound.org/people/FlaxGod/sounds/654101/: un trapo mojado escurrido, Zoom H1) → `blood-gush-1..4.ogg`; y «Blood Gush / Spray», de clif_creates (https://freesound.org/people/clif_creates/sounds/345985/: un pomelo exprimido, grabado de cerca) → `hemorrhage.ogg`. No piden atribución; se anota de dónde salen. `assets/decals/blood_atlas.png` no viene de ningún sitio: lo dibuja `tools/textures/bake_blood.py`.

33 sonidos aportados en `sfx/`, conservados sin modificación. Seis de ellos tienen ficha y licencia (Freesound, arriba) sin que se sepa todavía qué archivo es cada uno; otros dos, `creaky-wooden-door-slow-opening.mp3` y `sub-riser-presence.wav`, eran «DOOR creak» y «Sub Riser», y salieron del juego el 19/10/2026. Las copias activas y preparadas están en `assets/audio/sfx/`; [AUDIO.md](AUDIO.md) distingue 23 asignaciones actuales y diez reservas. Inventario con SHA-256 en `docs/assets/sfx_inventory.json`. Origen/autoría y permisos de distribución pendientes; no se atribuye licencia libre por el nombre del archivo.
