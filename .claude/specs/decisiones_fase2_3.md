# Decisiones del autor para las fases 2 y 3 (The Lurker)

24 de octubre de 2026. Reúne en un sitio las decisiones «para el autor» de `spec_f2_movement.md` (§15), `spec_f2_mind.md` (§14) y `spec_f3_integration.md` (§15). Cada una lleva la recomendación del director. **El autor las resolvió el 24 de octubre** (sección «Resuelto por el autor», al final): todas como se recomendaba salvo M1, M2, C3, C5, C7 e I2.

La M es del movimiento (2a), la C del cerebro (2b) y la I de la integración (fase 3).

## Cómo se mueve

| N.º | Qué hay que decidir | Recomendación |
|---|---|---|
| M1 | En los pasillos de servicio, la sala de climatización y la de máquinas no hay techo bajo al que agarrarse a 3,05 m. ¿Por dónde va? | **Por las paredes**: adelantar el parche de pared (WALL) para esas tres. Las otras opciones piden colisionadores que solo ven sus manos o mover las regletas. |
| M2 | Bajo un mueble de 2,2 m queda un hueco de 0,75 m y su cuerpo pide 1,0 m. ¿Qué cede? | **No pasa por encima de los más altos** (taquillas, estanterías): los rodea. Se decide de verdad cuando se mida su cuerpo. |
| M3 | Bajo el dintel de una puerta su cuerpo baja a 1,6 m. ¿Puede tapar el paso a la altura de la cabeza? | **Sí**: verla colgada en un vano es de lo que más asusta. |
| M4 | Cuando cuelga a la altura de la cabeza, ¿los supervivientes chocan con ella o la atraviesan? | **Chocan** (se paran, no se les empuja): es un cuerpo. |
| M6 | Una hoja de puerta que se cierra sobre ella bajo el dintel, ¿rebota como en un cuerpo? | **Sí**, como con un superviviente. |
| M7 | El «plénum», ¿son solo los conductos o también una capa oculta sobre las placas, con su sonido saliendo de la placa que tiene debajo? | **También la capa sobre las placas**: «se la oye correr por encima» en las oficinas abiertas lo pide. |
| M8 | Encima de una taquilla (2,3 m bajo un techo de 2,95) solo quedan 0,65 m. ¿Qué postura tiene ahí? | **Bajando por el frente de la taquilla** hasta la rendija, cabeza abajo. |
| M9 | En la planta 3, ¿empieza cada etapa en la sala de climatización, su nido, donde acaban los supervivientes? | **Sí**: el final es meterse en su casa. |
| M10 | Entre plantas: ¿cuánto tarda en bajar y se queda mientras alguien siga en su planta? | **Tarda lo del viaje del montacargas (8,5 s)** y **va a por el que se queda atrás** antes de bajar. |
| M11 | Una víctima agachada (cámara a 0,9 m) no puede verle la cara a 20° de ningún techo. ¿Mira arriba o baja ella? | **Baja ella** para el aviso. |
| M12 | No abre taquillas (provisional). | **Confirmar**: «no abre taquillas». |
| M13 | Detalles: los asomos como multiplicador (Muchos, Muchos, Normales, Pocos) y si la luz de un minutero la empuja como las zonas del cuadro. | **Sí a los dos.** |

## Cómo piensa y avisa

