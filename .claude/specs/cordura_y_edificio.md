# Plan: la cordura, el doppelgänger y el edificio grande (piso 2)

Pedido del autor el 18 de noviembre de 2026, tras la 1.10.2. Este documento es el plan de desarrollo. Nada de lo que describe está hecho todavía.

**Cómo se trabaja este cambio:** el autor pidió hacerlo todo de forma autónoma y sin delegar en otros agentes. Lo hace la sesión principal sola, en serie, fase por fase. Manda sobre el reparto en tres niveles de `CLAUDE.md` mientras dure este plan.

## 1. Lo que pide el autor

**The Lurker**
1. La cordura pasa a ser el centro. Con la cordura a 0, The Lurker puede coger a un jugador aunque la mire o la alumbre. La cordura ya no se recupera con luz.
2. La cordura se recupera con las máquinas de café: dos por planta, una en la llegada y otra en una esquina del plano, lejos de los puntos de interés. Al beber sale «Te sientes mejor...».
3. Habilidad nueva, Doppelgänger (tecla E): deja un clon acechando en una esquina. Si alguien pasa cerca sin verlo, lo asalta: susto y bajada fuerte de cordura. Si lo ven antes, huye y baja un poco la cordura. Unos 10 s de espera, sin límite de clones.
4. Fuera los ductos para quien la lleva: no aportaban, basta con andar por los techos.
5. El cambio de planta de ella es un recorrido de bajada que se ve y se entiende, no un viaje por ductos.
6. Espera entre ataques según los jugadores: 5 s con uno, bajando hasta 1,25 s con cinco. Atacar varias veces seguidas al mismo jugador baja cada vez menos cordura, para que alterne. Muy permisivo con quien juega solo.
7. Interfaz de quien la lleva rehecha entera: un disco con la espera del ataque, la presa coloreada de verde a rojo según su cordura, mucha más información visual. Antes, el autor decide qué recursos visuales de hoy quedan y cuáles salen (anexo A).
8. Las linternas y su haz se ven desde mucho más lejos, y se distingue mejor una sala con luz de una sin ella.
9. Beber la luz cada 10 s: apaga las luces y las linternas de la sala en la que está y de todas las contiguas (un 3 × 3 centrado en ella).

**El edificio**
10. Cada planta dura unos 15 minutos; el piso entero, de 40 a 50. Hoy el autor lo acaba en 6 a 12.
11. Fuera los códigos de sala y todo lo que cuelga de ellos.
12. Planta 1: todo más grande, más salas, todo más lejos y escondido. Llegar a la ventanilla de Personal tarda al menos 8 minutos, por un camino con vueltas que parecen contradecir el cartel.
13. Planta 2: un tipo de sala nuevo y otra vez todo más grande. Recorrido: llegada, cuadro eléctrico (como mucho 3 sectores a la vez, a elegir; uno ha de ser el de la gestión del montacargas; con un cuarto saltan todos los automáticos; el cartel lo dice), puerta motorizada pesada que solo abre con la corriente de su sector, y dentro la palanca del montacargas. Sin tictac: el montacargas queda libre al bajar la palanca. Los puntos, lejísimos unos de otros.
14. Planta 3: llegada, sala de seguridad (pantallas de modelos reales en vez de las de hoy), sentarse y usar un sistema de cámaras de la planta: plano completo, encender luces de cualquier sala, mirar y desbloquear hasta 8 salas especiales con cierre eléctrico, reconocer cuál es la sala de ventilación y abrirla. Las luces encendidas son señuelos para ella. En Versus, quien la lleva ve movimiento de jugador en esas salas hasta que se acerca. Quien opera las cámaras queda camuflado.
15. Evento de la ventilación: al abrir la escotilla, a ella se le avisa con radiación y luz en su pantalla. El ducto de escape pasa a ser un laberinto pequeño; ella elige por qué brazo entra, también por los que no tienen salida. Quien se mete en un brazo sin salida queda en desventaja; quien elige bien y se gira a tiempo, sale.

## 2. Lo que hay hoy (leído del código y de las medidas)

