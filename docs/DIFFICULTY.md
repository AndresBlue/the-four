# Dificultad de la IA — hoja de ruta

**Nada de esto está hecho.** Es el plan para tener cuatro dificultades de la criatura que lleva la máquina —**Apacible, Equilibrada, Desafiante y Pesadilla**— en individual y en cooperativo contra la IA. El orden de trabajo vive en [PLAN.md](PLAN.md); cuando una fase se termine, lo que quede hecho pasa al [diseño](GAME_DESIGN.md) y sale de aquí.

Punto de partida, decidido el 4 de octubre de 2026: **lo que hay hoy se parece a Desafiante.** Así que Desafiante es el juego actual tal cual, sin tocar un número; Equilibrada y Apacible se construyen aflojando desde ahí, y Pesadilla apretando.

## 1 · Qué es una dificultad aquí

**Una dificultad es un perfil:** un nombre y un valor para cada palanca que ya tiene el juego (sentidos, persecución, búsqueda, director, perdón), escrito en un solo archivo, como las reglas de la sala. El código no pregunta «¿es Pesadilla?»: pregunta cuánto ve la criatura, y el perfil contesta.

**No cambia lo que no se rompe** («Reglas que no se rompen», en el diseño), en ninguna de las cuatro:

- El director sabe dónde está todo el mundo y **nunca se lo dice a la criatura**: solo le da zonas.
- **Esconderse funciona** si nadie te vio entrar y no hiciste ruido al lado. Solo el refugio es seguro.
- **Se la oye antes de verla.** El audio anuncia, no castiga.
- La criatura no atraviesa paredes, no mata por contacto y no sabe nada que no haya visto u oído.

Lo que cambia entre dificultades es **cuánto margen de error tienes** y **cuánto oficio tiene ella**, no si juega limpio.

**Dos maneras de matizar, y hacen falta las dos:**

- **Números:** las mismas conductas, con más o menos alcance, prisa y paciencia. Con esto salen Apacible y Equilibrada.
- **Conductas:** cosas que la criatura hace o deja de hacer. Con esto sale Pesadilla, que si solo fuera «la de hoy pero más rápida» sería injusta en vez de temible.

## 2 · El carácter de cada una

| | Para quién | Cómo se siente | Qué castiga |
|---|---|---|---|
| **Apacible** | Quien juega por primera vez, o viene a pasear y a leer | La criatura es una presencia: avisa mucho, duda, se cansa pronto de buscar. Se puede aprender el piso | Correr sin mirar delante de ella |
| **Equilibrada** (la de fábrica) | La mayoría | Un error se paga con una persecución de la que se puede salir; dos seguidos, con una muerte | No romperle la vista, hacer ruido cerca |
| **Desafiante** (la de hoy) | Quien ya conoce el piso | Verte es casi cazarte: hay que jugar a no ser visto | Dejarse ver, esconderse tarde |
| **Pesadilla** | Equipos que ya salen en Desafiante | Parece que ha aprendido de vosotros: corta el paso, vuelve, mira donde os escondéis siempre | La rutina: repetir escondite, ruta o costumbre |

## 3 · Las palancas que ya existen

Los valores de **Desafiante son los de hoy** (comprobados en el código). Los de las otras tres son **el punto de partida para medir**, no el resultado: se ajustan en la fase 3 con los bots y después con gente.

### La criatura

