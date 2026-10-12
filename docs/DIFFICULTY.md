# Dificultad de la IA — hoja de ruta

**Hechas las fases 1 y 2 (4 de octubre de 2026); el resto, no.** Las cuatro dificultades se pueden elegir y cambian ya los números de la sección 3 (lo hecho está descrito en el [diseño](GAME_DESIGN.md), «Dificultad»); la etapa devuelta a solas también está (5 de octubre), y las conductas de Apacible de la sección 4 (5 de octubre, fase 4); las de Pesadilla y las marcas por dificultad siguen pendientes. Es el plan para tener cuatro dificultades de la criatura que lleva la máquina —**Apacible, Equilibrada, Desafiante y Pesadilla**— en individual y en cooperativo contra la IA. El orden de trabajo vive en [PLAN.md](PLAN.md); cuando una fase se termine, lo que quede hecho pasa al [diseño](GAME_DESIGN.md) y sale de aquí.

Punto de partida, decidido el 4 de octubre de 2026: **lo que hay hoy se parece a Desafiante.** Así que Desafiante es el juego actual tal cual, sin tocar un número; Equilibrada y Apacible se construyen aflojando desde ahí, y Pesadilla apretando. Lo decidido ese día está entero en la sección 9.

## 1 · Qué es una dificultad aquí

**La bestia está presente en todas.** En ninguna dificultad el piso puede ser «no encuentro a nadie, qué aburrido». Lo que se busca, también en la más fácil, es la escena que se repite una y otra vez:

> La vi. ¿Me habrá visto? Creo que sí. Voy a correr. Espero que no me alcance… Me salvé.

**Lo que sube con la dificultad no es cuántas veces pasa eso, sino lo difícil que es salir de ello.** En Apacible la escena acaba casi siempre en «me salvé» aunque se haga todo mal; en Pesadilla salir de ella pide haber pensado antes por dónde. Son dos ejes distintos y se ajustan por separado:

- **Encuentros:** cuántas veces la ves, te ve o te persigue. Es cosa sobre todo del **director**, y se mantiene alta en las cuatro.
- **Lo que cuesta salir de un encuentro:** cuánto tarda en reaccionar, cuánto corre, cuánto insiste, qué sabe buscar, y cuánto se perdona caer. Es cosa de **la criatura y del perdón** («mercy»), y es lo que escala.

**Una dificultad es un perfil:** un nombre y un valor para cada palanca, escrito en un solo archivo, como las reglas de la sala. El código no pregunta «¿es Pesadilla?»: pregunta cuánto ve la criatura, y el perfil contesta.

**Toca solo a la criatura y al perdón.** Ni el aura, ni lo que se ve en pantalla, ni la cordura, ni el apagón, ni cuántas teles sobran, ni si las notas se ven: son reglas del piso, y ya se cambian en **Reglas** de la sala. Mezclarlas impediría saber qué se mide.

**No cambia lo que no se rompe** («Reglas que no se rompen», en el diseño), en ninguna de las cuatro:

- El director sabe dónde está todo el mundo y **nunca se lo dice a la criatura**: solo le da zonas, nunca la sala de nadie, nunca a menos de 10 m en línea recta o 12 m andando.
- **Esconderse funciona** si nadie te vio entrar y no hiciste ruido al lado. Solo el refugio es seguro.
- **Se la oye antes de verla**, igual en las cuatro. El audio anuncia, no castiga.
- La criatura no atraviesa paredes, no mata por contacto y no sabe nada que no haya visto u oído.
- **No hay agarrar y soltar:** si te atrapa, caes. El perdón está en el piso (el sector que vuelve a empezar), no en sus manos.

**Dos maneras de matizar, y hacen falta las dos:** números (las mismas conductas con más o menos alcance, prisa y paciencia) y conductas (cosas que hace o deja de hacer). Apacible necesita las dos: si solo fuera «la de hoy, más lenta», sería una bestia que no aparece.

## 2 · El carácter de cada una

| | Para quién | Cómo se siente | Qué castiga |
|---|---|---|---|
| **Apacible** | Quien no juega mucho, o tiene poca mano | **Lenta de mente.** Aparece a menudo, se le nota cuando empieza a fijarse en ti, tarda en reaccionar, corre menos que tú, se cansa y se olvida. Correr te salva casi siempre | Quedarse quieto delante de ella, o meterse en un callejón |
| **Equilibrada** (la de fábrica) | La mayoría | Los mismos encuentros; salir de ellos pide romperle la vista, no solo correr. Un error se paga con una persecución; dos seguidos, con una muerte | No romperle la vista, hacer ruido cerca |
| **Desafiante** (la de hoy) | Quien ya conoce el piso | Verte es casi cazarte: hay que jugar a no ser visto | Dejarse ver, esconderse tarde |
| **Pesadilla** | Equipos que ya salen en Desafiante | Parece que ha aprendido de vosotros: corta el paso, vuelve, mira donde os escondéis siempre | La rutina: repetir escondite, ruta o costumbre |

