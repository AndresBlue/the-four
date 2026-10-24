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

El ascensor se usa entero, salvo la pared empapelada que trae alrededor, porque el coche va detrás de una pared del propio hotel. Su FBX está en `assets/props/elevator/elevator.fbx` y sus texturas en la misma carpeta (madera, suelo, metal, botonera con sus mapas de emisión y de metal, y botones de llamada), con los materiales `lift_*.tres`. `tools/props/build_elevator.gd` lo hornea a 0,8 de su tamaño en cinco piezas, todas en el espacio del coche:
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
<!-- /DRESSING -->

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
| `tube_hiss.wav` (bucle, sin usar aún), `tube_bell.wav` | `bsb_0138_compressed_air.wav`, `bsb_1922_industrial_bell_2.wav` | BigSoundBank | CC0 |
| `lever_1..3.wav`, `breaker.wav` | `bsb_3061..3063_industrial_switch_*.flac`, `bsb_1092_electric_circuit_breaker.flac` | BigSoundBank | CC0 |
| `tick.wav` (bucle) | `bsb_0082_timer_2_kitchen.flac` | BigSoundBank | CC0 |
| `lift_motor.wav` | `bsb_1712_elevator_6_floors.flac` | BigSoundBank | CC0 |
| `fans.wav` (bucle) | `bsb_3598_ventilation_5.flac` | BigSoundBank | CC0 |
| `hatch.wav` | `bsb_0773_metal_filing_cabinet.wav` | BigSoundBank | CC0 |
| `crawl_1.wav`, `crawl_2.wav` | `pixabay_83044_heater_vent_hit_lower_evdawg.mp3`, `pixabay_103305_heater_vent_hit_higher_evdawg.mp3` | Ev-Dawg, Pixabay | Pixabay Content License |
| `ladder.wav` | `pixabay_76052_ladder_aluminum_erik90.mp3` | erik90, Pixabay | Pixabay Content License |

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
