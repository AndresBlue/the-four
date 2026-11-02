# Área 4d: lo que sobrevive de la revisión de costuras

Revisión de los hallazgos contra el árbol de ahora, con U8 y U11 ya escritas, leyendo código y logs. No se ha ejecutado Godot: lo marcado «estimación» es aritmética, no medida. Las líneas son las de este árbol.

## 1. La regla de U15 y lo que hay que decidir antes

Los hallazgos no vieron esto, y pesa más que todo lo demás: **tal como está escrita, U15 acabará casi seguro en `NINGUNA CUMPLE`, y por tiempo, no por colocación.**

**R1. `-- 200` no cabe en los 590 s.**
- U15 dice: «Un pase cortado a los 590 s, que no deja cifras, no cumple».
- La base ya rozó el corte: `4d_base/head.txt` a las 06:13:37 y `metrics_200.log` a las 06:23:23, unos 586 s.
- Hoy, 40 pisos tardan 130 s en la parte B y 154 s en la C (entre los ficheros anteriores y `4d_revB2_metrics`, `4d_revC_metrics40`). Estimación para 200: de 650 a 770 s.
- `--survivors=5` con 100 pisos queda en unos 470 a 560 s (estimación).
- **Arreglo mínimo en el encargo de U15:** `-- 200` en segundo plano con `timeout 1500`, sin el corte de 590 s, y sin otro Godot al lado (el umbral dice «solo» porque se mide a solas).

**R2. La mediana de 2000 ms en `--survivors=5` es casi inalcanzable.**
- Los únicos datos del mismo día (23 de octubre, antes del rediseño) dan: 668 ms con 1 superviviente, 1281 con 2 y 1851 con 5 (`office_metrics_200_s1.log`, `office_metrics.json`, `office_metrics_200_s5.log`). Con 5 es 1,45 veces lo de 2.
- La base de hoy con 2 es 1962 ms. Estimación con 5: unos 2800 ms. U0 no midió ese pase.
- Para cumplir con 5, el pase de 2 tendría que bajar a unos 1385 ms. Los arreglos de la sección 4 no llegan.
- Las candidatas no cambian el número de salas (`ROOMS`), así que no hay motivo para esperar que el tiempo baje mucho.
- **Decisión del director:** o la mediana solo en `-- 200` (mi recomendación), o un umbral por pase con `-- 100 --survivors=5` a 2000 × 1,45. D8 lo fijó para todos los pases, así que el cambio es suyo.

**R3. Si la candidata 1 cae por tiempo, la cadena acaba mal.** La candidata 3 no puede cumplir la aceptación 4 (defecto G7), y cada vuelta completa de U15 son muchos minutos de máquina.

## 2. `office_lies_test`: el diagnóstico

**Se sostiene: el defecto está en cómo muestrea la prueba, y no hay defecto de colocación demostrado. Cambiar de semilla no lo arregla.**

**Hechos comprobados:**
- `verify_office_lies_test.log` (06:04) da 17/17. `4d_u7fix_lies.stdout` (08:08) y `4d_revB2_lies.stdout` (08:20) dan 16/17, con `{ "corner": 1, "partition": 1 }` ofrecidas.
- `4d_u7fix_lies_baseline.stdout` (08:09) da el mismo fallo. No sé sobre qué árbol corrió, así que no separa nada.
- `encargos_rd4d.json` no nombra `office_lies` ni una vez: solo lo recoge `verify.ps1:45`.
- La sonda `4d_revB2_faces.stdout` da para la semilla 81 32 mamparas en 8 salas, con 1 ofrecida y 0 aceptadas. También fallan la 1 (12 mamparas, 0 ofrecidas) y casi la 3 (1 aceptada). Otras aceptan decenas: 7, 21, 33, 2 y 4.

**Por qué pasa (`tests/office/office_lies_test.gd:224-238`):**
- La prueba solo se coloca en centros de sala y con 4 orientaciones.
- La banda es de 31,8° a 63,3° (`creature_sight.gd:32,148`). Con pasos de 90° solo entran los rumbos a 26,7° o más de un eje, el 40,7 % de la brújula. La cuenta está bien.
- Las mamparas salen agrupadas, 4 por sala: `DESKS_MOST` 8 deja 2 cabinas de 3 piezas (`office_generator.gd:1778`).
- Solo hay cabinas en los salones (`HALL_MIX`, tipo 2), no en `MUSTS` ni en `PLANTA_MIX`, así que un piso puede tener pocas.
- En el juego la cámara gira libre: esto no es un defecto del juego.