## 3 · Las palancas que ya existen

Los valores de **Desafiante son los de hoy** (comprobados en el código). Los de las otras tres son **el punto de partida para medir**, no el resultado: se ajustan en la fase 3 con los bots y después con gente.

### La criatura: lo que cuesta salir de un encuentro

| Palanca | Apacible | Equilibrada | Desafiante (hoy) | Pesadilla |
|---|---|---|---|---|
| Alcance de su vista | 55 m | 60 m | 70 m | 85 m |
| Lo deprisa que se fija en ti | ×0,6 | ×0,8 | ×1 (3,2/s cerca, 0,9/s lejos) | ×1,3 |
| Oído (sobre la tabla de ruidos) | ×0,85 | ×0,9 | ×1 | ×1,2 |
| Linterna que la atrae, hasta | 35 m | 40 m | 45 m | 55 m |
| Aviso antes de perseguir (se para, se gira y chilla) | 2,0 s | 1,5 s | 1,2 s | 0,8 s |
| Arranque de la persecución (velocidad inicial / aceleración) | 2,0 m/s / 2,0 m/s² | 2,3 / 2,8 | 2,5 / 3,2 | 3,0 / 4,0 |
| Velocidad de caza (tu carrera: 6,0 m/s) | 5,6 | 6,1 | 6,4 | 6,7 |
| Se cansa de perseguir aunque te vea | a los 12 s | a los 25 s | nunca | nunca |
| Sin verte, deja la persecución a los | 3 s | 5,5 s | 7 s | 10 s |
| Se rinde en una búsqueda sin pistas | 4–6 s | 7–9 s | 8–10 s | 12–15 s |
| Abre un armario «por si acaso» al buscar | nunca | 1 de cada 10 | 1 de cada 5 | 1 de cada 2 |
| Estocada: desde dónde / lo que tarda / lo que tarda en rehacerse | 1,8 m / 0,5 s / 1,0 s | 2,2 m / 0,35 s / 0,7 s | 2,4 m / 0,3 s / 0,6 s | 2,6 m / 0,25 s / 0,5 s |
| Registrar un armario (inmóvil) | 3,2 s | 2,8 s | 2,5 s | 2,0 s |
| Sale por otra tele encendida | no | cada 40 s como mucho | cada 25 s | cada 12 s |
| Protección al empezar el piso | 25 s | 20 s | 15 s | 10 s |

En Apacible corre menos que tú, y si te sigue viendo, a los 12 s se cansa: correr en cualquier dirección te salva casi siempre, y su estocada es tan lenta que oírla venir y echar a correr basta. Desde Equilibrada correr ya no basta: hay que romperle la vista.

### El director: cuántos encuentros hay

Hoy el director existe para que la criatura no regale muertes; en las dificultades bajas tiene además el trabajo contrario: **que no pase mucho rato sin que la veas**.

| Palanca | Apacible | Equilibrada | Desafiante (hoy) | Pesadilla |
|---|---|---|---|---|
| Si pasa este rato sin ningún encuentro, provoca uno | 1,5 min | 2 min | no existe (se mide) | 1,5 min |
| Una pista cada | 20–30 s | 25–35 s | 25–40 s | 18–30 s |
| Lo más cerca del equipo que la manda | 14 m | 16 m | 18 m | 14 m |
| Su jugada preferida | **cruzarse a la vista** | merodear | como hoy, sin preferida | esperar en lo que falta por hacer, y volver |
| Tiempo máximo de «pico» (cerca, manos fuera) | 15 s | 20 s | 25 s | 35 s |
| Respiro tras una persecución / una muerte | 20 s / 40 s | 30 s / 50 s | 30 s / 45 s | 20 s / 30 s |
| Cada muerte reciente la aleja | 10 m | 9 m | 8 m | 4 m |
| Espera en algo que el equipo tiene que hacer | de paso | poco | como hoy | a menudo |
| Retirada que vuelve | nunca | 2 de 10 | 4 de 10 | 7 de 10 |
| Todos escondidos y va hacia uno sin haberlo visto: algo se cae lejos, como mucho | cada 30 s | cada 45 s | cada 45 s | cada 90 s |
| Con la cordura a cero, la trae a rondar cada | 60–90 s | 45–60 s | 30–45 s | 20–30 s |

