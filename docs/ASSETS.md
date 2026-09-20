# Assets y créditos

Procedencia, licencias y permisos pendientes de todo lo que entra en el juego. Mientras queden permisos sin resolver, no se distribuye.

## Hotel actual

- Cartel de salida del refugio: lámina, luminaria y grabado originales. Las letras y la flecha las dibuja `tools/textures/make_exit_sign.py` como contornos propios en `assets/props/exit_sign/engraving.png`; no se usa ni se embarca ningún archivo de fuente.
- Arquitectura modular, veinte definiciones espaciales y mobiliario provisional: geometría original creada para este proyecto. No se atribuye a Sketchfab.
- Materiales: shaders procedurales propios (motivo del papel, medallones de la moqueta, desgaste y suciedad) sobre materiales escaneados CC0, listados abajo en «Materiales escaneados». Las cortinas siguen siendo solo procedurales.
- Pasos y señal de preparación de ataque: síntesis original en ejecución, sin muestras externas. Los sonidos de la ejecución (`assets/audio/events/execution_*.wav`), incluido el grito del agarre, son síntesis propia y determinista: `tools/audio/generate_event_sfx.py` y `tools/audio/generate_screamer.py`, sin muestras de terceros. Polvo, cortinas, niebla localizada y sondas de reflexión creados dentro de Godot. No se añadieron muebles externos.
- Copia utilizada: `assets/audio/hotel/ambience.wav`, idéntica al original `ambience.wav` de la raíz. SHA-256: `7f873c02a389c4da33befb3da559d613a98aa4cc051f91c805a7782c4d72adb1`.
- Ambiente: 410,46 s, estéreo, 11.025 Hz, PCM de 8 bits. Se reproduce en bucle y a volumen reducido; el original no se modifica. Autoría/licencia pendientes de verificar.
- Los otros cuatro audios nuevos quedan conservados para la selección de la etapa 2. Detalles técnicos en `hotel_audio_inventory.json`. La voz tiene un nivel notablemente mayor que el ambiente y requiere edición/mezcla antes de incorporarla.
- `deep_ambiance.flac`: conservar original; preparar copia en formato admitido por el importador al integrarlo. Todavía no se carga en el juego.
- La música anterior sigue en su bus separado. Su estado de permisos no cambia.

## Aportado por el usuario, con su ficha (revisado el 19/09/2026)

Assets que el usuario descargó e incorporó al juego. Cada ficha se abrió y se anotó tal cual la publica su autor. **Todos se acreditan en la pantalla de créditos del juego** (`game/ui/hotel_ui.gd`, `CREDITS`).

### Personajes jugables (`assets/players/`)