| Cosa | Hoy | Dónde |
|---|---|---|
| Superficie de una planta | mediana 3.340 m² (de 2.026 a 3.733) | `evidence/planta/metricas.json`, 200 semillas, 2 supervivientes |
| Salas por planta | medianas 57, 59 y 63 (máximo 75); tope de 99 por la numeración | igual; `office_generator.cap_numbers()` |
| Edificio | anillo de 11 o 12 vanos, espina de 12 o 13; de 86 a 101 m de largo por 23 a 41 de fondo | `office_palette.TYPOLOGIES` |
| Camino de la llegada a la salida | medianas 88, 96 y 109 m | `walk_0..2` |
| La ventanilla en ese camino | al 30 % (de 20 a 50 %): unos 26 m desde la recepción | `window` |
| Cordura | baja a oscuras (100 en 7,5 min; con linterna, 2,5 veces más lento); **sube con luz** (100 en 4 min); verla cuesta 4, que te mire 15, una vez cada 5 s; su chillido, 6 | `game/app/sanity.gd` |
| Cordura a 0 | el cuerpo queda marcado: quien la lleva lo ve a través de las paredes | `sanity.gd`, `lurker_view.gd` |
| Café | de 3 a 5 máquinas por piso, una taza por superviviente y máquina, devuelve la cordura entera, sin texto | `game/app/coffee.gd` |
| Ataque de quien la lleva | carga de 2 s vigilando; cae detrás y pide el aviso de la espalda; girarse con luz, correr o mirarla con luz salva; tras un fogonazo, 6 s sin atacar | `lurker_player.gd`, `lurker_warning.gd` |
| Beber la luz (Versus) | solo abajo, solo su sala, 6 s a oscuras, cada 25 s y 45 s por sala; nunca hitos ni vestíbulos | `lurker.gd` (`VERSUS_EVERY`, `judge_drink()`) |
| Ductos de quien la lleva | E junto a una rejilla: red en 3D, elegir salida, viaje a 9 m/s | `lurker_player.gd` (`start_trip()` y siguientes), `lurker_view.network()` |
| Cruce de planta | por el tronco de ductos, con los colores de la red | `lurker_versus.md` §7 |
| Planta 2 | palancas por zona con tope (3 o 2 según dificultad; la más antigua baja sola), palanca roja en el mismo cuadro, reloj de 45 a 90 s | `power_objective.gd` |
| Planta 3 | puesto con la ficha, consola que arranca ventiladores con cargas, paro, compuerta, ducto recto de 25 a 45 m con un cruce | `air_objective.gd`, `main_duct_geometry.gd` |
| Códigos | placa «P-114» por puerta, código de zona («R-2 ARCHIVO») en el cuadro y en los rótulos de pasillo | `office_palette.plaque()`, `power_objective.gd:110` |
| Las tres plantas | se generan y se montan a la vez | `floor_definition.PLANTAS`, `office_generator` |

## 3. Decisiones de diseño que propongo

Son propuestas. Las cifras son puntos de partida para afinar jugando, y cada una queda en una sola tabla del código.

### 3.1 La cordura (solo el piso 2; el hotel no cambia)

- **No sube con luz.** Una regla del tipo de piso; el hotel conserva la suya (`manifest_golden_test` y `creature_contract_test` no se tocan).
- **Sube solo con café** y al cambiar de planta, como hoy.
- **A 0:** el aviso de la espalda sigue sonando siempre, pero ni mirarla ni alumbrarla salvan a quien está a 0. Le salva correr (ella nunca alcanza a quien corre) y la luz o la mirada de un compañero que conserve cordura. Así, estar a 0 obliga a huir hacia un café.
- **Verla ya no puede costar lo de hoy.** Sin recuperación, que te mire costando 15 cada 5 s vacía a un jugador atento en medio minuto. La economía nueva, de partida:

| Qué | Coste | Notas |
|---|---|---|
| Oscuridad | como hoy | con la linterna encendida, 2,5 veces más lento |
| Verla de pasada | 2 | una vez cada 8 s |
| Que te mire | 5 | una vez cada 8 s |
| Ataque parado (te giraste o la alumbraste a tiempo) | 8 | cada repetición al mismo jugador, × 0,8, hasta × 0,4; recupera un escalón cada 20 s sin que lo ataque |
| Asomo visto | 6 | una vez cada 10 s por persona, como hoy |
| Doppelgänger que te asalta | 30 | |
| Doppelgänger visto a tiempo | 5 | |
| Su chillido cerca | 6 | como hoy |
| Jugador solo | todo lo suyo × 0,75 | «muy permisivo con un jugador en solitario» |

- **Meta que se comprueba con una simulación** (prueba nueva, sin Godot en marcha más de unos segundos): con defensa perfecta, una cordura entera aguanta al menos 5 minutos de presión seguida en solitario y al menos 3 con cinco jugadores. Con la llegada y dos cafés son tres barras por planta.