Que en Apacible y en Pesadilla la mande igual de cerca es a propósito: en las dos aparece mucho; lo que cambia es lo que pasa después.

### El perdón («mercy»)

Hoy, a solas no se perdona nada y en equipo se perdona un derrumbe: la misma criatura es bastante más dura a solas, y una partida de quien está aprendiendo se acaba en la primera caída. **El perdón es que el sector vuelva a empezar**: todos en pie en su entrada, sus teles apagadas otra vez y la criatura lejos y quieta un momento, como ya pasa hoy en equipo. Cuesta rehacer el sector, no la partida.

| | Apacible | Equilibrada | Desafiante (hoy) | Pesadilla |
|---|---|---|---|---|
| **Individual:** veces que el sector vuelve a empezar al caer | sin límite | 1 (eran 2 hasta el 12 de octubre de 2026; lo decidió el autor) | ninguna | ninguna |
| **Cooperativo:** derrumbes perdonados | sin límite | 2 | 1 | ninguno |
| La criatura espera ante el ascensor (vestíbulo / desde que bajasteis) | 25 s / 30 s | 20 s / 25 s | 15 s / 20 s | 10 s / 12 s |

## 4 · Conductas nuevas

Cada una es un interruptor del perfil, con su prueba, y se mide por separado: si una no se nota o resulta injusta, se quita sin tocar las demás. Ninguna le da información que no tenga.

### Para Apacible: la escena de «me salvé»

Una por cada paso de la escena:

1. **«La vi»: se cruza a la vista.** La jugada preferida del director: la hace pasar por donde vas a mirar —un pasillo que cruza el tuyo, el fondo de un salón—, a 15–25 m y antes de que ella te vea a ti. La mayoría de los encuentros empiezan porque la ves tú primero.
2. **«¿Me habrá visto?»: se le nota la duda.** Cuando empieza a fijarse en ti se para, gira la cabeza hacia ti y chasquea; si no pasa de ahí, sacude la cabeza y sigue su camino. Hoy esa sospecha es invisible.
3. **«Creo que sí»: aviso largo.** El chillido antes de perseguir dura 2 s y el arranque es lento: da tiempo a decidir aunque no sepas qué hacer.
4. **«Voy a correr»: corre menos que tú y se cansa.** Ver la tabla: 5,6 m/s y 12 s de persecución como mucho.
5. **«Espero que no me alcance»: estocada lenta y con aviso.** Si la oyes armar el golpe y corres, la esquivas por poco. Los «casi» son parte de la escena.
6. **«Me salvé»: te pierde enseguida, y lo dice.** Un gruñido de frustración al rendirse, que se oye: sabes que has escapado. (También en Equilibrada. En Pesadilla, a veces lo finge y vuelve.)
7. **Y otra vez.** Tras un respiro corto, el director prepara el siguiente encuentro (la fila «si pasa este rato sin ningún encuentro»).
8. **Solo abre el armario en el que te vio entrar.** Ni «por si acaso», ni por un ruido al lado: esconderse es siempre una salida.

### Para Pesadilla: la escena es otra

1. **Corta el paso.** Al perderte no va solo a donde te vio por última vez: si ibas hacia un vano, toma el camino paralelo para salirte al otro lado.
2. **Se acuerda de vuestras costumbres.** Los armarios y las salas donde el equipo ya se escondió en ese piso son los primeros que mira al buscar.
3. **Acude a lo que suena a objetivo.** Una tele recién encendida o un mueble registrado la traen a trote, no andando.
4. **No se deja distraer dos veces.** La segunda vez que algo se cae lejos mientras busca, termina la búsqueda antes de ir.
5. **Vuelve.** Después de rendirse y alejarse, a veces regresa por otro lado al cabo de medio minuto, y a veces finge el gruñido de rendirse.
6. **Recorre la sala al registrar.** En vez de mirar un punto y un armario, da una vuelta a la sala antes de irse.

## 5 · Individual y cooperativo

- **A solas** toda su atención es para uno, no hay compañero que distraiga ni que avise, y hoy una captura termina el piso. El perdón por dificultad (sección 3) lo cambia: en Apacible y Equilibrada caer cuesta el sector, no la partida.
- **En equipo** la criatura persigue a uno cada vez: con cuatro jugadores hay más ruido y más teles que encender, pero también tres personas libres mientras caza a la cuarta. Los encuentros se cuentan **por jugador**, no por equipo: que el más lanzado se lleve todos y el resto no la vea nunca también es «no encuentro a nadie». Falta saber cómo cambia todo con 2, 3, 4 y 5: se mide en la fase 2, y si la curva no es razonable el perfil lleva un factor por tamaño de equipo (sobre el director, que reparte la presión; no sobre los sentidos).
- **Versus** no tiene dificultad: la criatura es una persona. Solo cuenta para la IA que la sustituye si el cazador se desconecta.