| N.º | Qué hay que decidir | Recomendación |
|---|---|---|
| C1 | Las seis reglas de 0.3: la mirada con luz de un compañero también salva; la linterna cuenta por donde apunta la cámara; la latencia sumada con tope de 0,5 s; la captura hasta 0,6 s pasada la ventana; no abre taquillas y esconderse acaba el aviso; su drenaje pasivo nunca deja una sala a oscuras. | **Aprobar las seis.** |
| C2 | La latencia de quién cuenta. | **Solo la de la víctima, con tope de 0,5 s**: es lo que dice OFICINAS 1. |
| C3 | Alejarse andando durante la ventana del aviso. | **Salva, pero con una calma antes del siguiente aviso** a esa persona: si no, se repite sin fin. |
| C4 | Girarse con el mando en Pesadilla; si el aviso cierra el papel que se lee y el teclear en el mostrador. | **Pesadilla debe poder ganarse con el mando** a la sensibilidad por defecto; **el aviso cierra el papel y corta el teclear**. |
| C5 | ¿Existe un aviso desde arriba (en salas de más de 3,3 m)? | **No**: «siempre se oye detrás de ti», en horizontal. |
| C6 | «O la sala tiene luz»: ¿la luz de su cara o la sala de la víctima? | **La sala de la víctima**: que la víctima sepa si está a salvo por lo que ve a su alrededor. |
| C7 | Los asomos a oscuras, sin linterna, nadie le ve la cara. | **Su cara pálida se ve a oscuras a la distancia de un asomo**, sin luz: si no, el asomo no se ve nunca. |
| C8 | Cuando acecha, ¿cuenta como persecución (el aura al máximo) o tiene palabra propia? | **Palabra propia, `stalk`**: el acecho se nota por las garras y las luces, no por el pavor. |
| C9 | ¿Bebe la luz desde un conducto encima de la sala? ¿Y en los vestíbulos del montacargas? | **Desde el conducto sí** («luces que tiemblan a su paso»); **en los vestíbulos nunca**, que son el sitio seguro. |
| C10 | Sus ritmos: a qué multiplica `creep_scale` y el ritmo de retroceder. | `creep_scale` **sobre 1,0 m/s**; **retrocede despacio, a 0,8 m/s**. (Su velocidad en el ducto principal ya está decidida: 1 m/s.) |
| C11 | Ajustes nuevos que OFICINAS no trae (`sated`, `forget`, `encounter_every`, `cross`, `lead_every`, `peak_*`, `rest_chase`, `ambush`, `double_back`). | **Aprobar los valores del borrador** y medirlos con el lote de bots; en Apacible, `ambush` a 0, como el hotel. |

## Cómo encaja en el piso

| N.º | Qué hay que decidir | Recomendación |
|---|---|---|
| I1 | ¿Su drenaje pasivo deja la sala «a oscuras» para las reglas? | **No**: solo «beber la luz» del versus. Si no, oscurece cualquier sala al acercarse. |
| I2 | Los golpes del director en las puertas en el piso 2. | **Quitados**: se confundirían con sus señales. |
| I3 | Cada cuánto miente. | **Caras cada 40 a 90 s; mentiras de sonido al ritmo del hotel.** |
| I4 | El último que repta en el ducto principal. | **Puede mirar atrás libre con la cámara** (el cuerpo sigue girando despacio); sin ventana extra. |
| I5 | El aviso con los ventiladores en marcha. | **El aviso no lo tapan los ventiladores**: es una regla. |
| I6 | Los subtítulos delatan qué garras son de verdad (las mentiras no llevan). | **Quitar el subtítulo a sus sonidos de conducto y de placa**; el aviso y el chillido lo conservan. |
| I7 | El subtítulo de su respiración encima de una taquilla. | **«[Algo respira encima]»** (propuesta: el texto es tuyo). |
| I8 | ¿Bebe la luz desde dentro de un conducto? | **Sí**, como en C9: las lámparas tiemblan a su paso. |
| I9 | Las luces de emergencia de la planta 2, ¿tiemblan con ella? | **Sí**: si no, en esa planta pierde su señal más clara. |
| I10 | En versus, ¿solo entra en el ducto principal detrás del último que repta, también si la lleva una persona? | **Sí**, la misma regla. |
| I11 | Las decisiones de 0.5 (mentiras sin subtítulo, ni respiración ni clic fuera del aviso, la presencia solo encima de una taquilla, «techo alto» por encima de 3,0 m, el medio segundo limpio, `SANITY_SHRIEK` 6) y los números del director de 2b 4.2. | **Aprobarlas** y ajustarlas con el lote de equilibrio. |

## Lo que ya está decidido

- Velocidad en el ducto principal: 1 m/s en todas las dificultades (23 de octubre).
- Atajos de los conductos: al menos el 10 % (23 de octubre; sale un 12,7 %).
- Aviso del primer piso: «The Lurker acecha entre las sombras, no dejes que te atrape» (23 de octubre).

## Resuelto por el autor (24 de octubre de 2026)

Todas como la recomendación, salvo estas:

- **M1:** va **por las paredes y también por el techo**. Si tiene a un jugador cerca, **salta desde el techo para atacarlo**, abalanzándose sobre él con **un salto largo**.
- **M2:** **su cuerpo muta y se encoge** para pasar por debajo de los muebles altos. Se rectificará cuando se mida su cuerpo en el juego.
- **C3:** durante la ventana del aviso, **alejarse solo salva corriendo, no andando**.
- **C5:** **sí hay aviso desde arriba**, en las salas altas.
- **C7:** su cara solo se ve a oscuras **a muy poca distancia**; a media y larga distancia no se ve.
- **I2:** **los golpes del director en las puertas se mantienen** en el piso 2: asustan cuando no hay peligro.