### 3.2 El café

- Dos máquinas por planta: una en la sala de llegada (la recepción o el vestíbulo de llegada) y otra en la sala corriente más alejada de la llegada y de todos los hitos, en un rincón.
- Una taza por superviviente y máquina, como hoy. Recargable, un jugador atento junto a la máquina volvería a ser intocable.
- «Te sientes mejor...» en pantalla al notarse el café. Es una excepción que pide el autor a la regla de no escribir nada en partida.

### 3.3 El ataque y su espera

- Espera entre ataques de ella: 5,0 s con 1 superviviente vivo en su planta, 4,06 con 2, 3,13 con 3, 2,19 con 4 y 1,25 con 5. Se ve en su disco.
- Vale para quien la lleva. A la IA le sirve de suelo: nunca vuelve a intentarlo antes, y su dificultad puede alargarlo.
- La carga de 2 s vigilando se conserva para el salto largo.

### 3.4 Beber la luz

- Cada 10 s. Apaga 6 s las lámparas de su sala y de las salas contiguas (las que comparten con ella puerta, lado abierto o pared), y las linternas de quien esté dentro.
- También desde el plénum, sobre la sala que tiene debajo.
- No toca los vestíbulos del montacargas, las luces de emergencia ni la lámpara propia de cada hito. Fuera la espera de 45 s por sala.
- Las linternas vuelven a la tercera pulsación y nunca antes de 1 s, como hoy.

### 3.5 Doppelgänger

- E deja un clon en la esquina de techo más cercana de la sala en la que está o que tiene debajo. Espera de 10 s. Nunca en vestíbulos ni salas protegidas.
- El clon es su modelo real, quieto. Los supervivientes lo ven como a ella.
- **Asalto:** si un superviviente pasa a menos de 3,5 m sin haberlo visto, salta a su cara: medio segundo de su cara y sus manos, su chillido, 30 de cordura, y se deshace en tinta. No mata nunca.
- **Visto a tiempo:** si alguien lo tiene en su imagen con luz (la de la sala o su linterna) durante 0,3 s a menos de 10 m, o a menos de 4 m a oscuras, huye al techo: 5 de cordura.
- Sin límite de diseño. Tope técnico de 12 clones vivos: al dejar el decimotercero se deshace el más viejo.
- Lo juzga el anfitrión; viaja como un evento más de la criatura.
- La IA del cooperativo también los deja, de Equilibrada para arriba y con menos frecuencia. Va en una fase posterior a la del jugador.

### 3.6 Fuera los ductos de quien la lleva

- Se quitan el modo de red, el viaje, sus marcas y su tecla. E pasa al Doppelgänger.
- La IA no cambia: sigue moviéndose por el plénum y los ductos.
- El ducto de escape de la planta 3 no es de esta red: se queda y crece (3.11).

### 3.7 La bajada entre plantas

- Al cerrarse la etapa, ella va sola por el plénum hasta el montante del núcleo (el hueco de instalaciones junto al montacargas), se descuelga por él cabeza abajo y sale al plénum de la planta siguiente. Unos 5 s, con su cámara detrás y la losa cortada a la vista: se ve que atraviesa un forjado.
- Es automático, como hoy el cruce. Los supervivientes siguen oyéndola arañar por fuera del coche.

### 3.8 El edificio grande

- **Meta de tamaño**, a confirmar con la medición de la fase 0: de 2,5 a 3 veces la superficie de hoy (de 8.000 a 10.000 m² por planta, de 150 a 200 salas), con un edificio de 20 a 24 vanos (144 a 173 m) y más fondo (una segunda pareja de filas centrales con su pasillo).
- **Compartimentos.** La planta se parte en 4 a 6 sectores con muro cortafuegos y una sola puerta entre cada dos, en lados alternos: el camino hace eses por todo el edificio. Es lo que hace que el cartel parezca contradecirse: la flecha sigue el camino andable, que se aleja antes de volver.
- **Pasos cortados.** Algún pasillo directo queda cerrado (una reja, una puerta de servicio atrancada), para que el camino corto a la vista no sea el bueno.
- **Señales:** siguen escasas. La flecha de cada señal apunta por el camino andable.
- **Un superviviente:** se mantiene la regla de hoy (edificio menor), pero las metas de tiempo valen también para él.
- **Si el coste no cabe:** hoy las tres plantas se montan a la vez. Si triplicar la superficie no cabe en memoria, carga o fotogramas, la alternativa es montar solo la planta en juego y la siguiente durante el viaje del montacargas. Es un cambio grande y solo se hace si la fase 0 lo exige.