**Lo que no se puede saber sin ejecutar:** por qué se rechazó la única oferta de la 81. La explicación por U1 y `lay_lattice` es una hipótesis, y no hace falta para el arreglo.

**Arreglo (antes de U15; el archivo no lo toca U15):** escenificar la mampara como ya hace `staged_peek`. En `faces()`, antes del bucle:

```gdscript
var stage: Dictionary = await staged_partition(sight)
if not String(stage.clip).is_empty(): found["partition"] = stage.clip
```

Y el detalle del `check` añade `posed` y `offered`. El bucle queda solo para la esquina: `if found.has("corner"): break`, y `for i in 12: level.player.rotation.y = i * PI / 6.0`.

```gdscript
## A partition staged in view: the listener 10.5 to 18 m back along its normal, it
## 35 degrees off the middle of the picture (in the band, and in the torch's 40).
func staged_partition(sight) -> Dictionary: # {clip, posed, offered}
	var out := {"clip": "", "posed": 0, "offered": 0}
	for room in level.manifest.rooms:
		if FLOOR.is_void(room): continue
		for item in room.get("furniture", []):
			if String(item.kind) != "partition": continue
			var at: Vector3 = FLOOR.position_of(room) + Vector3(float(item.at[0]), 0, float(item.at[1]))
			var normal: Vector3 = Basis(Vector3.UP, int(item.turn) * PI / 2) * Vector3(0, 0, 1)
			for flip in [1.0, -1.0]:
				for back in [10.5, 12.0, 14.0, 18.0]:
					var stand: Vector3 = at + normal * flip * back
					stand.y = at.y + 0.04
					if FLOOR.room_at(level.manifest.rooms, stand).is_empty() or level.point_protected(stand): continue
					await stand_at(stand)
					for turn in [deg_to_rad(35.0), deg_to_rad(-35.0)]:
						var to: Vector3 = at - stand
						level.player.rotation.y = atan2(-to.x, -to.z) + turn
						level.player.camera.rotation.x = 0.0
						await physics_frame
						out.posed += 1
						for _try in 8: # SPOTS_MOST cuts a shuffled list
							for spot in lies.sight_spots(sight, level.player.camera):
								if String(spot.kind) != "partition": continue
								out.offered += 1
								if sight.place_spot(spot, level.player.camera):
									out.clip = String(sight.poser.animator.assigned_animation)
									sight.kind = ""
									return out
								sight.kind = ""
	return out
```

- **Lo he comprobado leyendo:**
  - la normal cuadra con `footprint` (giro impar, largo en z, normal en x);
  - 35° da un coseno de 0,82, dentro de la banda;
  - `lit()` acepta hasta 40° y 22 m con linterna (`phantom_sight.gd:185`);
  - `sight_spots` y `place_spot` no se tocan, así que `hidden_body` y `clear` se comprueban sobre física real.
- **Cómo leer el fallo:** `posed` 0, semilla sin sitio; `offered` 0, la oferta; `offered` mayor que 0 sin aceptar, regresión de verdad.
- **Prueba de que sigue probando lo mismo:** una mutación temporal del revisor, `at + away * 0.12` por `at - away * 0.12` en `lurker_hallucinations.gd:592`, debe dar FAIL. Luego se deshace con otra edición.
- **Encargos:** añadir `office_lies_test` a la lista de la parte D, anotado y fuera de la regla.

**A medir tras U15 (riesgo, no defecto):**
- `PARTITION_RANGE.x` es 10 y `CORNER_RANGE.x` es 8 (`lurker_hallucinations.gd:28-29`). Desde el centro de una celda de 9 x 9 su propia esquina queda a unos 6 m.
- Eso afecta a la prueba: en el juego el jugador no está en el centro.
- Repetir `4d_revB2_faces_probe.gd` en las mismas 8 semillas y comparar. Si cae a casi cero, lo decide el director.

## 3. Defectos que sobreviven

### Afectan a U15: aplicar antes, para no medir dos veces

**G1. Media. La banda de seguridad no cede si `accepts_security` rechaza.** `office_generator.gd:301-302,336,373-375`
- **Caso:** `candidates()` devuelve solo las celdas en banda si hay alguna. Si fallan todas, `fail("security")` sortea la planta y las de fuera de banda no se prueban. La candidata 1 deja en banda el 25 % de las celdas (9 de 36).
- **Por qué importa:** D9, y el texto que U17 escribirá en `DEVELOPMENT.md` («una banda que cede antes que sortear otro piso») sería falso. También afecta a U17.
- **Arreglo:** en `place_air()`, si `security < 0` y no es `standby`, una segunda vuelta con `candidates(..., false, -1)` menos las ya probadas, antes del `fail`. Solo cambia las plantas que iban a fallar.
- **Prueba:** `"security"` en `office_metrics -- 200` contra la base (1).