| Palanca | Apacible | Equilibrada | Desafiante (hoy) | Pesadilla |
|---|---|---|---|---|
| Alcance de su vista | 45 m | 60 m | 70 m | 85 m |
| Lo deprisa que se fija en ti | ×0,6 | ×0,8 | ×1 (3,2/s cerca, 0,9/s lejos) | ×1,3 |
| Oído (sobre la tabla de ruidos) | ×0,75 | ×0,9 | ×1 | ×1,2 |
| Linterna que la atrae, hasta | 30 m | 40 m | 45 m | 55 m |
| Aviso antes de perseguir (se para, se gira y chilla) | 1,8 s | 1,5 s | 1,2 s | 0,8 s |
| Velocidad de caza (tu carrera: 6,0 m/s) | 6,0 | 6,2 | 6,4 | 6,7 |
| Sin verte, deja la persecución a los | 4 s | 5,5 s | 7 s | 10 s |
| Se rinde en una búsqueda sin pistas | 5–7 s | 7–9 s | 8–10 s | 12–15 s |
| Abre un armario «por si acaso» al buscar | nunca | 1 de cada 10 | 1 de cada 5 | 1 de cada 2 |
| Estocada: desde dónde empieza / lo que tarda | 2,0 m / 0,45 s | 2,2 m / 0,35 s | 2,4 m / 0,3 s | 2,6 m / 0,25 s |
| Registrar un armario (inmóvil) | 3,2 s | 2,8 s | 2,5 s | 2,0 s |
| Sale por otra tele encendida | no | cada 40 s como mucho | cada 25 s | cada 12 s |
| Protección al empezar el piso | 25 s | 20 s | 15 s | 10 s |

En Apacible, correr en línea recta mantiene la distancia mientras dure el aliento (unos 12 s); desde Equilibrada, solo salva romperle la vista.

### El director

| Palanca | Apacible | Equilibrada | Desafiante (hoy) | Pesadilla |
|---|---|---|---|---|
| Una pista cada | 45–70 s | 35–50 s | 25–40 s | 18–30 s |
| Lo más cerca del equipo que la manda | 28 m | 22 m | 18 m | 14 m |
| Tiempo máximo de «pico» (la criatura cerca, manos fuera) | 15 s | 20 s | 25 s | 35 s |
| Respiro tras una persecución / una muerte | 45 s / 70 s | 35 s / 55 s | 30 s / 45 s | 20 s / 30 s |
| Cada muerte reciente la aleja | 12 m | 10 m | 8 m | 4 m |
| Espera en algo que el equipo tiene que hacer | nunca | poco | como hoy | a menudo |
| Retirada que vuelve | nunca | 2 de 10 | 4 de 10 | 7 de 10 |
| Todos escondidos y va hacia uno sin haberlo visto: algo se cae lejos, como mucho | cada 30 s | cada 45 s | cada 45 s | cada 90 s |
| Con la cordura a cero, la trae a rondar cada | 60–90 s | 45–60 s | 30–45 s | 20–30 s |

Los límites del director (nunca la sala de nadie, nunca a menos de 10 m en línea recta o 12 m andando) **no se mueven** en ninguna.

### El perdón (aquí se separan individual y cooperativo)

Hoy, solo no se perdona nada y en equipo se perdona un derrumbe. Eso hace que la misma criatura sea bastante más dura a solas. La propuesta usa lo que ya existe en las reglas de la sala (clemencia y derrumbes):

| | Apacible | Equilibrada | Desafiante (hoy) | Pesadilla |
|---|---|---|---|---|
| **Individual:** capturas que perdona (te suelta y se va lejos) | 2 | 1 | 0 | 0 |
| **Cooperativo:** derrumbes perdonados | 2 | 1 | 1 | 0 |
| **Cooperativo:** capturas que perdona a cada uno | 1 | 0 | 0 | 0 |
| La criatura espera ante el ascensor (vestíbulo / desde que bajasteis) | 25 s / 30 s | 20 s / 25 s | 15 s / 20 s | 10 s / 12 s |

## 4 · Conductas nuevas

Cada una es un interruptor del perfil, con su prueba, y se mide por separado: si una no se nota o resulta injusta, se quita sin tocar las demás.

### Para Pesadilla

1. **Corta el paso.** Al perderte no va solo a donde te vio por última vez: si ibas hacia un vano, toma el camino paralelo para salirte al otro lado.
2. **Se acuerda de vuestras costumbres.** Los armarios y las salas donde el equipo ya se escondió en ese piso son los primeros que mira al buscar.
3. **Acude a lo que suena a objetivo.** Una tele recién encendida o un mueble registrado la traen a trote, no andando.
4. **No se deja distraer dos veces.** La segunda vez que algo se cae lejos mientras busca, termina la búsqueda antes de ir.
5. **Vuelve.** Después de rendirse y alejarse, a veces regresa por otro lado al cabo de medio minuto (hoy solo lo hace el director, y 4 de cada 10).
6. **Recorre la sala al registrar.** En vez de mirar un punto y un armario, da una vuelta a la sala antes de irse.