## 6 · A qué apuntamos, y cómo se mide

Objetivos de partida, por piso entero:

| | Apacible | Equilibrada | Desafiante | Pesadilla |
|---|---|---|---|---|
| Encuentros por jugador y piso (la ves, te ve o te persigue) | 10 o más | 8 o más | los de hoy | 8 o más |
| Rato más largo sin ningún encuentro | 2 min | 2,5 min | los de hoy | 2 min |
| Persecuciones por jugador y piso | 3–5 | 3–5 | 3–5 | 4–6 |
| De cada 10 persecuciones, acaban en huida | 9 | 7 | 5 | 3 |
| Caídas por piso (equipo de 3) | menos de 1 | 1–2 | 2–4 | 4 o más |
| Pisos ganados sin derrumbes, 3 bots novatos | 80 % o más | 50–60 % | — | — |
| Pisos ganados, 3 bots expertos | — | 80 % o más | 45–55 % | 15–25 % |
| Pisos ganados, 1 bot experto | — | 60 % o más | 30–40 % | 15 % o menos |

En Apacible, con el perdón sin límite, el piso siempre se acaba ganando: lo que se mira es cuántas veces se sale de una persecución y cuántas veces se cae.

**Primera medida (5 de octubre de 2026)**, con los números de la sección 3 y sin ninguna conducta de la sección 4: 3 bots, 20 pisos por lote, semillas 200–219 (`./tools/bots.ps1 -Bots 3 -Runs 20 -Seed 200 -Difficulty … -Skill …`; los resúmenes en `evidence/bots/*medida*`).

| Lote | Ganados | Sin derrumbes | Caídas por piso | Encuentros por bot | Persecuciones por bot | Huidas de cada 10 | Rato más largo sin ella (mediana) |
|---|---|---|---|---|---|---|---|
| Desafiante, expertos | 65 % | 30 % | 3,3 | 2,1 | 1,8 | 1 | 26:52 |
| Desafiante, novatos | 0 % | 0 % | 4,3 | 1,8 | 1,8 | 1 | 4:28 |
| Equilibrada, novatos | 0 % (3 sin tiempo) | 0 % | 6,2 | 3,1 | 2,9 | 2 | 7:14 |
| Apacible, novatos | 70 % (6 sin tiempo) | 0 % | 11,8 | 6,5 | 8,1 | 3 | 13:53 |
| Pesadilla, expertos | 5 % | 5 % | 2,4 | 1,2 | 1,3 | 1 | 12:41 |

«Sin tiempo» son pisos que pasaron el tope de juego del lote rehaciendo etapas: en Apacible nadie pierde el piso, pero puede no terminarlo. Lo que dice:

- **Desafiante, la referencia, sale al 65 % con expertos**, por encima de lo que se esperaba (45–55 %). Se queda como está; los objetivos de las demás se leen contra ese 65 %.
- **Hay muy pocos encuentros**: unos 2 por bot y piso en Desafiante, lejos de los 8 o más del objetivo, y los expertos pasan una mediana de 27 minutos sin una señal de ella. Hace falta el encuentro garantizado del director (sección 4).
- **Ser perseguido es casi morir en todas**: 1 de cada 10 persecuciones acaba en huida en Desafiante y en Pesadilla, y solo 3 de cada 10 en Apacible. **Los números solos no hacen el «me salvé»**: Apacible tiene muchos encuentros (6,5) y muchas persecuciones (8,1), pero 11,8 caídas por piso. Hacen falta sus conductas: la duda visible, el cansancio, la estocada lenta, el gruñido de «te perdí».
- **Los novatos lo pierden todo fuera de Apacible.** Son bots, no personas —no se esconden bien y vuelven al peligro a los 4 s de perderla—, así que el número absoluto no es el de un jugador; lo que importa es el orden y la distancia entre dificultades.
- **Pesadilla sale al 5 % con expertos**, por debajo de su objetivo (15–25 %): se mira en la fase 5.

**Segunda medida (5 de octubre de 2026)**, con las conductas de la fase 4 (la duda, el cansancio, el gruñido, los armarios adivinados y los encuentros que cuida el director), las mismas semillas y lotes (`evidence/bots/*fase4*`). Entre paréntesis, la primera medida:

| Lote | Ganados | Sin derrumbes | Caídas por piso | Encuentros por bot | Persecuciones por bot | Huidas de cada 10 | Rato más largo sin ella (mediana) |
|---|---|---|---|---|---|---|---|
| Apacible, novatos | 75 % (70 %) | 0 % | 11,2 (11,8) | 8,0 (6,5) | 12,3 (8,1) | 4 (3) | 8:11 (13:53) |
| Equilibrada, novatos | 0 % (0 %) | 0 % | 6,3 (6,2) | 2,7 (3,1) | 3,1 (2,9) | 2 (2) | 5:32 (7:14) |
| Equilibrada, expertos | 60 % | 5 % | 4,0 | 2,8 | 2,5 | 2 | 26:58 |

Lo que dice:

- **Apacible va hacia donde tiene que ir, pero no llega.** Hay más encuentros (8 por bot, cerca de los 10) y más huidas (4 de cada 10), y el rato más largo sin ella baja a la mitad; pero los novatos siguen cayendo once veces por piso. El director cruza a la bestia unas 21 veces por piso, así que lo que deja ratos largos no es que no lo intente: según su registro (1708 jugadas «entre bastidores» en 20 pisos), los descansos tras cada caída, cuando la manda lejos, y los cambios de planta. Es lectura de los datos, no comprobada una a una.
- **Equilibrada no cambia para los novatos**: sus pisos se pierden igual, en las mismas caídas.
- **Equilibrada con expertos sale al 60 %**, por debajo del 80 % que se busca y del 65 % de Desafiante: con 20 pisos la diferencia con Desafiante cabe en el azar, pero el orden que se busca no está. Y los expertos siguen sin verla en 27 minutos: esquivan su vista, y el cruce del director no llega a quien no la mira.
- **Lo siguiente:** que el descanso tras una caída también acabe en un cruce cuando toca; que de una persecución en Equilibrada se salga más (sus números de la sección 3); y que los bots novatos se escondan como lo haría una persona, para que su resultado se parezca al de alguien.

**Tercera medida, a solas (5 de octubre de 2026): con gente, Apacible era un asedio.** Probado con jugadores nuevos y con quien conoce el juego: nadie acabó un piso a solas en Apacible en más de diez intentos, y la sensación era de una bestia acampada que controlaba un acceso. Medido con un solo bot, 12 pisos, semillas 300–311 (`evidence/bots/*solo_*`):

| Apacible a solas, bot novato | Antes | Primer ajuste | Segundo ajuste |
|---|---|---|---|
| Pisos ganados (el resto, sin tiempo) | 0 | 1 | 7 |
| Caídas por piso | 14,5 | 8,6 | 2,3 |
| Encuentros / persecuciones por piso | 22,7 / 37,8 | 17,0 / 32,8 | 15,5 / 15,9 |
| Huidas de cada 10 | 4 | 5 | 5 |
| Rato más largo sin ella (mediana) | 3:12 | 6:34 | 7:01 |

- **Qué pasaba.** El director trataba a un jugador solo como a un equipo: toda su atención sobre una persona. En Apacible la traía tan a menudo y tan cerca como en Pesadilla, descansaba 20 s tras una persecución y nada si te habías librado escondiéndote. Y a quien no llegaba a mirarla le debía «un encuentro» cada 30 s para siempre: en un piso de la medida base (semilla 304) la cruzó 49 veces, la trajo a merodear otras 49 porque el bot no se movía, y golpeó 59 puertas; la bestia pasó tramos de 300 s en una sola sala junto al bot, que se escondió 77 veces y no encontró el refugio en media hora. Ese mismo piso, tras el ajuste: 16 retiradas entre bastidores, 6 pasadas, 4 merodeos, 2 cruces y 2 golpes.
- **Qué se cambió** (todo en Apacible y Equilibrada; Desafiante y Pesadilla, igual): la carga y el respiro medido por ella, el cruce que cuenta aunque no se la mire, el camino libre durante el respiro, todo más espaciado a solas, nada de emboscadas ni de merodear a quien no se mueve tras un susto (primer ajuste); los ojos —ángulo, cuerpo a medio tapar— y unas piernas más lentas que las de quien corre (primer y segundo ajuste); oído más corto, la mitad durante un respiro, y veinte segundos sin fijarse en nadie tras cansarse (segundo). Las cifras, en el diseño.
- **El bot experto no sirve para medir a solas.** Sin criatura gana 12 de 12, pero tarda de 37 a 62 minutos de juego por piso (el sector 3, unos 25): **un piso a solas es largo aunque no haya nadie**. Con criatura ya no lo asedian (0,5 caídas, 1,3 persecuciones por piso), pero se esconde por su cuenta decenas de veces y se le acaba el tiempo del lote en el sector 3.
- **Equilibrada a solas**, tras el segundo ajuste: el novato cae 3,0 veces por piso (antes del ajuste no se midió a solas) y con dos etapas devueltas no gana ninguno; el experto, 0,9 caídas. Recibió después un ajuste más, suave (5,3 m/s, se cansa a los 12 s, medio torso para distinguirte); medido con él, el novato a solas sigue cayendo 3,0 veces por piso (5 huidas de cada 10, antes 4) y no gana ninguno de 12: **a solas, Equilibrada sigue fuera del alcance de un bot novato**, que pierde el piso a la tercera caída.