### 3.9 Planta 1

- La ventanilla, en el último sector del camino en ese: camino andable de la recepción a la ventanilla de 400 m o más (hoy, unos 26).
- De 16 a 28 estaciones del tubo en vez de 8 a 14.
- El montacargas, en otro sector, lejos de la ventanilla y de la recepción.

### 3.10 Planta 2

- **Sala nueva: la sala de maniobra del montacargas.** Un cuarto técnico con la palanca del montacargas, detrás de una puerta de acero motorizada.
- **El cuadro:** una palanca por sector (de 8 a 12). Se suben y se bajan con libertad. Como mucho 3 arriba: al subir la cuarta saltan todas con un golpe y la planta vuelve a la emergencia. Sin palanca roja y sin reloj.
- **El cartel del cuadro:** «Durante un apagón el sistema de respaldo solo puede manejar 3 sectores de electricidad. Por favor, no sobrecargar el sistema.»
- **La puerta:** sin corriente en su sector, un piloto rojo y un golpe sordo al intentarlo. Con corriente abre sola, despacio (4 a 5 s) y con un motor pesado. Si el sector se cae, se queda como esté.
- **La palanca de dentro** libera el montacargas en el acto.
- **Distancias** de camino andable: llegada a cuadro, cuadro a sala de maniobra y sala de maniobra a montacargas, 250 m o más cada una, en sectores distintos.
- El tope de 3 vale para todas las dificultades.

### 3.11 Planta 3

- **Sala de seguridad:** monitores y consola de modelos reales (se descargan con licencia que permita vender, o se recicla el terminal IBM que ya hay en `assets/props/office/`). Se quitan las pantallas hechas a mano y su parpadeo de superficies.
- **Sentarse** abre el sistema de cámaras, a pantalla completa y con el estilo de la cámara:
  - el plano completo de la planta, con el estado de la luz de cada sala;
  - las 8 salas especiales, marcadas CAM 1 a CAM 8, cada una con su cámara en directo (una sola imagen a la vez, a baja resolución);
  - encender o apagar la luz de cualquier sala, con un tope de 4 encendidas a la vez (la batería);
  - abrir o cerrar el cierre eléctrico de una sala especial.
- **Las 8 salas especiales:** la sala de ventilación y 7 más, distintas a la vista de la cámara. El jugador reconoce la climatizadora y abre esa. Sin lore nuevo: salas técnicas y de archivo corrientes.
- **Los señuelos:** una luz encendida desde las cámaras dura hasta que ella llega a 6 m o 60 s.
  - La IA la toma como una presencia que investigar, con la probabilidad de su dificultad.
  - Quien la lleva ve en esa sala figuras como las de los jugadores, que se mueven y desaparecen al acercarse.
- **El operador, camuflado en Versus:** sentado no lleva contorno ni baliza, y la consola en uso lee igual que las demás.
- **Los ventiladores salen del recorrido:** ya no hay que arrancarlos ni pararlos. La climatizadora queda como máquina de la sala. La compuerta abre con la sala desbloqueada.
- **La alerta:** al abrir la compuerta, la pantalla de quien la lleva se llena de calor y la sala arde a través de las paredes con la dirección marcada. La IA va hacia allí.
- **El laberinto:** el ducto de escape pasa de una línea de 25 a 45 m a una red de 60 a 90 m con 4 a 6 cruces, de 3 a 5 brazos sin salida y un solo camino al pozo. Cada brazo acaba en una rejilla por la que ella puede entrar.
  - Dentro, ella va a 1 m/s y quien repta a 1,2, como hoy.
  - Darse la vuelta dentro cuesta 1 s. En un brazo sin salida, la víctima tiene la espalda hacia la única entrada.
  - Avisa desde dentro a quien no mira atrás; girarse a tiempo con luz la echa, como siempre.
  - Quien la lleva ve el laberinto desde arriba con quienes reptan, y cada brazo con su entrada marcada: elige una y entra.

### 3.12 Códigos de sala

- Fuera las placas «P-114», la numeración de las salas, el código de zona del cuadro y de los rótulos de pasillo, y el tope de 99 salas.
- Se quedan los nombres de zona («ARCHIVO») y los números de estación del tubo.

