# Assets y créditos — 0.4-S1

## Hotel actual

- Arquitectura modular, veinte definiciones espaciales y mobiliario provisional: geometría original creada para este proyecto. No se atribuye a Sketchfab.
- Materiales: shaders procedurales propios (motivo del papel, medallones de la moqueta, desgaste y suciedad) sobre materiales escaneados CC0, listados abajo en «Materiales escaneados». Las cortinas siguen siendo solo procedurales.
- Pasos y señal de preparación de ataque: síntesis original en ejecución, sin muestras externas. Polvo, cortinas, niebla localizada y sondas de reflexión creados dentro de Godot. No se añadieron muebles externos.
- Copia utilizada: `assets/audio/hotel/ambience.wav`, idéntica al original `ambience.wav` de la raíz. SHA-256: `7f873c02a389c4da33befb3da559d613a98aa4cc051f91c805a7782c4d72adb1`.
- Ambiente: 410,46 s, estéreo, 11.025 Hz, PCM de 8 bits. Se reproduce en bucle y a volumen reducido; el original no se modifica. Autoría/licencia pendientes de verificar.
- Los otros cuatro audios nuevos quedan conservados para la selección de la etapa 2. Detalles técnicos en `hotel_audio_inventory.json`. La voz tiene un nivel notablemente mayor que el ambiente y requiere edición/mezcla antes de incorporarla.
- `deep_ambiance.flac`: conservar original; preparar copia en formato admitido por el importador al integrarlo. Todavía no se carga en el juego.
- La música anterior sigue en su bus separado. Su estado de permisos no cambia.

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

## Modelos aportados en 0.4-S1

Paquetes descargados por el usuario en `assets/props/*/*.zip` (fuera de git). Se extrajeron los FBX y las texturas necesarias, reducidas a 1024–2048 px; las mallas se hornean con `tools/props/build_model_props.gd`. Autoría y licencia por verificar antes de cualquier distribución.

- `tv/sony-trinitron-prl.zip`: televisor CRT de la escena de entrada (carcasa y pantalla separadas).
- `bedroom/bedroom-furniture-set.zip`: cama con escritorio y silla, escena de entrada.
- `other/sofa-pbr.zip`: sofá Chesterfield; sustituye al sofá provisional en todo el hotel.
- `other/wall-lamp-2048px2.zip`: aplique de pared con pantalla de tela; dos junto a cada cuadro en recepción, vestíbulos, pasillos y galerías (solo emisivo, sin luz propia).
- `plants/monstera-indoor.zip`: monstera en maceta con soporte; sustituye a la planta provisional.
- `plants/indoor-plant-dieffenbachia.zip`: sin usar (solo `.blend`, que Godot no importa sin Blender).
- `door/door-wooden-old-9mb.zip`: puerta de madera antigua con marco, pomo y bisagras (el archivo trae dos copias, cerrada y entreabierta; se usa la cerrada, nodo `01`). FBX en `assets/props/door/door.fbx` y texturas de 1024 px (`leaf_*` para la hoja, `frame_*` para marco y herrajes), materiales `door_leaf.tres` y `door_frame.tres`. `tools/props/build_door.gd` hornea `door_leaf.res` (hoja con pomo, bisagra en el origen) y `door_frame.res` (marco centrado en el vano), ajustados al vano del hotel (1,30 × 2,65 m) y no a su tamaño original (1,01 × 2,30 m de hoja). Sustituye a la hoja de caja y a las molduras de caja de todas las puertas; la colisión sigue siendo la caja de siempre.

## Candidatos y paquetes conservados

- [Hotel bed — Alex Jung](https://sketchfab.com/3d-models/hotel-bed-41ec871d6fd64719b8231ba6ecde6279): ficha revisada, CC Attribution, 738.300 triángulos aproximadamente. Descartada para instancias repetidas por su coste. No se descargó ni incorporó. El navegador accesible mostraba LOGIN, sin compartir la sesión del navegador del usuario.
- `the-sunmandoctor-nowhere.zip`: contiene `source/model (1).gltf` y una textura externa. Conservado para el piso de Sunman; no se ha incorporado todavía al hotel.
- `the-boy-and-the-bath-v2-doctor-nowhere-old.zip`: contiene otro ZIP en `source/` y texturas. Se conserva como material adicional en evaluación, sin sustituir a un enemigo del diseño.
- No se extrajeron ni modificaron esos paquetes durante P1. Su licencia y autoría deben verificarse antes de integrarlos/distribuirlos.

## Assets del prototipo histórico

Las secciones siguientes conservan la procedencia del H1 anterior. El mismo GLB de Locust también está activo en el hotel 0.4-S1; los originales no se modificaron.

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

33 sonidos originales aportados en `sfx/`, conservados sin modificación. Las copias activas y preparadas están en `assets/audio/sfx/`; [AUDIO.md](AUDIO.md) distingue 23 asignaciones actuales y diez reservas. Inventario con SHA-256 en `docs/assets/sfx_inventory.json`. Origen/autoría y permisos de distribución pendientes; no se atribuye licencia libre por el nombre del archivo.
