# Assets y créditos — 0.2

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