Ninguna le da información que no tenga: todas salen de lo que vio, oyó o recuerda.

### Para Apacible

1. **Duda.** Entre fijarse en ti y perseguirte hay un momento más largo y más sonoro: te da tiempo a reaccionar aunque no sepas qué es.
2. **Solo abre el armario en el que te vio entrar.** Ni «por si acaso», ni por un ruido al lado.
3. **No espera en los objetivos.** El director nunca la planta junto a una tele o al teclado.
4. **Se aleja después de un susto.** Tras una persecución de la que sales, se va entre bastidores siempre, no según la fase.

### Lo que NO se tocará por dificultad (recomendación)

El aura con la que se la oye venir, lo que se ve en pantalla, la cordura, el apagón, cuántas teles sobran y si las notas se ven. Son reglas del piso, no de la criatura, y ya se pueden cambiar en **Reglas** de la sala. Mezclarlas con la dificultad haría imposible saber qué se está midiendo.

## 5 · Individual y cooperativo

- **A solas** toda su atención es para uno, no hay compañero que distraiga ni que avise, y una captura termina el piso. Por eso el perdón de la tabla es distinto, y por eso los objetivos de abajo son más bajos.
- **En equipo** la criatura persigue a uno cada vez: con cuatro jugadores hay más ruido y más teles que encender, pero también tres personas libres mientras caza a la cuarta. Falta saber cómo cambia la dificultad con 2, 3, 4 y 5: se mide en la fase 2, y si la curva no es razonable el perfil lleva un factor por tamaño de equipo (sobre el director, que es quien reparte la presión; no sobre los sentidos).
- **Versus** no tiene dificultad: la criatura es una persona. Solo cuenta para la IA que la sustituye si el cazador se desconecta.

## 6 · A qué apuntamos, y cómo se mide

Objetivos de partida, por piso entero. Los porcentajes de los bots son **relativos**: los bots saben siempre dónde está la criatura, así que esquivan mejor que una persona. Sirven para comparar dificultades entre sí y para ver si un cambio aprieta o afloja; el número de verdad sale de las partidas con gente.

**No hay guardada ninguna medida del juego de hoy** (los lotes de bots anteriores se borraron en la limpieza de septiembre). La columna de Desafiante es lo que se esperaba al ajustar los bots; lo primero de la fase 2 es medirla. Si sale lejos de ahí, Desafiante se queda como está —es la referencia— y lo que se mueve son los objetivos de las otras tres.

| | Apacible | Equilibrada | Desafiante | Pesadilla |
|---|---|---|---|---|
| Pisos ganados, 3 bots sin clemencia | ≥ 85 % | 65–75 % | 45–55 % | 15–25 % |
| Pisos ganados, 1 bot | ≥ 75 % | 50–60 % | 30–40 % | ≤ 15 % |
| Caídas por piso (equipo de 3) | &lt; 1 | 1–2 | 2–4 | 4 o más |
| Persecuciones por jugador y piso | 1–2 | 2–4 | 3–5 | 5 o más |
| De cada 10 persecuciones, acaban en huida | 9 | 7 | 5 | 3 |
| Rato más largo sin saber nada de ella | 3 min | 2 min | 90 s | 60 s |

Lo que hay para medir, y lo que falta:

- **Ya existe:** los bots en lote (`tools/bots.ps1`), con resultado, duración, caídas y capturas por piso, y su grabación para repasar; y el parte de cada cinta, que ya guarda por jugador persecuciones, huidas, tiempo perseguido, caídas y lo más cerca que la tuvo.
- **Falta:** lanzar los lotes por dificultad y juntar el resultado en una tabla; anotar en la cinta la dificultad y la presión media del director; y ver las palancas en vivo en el observador.

## 7 · Dónde se elige y qué pasa con las marcas

