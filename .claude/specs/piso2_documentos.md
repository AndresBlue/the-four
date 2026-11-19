# Piso 2: primera tanda de documentos

**Propuesta sin aprobar** (19 de noviembre de 2026). Ocho de los veinticuatro que pide `.claude/specs/piso2_contenido.md`. Nada de esto está en el juego ni en `docs/LORE.md`: el autor los retoca y dice cuáles valen.

Medida y tono, los de los papeles del hotel (`game/discovery/discovery_catalog.gd`): unos 350 caracteres, dos o tres párrafos cortos, y casi siempre una pista que es verdad en el juego. Ninguno lleva «·» ni raya larga.

## El papel

El autor dibujó la hoja de las oficinas el 19 de noviembre de 2026 (`assets/hoja-oficina.png`), a partir de un memorándum de empresa de 1982: membrete THE FOUR, Oficinas Corporativas, Sede Central, Santiago, Chile, y las líneas Fecha, Para, De, Asunto y Cc.

- **`game/ui/office_memo.gd`** la rellena a máquina como `hotel_form.gd` rellena el formulario del hotel: `date`, `to`, `from`, `subject` (en mayúsculas), `cc`, el cuerpo en `lines`, una respuesta a pluma en `note` y un sello en `stamp`. `tools/capture/memo_capture.gd` saca dos de muestra a `evidence/planta/papeles/`.
- **Todavía no se lee en el juego:** falta engancharla al Archivo y a la lectura en el mundo, y que los memorandos que el piso ya tiene (la leyenda del cuadro, las instrucciones del puesto) pasen a esta hoja.
- **Van en la hoja** el 1, el 2, el 4, el 6 y el 7. El 3 es una página de un libro de novedades, el 5 una nota a mano y el 8 una carta.
- **Como la sede está en Santiago,** los textos van en un castellano que no suene de España: «Mantención», «marcar tarde».
- **Las tintas** (el autor, 19 de noviembre: lo escrito a máquina «no parece tinta real, sino algo digital encima»): las tres pasan por `paper_ink.gdshader`, que oscurece el papel en vez de taparlo, con grano, tramos secos y bordes comidos. La máquina y el timbre usan Special Elite, de tipo gastado; el lápiz pasta azul, Reenie Beanie, palabra a palabra y un poco torcida; el timbre deja zonas sin entintar. Las dos tipografías están en `assets/fonts/` con su licencia (`docs/ASSETS.md`).

## Lo que afirman más allá del lore confirmado

Para que el autor diga sí o no antes de nada:

1. **Antes de que el personal se fuera ya pasaban cosas en las oficinas** (ruidos en los ductos, luces que bajan, una cara en el techo). **Confirmado por el autor el 19 de noviembre de 2026:** «sí, ya se notaba antes de que se fueran».
2. **Nombres:** Tomás Requena (mantenimiento), Germán Ortuño (vigilante del puesto), Inés Barral (auxiliar de Registro), Nuria Valdés (Personal) y Aurelio Campos (médico de empresa).
3. **Lo que escribe el ente** en el 6: BUENOS DÍAS, y los nombres de quienes marcaron tarde.
4. **El 5 deja caer** que Inés quizá no llegó a irse.
5. **El año de las fechas.** Un memorándum lleva fecha y el año de las oficinas no está decidido: las muestras llevan «19__».

## Los ocho

### 1. Parte de mantenimiento

- **Papel:** hoja de avería, con una respuesta a mano al pie. Planta 2.
- **Quién, a quién:** Tomás Requena, de Mantención, a Servicios Generales.
- **Qué pasó antes:** lleva un mes oyendo los ductos y ya ha parado la máquina para descartarla.
- **Deja entrever:** que alguien de arriba quiere las rejillas abiertas.
- **Pista:** ella oye por las rejillas.

> Tercera vez este mes con los ductos de encima de la R-214. La climatizadora lleva parada desde el martes y siguen sonando. Suenan cuando alguien habla debajo de la rejilla y callan cuando se calla.
>
> Pido sellar esa rejilla y las dos de al lado.
>
> Respuesta al pie, a mano: No. Las rejillas se quedan abiertas.

### 2. Circular interna

- **Papel:** circular a todo el personal, sin firma. Planta 1.
- **Quién, a quién:** Dirección, a todos.
- **Qué pasó antes:** algo que la circular no cuenta.
- **Deja entrever:** que Dirección sabe de qué protege y no piensa decirlo.
- **Pista:** ella elige a quien está solo y a oscuras.

> Se recuerda a todo el personal:
>
> No se apaga la luz al salir de una sala. Quien tenga que quedarse fuera de hora no se queda solo, y se queda donde haya luz. Al archivo se va de dos en dos.
>
> Es por la seguridad de todos. No se atenderán preguntas sobre esta circular.

### 3. Libro del puesto de seguridad