**Los equipos de tres con los valores finales** (bots novatos, 20 pisos, semillas 200–219; entre paréntesis, la segunda medida):

| Lote | Ganados | Sin derrumbes | Caídas por piso | Encuentros por bot | Persecuciones por bot | Huidas de cada 10 | Rato más largo sin ella (mediana) |
|---|---|---|---|---|---|---|---|
| Apacible, novatos | 95 % (75 %) | 65 % (0 %) | 1,9 (11,2) | 5,0 (8,0) | 4,4 (12,3) | 6 (4) | 11:23 (8:11) |
| Equilibrada, novatos | 60 % (0 %) | 0 % (0 %) | 4,9 (6,3) | 4,9 (2,7) | 5,1 (3,1) | 6 (2) | 11:05 (5:32) |

- **Apacible en equipo ya es lo que se buscaba, o casi:** 95 % de pisos ganados, dos tercios sin perder ni una etapa (el objetivo era el 80 %), menos de dos caídas por piso y seis huidas de cada diez persecuciones.
- **Equilibrada en equipo entra en su objetivo** (50–60 % con novatos): 60 %.
- **Los encuentros bajan en Apacible** (5,0 por bot, la mitad del objetivo de 10 de la tabla de arriba): es el precio de dejar aire. Ese objetivo se escribió cuando se quería la misma frecuencia que en Pesadilla, y con gente resultó un asedio; queda por decidir, jugando, si 5 es poco.
- **Falta:** decidir si a solas un piso debe pedir menos; y, sobre todo, volver a probarlo con gente. **Equilibrada a solas quedó decidida el 12 de octubre: una sola etapa devuelta** (eran dos). Las medidas de arriba son con dos: con una, el bot novato, que ya solo ganaba 4 de 100, ganará menos; es una decisión de diseño, no de los números.

**Cuarta medida (5 y 6 de octubre de 2026): las cuatro, con 50 pisos por celda.** Semillas nuevas, 400–449, que no se usaron para ajustar nada; `./tools/bots.ps1 -Runs 50 -Seed 400 -Parallel 20` (`evidence/bots/*est50_*`). Con 50 pisos, un porcentaje tiene un margen de unos ±13 puntos en el centro (68 % es entre 54 y 79) y de unos 7 en los extremos (0 de 50 es «menos del 7 %»). El bot experto a solas se dejó fuera: no mide (tercera medida).

| Lote | Ganados | Sin derrumbes | Perdidos / sin tiempo | Caídas por piso | Encuentros por bot | Persecuciones por bot | Huidas de cada 10 | Rato más largo sin ella (mediana) | Piso ganado, minutos de juego (mediana) |
|---|---|---|---|---|---|---|---|---|---|
| **A solas, novato** · Apacible | 68 % | 4 % | 0 / 16 | 3,3 | 16,6 | 18,4 | 6 | 7:26 | 59 |
| A solas, novato · Equilibrada | 4 % | 2 % | 48 / 0 | 2,9 | 6,7 | 6,8 | 6 | 4:38 | 48 |
| A solas, novato · Desafiante | 0 % | 0 % | 50 / 0 | 1,0 | 1,1 | 1,2 | 1 | 1:41 | — |
| A solas, novato · Pesadilla | 0 % | 0 % | 50 / 0 | 1,0 | 1,1 | 1,1 | 1 | 1:29 | — |
| **Tres novatos** · Apacible | 100 % | 70 % | 0 / 0 | 1,6 | 4,3 | 4,1 | 6 | 12:18 | 26 |
| Tres novatos · Equilibrada | 68 % | 28 % | 15 / 1 | 4,6 | 5,0 | 4,8 | 6 | 10:54 | 27 |
| Tres novatos · Desafiante | 0 % | 0 % | 49 / 1 | 4,3 | 2,0 | 2,0 | 2 | 5:28 | — |
| Tres novatos · Pesadilla | 0 % | 0 % | 50 / 0 | 2,1 | 0,8 | 0,9 | 1 | 2:31 | — |
| **Tres expertos** · Apacible | 98 % | 92 % | 0 / 1 | 0,4 | 1,1 | 0,9 | 3 | 29:06 | 35 |
| Tres expertos · Equilibrada | 98 % | 82 % | 0 / 1 | 1,1 | 1,3 | 1,0 | 4 | 28:16 | 35 |
| Tres expertos · Desafiante | 46 % | 28 % | 23 / 4 | 3,4 | 2,1 | 1,6 | 1 | 27:13 | 37 |
| Tres expertos · Pesadilla | 0 % | 0 % | 45 / 5 | 2,2 | 1,0 | 0,9 | 1 | 13:18 | — |

