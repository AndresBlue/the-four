# Assets y créditos — 0.4-P1

## Hotel actual

- Arquitectura modular, veinte definiciones espaciales y mobiliario provisional: geometría original creada para este proyecto. No se atribuye a Sketchfab.
- Materiales de papel mural y moqueta: shaders procedurales propios. El resto usa materiales básicos; no son texturas fotorrealistas descargadas.
- Copia utilizada: `assets/audio/hotel/ambience.wav`, idéntica al original `ambience.wav` de la raíz. SHA-256: `7f873c02a389c4da33befb3da559d613a98aa4cc051f91c805a7782c4d72adb1`.
- Ambiente: 410,46 s, estéreo, 11.025 Hz, PCM de 8 bits. Se reproduce en bucle y a volumen reducido; el original no se modifica. Autoría/licencia pendientes de verificar.
- Los otros cuatro audios nuevos quedan conservados para la selección de la etapa 2. Detalles técnicos en `hotel_audio_inventory.json`. La voz tiene un nivel notablemente mayor que el ambiente y requiere edición/mezcla antes de incorporarla.
- `deep_ambiance.flac`: conservar original; preparar copia en formato admitido por el importador al integrarlo. Todavía no se carga en el juego.
- La música anterior sigue en su bus separado. Su estado de permisos no cambia.

## Candidatos y paquetes conservados

- [Hotel bed — Alex Jung](https://sketchfab.com/3d-models/hotel-bed-41ec871d6fd64719b8231ba6ecde6279): ficha revisada, CC Attribution, 738.300 triángulos aproximadamente. Descartada para instancias repetidas por su coste. No se descargó ni incorporó. El navegador accesible mostraba LOGIN, sin compartir la sesión del navegador del usuario.
- `the-sunmandoctor-nowhere.zip`: contiene `source/model (1).gltf` y una textura externa. Conservado para el piso de Sunman; no se ha incorporado todavía al hotel.
- `the-boy-and-the-bath-v2-doctor-nowhere-old.zip`: contiene otro ZIP en `source/` y texturas. Se conserva como material adicional en evaluación, sin sustituir a un enemigo del diseño.
- No se extrajeron ni modificaron esos paquetes durante P1. Su licencia y autoría deben verificarse antes de integrarlos/distribuirlos.

## Assets del prototipo histórico

Las secciones siguientes documentan el H1 anterior. Locust sigue disponible en esa escena; no hay una criatura activa en el hotel 0.4-P1.

## The Locust

- Archivo recibido del usuario: `source_assets/locust.zip`.
- Fuente del archivo incorporado: `source/locust.glb` dentro del ZIP.
- Archivo en uso: `assets/enemies/locust.glb` (15.303.916 bytes).
- Creador del modelo: Doumty, identificado en los nombres de texturas `locust_by-doumty_*` y en la ficha correspondiente.
- Personaje original: Doctor Nowhere.
- Ficha: https://sketchfab.com/3d-models/toe-locust-by-doumty-cd344df3cdc04fb5b8d1ca73a8a26c37
- Ficha original de Workshop enlazada por el autor: https://steamcommunity.com/sharedfiles/filedetails/?id=3544392594
- Licencia anunciada en la ficha consultada el 16/09/2026: **CC Attribution-NonCommercial-NoDerivs**. El archivo suministrado no incluye un documento de licencia. La apertura directa de la ficha devolvió 403, pero el índice consultado muestra explícitamente esta licencia; comprobar la versión y sus condiciones con el autor antes de distribuir.
- Adaptación local: escala de instancia de 1,9×, posición de apoyo y pose estática de brazos calculada en Godot. El GLB y sus texturas originales se mantienen sin modificar.

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