## 4. Fases

Cada fase acaba con sus pruebas, una pasada de `tools/verify.ps1`, sus capturas o medidas, los documentos al día (`docs/OFICINAS.md`, este plan, `.claude/relevo.md`) y su commit. Entre fases se puede jugar.

| Fase | Qué | Tamaño | Versión |
|---|---|---|---|
| 0 | Medir antes de decidir | pequeña | ninguna |
| 1 | Cordura, café y el ataque | mediana | 1.11.0 |
| 2 | Doppelgänger, sin ductos, beber 3 × 3, la bajada | grande | 1.12.0 |
| 3 | Interfaz y vista de quien la lleva | grande | 1.13.0 |
| 4 | Sin códigos y el edificio grande | muy grande | 1.14.0 |
| 5 | Planta 1 lejana | mediana | con la 4 |
| 6 | Planta 2: sectores, puerta y sala de maniobra | grande | 1.15.0 |
| 7 | Planta 3: seguridad y cámaras | muy grande | 1.16.0 |
| 8 | Planta 3: alerta y laberinto | grande | con la 7 |
| 9 | Tiempos, la IA con clones, remates | mediana | 1.17.0 |

El tamaño es relativo. No doy horas: no tengo forma fiable de estimarlas.

### Fase 0. Medir antes de decidir

- Una herramienta nueva, `tools/dev/office_explorer.gd`: un explorador ingenuo que recorre el plano sin conocerlo (abre lo que ve, sigue la señal que tiene delante, vuelve atrás) y da los minutos a pie hasta cada hito, sobre muchas semillas y sin montar el piso.
- La línea de base de hoy con esa herramienta y con los bots (`tools/bots.ps1`).
- Una prueba de escala sin diseño nuevo: el edificio de hoy con el doble de vanos. Se miden generación, montaje, carga, memoria y banco.
- **Sale de aquí:** el tamaño que cabe y si hace falta montar las plantas de una en una. Se lo cuento al autor antes de la fase 4.

### Fase 1. Cordura, café y el ataque

- `sanity.gd`: la regla sin luz y los costes nuevos para el piso 2; la cuenta de repeticiones por víctima.
- `lurker_warning.gd`, `lurker.gd`: a 0 no salvan la mirada ni la luz propias; la espera entre ataques por jugadores, para la IA y para quien la lleva.
- `coffee.gd`: dos por planta con la colocación nueva; el texto.
- Pruebas: la simulación de la economía, `coffee_test`, `lurker_fairness_test`, `lurker_stalk_test`, `office_lies_test` y lo que dependa de la recuperación con luz.
- **Aceptación:** la simulación cumple las metas de 3.1; en una partida con bots, un superviviente a 0 que la mira es cogido tras su aviso, y uno que corre se salva.

### Fase 2. Doppelgänger, sin ductos, beber, la bajada

- El clon: su nodo, su juez en el anfitrión, su evento en la red, el asalto y la huida. Reutiliza el modelo de las alucinaciones (`phantom_sight`) donde sirva.
- Quitar el modo de ductos de `lurker_player.gd`, `lurker_view.gd`, `match_net.gd`, las sugerencias y sus pruebas.
- Beber con la regla nueva (`judge_drink()`, `drink()`), y sus pruebas.
- La bajada por el montante: su recorrido, la cámara y el corte de la losa.
- Protocolo de red a `the-four-net-24`.
- **Aceptación:** `net_test` de Versus con clones (asalto y visto a tiempo) y con la bajada; una sesión con ventana de `lurker_hunt_drive` con capturas de cada cosa.

### Fase 3. Interfaz y vista de quien la lleva

Empieza cuando el autor diga qué queda y qué sale del anexo A.

- El disco de la espera del ataque.
- La presa coloreada de verde a rojo por su cordura (el dato ya llega a su máquina dos veces por segundo).
- Las linternas como baliza desde mucho más lejos (de 30 a 80 m o más) y su haz dibujado.
- Las salas con luz y sin luz, distintas de un vistazo.
- Los clones dejados, marcados; la huella de lo que apagaría al beber.
- **Aceptación:** una hoja de capturas con cada recurso y su leyenda, para que el autor la juzgue.

### Fase 4. Sin códigos y el edificio grande