Lo que dice, contra los objetivos del principio de esta sección:

- **La escalera está, y bien separada.** Con novatos en equipo: 100 → 68 → 0 → 0. Con expertos: 98 → 98 → 46 → 0. Las dos fáciles son para cualquiera y las dos altas, para quien sabe: un equipo novato no gana ni un piso de 100 en Desafiante o Pesadilla.
- **Entran en su objetivo:** Desafiante con expertos, 46 % (se buscaba 45–55); Equilibrada con expertos, 98 % (80 o más); Equilibrada con novatos, 68 % (50–60: algo por encima); Apacible con novatos, 100 % ganados y 70 % sin perder una etapa (se buscaba el 80 % sin derrumbes: cerca).
- **Pesadilla no la gana nadie:** 0 de 50 con tres expertos (menos del 7 %), cuando se buscaba un 15–25 %. Los expertos caen en cuanto se la encuentran (1 huida de cada 10). Jugando se siente bien opresiva, pero hoy es imposible para estos bots: es de la fase 5.
- **Entre Apacible y Equilibrada, para quien sabe, casi no hay diferencia** (98 y 98 %): se distinguen en las caídas (0,4 y 1,1 por piso) y en los pisos limpios (92 y 82 %). Para quien no sabe sí la hay: 100 contra 68 %.
- **Una persecución se salva 6 veces de cada 10 en las dos fáciles** con novatos (eran 4 y 2), y 1–2 de cada 10 en las dos altas. El objetivo era 9 y 7: los novatos siguen sin esconderse como una persona.
- **A solas, Apacible sale: 68 %**, y lo que no se gana es tiempo del lote agotado en el tercer sector, no un piso perdido. Pero cuesta 3,3 caídas y 18 persecuciones por piso: no es «a la primera y sin un rasguño» para un bot novato.
- **A solas, Equilibrada no sale: 4 %.** Se escapa igual de bien que en Apacible (6 de cada 10) y se cae 2,9 veces por piso; con dos etapas devueltas, la tercera caída acaba el piso. **Lo que la separa de Apacible a solas es la clemencia, no la bestia.**
- **A solas, Desafiante y Pesadilla acaban en el primer encuentro** para un novato: una caída, un minuto y medio. Es lo que dicen que son (a solas no perdonan ninguna).
- **Un piso ganado dura lo que se buscaba en equipo** (26 a 37 minutos de juego; el objetivo, 25–40) **y el doble a solas** (59): un piso a solas es largo.
- **Los encuentros siguen por debajo de los 8–10 por jugador** de la tabla de objetivos en todas las celdas de equipo (4–5 con novatos, 1–2 con expertos, que la esquivan). Con gente, más que eso resultó un asedio: el objetivo de la tabla es el que hay que revisar, jugando.


**Dos clases de bots, porque una sola no sirve.** Los de hoy saben siempre dónde está la criatura y juegan a que no los vea nunca: son **expertos**, y apenas tienen encuentros. Para medir Apacible y Equilibrada hacen falta **bots novatos**: que solo sepan de ella lo que ven y oyen, que anden a la vista, que corran en cuanto la ven y que se escondan tarde. Si un novato sale de Apacible, una persona que no juega mucho también.

Lo que hay para medir, y lo que falta:

- **Ya existe:** los bots en lote (`tools/bots.ps1`), con resultado, duración, caídas y capturas por piso, y su grabación para repasar; y el parte de cada cinta, que ya guarda por jugador persecuciones, huidas, tiempo perseguido, caídas y lo más cerca que la tuvo.
- **Falta:** los bots novatos; contar los **encuentros** en el parte (la viste —la cordura ya sabe cuándo alguien la ve—, se fijó en ti, te persiguió) y el tiempo entre uno y otro; la dificultad en la cinta; lotes por dificultad, tamaño de equipo y clase de bot, juntados en una tabla; y ver las palancas en vivo en el observador.

## 7 · Dónde se elige y qué pasa con las marcas

