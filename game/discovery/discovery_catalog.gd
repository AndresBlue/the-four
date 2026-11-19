extends RefCounted
## Optional documents found on the floors: twenty-four in the hotel (the
## author, 18 November 2026) and four for each of the other floors, until
## they have theirs. They explain what the player has seen and give hints,
## never power. Only the hotel's are written; the other twelve slots stay
## locked.
## Those that are the hotel's own paperwork carry `form`: what is typed in the
## fields of its form around the body (game/ui/hotel_form.gd), which is how
## they are read and how they look lying on a table. The offices' will carry
## `memo`, what is typed on their sheet (game/ui/office_memo.gd): read on it
## already, with none written and no picture of it lying on a table yet. The
## rest carry `paper`,
## the ruled paper they are typed on (game/ui/ruled_paper.gd): a letter
## folded in four, a page of a notebook.
const TOTAL := 36
const ENTRIES := [
	{
		"id": "locust_reception",
		"creature": "locust",
		"title": "Nota para el turno de noche",
		"header": "Recepción, papel con membrete del hotel",
		"body": "Tres quejas más de la planta primera. Dicen que la tele se enciende sola pasadas las tres y que en la pantalla sale alguien mirando desde muy cerca. El 107 pidió cambiar de habitación. El 112 no contestó al teléfono.\n\nYa desenchufé dos aparatos y volvieron a encenderse. No subas solo. Si oyes golpes en una puerta, no abras para ver quién es.",
		"form": {"number": "0417", "post": "RECEPCIÓN", "place": "PLANTA PRIMERA", "subject": "NOTA PARA EL TURNO DE NOCHE", "type": "incidente", "action": {"informar": "TURNO DE NOCHE"}, "priority": "alta", "state": "pendiente", "signed": true, "seed": 417},
	},
	{
		"id": "locust_maintenance",
		"creature": "locust",
		"title": "Parte de mantenimiento",
		"header": "Hoja de avería, sin firmar",
		"form": {"number": "0388", "post": "MANTENIMIENTO", "place": "HABITACIÓN 107", "subject": "PANTALLA DEL TELEVISOR ROTA", "type": "incidente", "action": {"seguimiento": true}, "priority": "urgente", "state": "pendiente", "seed": 388},
		"body": "Habitación 107: pantalla del televisor rota. Los cristales están fuera, sobre la moqueta, no dentro del tubo. Lo rompieron desde dentro.\n\nMarcas en el marco de la puerta, a más de dos metros y medio de altura, como de algo que se agacha para pasar. Arañazos en el interior de dos armarios del pasillo. Pido que alguien más venga a verlo antes de cambiar nada.",
	},
	{
		"id": "locust_letter",
		"creature": "locust",
		"title": "Carta sin enviar",
		"header": "Papel doblado en cuatro",
		"paper": "carta",
		"body": "Si alguien encuentra esto: me he pasado la noche dentro de un armario. Lo que anda por los pasillos ve muy lejos, mucho más lejos que tú. No le apuntes con la linterna, la luz lo trae.\n\nCuando se para en seco y chilla, ya sabe dónde estás. Ese segundo es lo único que tienes: sal de su vista. Y no abras las puertas del armario para mirar si lo tienes delante.",
	},
	{
		"id": "locust_guard",
		"creature": "locust",
		"title": "Registro del vigilante",
		"header": "Libreta de rondas, última página",
		"paper": "libreta",
		"body": "02:40 Pasos en la planta de arriba. No son de persona, suenan como puntas contra el suelo.\n02:55 Se oye por las puertas abiertas y por los pasillos. A través de las paredes, nada. Cierro detrás de mí.\n03:10 En la sala de la salida no entra. Me quedo aquí hasta que se haga de día.",
	},
	# The twenty more of the hotel (the author, 18 November 2026): six of the
	# twenty-four come out in a floor.
	{
		"id": "locust_owners",
		"creature": "locust",
		"title": "Circular de la propiedad",
		"header": "Circular de dirección, copia del tablón del personal",
		"body": "Por indicación de la propiedad, y hasta nuevo aviso:\n\nLas habitaciones de la lista no se asignan a ningún huésped, aunque el hotel esté completo. No se limpian y no se abren.\n\nEl ascensor de servicio no es para el personal ni para los huéspedes. Si alguna vez llega con las puertas abiertas, no se entra.\n\nLas entregas de madrugada en el muelle de carga no se firman ni se anotan, y quien las recibe no pregunta qué traen.\n\nLa propiedad agradece, como siempre, su discreción.",
		"form": {"number": "0102", "post": "DIRECCIÓN", "place": "TODO EL HOTEL", "subject": "INSTRUCCIONES DE LA PROPIEDAD", "type": "otro", "action": {"informar": "TODO EL PERSONAL"}, "priority": "alta", "state": "en_curso", "signed": true, "seed": 102, "rows": [["318", "NO SE ASIGNA"], ["322", "NO SE ASIGNA"], ["331", "NO SE ASIGNA NI SE LIMPIA"]], "notes": ["COPIA AL TABLÓN", "EL PERSONAL NO BAJA DEL SÓTANO"]},
	},
	{
		"id": "locust_switchboard",
		"creature": "locust",
		"title": "Libro de la centralita",
		"header": "Libreta de la centralita, turno de noche",
		"paper": "libreta",
		"body": "01:12 Llamada desde la 116. La 116 está vacía.\n01:40 Otra vez la 116. Al descolgar no habla nadie: se oye su tele, y esa tele está desenchufada.\n02:05 Se encienden todas las luces del cuadro a la vez, como si llamara el hotel entero.\n02:30 Llamada desde una extensión que no existe. Suena muy lejos, como de debajo.\n02:51 Tres golpes en la puerta de la 120, y no hay nadie. Al otro lado del pasillo cae algo, y lo que anda por la planta va hacia allí.\n03:15 Me llaman a mí, a esta centralita. Sigo sin oír a nadie, pero tengo la sensación de que se lo está pasando bien.\n03:40 He desconectado el cuadro. Sigue sonando.",
	},
	{
		"id": "locust_complaint",
		"creature": "locust",
		"title": "Queja de la habitación 214",
		"header": "Carta dejada en recepción, sin sobre",
		"paper": "carta",
		"body": "Al director:\n\nAnoche, pasadas las tres, el televisor de mi habitación se encendió solo. No había canal: salía mi propia habitación, vista desde la esquina de arriba, con la luz apagada y la cama hecha. Yo estaba acostado en esa cama, y en la imagen no había nadie.\n\nLuego algo se asomó por el borde de la pantalla. Una cara blanca, lisa como una máscara, con agujeros donde van los ojos. Se quedó mirando la cama, el sitio donde yo estaba y en la imagen no estaba.\n\nDesenchufé el aparato y la imagen siguió. Pasé el resto de la noche en el pasillo, con la luz encendida.\n\nNo pienso pagar esa noche. Y le aconsejo que alguien vaya a la 214: cuando me fui, la tele seguía encendida y ya no salía mi habitación. Salía el pasillo, y la puerta de la 214 vista desde fuera, como si lo que había dentro de la tele ya estuviera saliendo.\n\nUn huésped.",
	},
	{
		"id": "locust_rules",
		"creature": "locust",
		"title": "Normas que nadie firmó",
		"header": "Hoja a máquina pegada en el office del personal",
		"paper": "carta",
		"body": "Para quien haga la noche. Esto no viene en ningún reglamento: lo hemos ido aprendiendo.\n\n1. Una tele encendida es una puerta. No enciendas ninguna si no hace falta, y no te quedes delante.\n2. Si oyes chasquidos, como de langosta, no vayas a ver. Sal de su vista y cierra al pasar: a través de las paredes no oye, por las puertas abiertas sí.\n3. Correr hace ruido y cansa. Corre solo cuando ya te ha visto, y no pares hasta haberle salido de la vista un rato: se pierde enseguida.\n4. En el armario no te muevas. Si se queda mirando las puertas y no abre, no salgas: te está esperando.\n5. Las habitaciones de una sola puerta son trampas.\n6. Si se va la luz, no corras a ciegas. Busca el cuarto de servicio y su cuadro.\n7. En la sala del ascensor no entra. Si llegas, espera allí a los demás.\n\nY si alguien no vuelve de su ronda, no salgas a buscarlo de noche.",
	},
	{
		"id": "locust_rooms",
		"creature": "locust",
		"title": "Estado de habitaciones",
		"header": "Parte de la gobernanta, planta segunda",
		"body": "Faltan dos camareras desde el martes. Sus taquillas siguen cerradas y sus abrigos, colgados.\n\nAlguna sigue apuntando la clave del ascensor de la tercera en papeles por las habitaciones, un número en cada una, para no llevarla encima. Los encuentro en los cajones, en las baldas y encima de los muebles. Está prohibido, y lo sabéis.",
		"form": {"number": "0291", "post": "GOBERNANTA", "place": "PLANTA SEGUNDA", "subject": "ESTADO DE HABITACIONES", "type": "observacion", "action": {"derivar": "DIRECCIÓN"}, "priority": "alta", "state": "pendiente", "signed": true, "seed": 291, "rows": [["204", "SIN HUÉSPED. LA CAMA, CALIENTE"], ["209", "ARMARIO REVENTADO"], ["211", "LA TELE NO SE APAGA"], ["217", "NO ABRE NADIE. SE OYE RESPIRAR"], ["223", "HUELE A HIERRO. NO HE ENTRADO"], ["230", "LIMPIA"]], "notes": ["NADIE LIMPIA SOLA", "LA 217 NO FIGURA EN RESERVAS"]},
	},
	{
		"id": "locust_television",
		"creature": "locust",
		"title": "Informe del servicio técnico",
		"header": "Hoja de visita de un técnico de fuera",
		"body": "Revisados catorce aparatos. Ninguno tiene avería: tubo, fuente y antena, en orden.\n\nTodos reciben, aun sin cable de antena, una señal que no emite ninguna estación: la imagen de un pasillo de este hotel, que cambia de pasillo al cambiar de aparato. Con dos aparatos encendidos a la vez, cada uno enseña el sitio donde está el otro, como si estuvieran conectados entre sí.\n\nEn uno de ellos algo pasó muy cerca de la cámara, de una pantalla hacia la otra. Lo vi salir por la segunda.\n\nRecomiendo retirar todos los televisores. Dirección dice que no, que son órdenes de la propiedad y que se quedan enchufados.",
		"form": {"number": "0553", "post": "SERVICIO TÉCNICO", "place": "PLANTAS PRIMERA Y SEGUNDA", "subject": "REVISIÓN DE TELEVISORES", "type": "tarea", "action": {"informar": "DIRECCIÓN"}, "priority": "media", "state": "cerrado", "seed": 553, "notes": ["NO VUELVO", "LA FACTURA, APARTE"]},
	},
	{
		"id": "locust_bellboy",
		"creature": "locust",
		"title": "Carta de un botones",
		"header": "Carta a una madre, sin echar al correo",
		"paper": "carta",
		"body": "Querida mamá:\n\nEl trabajo es bueno y pagan más de lo que te dije. Me han dado un uniforme con botones dorados y una habitación en la planta de servicio. Las normas son raras, pero aquí todo el mundo las cumple sin preguntar, así que yo también.\n\nHay un señor mayor que trabaja en el archivo, en el sótano. No ficha, no come con nosotros y no sale nunca. Dicen que ya estaba aquí cuando construyeron el hotel. El primer día me llamó por mi nombre antes de que nadie se lo dijera, y me preguntó si pensaba quedarme mucho tiempo. Le dije que sí. Apuntó algo.\n\nEl ascensor de servicio solo baja. Lo he visto con mis propios ojos: no tiene botón para subir.\n\nMañana empiezo en el turno de noche. Dicen que de noche es otro hotel.\n\nUn beso muy fuerte. Te escribo pronto.",
	},
	{
		"id": "locust_blackout",
		"creature": "locust",
		"title": "Rondas de la planta segunda",
		"header": "Libreta del vigilante, otra página",
		"paper": "libreta",
		"body": "03:02 Se han ido encendiendo las teles de la planta, una tras otra. Cuando solo quedaba una apagada, se fue la luz de toda la planta a la vez.\n03:05 A oscuras no se cansa. Con luz se para de vez en cuando, como a coger aire. Ahora no se para.\n03:09 El cuadro del cuarto de servicio está cerrado con llave. Mantenimiento deja dos llaves por planta en los cajones de cómodas y cajoneras. Se ve el llavero asomando por la rendija.\n03:20 Cuadro abierto, luz dada. Vuelven a zumbar los fluorescentes. Nunca me había alegrado tanto de oírlos.",
	},
	{
		"id": "locust_before",
		"creature": "locust",
		"title": "Hoja de alguien que bajó",
		"header": "Hoja de libreta suelta, sin nombre",
		"paper": "libreta",
		"body": "No soy del hotel. Me desperté en una habitación de la planta primera con la tele encendida, y no sé cómo llegué.\nTres plantas, una debajo de otra. Para bajar a la siguiente hay que ganarse su ascensor. Para subir no hay manera.\nEn la tercera hay un teclado y cuatro números escondidos en los muebles. Los he marcado en mi hoja con el lápiz, por si alguien viene detrás.\nAlguien vendrá. La puerta de cada ascensor se abre sola en cuanto haces lo que pide su planta. No la abre lo que anda por los pasillos: eso hace ruido. Esto no hace ninguno.\nCreo que a alguien le divierte vernos bajar.",
	},
	{
		"id": "locust_coffee",
		"creature": "locust",
		"title": "Nota en la cafetera",
		"header": "Hoja de libreta pegada con cinta a una máquina",
		"paper": "libreta",
		"body": "El café es gratis desde que no viene nadie a cobrarlo.\nTómate uno cuando empieces a oír puertas que nadie abre, armarios que se cierran o pasos en la sala de al lado. Se pasa enseguida, ya verás.\nLa mitad de lo que se oye de madrugada no está. La otra mitad, sí.\nPara saber cuál es cuál: lo que no está nunca suena cuando lo de verdad anda cerca. Si de pronto todo se calla, no te quedes a escuchar.\nY lava la taza.",
	},
	{
		"id": "locust_infirmary",
		"creature": "locust",
		"title": "Parte del botiquín",
		"header": "Parte de recepción, botiquín del mostrador",
		"body": "Huésped de la 309, varón, de unos cuarenta años. Llega descalzo al mostrador. Dice que algo muy alto ha cruzado la sala de al lado: ha oído sus pasos, sus chasquidos y su respiración, a dos puertas de él. Fuimos a mirar. La sala estaba cerrada y vacía.\n\nEs el tercero esta semana, y no se conocen entre ellos. Los tres llevaban horas sin luz por los cortes de la planta tercera. Los tres juran que se oía igual que lo de verdad.\n\nNo tengo otra cosa que darles que luz y un café. A los tres se les ha pasado.",
		"form": {"number": "0624", "post": "RECEPCIÓN", "place": "BOTIQUÍN", "subject": "CRISIS NERVIOSA DE UN HUÉSPED", "type": "incidente", "action": {"terreno": true, "seguimiento": true}, "priority": "media", "state": "en_curso", "signed": true, "seed": 624, "time": ["04", "10"], "notes": ["VUELVE A SU HABITACIÓN", "PIDE QUE NO LE APAGUEMOS LA LUZ"]},
	},
	{
		"id": "locust_lost",
		"creature": "locust",
		"title": "Objetos perdidos",
		"header": "Hoja del libro de objetos perdidos, conserjería",
		"body": "Nadie ha venido a reclamar nada. Llamamos a los números de las fichas y no contesta nadie, o el número no existe.\n\nLas maletas pesan como si estuvieran llenas. Dirección dice que no se abren, pero de una asomaban papeles por la cremallera y alguien se los ha llevado.\n\nLa videocámara estaba encendida cuando la encontramos, en el suelo, grabando el techo.",
		"form": {"number": "0730", "post": "CONSERJERÍA", "place": "CONSIGNA", "subject": "OBJETOS SIN RECLAMAR", "type": "otro", "action": {"sin": true}, "priority": "baja", "state": "pendiente", "seed": 730, "rows": [["107", "MALETA, SIN ABRIR"], ["112", "ZAPATO DE HOMBRE, UNO SOLO"], ["205", "ALIANZA, EN EL DESAGÜE"], ["219", "VIDEOCÁMARA, SIN CINTA"], ["226", "MALETA, SIN ABRIR"], ["304", "UN DIENTE, EN LA MOQUETA"], ["317", "GAFAS, PISADAS"]]},
	},
	{
		"id": "locust_tapes",
		"creature": "locust",
		"title": "Cintas de seguridad",
		"header": "Parte del vigilante de la sala de control",
		"body": "Faltan las cintas de las cámaras del vestíbulo de las seis últimas noches. No las ha sacado nadie de seguridad, y la sala de control estaba cerrada con llave.\n\nAparecen después, una a una, en el cajón de la mesa: rebobinadas y con una etiqueta escrita a mano. Solo un número. La primera llevaba el 75, y la de ayer, el 80. No es la letra de nadie de aquí.\n\nHe visto la 80 entera. En toda la noche no entra nadie en la sala de control. A las 04:12 la imagen se va a negro un minuto, y cuando vuelve falta otra cinta.\n\nEsta noche falta la de la cámara del ascensor de servicio.",
		"form": {"number": "0812", "post": "SEGURIDAD", "place": "SALA DE CONTROL", "subject": "CINTAS DE VÍDEO DESAPARECIDAS", "type": "incidente", "action": {"informar": "DIRECCIÓN"}, "priority": "alta", "state": "pendiente", "signed": true, "seed": 812, "notes": ["NO LAS HE BORRADO", "SIGO SIN SABER QUIÉN LAS NUMERA"]},
	},
	{
		"id": "locust_wardrobes",
		"creature": "locust",
		"title": "Parte de carpintería",
		"header": "Hoja de avería de carpintería",
		"body": "Cinco armarios con las dos hojas abiertas de golpe a la vez, sin tocar los tiradores. Las bisagras, arrancadas del todo. En dos hay sangre seca por dentro.\n\nLa camarera que se escondió en el de la 132 sigue viva. Dice que la cosa se paró delante, chasqueó una vez y, en vez de abrir, se apartó dos o tres pasos y se quedó mirando las puertas. Ella no se movió. Al rato se fue.\n\nDice también que por la rendija de una hoja mal cerrada se ve todo el pasillo, y que desde el pasillo también se la veía a ella.\n\nPido cambiar las hojas por otras que cierren bien.",
		"form": {"number": "0465", "post": "CARPINTERÍA", "place": "PLANTA PRIMERA", "subject": "ARMARIOS DESTROZADOS", "type": "tarea", "action": {"terreno": true}, "priority": "alta", "state": "en_curso", "seed": 465},
	},
	{
		"id": "locust_manager",
		"creature": "locust",
		"title": "Carta a la propiedad",
		"header": "Copia de una carta del director del hotel",
		"paper": "carta",
		"body": "A la propiedad:\n\nLes escribo por tercera vez, y les ruego que esta vez me contesten.\n\nCuando me dieron el puesto me dijeron que ustedes tenían sus oficinas en este mismo edificio. En siete años no he visto entrar ni salir de ellas a nadie. Hasta hace un mes, por lo menos, llegaban sus entregas de madrugada al muelle de carga. Ya no llega nadie.\n\nDesde entonces se oyen máquinas debajo del sótano, y en los planos que me enviaron no hay nada debajo del sótano. Me faltan tres empleados, y el vigilante de noche se encierra en la sala del ascensor hasta que amanece. Los huéspedes se quejan de algo muy alto que anda por los pasillos.\n\nSu única respuesta ha sido un télex, a las tres de la mañana: CONTINÚEN CON NORMALIDAD. En su número no contesta nadie, y los télex siguen llegando todas las noches a la misma hora.\n\nSi esto es una broma, no la entiendo.\n\nEl director.",
	},
	{
		"id": "locust_evacuation",
		"creature": "locust",
		"title": "Plan de evacuación",
		"header": "Hoja de instrucciones colgada detrás de las puertas",
		"body": "En caso de emergencia, el personal no usará la salida principal. Se dirigirá al ascensor de servicio de su planta.\n\nLa puerta que da al ascensor no se abrirá mientras falte alguien de la planta que siga en pie. No se sale a buscar a nadie: dentro de esa sala no le pasará nada.\n\nEl ascensor no se pondrá en marcha hasta que alguien pulse desde dentro. Siempre baja.\n\nLa propiedad recogerá al personal abajo.",
		"form": {"number": "0019", "post": "SEGURIDAD", "place": "TODAS LAS PLANTAS", "subject": "PLAN DE EVACUACIÓN DEL PERSONAL", "type": "otro", "action": {"informar": "TODO EL PERSONAL"}, "priority": "urgente", "state": "en_curso", "signed": true, "seed": 19, "notes": ["REVISADO POR DIRECCIÓN", "SIN SIMULACROS, POR ORDEN DE LA PROPIEDAD"]},
	},
	{
		"id": "locust_family",
		"creature": "locust",
		"title": "Carta de una madre",
		"header": "Carta recibida en recepción, con su sobre",
		"paper": "carta",
		"body": "Muy señores míos:\n\nMi hijo se alojó en su hotel hace cinco semanas, en la habitación 118. Desde entonces no sabemos nada de él. Ustedes me contestan que no consta ninguna reserva a su nombre, pero tengo delante su última postal, con el sello del hotel.\n\nEn ella dice que el hotel es precioso y que hay muy poca gente. Dice que de noche la tele de su habitación se enciende sola y que no le importa, porque le hace compañía. Y dice que el ascensor del fondo tiene un botón más que los otros, por debajo del último, y que ese botón no lleva número.\n\nNo les pido que me devuelvan el dinero. Les pido que alguien vaya a mirar.\n\nQuedo a la espera de su respuesta.",
	},
	{
		"id": "locust_insomniac",
		"creature": "locust",
		"title": "Lo que sé de él",
		"header": "Libreta de un huésped, la página más gastada",
		"paper": "libreta",
		"body": "Lo que sé de él, por si me pasa algo:\nNo ronda la sala de al lado: se va lejos, a las que lleva más tiempo sin ver. La que acaba de mirar es la más segura durante un rato.\nAl entrar en una sala se queda quieto un momento, mirando.\nSi le sales de la vista unos segundos se pierde, y se pone a buscar por donde te vio la última vez.\nCuando bajo de planta, baja detrás. Tarda un poco en empezar a buscar, como si contara.\nCorre tanto como yo, o más. No le ganes corriendo: gánale doblando esquinas.\nHoy me ha mirado desde el otro extremo del pasillo. Creo que ya sabe dónde duermo.",
	},
	{
		"id": "locust_lift",
		"creature": "locust",
		"title": "Revisión del ascensor de servicio",
		"header": "Parte del ascensorista, sin firmar",
		"body": "Cabina, cables y frenos en buen estado. Observaciones:\n\nLa botonera tiene un solo pulsador, sin rótulo. La cabina no se mueve hasta que alguien lo pulsa desde dentro, y siempre va hacia abajo. No hay forma de hacerla subir, tampoco desde la sala de máquinas. Y sin embargo cada mañana está otra vez arriba, esperando con las puertas abiertas.\n\nPor las marcas de las guías, el hueco tiene paradas por debajo del sótano que no figuran en ningún plano. He contado tres.\n\nSolté una moneda por la rendija de la puerta. No la oí llegar al fondo.\n\nNo firmo la revisión hasta que alguien me explique adónde va.",
		"form": {"number": "0904", "post": "MANTENIMIENTO", "place": "ASCENSOR DE SERVICIO", "subject": "REVISIÓN ANUAL", "type": "tarea", "action": {"derivar": "LA PROPIEDAD"}, "priority": "media", "state": "pendiente", "seed": 904},
	},
	{
		"id": "locust_archive",
		"creature": "locust",
		"title": "Acuse de recibo del archivo",
		"header": "Impreso del hotel, con el sello del archivo",
		"body": "Recibidos en el archivo los papeles de la planta primera. Constan todos, también los que nadie llegó a entregar.\n\nTodo lo que se escribe en este edificio acaba aquí, tarde o temprano: las notas, los partes, las cartas que no se echaron al correo y las cintas. Se ordenan y se guardan. El archivo no cierra.\n\nA quien lea esto: no hace falta que lo devuelva. Ya consta.",
		"form": {"number": "0001", "post": "ARCHIVO", "place": "SÓTANO", "subject": "ACUSE DE RECIBO", "type": "otro", "action": {"sin": true}, "priority": "baja", "state": "cerrado", "signed": true, "seed": 1, "notes": ["ARCHIVADO", "COPIAS: NINGUNA"]},
	},
]

static func entry(id: String) -> Dictionary:
	for item in ENTRIES:
		if item.id == id: return item
	return {}

static func for_creature(creature: String) -> Array:
	return ENTRIES.filter(func(item): return item.creature == creature)