- Quitar los códigos (3.12) y el tope de 99.
- El edificio según lo que diga la fase 0: más vanos, más fondo, los sectores con sus puertas alternas, los pasos cortados.
- El validador, la comprobación física, la navegación de ella, el plano de la hoja y las señales, a la escala nueva.
- `office_palette.VERSION` a 4.
- **Aceptación:** 60 semillas sin planta de reserva; el banco dentro de lo que el autor acepte (hoy, 8,9 ms el recorrido); las pruebas de oficina en verde; el hotel, sin cambios.

### Fase 5. Planta 1 lejana

- La ventanilla al fondo del camino en ese, el montacargas en otro sector, más estaciones.
- **Aceptación:** en 60 semillas, camino andable a la ventanilla de 400 m o más en el 95 %; el explorador ingenuo, 8 minutos de mediana hasta la ventanilla y 13 o más la planta.

### Fase 6. Planta 2

- La sala de maniobra (tipo nuevo en `office_palette`, su receta, su hito), la puerta motorizada con su sonido (se busca con licencia válida), el cuadro con la regla de los 3 y su cartel, fuera la palanca roja y el reloj.
- **Aceptación:** `net_test` de la planta entera con el recorrido nuevo; el explorador ingenuo, 13 minutos o más de mediana.

### Fase 7. Planta 3: seguridad y cámaras

- Los modelos de pantallas, el asiento, la interfaz de cámaras, los cierres eléctricos, las 8 salas, las luces como señuelo para la IA y las figuras falsas para quien la lleva, el camuflaje del operador, fuera los ventiladores del recorrido.
- **Aceptación:** una partida entera con bots por el recorrido nuevo; capturas de la interfaz; en Versus, las figuras falsas y su desaparición.

### Fase 8. Planta 3: alerta y laberinto

- La red del ducto de escape en el generador y en su geometría, las rejillas de los brazos, la vuelta dentro del ducto, la alerta, el modo de quien la lleva para elegir brazo.
- **Aceptación:** en 60 semillas el laberinto cabe y tiene un solo camino al pozo; `net_test` con una captura en un brazo sin salida y una huida girándose a tiempo.

### Fase 9. Tiempos y remates

- Medir las tres plantas con el explorador y con los bots, y ajustar hasta los 15 minutos por planta.
- La IA con clones.
- Auditoría de los documentos contra el código.

## Estado de la fase 0 (18 de noviembre de 2026)

**El explorador.** `tools/dev/office_explorer.gd` hace las medidas sobre el plano, sin montarlo: 40 semillas en 38 s. Registros en `evidence/planta/fase0/`.

| Plano | Salas por planta (con celdas de pasillo) | Explorador ingenuo, piso (mediana) | Por planta | Camino directo, piso | Dibujar un piso |
|---|---|---|---|---|---|
| Hoy (área 1, 2 supervivientes) | unas 120 | 15,3 min (8,5 a 19,2) | 4,0 · 4,1 · 7,0 | 4,8 min | menos de 1 s |
| Área 2 | 242 | 25,4 min | 6,5 · 7,3 · 11,9 | 5,8 min | 1,4 s |
| Área 3 | 356 | 31,2 min | 8,6 · 9,7 · 14,1 | 6,8 min | 2,4 s |

- **Calibración.** El autor tarda hoy de 6 a 12 minutos, entre el camino directo (4,8) y el ingenuo (15,3), que no lee las señales. Un jugador real tarda unas 0,6 veces lo que tarda el ingenuo.
- **Lo que sale de aquí:** el tamaño solo no basta. Con el triple de superficie, el ingenuo tarda el doble y el camino directo apenas crece, porque los hitos siguen colocados por su fracción del recorrido.
  - Para 40 a 50 minutos de jugador real hacen falta, además del tamaño, los caminos en ese entre sectores (3.8) y los tramos nuevos de cada planta (3.9 a 3.11).
  - La meta en el explorador: 25 minutos de ingenuo por planta.
- **El coste del edificio de área 2**, en el banco en Alto con la semilla 81 (`--office-area=2.0`, una opción nueva de `office_palette.areas_for()` solo para herramientas):

| Medida | Área 1 | Área 2 |
|---|---|---|
| Recorrido | 8,99 ms (banco de la 1.10.2, 1920 × 1080) | 9,97 ms |
| Primitivas | 415.000 | 715.000 |
| Objetos | 891 | 1.601 |
| Carga del piso | unos 21 s | 24,5 s |
| Memoria estática máxima | 1,11 GB | 1,32 GB |

- **Conclusión:** cabe, así que no hace falta montar las plantas de una en una. La pasada de área 1 de esta prueba salió a 2560 × 1369 y no se compara.