- **Papel:** libro de novedades, turno de noche. Planta 3.
- **Quién, a quién:** Germán Ortuño, vigilante, para el relevo.
- **Qué pasó antes:** una noche más solo ante las cámaras.
- **Deja entrever:** que el relevo no llegó.
- **Pista:** la consola enciende luces lejos, ella va a mirarlas, y solo hay cuatro a la vez.

> 02.10. Cámara 4, techo del archivo. Algo se mueve en la imagen.
> 02.12. Rebobino. En la cinta no hay nada.
> 02.40. Enciendo desde la consola la luz de la 7, en la otra punta. A los dos minutos está en la 7.
> 02.44. La batería solo aguanta cuatro luces a la vez y se apagan solas. Las voy encendiendo lejos de mi pasillo.
> 03.30. El relevo no ha subido.

### 4. Informe médico

- **Papel:** informe del servicio médico, con sello de DENEGADO. Planta 1.
- **Quién, a quién:** el doctor Aurelio Campos, a Personal, sobre Inés Barral.
- **Qué pasó antes:** ella lleva semanas viéndolo y nadie más lo ve.
- **Deja entrever:** que a nadie se le deja cambiar de planta.
- **Pista:** mirarla gasta la cordura, y el café la devuelve.

> La empleada dice ver una cara en el techo de su despacho. Solo cuando levanta la vista. Dice que la cara la mira mientras ella la mire, y que cuanto más la mira peor se encuentra después.
>
> Le he indicado que no mire. Refiere que solo se le pasa con el café de la máquina del pasillo.
>
> Solicita traslado a otra planta.
>
> DENEGADO.

### 5. Nota de la salida

- **Papel:** hoja arrancada de un bloc, sobre una mesa. Planta 2.
- **Quién, a quién:** Nuria Valdés, de Personal, a Inés Barral.
- **Qué pasó antes:** se están yendo deprisa y cada uno carga lo que puede.
- **Deja entrever:** que Inés quizá no salió.
- **Pista:** no quedarse a oscuras.

> Inés:
>
> No te he podido esperar. Me llevo las fichas de la A a la M. Las demás no me caben y no hay segundo viaje.
>
> Deja lo que estés haciendo. No recojas la mesa, no apagues nada, no vuelvas a por el abrigo.
>
> Si lees esto es que sigues aquí. No te quedes a oscuras.
>
> N.

### 6. Queja por los terminales

- **Papel:** nota interna de Registro, con una respuesta al pie. Planta 2.
- **Quién, a quién:** Inés Barral, a Proceso de Datos.
- **Qué pasó antes:** los terminales amanecen con cosas que nadie ha tecleado.
- **Deja entrever:** al ente, que juega con ellos y sabe quién es cada uno.
- **Pista:** ninguna de juego. Prepara los terminales que se podrán leer.

> Esta mañana todos los terminales de la planta tenían lo mismo en pantalla y nadie había entrado todavía: BUENOS DÍAS.
>
> A media tarde ponían los nombres de los que habíamos marcado tarde. El mío el primero.
>
> Proceso de Datos dice que no hay nadie conectado. Pido que se apaguen por la noche.
>
> Respuesta al pie: No se pueden apagar.

### 7. Cartel de la sala de descanso

- **Papel:** cartulina pegada junto a la máquina de café. Cualquier planta.
- **Quién, a quién:** nadie firma; es de los propios empleados.
- **Qué pasó antes:** ya saben qué les pasa y con qué se les pasa.
- **Deja entrever:** que ver cosas era tan corriente que tenía cartel.
- **Pista:** una taza por persona y máquina, y tarda un momento en notarse.

> UNA TAZA POR PERSONA.
>
> No es por ahorrar. La segunda no hace nada.
>
> Si llevas un rato viendo cosas por el rabillo del ojo, tómate la tuya y espera un momento. Se pasa.
>
> Si no se pasa, no te quedes solo.

### 8. Carta sin enviar

- **Papel:** carta a medio escribir, en un cajón. Planta 3.
- **Quién, a quién:** Tomás Requena, a su hermana Luisa.
- **Qué pasó antes:** años sin poder contar en casa dónde trabaja.
- **Deja entrever:** que les enseñaron qué hacer, y que les dijeron que lo de abajo estaba guardado.
- **Pista:** cuando las lámparas bajan, ella está cerca; y la vuelta con la linterna encendida.

> Luisa:
>
> No te puedo contar dónde trabajo, ya lo sabes. Te cuento lo que sí puedo.
>
> Aquí las luces bajan solas. No se van: bajan, como si alguien les quitara la mitad. Nos han enseñado que cuando bajan no hay que quedarse debajo, y que si notas a alguien detrás te des la vuelta con la linterna encendida, sin pensarlo.
>
> Dicen que lo de abajo está bien guardado. Yo ya solo miro las lámparas.
>
> Tomás
