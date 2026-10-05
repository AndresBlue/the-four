# Dificultad de la IA — hoja de ruta

**Hechas las fases 1 y 2 (4 de octubre de 2026); el resto, no.** Las cuatro dificultades se pueden elegir y cambian ya los números de la sección 3 (lo hecho está descrito en el [diseño](GAME_DESIGN.md), «Dificultad»); la etapa devuelta a solas también está (5 de octubre); las conductas de la sección 4 y las marcas por dificultad siguen pendientes. Es el plan para tener cuatro dificultades de la criatura que lleva la máquina —**Apacible, Equilibrada, Desafiante y Pesadilla**— en individual y en cooperativo contra la IA. El orden de trabajo vive en [PLAN.md](PLAN.md); cuando una fase se termine, lo que quede hecho pasa al [diseño](GAME_DESIGN.md) y sale de aquí.

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
| **Individual:** veces que el sector vuelve a empezar al caer | sin límite | 2 | ninguna | ninguna |
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
| **4 · Conductas de Apacible** | La escena de «me salvé», paso a paso, empezando por el director (encuentros) y la duda visible | Los bots novatos tienen los encuentros y las huidas de la sección 6 |
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
8. **La interacción con la bestia es alta en todas.** Apacible tiene tantos encuentros como las demás o más; lo que tiene es una bestia lenta de mente, de la que casi siempre se sale.

9. **A solas, la etapa vuelve a empezar como en equipo** (5 de octubre), con las veces de la tabla del perdón; Desafiante, ninguna, como siempre.
10. **Un piso no se repite nunca después de perderlo** (5 de octubre): Reintentar empieza otro, a solas y en red, y perder borra el punto de control.

Los números de las tablas no están decididos: son el punto de partida, y salen de medir.