**G2. Media. Seis esquinas de `CORNER_SIZES` no contienen la pieza de 4c.** `office_palette.gd:454,458,459,464,465,467`

Comprobado contra `encargos_rd4c.json` U8 y contra D1.

| Clave | Reserva hoy | Pieza de 4c | Fila nueva |
|---|---|---|---|
| `coat_rack` | 0,5 x 0,5, desde -0,75 | postes en x ±0,585 a ±0,61, fondo 0,4 | `[1.22, 0.5, -0.75]` |
| `board` | fondo 0,4 | `whiteboard_mobile`, fondo 0,6 | `[1.5, 0.6, -0.7]` |
| `projector` | 0,6 x 0,45 | carrito 0,8 x 0,5 | `[0.8, 0.5, -0.7]` |
| `plant` | z -0,275 a 0,275 | z -0,7 a -0,15 | `[0.55, 0.55, -0.7]` |
| `basin` | z -0,375 a 0,375 | z -1,198 a -0,748, sin solape | `[0.6, 0.45, -1.198]` |
| `boxes` | x ±0,5 | según el hallazgo, escalera y foco en almacén y depósito: no lo he comprobado | releer al rehacer 4c |

- **Por qué ahora:** cambiar la tabla mueve los pisos y la cifra de suelo ocupado. Dejarlo para 4c invalidaría lo medido en U15 y U16.
- `plant` y `basin` las sigue dibujando hoy `prop_factory`, así que hasta 4c hay un desajuste provisional, en un piso sin publicar.
- **Prueba:** comparar el AABB dibujado con `corner_rect()` para cada clave, en la prueba de vestido al rehacer 4c.

**G3. Media. Los salones de dirección no pasan por su banda.** `office_generator.gd:538`, con `HALL_MIX[2]`
- **Caso:** ARCHIVE se quita fuera de banda, EXEC_OFFICE no. Con la candidata 1, el 31 % de las celdas tiene un lado de 9 m. Dirección no está en `BANDED` (`office_proportion_test.gd:29`).
- **Dato:** `4d_revC_proportion.stdout:37` da `direccion suelo=8,5 salas=67 banda=16`. Hay muchas celdas por piso, porque la prueba cuenta cada celda de salón.
- **Arreglo:** en `:538`, quitar también EXEC_OFFICE si algún miembro no cumple su banda. `OPEN_OFFICE` queda en la mezcla, así que nunca se vacía.
- **Queda sin resolver:** las celdas de salón que no son cabeza no llevan mesa, y bajan la mediana de 22 %. Si dirección sale roja en U16, mirar esto antes que la receta.

- **Las secretarías:** con G3 y la lista de hoy, «Más de la mitad de las secretarías tienen puerta a un despacho de dirección» da 32 de 64 y falla por una. Con módulos de 8 m o más casi ninguna celda entra en la banda de dirección, así que se mide tras U15 sin tocar el umbral. Si sigue en rojo, se prueba primero ampliar `SUITE_SWAP`.

**G5. Baja. El archivo forzado ignora la banda.** `office_generator.gd:817-820`
- **Caso:** `straights[0]` es el primero por `order`, aunque tenga una celda de 6 m.
- **Arreglo:** filtrar `straights` por `fits_band(ARCHIVE)` en todos sus miembros si queda alguno.

**G6. Baja. El relevo de juntas siempre sale fuera de banda.** `office_generator.gd:555`
- **Caso:** juntas pide largo de 8 o más y despacho de 7,5 o menos, y OFFICE no está en `PLANTA_MIX[2]`.
- **Arreglo:** `pick = palette.STORE`, que no tiene banda. Viene de antes de 4d.
- **Prueba:** OFFICE en la planta 2 con largo mayor de 7,5 sobre `main_cells` da 0.

**G7. Baja, solo si U15 llega a la candidata 3. Los aseos nunca caen en banda.** `office_palette.gd:387`
- **Caso:** corto de 6,5 o menos con mínimo 7. La comprobación de `BANDED` falla siempre, y U16 no puede salir en verde.
- **Arreglo:** ninguno ahora. Si U15 para en la 3, sube al director antes de U16.