- **Individual:** al empezar «Nueva partida», una pantalla con las cuatro y una línea de cada una; se recuerda la última. «Continuar» y «Reintentar» conservan la del piso. No se cambia a mitad de un piso.
- **Cooperativo:** en la sala, junto a «Tipo de partida», la elige el anfitrión y la ven todos.
- **De fábrica:** Equilibrada.
- **Marcas:** un solo tablón por compañía, con la dificultad escrita en cada cinta y en cada línea, un filtro por dificultad y el puntaje multiplicado (Apacible ×0,8 · Equilibrada ×1 · Desafiante ×1,25 · Pesadilla ×1,5). Hitos nuevos por salir en Desafiante y en Pesadilla. Las cintas guardadas hasta hoy se etiquetan como Desafiante, que es lo que eran.
- **Con las reglas de la sala:** la dificultad pone el perfil de la criatura y el perdón; una regla cambiada a mano manda sobre ella, y esa cinta va al tablón «con otras reglas», como ahora.

## 8 · Fases

Cada fase se cierra con la batería en verde, lo hecho descrito en el diseño y su commit.

| Fase | Qué se hace | Se da por buena cuando |
|---|---|---|
| **1 · Cimientos** (hecha) | El archivo de perfiles; la criatura, el director, las teles y el ascensor leen sus números de él en vez de constantes; la dificultad viaja con la partida, el punto de control y la cinta; la pantalla para elegirla | Con Desafiante, el juego es idéntico al de hoy: mismas pruebas, mismos resultados de los bots en las mismas semillas |
| **2 · Instrumentos** (hecha) | Los bots novatos; los encuentros en el parte; lotes por dificultad, tamaño de equipo (1 a 5) y clase de bot, con tabla comparativa; las palancas a la vista en el observador | Hay una tabla de Desafiante que sirve de referencia, repetible, con encuentros |
| **3 · Apacible y Equilibrada, por números** | Los valores de la sección 3, medidos y corregidos | Lo que cuesta salir de un encuentro va en orden de Apacible a Pesadilla (lo que fabrica encuentros, no: es alto en las cuatro), y los números se acercan a la sección 6 |
| **4 · Conductas de Apacible** (hecha y medida: aún no llega a los objetivos, sección 6) | La escena de «me salvé», paso a paso, empezando por el director (encuentros) y la duda visible | Los bots novatos tienen los encuentros y las huidas de la sección 6 |
| **5 · Conductas y números de Pesadilla** | Sus seis conductas, una a una, y después sus valores | Entra en sus objetivos sin romper ninguna regla de las que no se rompen |
| **6 · Individual y equipo** (la etapa devuelta a solas, hecha) | El sector que vuelve a empezar a solas; el perdón por dificultad; si hace falta, el factor por tamaño de equipo | La curva de 1 a 5 jugadores es razonable en las cuatro |
| **7 · Marcas** | Dificultad en cintas y tablones, filtro, multiplicador e hitos | — |
| **8 · Con gente** | Tres partidas por dificultad, a solas y en equipo, con el parte de cada una | Los números finales salen de esas partidas, no de los bots |

Las fases 1 y 2 no cambian nada que se note jugando: son el andamio. La primera dificultad nueva que se puede probar llega al final de la 3, y Apacible tal como se describe aquí, al final de la 4.

## 9 · Decidido el 4 de octubre de 2026

1. **Desafiante es exactamente lo de hoy**, sin tocar nada: es la referencia.
2. **La de fábrica es Equilibrada.**
3. **El perdón cambia con la dificultad, y es el sector que vuelve a empezar.** Nada de que la criatura te agarre y te suelte.
4. **La dificultad toca solo a la criatura y al perdón.** Lo demás del piso se cambia en Reglas de la sala.
5. **Marcas:** un tablón con la dificultad a la vista, filtro y multiplicador de puntaje.
6. **El aura no cambia con la dificultad**: se la oye venir igual en las cuatro.
7. **No se cambia de dificultad a mitad de un piso.**
8. **La interacción con la bestia es alta en todas.** Apacible tiene tantos encuentros como las demás o más; lo que tiene es una bestia lenta de mente, de la que casi siempre se sale. **Matizado el 5 de octubre, tras probarlo con gente:** en Apacible y Equilibrada los encuentros vienen por episodios, con un respiro entre uno y otro que se mide por lo vivido, y a solas más espaciados; el objetivo de Apacible es poder acabar el piso a la primera, con acción pero casi siempre ileso. Desafiante y Pesadilla son para quien tiene experiencia y siguen opresivas.

9. **A solas, la etapa vuelve a empezar como en equipo** (5 de octubre), con las veces de la tabla del perdón; Desafiante, ninguna, como siempre.
10. **Un piso no se repite nunca después de perderlo** (5 de octubre): Reintentar empieza otro, a solas y en red, y perder borra el punto de control.

Los números de las tablas no están decididos: son el punto de partida, y salen de medir.