## Estado de la fase 1 (18 de noviembre de 2026)

Hecha según 3.1 a 3.3, con dos cambios sobre la propuesta tras simular la economía (`tests/office/lurker_mind_test.gd`):
- **Cifras finales:** verla cuesta 1,5; que te mire, 3,5; un susto cada 12 s (no 8); su asomo, 6; su chillido, 3. Quien juega solo paga el 60 % (no el 75 %): con el 75 %, solo y bajo presión seguida, la cordura acababa a los 5 minutos justos.
- **Dónde:**
  - las cifras, en `lurker.gd` (`MIND`, `ATTACK_WAIT`, `attack_wait()`, `parried_cost()`);
  - la regla sin luz y los costes, en `sanity.gd` (`rules()`, `pay()`, `alone_share()`);
  - la mente gastada, en `creature_sight.spent()`, que quita su mirada y su linterna de `watched()`, `torch_covers()` y `look_of()`; `lurker_brain.cue_allowed()` la avisa aunque la mire, y `lurker_warning.check()` no aborta por la luz;
  - la espera entre avisos, en `lurker_warning.can_start()` (`gap`, `last_start`); quien la lleva la ve en su tecla (`lurker_player.judge_prey()`);
  - el café, en `coffee.place_offices()` y `hotel_ui.flash(..., steady)`.
- **Pruebas:**
  - `lurker_fairness_test`: dos casos nuevos, a 0 ni su linterna ni la luz la salvan; la linterna de un compañero con cordura sí, la de uno a 0 no;
  - `lurker_mind_test` (nueva);
  - `coffee_test`: dos por planta, una en la llegada y otra lejos;
  - `lurker_stalk_test` reinicia la espera entre casos.
- **Sin comprobar en una partida:** el ritmo real, con la IA y en Versus.

## Estado de la fase 2 (18 de noviembre de 2026)

Hecha según 3.4 a 3.7, solo para quien la lleva en Versus (la IA del cooperativo no deja dobles ni bebe en 3 × 3 todavía: fase 9).
- **Doppelgänger** (`lurker_doubles.gd`):
  - E (X en el mando) pide al anfitrión un doble (`match_net.lurker_double()`, `lurker.judge_double()`);
  - el doble es su modelo de verdad, boca abajo y colgado en la esquina de la sala más cercana a ella;
  - lo juzga el anfitrión (`lurker_doubles.judge()`) y viaja como evento de la criatura (`"double"`);
  - el salto cuesta 30 de cordura (`MIND.double`, que baja con las repeticiones como los ataques parados) y ser visto, 5 (`MIND.double_seen`);
  - tope de 12 vivos.
- **Fuera los ductos de quien la lleva:**
  - código quitado: el viaje en `lurker_player.gd`, su dibujo en `lurker_view.gd` (red, columnas, colores morado y rosa), `judge_duct()` y `request_duct`;
  - la acción `lurker_enter` pasa a ser `lurker_double`.
- **Beber 3 × 3** (`lurker.touching()`, `deep_more`):
  - cada 10 s (`VERSUS_EVERY`), sin la espera de 45 s por sala, también desde el plénum;
  - el evento `"drink"` lleva las salas de alrededor.
- **La bajada** (`lurker_motion.begin_drop()`, `descend()`):
  - entra en el tronco sobre el pasillo más cercano y baja por él del 20 al 80 % de los 8,5 s del viaje;
  - la cámara de quien la lleva la sigue con su vista de siempre, sin los colores de los ductos.
- **Protocolo** `the-four-net-24`.
- **Pruebas:**
  - `lurker_player_test`: el doble en una esquina de cada planta, otro rechazado en su espera;
  - `lurker_stalk_test`: el salto a quien pasa debajo sin verlo y la huida si lo ven con luz;
  - `net_test` `lurker_versus`: las salas que tocan la suya se beben con ella;
  - `creature_contract_test`: la lista de mensajes de red, con `request_double`;
  - `verify`: 100 de 102; las dos que fallaron se arreglaron y pasaron sueltas (la lista de mensajes de red y el tirón de `voice_test`). Banco igual (8,85 ms).
- **Sin ver todavía:**
  - no hay capturas del doble ni de la bajada en una partida;
  - la pantalla de quien la lleva no marca sus dobles (fase 3).

## 5. Riesgos