**L2. Media, decisión del director. Los asientos de salida caen en el mostrador.** `match_net.gd:33,159-161`, `revival.gd:27,117`, `office_palette.gd:490`
- **Caso:** el anillo de 1,2 m alrededor del centro de recepción, con cápsula de 0,3, llega a 1,5. `keep_clear` reserva 0,6. El frente del mostrador queda a `half - 2,34`: 1,16 con lado 7, y hay solape por debajo de 7,68 m. Con 8 m no pasa.
- **Rebajada de alta a media:** el centro entra como mucho 0,04 m en el mostrador en el caso citado, así que lo esperable es un empujón al salir, no quedarse atascado. Sin ejecutar no se puede afirmar.
- **Opciones:**
  - zona de radio 1,5 en la sala de inicio y largo de recepción de 8 o más (`ROOM_BANDS`);
  - aceptar el empujón, sin cambios.
- **Coste de la primera:** si el mostrador no cabe en una celda relajada, comprobar que ninguna prueba lo exija. Mueve pisos, así que iría antes de U15.

### Afectan a U16

**G4. Riesgo ya avisado, con un dato nuevo. La mesa S no lleva silla cercana.** `office_generator.gd:1804-1816`
- **Ya lo sabías:** está en `al_director`, en los encargos. La cuenta es correcta (asientos en 0 y ±0,8, y hacen falta 0,9).
- **El dato nuevo:** la comprobación del 80 % está hoy en rojo por poco, con `227 de 286`, el 79,4 % (`4d_u11.log:71`), con la lista de hoy, de módulos de 8 m o más. Con módulos menores cabrán menos mesas largas, así que es de esperar que baje (sin medir).
- **Arreglo aprobado:** si el bucle no puso ninguna silla, prueba en `±(top / 2 - 0.3)`, que en la S da ±0,9. No hay sorteos. Con la lista de hoy no cambia nada, porque todas las mesas son L (227 de 286, el 79,4 %): el umbral no se toca y se juzga con las medidas de U15.

**L3. Baja. Los papeles pueden quedarse sin sitio, pero ya hay comprobación.** `office_proportion_test.gd:240-244,275`
- **Corregido del hallazgo:** sí hay prueba de oficinas que lo cuenta, y hoy pasa con 3 (`4d_revC_proportion.stdout:74`). Tampoco se rompe ninguna regla: `office_palette.gd:522` trata de los sustitutos de receta, y `desk` y `table` siguen sin serlo.
- **Lo que sí se sostiene:**
  - la mediana de esquinas por sala baja de 3 a 1 (`4d_base/metrics_200.log:56`, `4d_revC_metrics40.log:57`);
  - la prueba no aplica `least` (`document_placement.gd:46`), que es lo que decide si una mesa vale.
- **Arreglo:** contar en la prueba solo salas con `route_metres >= maxf(MIN_FROM_START, deepest * SHARE_IN)`.

### Para el arreglo tras verify

**L1. Alta con U15. Reanimar en el vestíbulo mete el cuerpo en la pared del montacargas.** `revival.gd:27,117-121`, `hotel_geometry.gd:1799`
- **Caso:** el cuerpo llega a 1,5 m del centro y la cara de la pared queda a `L/2 - 2,34`. La tabla del hallazgo cuadra:

| Lado | Solape | Centro más allá de la pared |
|---|---|---|
| 8 | 0 % | 0 % |
| 7,5 | 3,75 % | 0 % |
| 7 | 14 % | 0 % |
| 6,5 | 25 % | 8 % |
| 6 | 35 % | 19 % |

- **Cuándo:** cada reanimación, también a solas. Detrás de la pared está el relleno macizo (`hotel_geometry.gd:1730-1742`): aquí sí hay riesgo de quedarse atrapado.
- **Quién lo ve:** ninguna prueba de oficinas lo mira. Tampoco la aceptación 7.
- **Arreglo mínimo:**
  - en `revival_point()`, y solo con `manifest.floor == 2`, apartar el punto unos 0,9 m de `FLOOR.lift_wall(room)`;
  - bajar el reparto a ±0,9 con esa misma condición, para no pisar el archivador de la pared del fondo;
  - el hotel queda igual, porque su manifiesto no lleva `floor`.
- **Prueba:** en cada `gates[i].arrive`, `intersect_shape` con cápsula 0,3 en el punto y sus cuatro extremos, vacío. Añadirla a `office_test_physics`.