| Carpeta | Modelo | Autoría | Licencia | Ficha |
|---|---|---|---|---|
| `detective` | detective | haider706 | CC Attribution 4.0 | [Sketchfab](https://sketchfab.com/3d-models/detective-b1de47c043314837a844698f2380daad) |
| `detective_woman` | Debra — Detective Woman (Game Model) | Zukomazi | CC Attribution 4.0 | [Sketchfab](https://sketchfab.com/3d-models/debra-detective-woman-game-model-208e5cf748404521894bf30c95f25c12) |
| `realistic_female` | Realistic Female | Biviyt | **CC Attribution-ShareAlike 4.0** | [Sketchfab](https://sketchfab.com/3d-models/realistic-female-b0cc2a6c26114da184252e433cf75d23) |

### Mobiliario (`assets/props/`)

| Carpeta | Modelo | Autoría | Licencia | Ficha |
|---|---|---|---|---|
| `sofa` | Sofa (Game Ready / 2K PBR) | Meerschaum Digital, sobre «Old Sofa (FREE)» de VISJA FILIP RUMIN | CC Attribution | [Sketchfab](https://sketchfab.com/3d-models/sofa-game-ready-2k-pbr-959bc21f62964c068e441622e8d1103a) |
| `monstera` | Monstera Deliciosa Potted Mid-Century plant | Giora (ChubbyPanda) | CC Attribution | [Sketchfab](https://sketchfab.com/3d-models/monstera-deliciosa-potted-mid-century-plant-1ab9bf841df04c07b1819be596327629) |
| `wall_lamp` | Wall Lamp — 2048px² | Mark Peters | CC Attribution | [Sketchfab](https://sketchfab.com/3d-models/wall-lamp-2048px2-487c69d1748c46d2b3cc433fe6885a5e) |

Siguen sin ficha, y por tanto sin licencia comprobada: el televisor de la escena de entrada, el dormitorio de esa misma escena, la puerta de madera y el armario.

### Sonido (Freesound)

El usuario aportó estos ocho; el reparto archivo por archivo dentro de `assets/audio/` todavía no está anotado (pendiente de que el usuario diga cuál es cuál).

| Sonido | Autoría | Licencia | Ficha |
|---|---|---|---|
| Bed sheets (SoundAction 104) | alexarje | CC BY 4.0 | [863082](https://freesound.org/people/alexarje/sounds/863082/) |
| men_sneaker_shoes_walking_sound_09262024 | Artninja | CC BY 4.0 | [757366](https://freesound.org/people/Artninja/sounds/757366/) |
| Open letter and reading | dersuperanton | CC BY 4.0 | [434466](https://freesound.org/people/dersuperanton/sounds/434466/) |
| horror ambience 161101_1038 | klankbeeld | CC BY 4.0 | [535780](https://freesound.org/people/klankbeeld/sounds/535780/) |
| Door Opening | AUDACITIER | CC BY 4.0 | [632128](https://freesound.org/people/AUDACITIER/sounds/632128/) |
| Atmosphere 2 | oldaccount | CC BY 3.0 | [316800](https://freesound.org/people/oldaccount/sounds/316800/) |
| DOOR creak — multiple creaks wooden door | mickfire | **CC BY-NC 4.0** | [326416](https://freesound.org/people/mickfire/sounds/326416/) |
| Sub Riser | deleted_user_3277771 (Josh Mclelland) | **CC BY-NC 3.0** | [185372](https://freesound.org/people/deleted_user_3277771/sounds/185372/) |

### Lo que esto impide

- **No comercial:** los dos sonidos marcados arriba y el modelo de The Locust (CC BY-NC-ND) prohíben el uso comercial. Mientras sigan en el juego, no se puede vender ni monetizar.
- **Sin obra derivada:** la licencia de The Locust es además NoDerivs, y el hotel lo escala y le mueve los huesos. Hay que resolverlo con el autor o sustituirlo antes de publicar.
- **CompartirIgual:** «Realistic Female» obliga a distribuir bajo la misma licencia cualquier obra derivada del modelo.
- **Atribución:** todos los CC BY exigen crédito, y ya lo tienen en la pantalla de créditos. Los CC0 (ambientCG, Poly Haven) y el dominio público (Art Institute of Chicago) no lo exigen; se acreditan igualmente.

<!-- SCANS: generado por tools/textures/ingest_pbr.py, no editar a mano -->
## Materiales escaneados (fase 3 de REALISM.md)

Todos CC0 (dominio público): no exigen atribución, se acreditan igualmente. Descargas originales en `source_assets/textures/` (fuera de git); en `assets/textures/<set>/` quedan color, normal (OpenGL) y ORM a 2048 px y a 1024 px (`_1k`, preset Bajo).

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

Poly Haven, CC0 (dominio público): no exigen atribución, se acreditan igualmente. Descargas originales en `source_assets/props/` (fuera de git); en `assets/props/hotel/<id>/` quedan las texturas (1024 px, 2048 en los muebles grandes) y los materiales, y `tools/props/build_catalogue.gd` hornea `assets/props/hotel/<id>.res`.

| Modelo | Autoría | Licencia |
|---|---|---|
| [Arm Chair 01](https://polyhaven.com/a/ArmChair_01) | Kirill Sannikov | CC0 1.0 |
| [Cash Register 01](https://polyhaven.com/a/CashRegister_01) | Joe Seabuhr | CC0 1.0 |
| [Chandelier 01](https://polyhaven.com/a/Chandelier_01) | Kirill Sannikov | CC0 1.0 |
| [Classic Console 01](https://polyhaven.com/a/ClassicConsole_01) | Kirill Sannikov | CC0 1.0 |
| [Classic Nightstand 01](https://polyhaven.com/a/ClassicNightstand_01) | Kirill Sannikov | CC0 1.0 |
| [Gothic Bed 01](https://polyhaven.com/a/GothicBed_01) | Kirill Sannikov | CC0 1.0 |
| [Gothic Commode 01](https://polyhaven.com/a/GothicCommode_01) | Kirill Sannikov | CC0 1.0 |
| [Green Chair 01](https://polyhaven.com/a/GreenChair_01) | Kirill Sannikov | CC0 1.0 |
| [Ottoman 01](https://polyhaven.com/a/Ottoman_01) | Caspian Fortune | CC0 1.0 |
| [Sofa 01](https://polyhaven.com/a/Sofa_01) | Kirill Sannikov | CC0 1.0 |
| [Wet Floor Sign 01](https://polyhaven.com/a/WetFloorSign_01) | Fran Calvente | CC0 1.0 |
| [Alarm Clock 01](https://polyhaven.com/a/alarm_clock_01) | Yann Kervran, James Ray Cock | CC0 1.0 |
| [Bleach Bottle](https://polyhaven.com/a/bleach_bottle) | James Ray Cock | CC0 1.0 |
| [Book Encyclopedia Set 01](https://polyhaven.com/a/book_encyclopedia_set_01) | John Malcolm | CC0 1.0 |
| [Brass Vase 02](https://polyhaven.com/a/brass_vase_02) | Rico Cilliers | CC0 1.0 |
| [Cardboard Box 01](https://polyhaven.com/a/cardboard_box_01) | Rahul Chaudhary | CC0 1.0 |
| [Ceramic Vase 01](https://polyhaven.com/a/ceramic_vase_01) | James Ray Cock | CC0 1.0 |
| [Cigarette Pack](https://polyhaven.com/a/cigarette_pack) | Ulrich Büch | CC0 1.0 |
| [Clipboard](https://polyhaven.com/a/clipboard) | ProgrammerOnCoffee | CC0 1.0 |
| [Dining Chair 02](https://polyhaven.com/a/dining_chair_02) | James Ray Cock | CC0 1.0 |
| [Drawer Cabinet](https://polyhaven.com/a/drawer_cabinet) | Ulan Cabanilla | CC0 1.0 |
| [Fancy Picture Frame 01](https://polyhaven.com/a/fancy_picture_frame_01) | Rob Tuytel, Rico Cilliers | CC0 1.0 |
| [Hanging Picture Frame 02](https://polyhaven.com/a/hanging_picture_frame_02) | James Ray Cock | CC0 1.0 |
| [Industrial Storage Cart](https://polyhaven.com/a/industrial_storage_cart) | Jule Bielitz | CC0 1.0 |
| [Jug 01](https://polyhaven.com/a/jug_01) | Kuutti Siitonen | CC0 1.0 |
| [Metal Office Desk](https://polyhaven.com/a/metal_office_desk) | Ulan Cabanilla | CC0 1.0 |
| [Metal Trash Can](https://polyhaven.com/a/metal_trash_can) | GurJas Studios | CC0 1.0 |
| [Modern Arm Chair 01](https://polyhaven.com/a/modern_arm_chair_01) | Vibrant Nordic | CC0 1.0 |
| [Multi Cleaner Bottle](https://polyhaven.com/a/multi_cleaner_bottle) | James Ray Cock | CC0 1.0 |
| [Office Notepads](https://polyhaven.com/a/office_notepads) | Ulan Cabanilla | CC0 1.0 |
| [Ornate Mirror 01](https://polyhaven.com/a/ornate_mirror_01) | James Ray Cock | CC0 1.0 |
| [Painted Wooden Cabinet](https://polyhaven.com/a/painted_wooden_cabinet) | Kirill Sannikov | CC0 1.0 |
| [Plastic Crate 02](https://polyhaven.com/a/plastic_crate_02) | Fabi_G | CC0 1.0 |
| [Round Wooden Table 01](https://polyhaven.com/a/round_wooden_table_01) | Ulan Cabanilla | CC0 1.0 |
| [Side Table Tall 01](https://polyhaven.com/a/side_table_tall_01) | James Ray Cock | CC0 1.0 |
| [Small Wooden Table 01](https://polyhaven.com/a/small_wooden_table_01) | Ulan Cabanilla | CC0 1.0 |
| [Sofa 03](https://polyhaven.com/a/sofa_03) | Fran Calvente | CC0 1.0 |
| [Stationery Supplies](https://polyhaven.com/a/stationery_supplies) | Mateusz Sadek | CC0 1.0 |
| [Steel Frame Shelves 01](https://polyhaven.com/a/steel_frame_shelves_01) | James Ray Cock | CC0 1.0 |
| [Television 02](https://polyhaven.com/a/television_02) | Benny Weimer | CC0 1.0 |
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

- `tv/sony-trinitron-prl.zip`: televisor CRT de la escena de entrada (carcasa y pantalla separadas).
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
- Licencia anunciada en la ficha consultada el 16/09/2026: **CC Attribution-NonCommercial-NoDerivs**. El archivo suministrado no incluye un documento de licencia. La apertura directa de la ficha devolvió 403, pero el índice consultado muestra explícitamente esta licencia; comprobar la versión y sus condiciones con el autor antes de distribuir.
- Adaptación local: H1 conserva escala 1,9× y pose estática. El hotel usa 1,65× (altura medida 2,46 m), oscilación procedural de huesos y preparación visual de ataque. Es animación provisional, no un paquete final de animaciones. El GLB y sus texturas originales se mantienen sin modificar; los permisos pendientes de distribución no cambian.

No atribuir este modelo a xerio3900 ni aplicar la licencia CC BY del candidato anterior: se trata de un modelo distinto. No presentar el asset como oficial de Doctor Nowhere ni suponer autorización comercial. Resolver el permiso de distribución de esta integración y sus adaptaciones, o sustituirla, antes de una entrega pública.

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

33 sonidos aportados en `sfx/`, conservados sin modificación. Ocho de ellos ya tienen ficha y licencia (Freesound, arriba); falta anotar qué archivo es cada uno. Las copias activas y preparadas están en `assets/audio/sfx/`; [AUDIO.md](AUDIO.md) distingue 23 asignaciones actuales y diez reservas. Inventario con SHA-256 en `docs/assets/sfx_inventory.json`. Origen/autoría y permisos de distribución pendientes; no se atribuye licencia libre por el nombre del archivo.