- **El coste del edificio grande** no se conoce hasta la fase 0. Puede obligar a montar las plantas de una en una.
- **El tiempo de un jugador real no se puede medir sin jugadores.** El explorador ingenuo y los bots son aproximaciones; los 15 minutos se confirman cuando juegue el autor.
- **La economía de la cordura** cambia el piso entero, también en cooperativo contra la IA. Hay que rejugar las cuatro dificultades.
- **Las cámaras** dibujan una segunda vista del mundo: se limita a una imagen a la vez y a baja resolución.
- **El laberinto** corre por el plénum sobre salas ya amuebladas: puede no caber en todos los edificios y pedir reintentos del generador.
- **Assets nuevos** (pantallas, sonido de la puerta): dependen de encontrar licencias que permitan vender.
- **Las partidas guardadas y los ejecutables viejos** dejan de valer en cada cambio de protocolo o de versión del generador.

## Anexo A. Recursos visuales de quien lleva a The Lurker, hoy

Para que el autor diga cuáles quedan y cuáles salen.

**La imagen**
1. Visión térmica en azul marino muy oscuro: la geometría fría, casi negra y legible.
2. Las luminarias de las salas encendidas como calor (magenta desde arriba).
3. Las luces de emergencia como calor.
4. Las lámparas de los hitos y de los muebles como calor.
5. Las máquinas de los objetivos (máquina de escribir, estaciones, lector, cuadro, minuteros, consola, climatizadora, compuerta): brillan con su forma y laten si alguien está a menos de 1,6 m.
6. Los rotores de la climatizadora en marcha.
7. Los cables vivos de las salas encendidas, tenues, hasta 16 m.
8. Las linternas: lo más caliente, y baliza a través de las paredes hasta 30 m.
9. La mancha de calor que una fuente tapada deja en la cara del muro que la tapa.
10. Las personas: figuras oscuras con un contorno claro, hasta 20 m.
11. Quien está a cordura 0: silueta fría a través de las paredes.
12. Desde arriba no se dibuja el falso techo: se ve dentro de las salas, con la perfilería tenue a su alrededor.
13. Todo a negro pasados unos 20 m, salvo lo que brilla.
14. Los núcleos y el borde del edificio como muros hasta la losa (lo que la para).
15. Su cuerpo real con su tinta y un borde frío, tramado donde taparía a la presa o el centro de la imagen.
16. La ganancia automática de la cámara entre lo más frío y lo más caliente.
17. El grano y las rayas del sensor.
18. La calibración: la imagen se congela 0,35 s con un clic cada 25 a 55 s.
19. El deslumbramiento de su propia sala encendida más allá de 4 m.
20. El fogonazo: la imagen saturada 2,5 s cuando le dan con una linterna en la cara.
21. La huida: la imagen se cierra por los bordes y la cámara sube sola.
22. La onda de calor de un ruido fuerte (una puerta, una carrera, el tecleo), 0,9 s.
23. La estela de los halos al mover la cámara.

**Marcas en el mundo**
24. La presa sobre su figura: blanca si puede atacar, roja si no.
25. La placa por la que caería detrás de la presa, con ese mismo color.
26. Una línea roja desde los ojos de quien le vería la cara.
27. Una línea roja desde la linterna que la cubre.
28. El suelo de la sala enrojecido si la presa está en una sala con luz.
29. El contorno de la placa por la que bajaría, con su tecla al lado.
30. El contorno de la entrada de ducto a menos de 3 m, con su tecla.

**La red de ductos** (sale con este plan)
31. El mundo en morado oscuro y los tubos en rosa.
32. Las salidas como columnas de luz; la elegida en blanco, con su camino encendido.
33. La cámara siguiendo el viaje; el cruce de planta con esos colores.

**Al pie de la pantalla**
34. Sus teclas con el nombre de cada acción: Atacar, Bajar o Subir, Sigilo, Ductos, Beber la luz, Asomarse. Apagadas si no se puede; la espera se vacía sobre la tecla.
35. La carga del acecho (2 s) sobre la tecla de Atacar.
36. La cuenta atrás de su gracia al empezar.
37. La cámara: detrás y encima de ella arriba, a un lado abajo, y el encuadre de la presa al atacar; zum con la rueda.

**Mi recomendación:** salen 30 a 33 (los ductos), 7 (los cables: ruido que no informa) y 18 (la congelación quita control). 34 pierde «Ductos» y gana «Doppelgänger». El resto queda, con 8, 10 y 11 reforzados por los puntos 7 y 8 del pedido.