**L5. Baja. El cartel de salida cuelga fuera de la sala.** `hotel_geometry.gd:1491`
- **Caso:** `z = 4.8` fijo. Con lados de 8 y 9 m en z ya sobresale 0,8 y 0,3 m. Con la banda de refugio (largo de 7 o menos), de 1,3 a 1,8 m. Comprobado que oficinas pasa por ahí (`office_geometry.gd:1605`, `super`).
- **Arreglo, sin tocar `hotel_geometry.gd`:** `office_geometry.gd` sobrescribe `exit_sign()` y, mientras `extras()` hace un REFUGE, limita `pos.z` a `span_z / 2 - 0.2`, la holgura del 4,8 en un módulo de 10 m. Con 0,1 el cartel entraba en la pared, cuya mitad mide 0,09. Mover el `ExitSign` tras `super` no sirve: `box()` fija la transformación de sus cajas al llamarla, y el perfil, el vástago y el plafón se quedarían donde estaban.
- **Prueba:** `abs(position.z) < span_z / 2 - 0.05` en cada `ExitSign` de un REFUGE.

### U17

Solo G1, por el texto de la banda que cede. Si se cambian R1 o R2, la nota `spec_proporcion.md` D8 hay que corregirla también.

## 4. El tiempo del generador

**El diagnóstico de los hallazgos está incompleto.** Paró en la parte B (2308 ms) y dijo que U8 estaba sin medir. Está medida, y es peor.

| Pase | Pisos | Intentos fallidos | Intentos | q | island/intento | p50 (ms) | Máx (ms) |
|---|---|---|---|---|---|---|---|
| Base | 200 | 194 | 393 | 0,494 | 1,478 | 1962 | p99 6470 |
| Parte A (`4d_rev_r2`) | 40 | 34 | 74 | 0,459 | 1,486 | 1868 | 4978 |
| U7 | 40 | 34 | 74 | 0,459 | 1,486 | 1929 | 5357 |
| Parte B (`4d_revB2`) | 40 | 50 | 89 | 0,562 | 1,494 | 2308 | 8217 |
| **Parte C (`4d_revC`)** | 40 | 46 | 86 | 0,535 | 1,488 | **2926** | 6174 |

- **De A a B se sostiene:** U7 tiene los mismos sorteos que A y sube unos 60 ms. El salto a 2308 viene de más intentos, tras U9, la única unidad posterior que cambia algo que lea el generador.
- **De B a C no son intentos:** hay menos y la mediana sube 618 ms. `4d_u8_metrics.log` (20 pisos) da 3125, y `4d_revC_time_probe.log` (12 semillas) da 2907, con `place_refuge` en solo el 3,6 %. Así que no es el segundo `super` de U8 ni `refuge_fits`.
- **Causa más probable, sin demostrar:** la mezcla de tipos. U8 avisó de que saldría rara con la lista de hoy, y en 8 pisos `4d_revC_proportion.stdout` da archivo 402 salas, juntas 336, descanso 264, reprografía 260 y correo 202, frente a 8 de despacho. Son recetas caras repetidas. Por eso **2926 no predice U15**, y tampoco lo hace 2308.

### Arreglos

Todos dejan el manifiesto idéntico. Prueba común: `hash(var_to_str(data))` en las semillas 1 a 40 antes y después. Los pesos son estimaciones. Afectan a U15, y se aplican antes en este orden:

**D2. Búsquedas repetidas que ya se sabe que fallan.** `office_recipes.gd:327-338`
- Si una tirada falla, nada cambia, así que las siguientes dan lo mismo. `dining_set` tiene de 3 a 4 tiradas y cada búsqueda son 196 intentos.
- **Arreglo:** `break` en `:338`, y `if not lay_middle(...): break` en `:329`. `runs` ya está sorteado en `:324`.
- **Peso:** el hallazgo dice de 10 a 30 ms. Con la mezcla de hoy, de unas 33 salas de descanso por piso, será bastante más. Sin medir.

**D1. `duct_bridge` se descubre tarde.** `office_generator.gd:1896`, dentro de `furnish_ducts`, el décimo paso de `:916`
- Son 44 de los 46 fallos de la parte C, y cada uno paga los 9 pasos anteriores.
- **Comprobado que se puede adelantar:**
  - de `:1832` a `:1896` no hay sorteo (el `shuffle` es de `:1903`);
  - nada cambia `type`, `adjacency` ni `edges` después de `finish` (las escrituras acaban en `:893`);
  - cada sistema tiene su flujo sembrado por intento (`:900-903`), y `f` se tira al fallar;
  - los enlaces sueltos de una planta no entran en los trozos de otra.
