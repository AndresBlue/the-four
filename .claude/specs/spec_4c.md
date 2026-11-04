# Área 4c, segunda redacción (4 de noviembre)

Manda sobre `encargos_rd4c.json` (25 de octubre), que se redactó antes de 1b+2, 4a, 4b, 5 y 4d. Ese archivo es el **borrador**: su diseño, sus unidades y su prueba de aceptación siguen valiendo salvo lo que diga esta nota. Lo que cambia es que todos sus fragmentos «antes», firmas y números se levantan de nuevo contra el código de hoy (`main` en 684b02c). Diseño de fondo: `spec_rediseno.md` (versión 2), fila «4c» de la sección 12, con las secciones 2, 5, 6, 7, 10 y 11. Las decisiones de 4d están en `spec_proporcion.md` y `spec_4d_fisica.md`.

## Decisiones del director sobre las preguntas del borrador (numeradas como su `al_director`)

1. Todo «antes» se copia del código de hoy. La puerta de entrada de U1 se queda, comprobando 684b02c y que el árbol no tenga cambios en los archivos del área.
2. **Los cuadros de fusibles del hotel se quedan en el piso 2** mientras algo los use (el apagón y su reposición, `code_lock.place_panels()`, `floor_save`, `match_net`). No se sobrescribe `fuse_boxes()`. `wall_stretches()` deja sus tramos para ellos, y lo colgado no se pone encima. Si las fichas demuestran que nada del piso 2 los usa, el redactor lo sube y no los quita por su cuenta.
3. La esquina `desk` es la mesa auxiliar de acero con el tablero a 0,84 y su silla. Vale que haya dos mesas en despacho, dirección, secretaría y naves.
4. Los lavabos son `FIXTURES.basin` contra el panel alicatado, con `WALL.mirror` y el aplique encima. Su fila de `CORNER_SIZES` pasa a ser la huella de esa pieza (contrato de 4d: lo que barre `validate_physics` lo reserva la colocación). Si `basin` sale de `HOTEL_KINDS`, su fila se mueve con ella. `office_pieces_test.check_corner_reserves` sigue en verde.
5. El globo, la planta alta, la escalera de tijera y el foco de obra se colocan, con su colisionador y su reserva. `plastic_bottle_gallon` no se ingiere: nadie lo pone.
6. y 7. Resueltas en el borrador.
8. Se aceptan los textos de los carteles. No llevan «·» ni «—».
9. Las láminas, en código, como dice el borrador.
10. Los modelos, como dice el borrador, sin `plastic_bottle_gallon` (decisión 5).
11. **La central de adorno del correo lleva una variante de `mail_central` con las lámparas en `lamp_off`**: una luz encendida en una sala a oscuras le miente al jugador. Es un argumento o una función nueva en `pieces/mail_equipment.gd`, sin cambiar la pieza del área 5.
12. a 15. Se aceptan como las da el borrador. Sin rastro de papeles hacia el montacargas.
16. Al cerrar 4c, el director añade a `verify.ps1` `office_dressing_test` y **devuelve `office_proportion_test`**. Ninguna unidad toca `verify.ps1`.
17. a 19. Se aceptan. Lo de la 19 es del área 6.
20. a 22. Constan. La herramienta `ingest_models.py` no se ejecuta nunca sin `--set=office`, ni con `--help`.

## Lo que 4d deja a 4c (entra en las unidades)

- **La prueba de aceptación suma `office_proportion_test` en verde**, sin bajar ningún umbral. Hoy da 42/55, y estos son los fallos:
  - el suelo ocupado queda bajo su banda en 10 tipos: ventanilla 15,9 de 20, correo 16,2 de 18, archivo 13,6 de 20, archivo_movil 30,1 de 40, despacho 17,5 de 20, dirección 16,8 de 22, secretaría 17,4 de 20, juntas 18,4 de 22, seguridad 16,6 de 20 y eléctrico 11,1 de 16;
  - la pieza principal en cuadro queda bajo 30 en secretaría (29,8) y aseos (21,2);
  - hay una sola mesa para los papeles por planta, y la prueba pide dos.

  El redactor tiene que comprobar qué cuenta esa prueba como suelo ocupado (muebles, esquinas, lo menudo) y decir qué unidad sube cada cifra. Si lo de 4c no puede subir alguna, lo sube al director con la cifra que se espera.
- La reserva de `LOCKER` mide 1,3 x 0,7 y la taquilla real 1,1: se ajusta a la real. En 108 casos los aseos se quedan sin cabinas por las reservas de taquilla, y con la reserva justa se vuelve a medir (`evidence/4d_aseos_probe.gd`).
- La silla cercana (G4, `lay_near_chairs()`).
- `office_lies_test`: la comprobación de la mampara tiene que distinguir de qué lado posa (`place_spot` acepta lo mismo con +0,12 que con -0,12).
- El tope de 100 de `archivo_movil` en `office_proportion_test` no cambia: el suelo ocupado no puede pasar de 100.
- Fuera de 4c (área 6): el encuadre de `office_rooms_capture` cuando la hoja de la puerta tapa el cuadro, la cuota de cue (0,876 frente a 0,900), el umbral de `office_test_generator` y C6b.

## Cuota

La redacción se hace ahora. El frente va tras la renovación semanal del 7 de noviembre: el tramo A primero, y el abandono (tramo B) el último, porque es lo primero que se corta si la cuota no da.

## Tras la redacción (`encargos_rd4c2.json`, 4 de noviembre)

Las fichas cambian dos cosas de arriba:

- **Decisión 2, cambiada: los cuadros de fusibles se quitan del piso 2.** Nada del piso 2 los usa: no tiene objetivo «code», así que `place_panels()` no corre, `goal.blackout` solo lo pone `televisions_objective.gd`, y `match_net` nunca llega a «power». `office_palette.gd:228` ya dice «No fuse boxes». Por eso `office_geometry.gd` sobrescribe `fuse_boxes()` para que devuelva `false`, y sobran `fuse_spare()` y su comprobación.
- **`office_proportion_test` no se pone en verde en 4c.** `floor_taken()` solo cuenta lo que tiene huella en planta (muebles, esquinas, taquillas y equipos), y 4c no añade nada de eso. Lo que falta son muebles en las recetas, y una segunda mesa para los papeles por planta. Va a un área propia, **4e, las recetas llenas**, entre 4c y el área 6. Esa área mueve la colocación y vuelve a pasar la física. La prueba sigue fuera de `verify` hasta 4e, y 4c solo pide que no falle ninguna comprobación que hoy pasa.

Lo demás de la redacción se acepta como viene:
- LOCKER a 1,1 de fondo, con la fila nueva del lavabo medidas juntas en U6b. Si suben los aseos sin cabinas, se decide con la cifra.
- El riesgo de MASK sin alfa en tres plantas: si salen como placas en la hoja, se quitan de `MODELS`.
- La lámpara de pie y el globo pueden asomar por encima del alféizar delante de un cristal interior. Se acepta: es lo que pasa en una oficina de verdad.