- **Individual:** al empezar «Nueva partida», una pantalla con las cuatro y una línea de cada una; se recuerda la última. «Continuar» y «Reintentar» conservan la del piso.
- **Cooperativo:** en la sala, junto a «Tipo de partida», la elige el anfitrión y la ven todos.
- **De fábrica:** Equilibrada.
- **Marcas (recomendación):** la dificultad va escrita en cada cinta y en cada línea del tablón; el tablón se puede filtrar por dificultad; el puntaje lleva un multiplicador (Apacible ×0,8 · Equilibrada ×1 · Desafiante ×1,25 · Pesadilla ×1,5); y hay hitos nuevos por salir en Desafiante y en Pesadilla. Las cintas guardadas hasta hoy se etiquetan como Desafiante, que es lo que eran.
- **Con las reglas de la sala:** la dificultad pone el perfil de la criatura y el perdón de partida; una regla cambiada a mano manda sobre ella, y esa cinta va al tablón «con otras reglas», como ahora.

## 8 · Fases

Cada fase se cierra con la batería en verde, lo hecho descrito en el diseño y su commit.

| Fase | Qué se hace | Se da por buena cuando |
|---|---|---|
| **0 · Decisiones** | Las de la sección 9 | Están contestadas |
| **1 · Cimientos** | El archivo de perfiles; la criatura, el director, las teles y el ascensor leen sus números de él en vez de constantes; la dificultad viaja con la partida, el punto de control y la cinta; la pantalla para elegirla | Con Desafiante, el juego es idéntico al de hoy: mismas pruebas, mismos resultados de los bots en las mismas semillas |
| **2 · Instrumentos** | Lotes de bots por dificultad y por tamaño de equipo (1 a 5) con tabla comparativa; dificultad y presión del director en la cinta; palancas a la vista en el observador | Hay una tabla de Desafiante que sirve de referencia, repetible |
| **3 · Apacible y Equilibrada, por números** | Los valores de la sección 3, medidos y corregidos hasta entrar en los objetivos | Los bots dan los porcentajes de la sección 6, y cada palanca va en orden de Apacible a Pesadilla |
| **4 · Conductas** | Las de Apacible primero (son pocas y baratas), luego las de Pesadilla, una a una | Cada conducta tiene su prueba y su medida antes y después |
| **5 · Pesadilla, por números** | Sus valores, ya con las conductas puestas | Entra en sus objetivos sin romper ninguna regla de las que no se rompen |
| **6 · Individual y equipo** | El perdón por modo y, si hace falta, el factor por tamaño de equipo | La curva de 1 a 5 jugadores es razonable en las cuatro |
| **7 · Marcas** | Dificultad en tablones, multiplicador, filtro e hitos | — |
| **8 · Con gente** | Tres partidas por dificultad, a solas y en equipo, con el parte de cada una | Los números finales salen de esas partidas, no de los bots |

Las fases 1 y 2 no cambian nada que se note jugando: son el andamio. La primera dificultad nueva que se puede probar llega al final de la 3.

## 9 · Lo que hay que decidir antes de empezar

1. **¿Desafiante es exactamente lo de hoy?** Recomendado: sí, sin tocar nada, para tener una referencia fija.
2. **¿La de fábrica es Equilibrada?** Recomendado: sí.
3. **¿El perdón cambia con la dificultad** (sección 3), o se deja siempre como hoy y que cada sala lo cambie en Reglas? Recomendado: cambia, porque es lo que más iguala individual y equipo.
4. **¿La dificultad toca solo a la criatura y al perdón**, o también cosas del piso (cordura, apagón, teles)? Recomendado: solo criatura y perdón.
5. **Marcas:** ¿un tablón con la dificultad a la vista y multiplicador de puntaje (recomendado), o tablones separados por dificultad?
6. **¿Pesadilla puede cambiar el aura** (oírla desde menos lejos)? Recomendado: no; es de las reglas que no se rompen.
7. **¿Se puede cambiar de dificultad a mitad de un piso?** Recomendado: no; se elige al empezarlo.