- **Arreglo:** extraer `:1832-1897` a una función sobre un `job` desechable (`ducts`, `node_of`, `duct_pairs`). Llamarla al empezar `furnish()`, y devolver `{"fail": "duct_bridge"}` si falla.
- **Peso:** de 300 a 450 ms por intento fallido (estimación). Solo cambia el motivo en `stats` de los intentos que antes caían por `board` o `window_desk`.

**D4. `fixtures()` se recalcula sala por sala.** `office_layout.gd:128-148`, llamado desde `:194`
- `office_validator.gd:47-74` ya lo resolvió con `fixtures_by_room`.
- **Arreglo:** en `furnish_furniture` (`:1636`), calcular una vez `view["spots"]` por sala, y que `fixtures()` lo devuelva si existe. Ningún punto de pared entra en `job.out` durante ese paso: comprobado.
- **Peso:** de 100 a 150 ms por intento, según el hallazgo. Sin medir.

**D3. El validador evalúa cada cápsula entera.** `office_validator.gd:852`
- **Arreglo:** `RECIPES.prepare(zones)` después de `:836`, y `RECIPES.hits(r, zones)` en lugar de `LAYOUT.blocked`. La respuesta es la misma: un rectángulo fuera de la caja crecida queda a `r` o más.
- **Peso:** de 60 a 110 ms por intento validado. Sin medir.

**D5.** `office_recipes.gd:274-277`: cierto, y de 15 a 25 ms. No merece unidad propia. Se puede hacer si se toca el archivo por D2.

### Medir antes de confiar

- **La sonda de fases** está sin ejecutar: `C:\Users\Poblete\AppData\Local\Temp\claude\E--Projects-The-Four\30ec7d89-bfbc-4c56-b84b-8bc1cdb0c707\scratchpad\4d_gen_phases_probe.gd`. Hay que copiarla a `evidence/`.
- Sirve correrla con la candidata 1 puesta en temporal, no con la lista de hoy, cuya mezcla engaña.
- Para comparar, `office_metrics -- 200`: 40 pisos no distinguen estos cambios.
- Solo cuando U8 esté aceptada: los arreglos tocan los mismos archivos.

### D6. La regla de reserva depende de q

Con 8 intentos (`map_generator.gd:45,107`), la probabilidad de reserva es q elevado a 8.

| q | Reservas esperadas en 200 | Probabilidad de más de 1 |
|---|---|---|
| 0,435 (U4) | 0,26 | 3 % |
| 0,494 (base) | 0,71 | 16 % |
| 0,535 (C) | 1,34 | 39 % |
| 0,562 (B) | 1,98 | 59 % |

- **Riesgo:** U15 puede descartar una candidata por el sorteo, no por la colocación. D1 abarata los fallos, pero no cambia q.
- **Arreglo mínimo, decisión del director:** un gancho `attempts()`, con 8 en el hotel y 12 en oficinas. Con q de 0,56 da 0,19 en 200, y solo cambian los pisos que iban a reserva.
- **Aceptación 5 de `encargos_rd4d.json`, corregida aquí (ese JSON no se edita):** `verify.ps1` en verde, con el trabajo nuevo de capas (`--floor=2`), con `manifest_golden_test` y `creature_contract_test` y con `git diff` de `hotel_geometry.gd`, `map_validator.gd` y `room_layers.gd` vacío (salvo la fila a de U15, si se usó) y solo los ganchos `refuge_fits` y `attempts` en `map_generator.gd`. Lo mismo vale para el punto 9 de las pruebas de ese JSON.
- `duct_bridge` por piso va en 1,10 (parte C) frente a 0,80 de la base, un 37 % más. El límite es del 50 % y solo se compara en el pase de 200.

## 5. Lo que se ha quitado

- **La semilla como arreglo:** queda solo como último recurso, si el piso no permite ninguna colocación, y entonces se corren las 17 comprobaciones.
- **El cuarto defecto de `lurker`:** es el de `lies`, repetido.
- **«U8 sin medir» y el orden de pesos basado solo en B:** ver la sección 4.
- **«Ninguna prueba de oficinas cuenta los papeles» y «se rompe la regla de la paleta»:** falsos (L3).
- **El caso concreto de los aseos de 6,5 m en G2:** la clave `basin` está demostrada, pero el caso con la taquilla no lo he repasado, así que no lo cito como probado.
