> Manda docs/PORT_UNREAL.md donde este diseño diga otra cosa. Correcciones posteriores: .claude/specs/unreal/LEEME.md.

# Diseño del port: Red y Steam

Escrito el 15 de noviembre de 2026. Solo lectura: no se ejecutó Godot ni Unreal, no se compiló nada y no se consultó la web (todo lo de Epic sale del motor instalado). Marcas: **[G]** leído hoy en el código de Godot; **[M]** leído hoy en el motor (`UE:` = `C:/Program Files (x86)/UnrealEngine/UE_5.8/Engine`); **[F]** tomado de `fichas/red.md` o `fichas/servicios.md` sin releer el origen; **[D]** decisión de este documento. `<P>` = `E:/Projects/TheFourUE` (`diseno/metodo.md` §2.1).

## 1. Qué hay hoy en Godot

- **Archivos.** `game/net/net_session.gd` (448 líneas, sala), `match_net.gd` (1231, partida), `remote_player.gd` (299, cuerpo de otro), `steam_link.gd` (336, Steam), `steam_diagnose.gd` (38); prueba `tests/net/net_test.gd` (806, 209 comprobaciones) lanzada por `tools/net_test.ps1` [F §1].
- **Topología.** Estrella con anfitrión autoritario en el asiento 1; los invitados solo hablan con él y él reenvía a mano (`server_relay = false`, `relay()`) [F §2]. 6 asientos, 5 supervivientes, mínimo 2, 2 observadores sin asiento que solo entran por IP (`net_session.gd:27-39` [G]).
- **RPC.** 55, todas `call_remote`: 50 en `match_net.gd` y 5 en `net_session.gd` [G, `grep -c "^@rpc"`]. Canales fiable, no fiable y no fiable ordenado. Los nombres y argumentos de las 50 están fijados en `tests/hotel/creature_contract_test.gd:86-89` [F §4].
- **Ritmos.** Jugador y criatura a 20 Hz, sesión y cordura a 2 Hz, gracia de reconexión 60 s, espera de construcción 30 s, alcance de quien pide 5 m (`match_net.gd:23-32` [G]). Los remotos interpolan a 0,1 s con el reloj de llegada, no con el del emisor (`remote_player.gd:15, 162, 243` [F §7]).
- **Movimiento.** Cada cliente mueve su cuerpo y manda su estado (12 campos, `match_net.gd:307-332`); el anfitrión solo comprueba que el asiento coincide con quien envía y reenvía (`:337-340`) [F §7]. No hay predicción ni corrección.
- **Planta.** Viaja la semilla, no la planta. Cada máquina genera y manda el hash del manifiesto; si difiere, el anfitrión la echa (`match_net.gd:131, 158, 187-191`) [F §6].
- **Unirse a mitad.** Solo vuelve un asiento que se cayó (mismo nombre) o entra un observador: `begin` con marca, construir, `report_ready`, `restore(...)` con el estado entero y después `session_state` [F §8].
- **Transporte.** ENet en UDP 38430, o `SteamMultiplayerPeer` dentro de un lobby de Steam solo para amigos [F §3].
- **Steam.** GodotSteam 4.22.1. **AppID 480 (Spacewar)**: `project.godot:73` y `steam_link.gd:30` [G]. Usa lobby, invitaciones (overlay y directa), `join_requested`, `+connect_lobby`, presencia `connect`, lista de amigos y sus salas, logros (`setAchievement` + `storeStats`, nombres `F<piso>_<ID>`) y logros de un amigo (`requestUserStats`). No usa tickets, tablas de puntuación, nube ni voz [F §10]. Con el 480 no hay logros reales: Steam los rechaza todos (`docs/DEVELOPMENT.md:76-77` [G]).
- **Guardados.** JSON en `user://` (`hotel_settings.json`, `records.json`, `discoveries.json`, `hotel_checkpoint.json`, `coop_checkpoint.json`) y un binario `store_var` (`hotel_checkpoint.state`) [F servicios §3].
- **Pruebas.** Cinco escenarios (coop, versus, late, observer, office_coop), un proceso por rol, puertos fijos 24600 a 24650 (`tools/verify.ps1:121` [G]).

## 2. Cómo queda en Unreal

Todo es C++ y texto de configuración. **Este dominio no crea ningún asset binario.** El mapa vacío es el de `diseno/mundo.md` (U10).

### 2.1 Plugins y configuración (texto)

- `TheFour.uproject`: activar `OnlineSubsystem`, `OnlineSubsystemUtils`, `OnlineSubsystemNull`, `OnlineSubsystemSteam` y `SteamSockets` (los dos últimos vienen apagados: `UE:Plugins/Online/OnlineSubsystemSteam/OnlineSubsystemSteam.uplugin:11`, `UE:Plugins/Runtime/Steam/SteamSockets/SteamSockets.uplugin:10` [M]).
- `Config/DefaultEngine.ini`:
  - `[OnlineSubsystem] DefaultPlatformService=Steam`.
  - `[OnlineSubsystemSteam] bEnabled=true`, `SteamDevAppId=480`, `bRelaunchInSteam=false`, `bInitServerOnClient=true`, `bAllowP2PPacketRelay=true` (valores base en `UE:Config/BaseEngine.ini:2510-2519` [M]) y la lista de logros `Achievement_<n>_Id=F1_OUT…` (formato en `UE:Plugins/Online/OnlineSubsystemSteam/Source/Private/OnlineAchievementsInterfaceSteam.h:44-68` [M]).
  - `[/Script/Engine.GameEngine]`: `GameNetDriver` con `DriverClassName=/Script/SteamSockets.SteamSocketsNetDriver` y `DriverClassNameFallback=/Script/OnlineSubsystemUtils.IpNetDriver` (la definición base es IpNetDriver: `BaseEngine.ini:343` [M]).
  - `[URL] Port=38430` (el base es 7777: `BaseEngine.ini:31` [M]).
  - Iris no se toca: queda apagado.
- Módulo: carpeta `Source/TheFour/Net/` dentro del módulo de juego `TheFour` (`diseno/metodo.md:40`). Dependencias nuevas en `TheFour.Build.cs`: `OnlineSubsystem`, `OnlineSubsystemUtils`, `NetCore`.

### 2.2 Clases (C++)

| Clase | Base | Qué lleva |
|---|---|---|
| `AFourGameMode` | `AGameMode` (solo existe en el anfitrión) | Lo que hoy decide el anfitrión: `PreLogin` (versión, sala llena, partida empezada salvo asiento que vuelve), `Login` (asiento, nombre único), `Logout` (caída, gracia de 60 s), `StartMatch(Seed)`, `JudgeReady`, `ReturnToLobby`, validaciones `NearSender` (5 m). Firmas del motor: `UE:Source/Runtime/Engine/Classes/GameFramework/GameModeBase.h:293, 323, 342` [M] |
| `AFourGameSession` | `AGameSession` | `MaxPlayers=6`, `MaxSpectators=2` (`UE:.../GameFramework/GameSession.h:33, 37` [M]) |
| `AFourGameState` | `AGameStateBase` | Propiedades replicadas: `Seats` (`TArray<FFourSeat>`), `HostOptions`, `bPlaying`, `Session` (`FFourSessionNet`: estado, vidas, tiempo, mensaje, etapa, `FFourGoal`), `Minds` (cordura por asiento). `SetNetUpdateFrequency(2)` |
| `AFourPlayerState` | `APlayerState` | `Seat` replicado (0 = observador). Nada más: el asiento sobrevive a la desconexión en `Seats`, no aquí |
| `AFourPlayerController` | `APlayerController` | Dueño de `UFourMatchLink`. Un controlador por par, también el del anfitrión y el de quien mira |
| `UFourMatchLink` | `UActorComponent` replicado, en el controlador | **Todas las RPC fiables de partida**: `Server…` (peticiones) y `Client…` (resultados). El anfitrión avisa a todos con `AFourGameMode::ToEveryone(TFunctionRef<void(UFourMatchLink&)>)`, que recorre los controladores. Una cabecera y un `.cpp` por familia (`FourMatchLink_Doors.cpp`, `_Hides`, `_Lifts`, `_Office`, `_Sheet`, `_Versus`, `_Capture`, `_Rejoin`) |
| `AFourSurvivor` | el peón de `diseno/jugador.md` | Replicado, `bAlwaysRelevant`. `ServerPushState(FSurvivorNetState)` no fiable a 20 Hz; propiedad `NetState` replicada con `COND_SkipOwner`; en los demás, `OnRep_NetState` llama a `PushRemote(State, RelojLocal)` (`diseno/jugador.md:49`) |
| `AFourCreature` | el de `diseno/criaturas.md` | Replicado, creado por el anfitrión, `bAlwaysRelevant`. `NetState` (`FCreatureNetState`) igual que el superviviente; `ServerPushState` solo cuando la conduce el cazador. `MulticastEvent`/`MulticastCall` fiables, con `ServerEvent`/`ServerCall` delante si conduce un cliente |
| `UFourOnlineSubsystem` | `UGameInstanceSubsystem` | Steam por las interfaces de `IOnlineSubsystem`: sala, unirse, invitar, amigos, presencia, logros. Único archivo que incluye cabeceras de OnlineSubsystem |
| `UFourNetScenario` | `UGameInstanceSubsystem`, solo no Shipping | Con `-FourNetRole=<rol>`: guion del escenario y volcado a `Saved/verify/net_<rol>.json` (port de `tests/net/net_test.gd`) |

### 2.3 Tipos de datos (C++, `Net/FourNetTypes.h`)

`FFourSeat` (nombre, personaje, conectado, id de jugador), `FFourHostOptions`, `FFourMatchConfig` (seed, mode, locust_seat, survivors, rules, floor, difficulty, versión del generador), `FFourGoal` (blackout, ready, done, needed), `FFourSessionNet`, `FSurvivorNetState` (12 campos), `FCreatureNetState` (6 o 12 campos), `FFourSheetOp`, `FFourRestore`, y **`FFourBlob`**: bytes con `NetSerialize` propio (longitud y datos), para la foto y para los `data` de objetivos que hoy son `Dictionary`.

Constantes en `Net/FourNetConstants.h`, mismas cifras: `Port 38430`, `MaxPlayers 6`, `MaxSurvivors 5`, `Observers 2`, `MinPlayers 2`, `Protocol "the-four-net-22"`, `SendRate 20`, `SessionRate 2`, `ReconnectGrace 60`, `ReadyTimeout 30`, `Reach 5`, `SheetRate 30`, 128 puntos por trozo, `PhotoMaxBytes 24576`, `ShriekRange 26`, `ShriekTime 4`, `ShriekRate 5` [F §12].

### 2.4 Flujo

1. **Un solo mapa.** Título, sala y partida viven en el mapa vacío, sin viajes entre sala y partida. Solo: el mismo mapa en `NM_Standalone`; las RPC `Server…` y `Client…` se ejecutan en local, así que no hay dos caminos de código.
2. **Crear sala.** Abrir el mapa con `?listen`. Con Steam: `IOnlineSession::CreateSession` con 6 plazas, `bShouldAdvertise`, `bAllowJoinViaPresenceFriendsOnly`, `bUsesPresence`, `bUseLobbiesIfAvailable`, `bAllowInvites` y los datos `game=the_four`, `protocol`; eso da un lobby solo para amigos (`UE:.../OnlineSessionAsyncLobbySteam.cpp:74-79` [M]).
3. **Entrar.** URL con `?Name=…?Char=…?Proto=…?Gen=…` y `?SpectatorOnly=1` para mirar (`UE:.../Private/GameSession.cpp:228` [M]). `PreLogin` rechaza con el mismo texto de hoy; `Login` da el asiento. Sustituye a `register`, `refused` y `welcome`.
4. **Empezar.** `StartMatch` → `ClientBegin(Config, Marca)` a todos → cada máquina genera (`diseno/mundo.md` D12) → `ServerReportReady(Sha256)` → `JudgeReady` → `ClientGo()`. Espera máxima 30 s.
5. **Jugar.** Peticiones por `Server…`, validadas en el anfitrión igual que hoy; resultados por `Client…` a todos. Los actores de la planta (puertas, armarios, televisores…) los crea cada máquina y **no se replican**: se nombran por el mismo índice entero que hoy.
6. **Volver o mirar.** `Login` reconoce el asiento caído por nombre → `ClientBegin(Config, Returning)` → construir → `ServerReportReady` → `ClientRestore(FFourRestore)` y la hoja por tandas. Peones, criatura, `Session` y `Minds` llegan solos por replicación.

## 3. Correspondencia pieza a pieza

Las 55 RPC. «S» = `Server` en `UFourMatchLink` (cliente → anfitrión); «C» = `Client` en `UFourMatchLink`, que el anfitrión envía a todos o a uno; «P» = propiedad replicada. Todas las S y C son `Reliable` salvo las marcadas.

| RPC de Godot | En Unreal | Tipo |
|---|---|---|
| `register`, `refused`, `welcome` | URL de entrada + `AFourGameMode::PreLogin`/`Login`; `AFourPlayerState::Seat` | motor + P |
| `lobby_state` | `AFourGameState::Seats`, `HostOptions`, `bPlaying` | P |
| `profile` | `ServerSetCharacter(uint8)` | S |
| `begin` | `ClientBegin(FFourMatchConfig, EFourBeginMark)` | C |
| `report_ready` | `ServerReportReady(FString Sha256)` | S |
| `go`, `back_to_room`, `floor_left`, `code_state` | `ClientGo()`, `ClientBackToRoom()`, `ClientFloorLeft()`, `ClientCodeState()` | C |
| `player_state` | `AFourSurvivor::ServerPushState` (no fiable) + `NetState` | S + P |
| `locust_state` | `AFourCreature::NetState`; `ServerPushState` (no fiable) si conduce el cazador | P (+ S) |
| `session_state` | `AFourGameState::Session` | P |
| `minds_state` | `AFourGameState::Minds` | P |
| `request_door` / `door_swung`, `door_settled` | `ServerRequestDoor(Index, bSlow, bForceful)` / `ClientDoorSwung(Index, Target, bSlow, bForceful)`, `ClientDoorSettled(Index, bOpened)` | S / C |
| `request_hide` / `hide_state`, `hide_forced` | `ServerRequestHide(Index, bEntering, bQuiet)` / `ClientHideState(Index, Seat, bQuiet)`, `ClientHideForced(Index)` | S / C |
| `request_television` / `television_state` | `ServerRequestTelevision(Index)` / `ClientTelevisionState(Index, bValue)` | S / C |
| `request_container` / `container_state` | `ServerRequestContainer(Index)` / `ClientContainerState(Index, bValue, Seat)` | S / C |
| `request_panel` / `panel_state` | `ServerRequestPanel(Index, EFourPanelAction)` / `ClientPanelState(Index, Action)` | S / C |
| `request_code` | `ServerRequestCode(FString Text)` | S |
| `request_lift` / `ride_state`, `locust_rode` | `ServerRequestLift(Index)` / `ClientRideState(Seat, Point)`, `ClientLocustRode(Point)` | S / C |
| `request_office` / `office_state`, `office_refused` | `ServerRequestOffice(FName Objective, FName Action, Index)` / `ClientOfficeState(Objective, Action, Index, Seat, FFourBlob)`, `ClientOfficeRefused(...)` | S / C |
| `office_photo` | `ServerOfficePhoto(FFourBlob)` / `ClientOfficePhoto(Seat, FFourBlob)` | S / C |
| `sheet_chunk` / `sheet_confirmed` | `ServerSheetChunk(OpId, Kind, TArray<FVector2f>)` / `ClientSheetConfirmed(...)` | S / C |
| `player_card` | `ServerPlayerCard(FFourCard)` / `ClientPlayerCard(Seat, FFourCard)` | S / C |
| `player_noise` | `ServerPlayerNoise(Point, Radius, Kind)` (no fiable) | S |
| `play_world_sound` | `ClientWorldSound(FName Sound, Point, Gain, Start)`; el nombre es una fila de la tabla de sonidos, no una ruta | C |
| `creature_event_rpc` | `AFourCreature::ServerEvent` / `MulticastEvent(FName Kind, FFourBlob)` | S / multicast |
| `locust_call` | `AFourCreature::ServerCall` / `MulticastCall(FName Kind, int32 Segment, float Pitch)` | S / multicast |
| `strike`, `request_force`, `request_shriek`, `request_warp` | `ServerStrike(Origin, Facing)`, `ServerRequestForce(Index)`, `ServerRequestShriek()`, `ServerRequestWarp(Index)` | S |
| `warp_state` | `ClientWarpState(Index)` | C |
| `shriek_reveal`, `heard_contact` | `ClientShriekReveal(TArray<FVector>)`, `ClientHeardContact(...)` (no fiables, solo al cazador) | C |
| `execute_start`, `lens_settled`, `revived_state`, `floor_summary` | `ClientExecuteStart(Seat, Point, Yaw, FFourCapture)`, `ClientLensSettled(Id, Rest, bLook)`, `ClientRevived(Places, bRestart, CreatureAt)`, `ClientFloorSummary(FString)` | C |
| `tell_lens` | `ServerTellLens(Id, FTransform Rest, bSeen)` | S |
| `restore` | `ClientRestore(FFourRestore)` + `ClientRestoreSheet(TArray<FFourSheetOp>)` por tandas | C |

Lo que no es RPC:

| Godot | Unreal |
|---|---|
| `ENetMultiplayerPeer`, puerto 38430 | `UIpNetDriver` (respaldo de la definición), `[URL] Port=38430` |
| `SteamMultiplayerPeer` | `USteamSocketsNetDriver` sobre el relé de Steam |
| `relay()` a mano, `server_relay=false` | Replicación del motor (`COND_SkipOwner`) y `ToEveryone` |
| `get_remote_sender_id()` + asiento | El controlador dueño del `UFourMatchLink` que recibe la `Server…` |
| `call_remote` y copia a mano en el anfitrión | La `Client…` del controlador local del anfitrión se ejecuta en local |
| `floor_live` (ignorar hasta estar construido) | `UFourMatchLink::bFloorLive`, misma regla |
| `hash(JSON.stringify(manifest))` | SHA-256 canónico de `diseno/mundo.md` D12 |
| `PROTOCOL` + hash de versiones | Opciones `Proto` y `Gen` en `PreLogin`, además de la comprobación de versión de red del motor |
| `away` + `RECONNECT_GRACE` | `Seats[i].bConnected` + temporizador en `AFourGameMode`; no se usa `InactivePlayerArray` |
| `coop_checkpoint.json` | El mismo JSON bajo `Saved/SaveGames/` (lo fija el dominio de servicios) |
| `steam_link.gd` | `UFourOnlineSubsystem` |
| `steam_diagnose.gd` | Orden de consola `Four.SteamDiagnose` en el mismo subsistema |
| `tests/net/net_test.gd`, `tools/net_test.ps1` | `UFourNetScenario`, `<P>/Tools/net_test.ps1` |

Steam, función a función: `createLobby` → `CreateSession`; `joinLobby` → `JoinSession` + `GetResolvedConnectString` + `ClientTravel`; `activateGameOverlayInviteDialog` → `IOnlineExternalUI::ShowInviteUI` (`UE:.../OnlineExternalUIInterfaceSteam.cpp:82` [M]); `inviteUserToLobby` → `SendSessionInviteToFriend`; `join_requested` → `OnSessionUserInviteAccepted` (`UE:.../OnlineAsyncTaskManagerSteam.cpp:46` [M]); `+connect_lobby` → ya lo trata el motor (`UE:.../OnlineSessionInterfaceSteam.cpp:1117-1179` [M]); `setRichPresence("connect")` → lo pone el motor para sesiones con presencia (`UE:.../OnlinePresenceInterfaceSteam.cpp:171` [M]); amigos y sus salas → `IOnlineFriends::ReadFriendsList`, `FindFriendSession`; `setAchievement` + `storeStats` → `IOnlineAchievements::WriteAchievements`; logros de un amigo → `QueryAchievements` (ver §10).

## 4. Decisiones

**D1. Servidor de escucha con el modelo de juego del motor, no un canal propio.** Cada cosa a su clase: lo que decide el anfitrión a `AFourGameMode`, lo que todos leen a `AFourGameState`, el asiento a `AFourPlayerState`, las peticiones al controlador. Descartado: un actor único «Match» con las 55 RPC copiadas (el motor no deja a un cliente llamar a una RPC de servidor en un actor que no es suyo); servidor dedicado (no existe hoy y pide otra máquina o proceso).

**D2. `OnlineSubsystemSteam` + `SteamSockets`.** Cubre todo lo que usa `steam_link.gd` (tabla del §3) con plugins que ya vienen en 5.8 y con Steamworks 1.64 incluido (`UE:Source/ThirdParty/Steamworks/Steamv164` [M]). `SteamSockets` es el transporte con P2P y relé; `SocketSubsystemSteamIP` no hace NAT (`UE:Plugins/Online/SocketSubsystemSteamIP/SocketSubsystemSteamIP.uplugin:7` [M]). Descartado:
- Steamworks directo: habría que escribir a mano lobby, invitaciones y el enlace con el transporte. Queda como salida puntual dentro de `UFourOnlineSubsystem` si una interfaz no llega (logros de un amigo).
- EOS: pide cuenta de desarrollador de Epic y otra identidad; no aporta nada a un juego solo de Steam y choca con «sin crear cuentas».
- OnlineServices (la interfaz nueva): en 5.8 no trae implementación de Steam, solo EOS, Null y un adaptador (`UE:Plugins/Online/` [M, listado]).

**D3. Iris no.** Viene apagado y marcado Beta [F `briefs/ue58.md`]; aquí hay 6 pares y unos 8 actores replicados. La replicación clásica basta. Se revisa solo si un perfil de red lo pide.

**D4. Las RPC fiables de partida van todas por el controlador de cada par, no por multicast en `AFourGameState`.** Hoy todo viaja por un único flujo ordenado por par; el motor solo garantiza el orden dentro de un mismo actor. Si `ClientRestore` fuera por el controlador y `door_swung` por multicast del GameState, una puerta podría llegar antes que la restauración que la pisa. Por el mismo componente el orden es el de hoy. Además es el port más mecánico: cada `@rpc` conserva nombre y argumentos. Excepción: los eventos de la criatura van por su propio actor (nacen y mueren con él y no dependen de `restore`).

**D5. Estado periódico como propiedades replicadas.** `lobby_state`, `session_state` y `minds_state` ya son estado empujado a 2 Hz; como propiedades, quien entra tarde las recibe sin código. El cliente las aplica solo con `bFloorLive`, como hoy.

**D6. Movimiento: el cliente manda, como hoy. Sin predicción ni corrección del motor.** `diseno/jugador.md` D1 ya descarta `CharacterMovementComponent`, y D11 fija 20 Hz, 0,1 s y 12 estados. La red solo transporta `FSurvivorNetState`. Descartado: autoridad del anfitrión con predicción (cambia la sensación y exige reescribir el movimiento sobre el modelo de red del motor); `bReplicateMovement` (suavizado propio del motor, distinto del de hoy).

**D7. Criaturas con autoridad del anfitrión; el cazador conduce la suya.** En coop la mente corre solo en el anfitrión y los demás ven la réplica interpolada. En versus el controlador del cazador posee la criatura y manda su estado; golpe, forzar armario, chillido y salto por televisor los valida el anfitrión. Si el cazador se cae, el anfitrión le pone la IA (hoy `seat_dropped`, `match_net.gd:1116-1119` [F §9]).

**D8. Puertas, luces e interactivos: actores locales, por índice.** No se replican como actores: la planta la crea cada máquina y el motor no puede replicar un actor que el servidor no ha creado. El índice entero ya es estable porque sale de la misma planta comprobada por SHA. El apagón sigue en `Session.Goal.bBlackout`; la corriente del piso 2 en `ClientOfficeState`. La luz que bebe la criatura se sigue calculando en cada máquina desde la posición replicada, y su temblor sigue sin sincronizar, como hoy [F §7]. Descartado: `FFastArraySerializer` con el estado de cada puerta (obliga a reescribir cada manejador como estado más `OnRep`; se pierde el port mecánico y los parámetros del vaivén).

**D9. Semilla en cada par y SHA.** Como `diseno/mundo.md` D12. El respaldo local por física (planta 404) desaparece porque `validate_physics` pasa a prueba (`mundo.md` D9), así que esa fuente de desajuste se va.

**D10. Unirse a mitad: igual que hoy.** Solo asientos que vuelven y observadores. `ClientRestore` lleva puertas, armarios, posiciones, televisores y progreso; la hoja va aparte en tandas porque el motor corta el canal si se acumulan 512 envíos fiables sin confirmar (`UE:.../Classes/Engine/NetConnection.h:82` [M]) o si un envío pasa de 64 KB (`UE:.../Private/DataChannel.cpp:105` [M]), y hoy la hoja admite 3000 operaciones.

**D11. `FFourBlob` con serialización propia.** Los arrays en red tienen por defecto un tope de 2048 elementos (`UE:.../Classes/Engine/NetworkSettings.h:33` [M]); una foto de 24 576 bytes como `TArray<uint8>` lo pasa. Descartado: subir el tope global en el ini (afecta a todo y relaja una defensa).

**D12. AppID 480 hasta que el autor tenga el suyo; guardados y logros.** Hoy no hay AppID propio en el repo, así que **no hay logros de Steam que conservar**: los hitos viven en `records.json`. Al pasar al AppID real, el arranque ya manda todos los hitos locales a Steam (como hoy `unlock()` al arrancar), y basta con crear en Steamworks los logros `F<piso>_<ID>`. Los guardados cambian de carpeta (de `%APPDATA%/Godot/app_userdata/THE FOUR — Hotel` a `Saved/` del juego): se propone leer una vez, sin escribir, `records.json`, `discoveries.json` y `hotel_settings.json` de la carpeta antigua (pregunta 3). Los puntos de control no se migran: el binario `store_var` es de Godot y la planta cambia con el generador.

**D13. Juego por IP: se conserva, con una condición.** Con Steam abierto en los dos equipos, IP va por `SteamSockets` en modo de paso (`?bIsLanMatch`: `UE:.../SteamSocketsNetDriver.cpp:67-68, 92-95` [M]); sin Steam (`-nosteam`), por `IpNetDriver`. Un equipo con Steam y otro sin él no se entienden. Los observadores siguen entrando por IP.

**D14. Pruebas: procesos `-game -nullrhi -nosteam` en una máquina.** Port directo de `net_test.ps1`. Con `-nosteam` el motor cae a `OnlineSubsystemNull` e `IpNetDriver`, sin cuenta ni cliente de Steam. Descartado: PIE con varios clientes (necesita el editor con ventana y no es lo que se publica); pruebas de Steam automáticas (Steam no admite dos sesiones en un PC: `docs/DEVELOPMENT.md:81` [G]).

## 5. Prueba de concepto visual

**No entra nada de red** (`diseno/poc.md:155`). La red no cambia la imagen. Lo único que conviene dejar hecho al crear el proyecto, porque es texto y no cuesta: los cinco plugins en el `.uproject` con `bEnabled=false` en `[OnlineSubsystemSteam]`, para que la prueba de concepto no dependa de Steam.

## 6. Unidades de trabajo

«∥» = puede ir en paralelo con las de su misma línea de dependencias (archivos disjuntos, sin motor). Las que arrancan procesos del motor van en serie y bajo el cerrojo de `Tools/ue.ps1`.

| # | Unidad | Origen | Resultado | Prueba de aceptación |
|---|---|---|---|---|
| N0 | Humo de red (tras `metodo` M0-M3) | `tools/net_test.ps1` | `AFourGameMode`, `AFourPlayerController` mínimos, `UFourNetScenario`, `Tools/net_test.ps1`, ini del §2.1 | Dos procesos `-nosteam` en el puerto 24600: el invitado entra, cruza una `Server…` y una `Client…`, y los dos JSON lo dicen. Anotados arranque y RAM por proceso |
| N1 ∥ | Tipos, constantes y cabecera completa de `UFourMatchLink` (las firmas del §3, cuerpos vacíos) | `net_session.gd`, `match_net.gd` (cabeceras de las 55) | `FourNetTypes.h`, `FourNetConstants.h`, `FourMatchLink.h` | Compila; prueba de capa 2: `FFourBlob` de 24 576 bytes va y vuelve igual; una prueba comprueba que las 50 de la lista `RPCS` tienen su correspondencia |
| N2 | Sala (tras N0, N1) | `net_session.gd` entero | `PreLogin`, `Login`, `Logout`, `Seats`, opciones, personaje | Escenario: séptimo rechazado, nombre repetido pasa a «Nombre 2», versión distinta da el texto de hoy, observador con asiento 0, mínimo 2 para empezar |
| N3 | Arranque coordinado (tras N2 y `mundo` U16) | `match_net.gd:107-257`, `net_session.gd:410-442` | `StartMatch`, `ClientBegin`, `ServerReportReady`, `JudgeReady`, `ClientGo`, `ClientBackToRoom`, punto de control coop | Dos procesos con la misma semilla llegan a `go`; uno con el generador alterado recibe «Tu piso no coincide…»; a los 30 s se empieza sin el que no construyó |
| N4 | Supervivientes a 20 Hz (tras N3 y `jugador` J14) | `match_net.gd:274-340`, `remote_player.gd` | `ServerPushState`, `NetState`, `OnRep` | Es `jugador` J16: el remoto sigue al local a 0,1 s sin saltos; un salto de más de 3 m se toma de golpe |
| N5 ∥ | Sesión y cordura (tras N3) | `match_net.gd:358-372` | `Session`, `Minds` replicadas | El invitado ve etapa, vidas y apagón iguales a los del anfitrión en menos de 1 s; nada se aplica antes de `bFloorLive` |
| N6a-e ∥ | Interactivos, un `.cpp` por familia (tras N3): puertas; armarios; televisores, cajones y paneles; código y ascensores; ruidos y sonidos del mundo | `match_net.gd:388-770` | `FourMatchLink_<Familia>.cpp` | Por familia, el tramo correspondiente del escenario coop: petición fuera de 5 m rechazada, estado igual en los tres procesos |
| N7 | Criatura en red y versus (tras N4 y `criaturas` C10, C16) | `match_net.gd:342-354, 780-927`, `pack_state`, `follow_state` | `NetState` de la criatura, eventos, golpe, forzar, chillido, salto, oído | Es `criaturas` C18 (réplica a menos de 0,3 m); escenario versus en verde |
| N8 ∥ | Captura, revivir, parte y fichas (tras N6) | `match_net.gd:624-629, 970-1039`, `executions.gd:193, 552, 560` | `FourMatchLink_Capture.cpp` | Tramo de captura y de revivir del escenario coop |
| N9 ∥ | Objetivos del piso 2 y foto (tras N6) | `match_net.gd:427-481` | `FourMatchLink_Office.cpp` | Escenario office_coop; foto de 24 576 bytes aceptada, una mayor rechazada |
| N10 ∥ | Hoja compartida (tras N6) | `match_net.gd:1046-1082` | `FourMatchLink_Sheet.cpp` | 30 trozos por segundo y asiento, el 31 se descarta; 128 puntos máximo |
| N11 | Volver y mirar (tras N6-N10) | `match_net.gd:1108-1201`, `net_session.gd:263-335` | `ClientRestore`, tandas de hoja, gracia de 60 s, cazador que se va | Escenarios late y observer; reincorporación con la hoja a 3000 operaciones sin que se corte la conexión |
| N12 | Steam: sala, amigos, invitaciones, presencia (tras N2; build empaquetada) | `steam_link.gd:137-255, 315-336` | `UFourOnlineSubsystem` | Manual, dos equipos y dos cuentas (pasos de `docs/DEVELOPMENT.md:81`): crear, invitar, aceptar con el juego abierto, jugar un piso. `Four.SteamDiagnose` sin errores. Overlay comprobado |
| N13 ∥ | Logros (tras N12) | `steam_link.gd:265-311`, `hotel_main.gd:317-321` | `Unlock`, lista en el ini generada desde la tabla de hitos | Con 480: la llamada sale y el registro recoge el rechazo sin error de juego. Con AppID real: un logro se ve en el overlay |
| N14 | Cinco escenarios en `verify -Net` (tras N11; es `metodo` M13) | `tests/net/net_test.gd` | Escenarios coop, versus, late, observer, office_coop | Los cinco en verde dos veces seguidas |

## 7. Riesgos y cómo se detectan pronto

| Riesgo | Detección |
|---|---|
| Varios procesos del editor con `-game -nullrhi` no caben o tardan demasiado (hasta 4 por escenario) | N0 mide arranque y RAM con dos; si no cabe, los escenarios corren sobre una build Development empaquetada |
| Orden entre RPC fiables de actores distintos (base de D4) | Escenario late de N11: 50 puertas movidas durante la reincorporación deben quedar igual en los dos lados |
| Tope de arrays y de tamaño de envío (D10, D11) | Prueba de `FFourBlob` en N1 y hoja llena en N11 |
| El overlay de Steam no se engancha (en Godot exigió iniciar Steam antes del dispositivo gráfico: `docs/DEVELOPMENT.md:79` [G]) | N12, lo primero que se mira en la build empaquetada |
| `SteamSockets` en servidor de escucha no entra en la red de relé a tiempo (acceso diferido: `UE:.../SteamSocketsNetDriver.cpp:83-88` [M]) | N12: crear sala nada más arrancar el juego |
| IP mezclando un equipo con Steam y otro sin él (D13) | Mensaje claro en el menú; comprobarlo en N12 |
| La propiedad replicada no sale a 20 Hz reales (frecuencia de actor y tope de 30 del servidor: `BaseEngine.ini:1867` [M]) | N4 registra los intervalos de llegada: media de 50 ms |
| `Dictionary` de `office_state` y de eventos de criatura sin esquema | N1 lista los campos reales leyendo cada `apply`; si varían mucho, se quedan en `FFourBlob` |
| Steam activo en pruebas las vuelve lentas o frágiles (pasó en Godot) | Todas las pruebas con `-nosteam`; en el editor el motor ya no lo activa (`UE:.../OnlineSubsystemSteam.cpp:484-489` [M]) |

## 8. Preguntas para el autor

1. **AppID.** ¿Tienes ya un AppID propio en Steamworks o el juego sigue solo con el 480? De eso depende cuándo se pueden probar logros e invitaciones con el juego cerrado.
2. **Juego por IP y observadores.** ¿Se conservan en la versión de Unreal? Si solo se va a jugar por Steam, el modo IP queda para pruebas y se quita del menú.
3. **Marcas de los jugadores actuales.** ¿Quieres que la versión de Unreal lea una vez (sin escribir) `records.json`, `discoveries.json` y los ajustes de la carpeta del juego de Godot, para que nadie pierda sus marcas e hitos?
4. **Prueba con dos equipos.** N12 necesita dos PC con dos cuentas de Steam amigas. ¿La haces tú con alguien, y cuándo?

## 9. Qué instalar o bajar

Nada que descargar.

| Pieza | Fuente | Licencia |
|---|---|---|
| `OnlineSubsystem`, `OnlineSubsystemUtils`, `OnlineSubsystemNull`, `OnlineSubsystemSteam`, `SteamSockets`, `SteamShared` | Incluidos en UE 5.8.4 (`UE:Plugins/Online`, `UE:Plugins/Runtime/Steam`) | La del motor |
| Steamworks SDK 1.64 | Incluido (`UE:Source/ThirdParty/Steamworks/Steamv164`) | Acuerdo del SDK de Steamworks (`Steamworks.tps`, sin leer) |
| Cliente de Steam con sesión iniciada | Ya está en la máquina | — |

Para publicar con AppID propio hace falta la cuenta de Steamworks del autor; eso no lo hace un agente.

## 10. Sin comprobar

- Nada se ha ejecutado ni compilado. Ninguna firma de `IOnlineSession`, `IOnlineFriends`, `IOnlineExternalUI`, `IOnlinePresence` ni `IOnlineAchievements` se ha leído en su cabecera: los nombres del §3 son los habituales de esas interfaces y cada unidad los busca en `UE:Plugins/Online/OnlineSubsystem/Source/Public/Interfaces` antes de usarlos.
- Que las RPC fiables solo estén ordenadas dentro de un mismo actor (base de D4), que un cliente no pueda llamar una RPC de servidor en un actor ajeno (D1) y que una RPC `Client…` del controlador local del anfitrión se ejecute en local: conocimiento del motor, no releído en 5.8.
- Que el tope de 2048 elementos se aplique también a los parámetros de RPC y no solo a propiedades.
- Que `QueryAchievements` de Steam sirva para otro usuario (logros de un amigo). Si no, llamada directa a `ISteamUserStats::RequestUserStats`.
- Que `FindFriendSession` devuelva las salas de amigos como hoy `friend_rooms`.
- Que `bInitServerOnClient=true` sea necesario con `SteamSockets` en servidor de escucha, y el comportamiento exacto de `?bIsLanMatch` entre dos equipos con Steam.
- Cómo se engancha el overlay en una build empaquetada y si hay que arrancar desde Steam.
- Estado exacto de Iris en 5.8 (tomado de `briefs/ue58.md`); solo se vio que su código está en `UE:Source/Runtime/Net/Iris`.
- Que `-nosteam` desactive Steam también en `-game` con el binario del editor (solo se vio el mensaje que lo recomienda, `OnlineSubsystemSteam.cpp:406`).
- Si los escenarios de red de Godot corren a paso fijo de 60 o en reloj real, y cuál conviene en Unreal.
- Memoria y tiempo de 3 o 4 procesos `-game -nullrhi` a la vez.
- Los campos reales de `config`, `goal`, `progress`, `data` de objetivos y datos de eventos de criatura: salen de las fichas; N1 los lee del código.
- Simulación de retardo y pérdida con las órdenes del motor (`NetEmulation.*`): no buscadas.
- De Godot solo se releyó hoy: el recuento de `@rpc`, las constantes de `net_session.gd:27-39` y `match_net.gd:23-32`, `steam_link.gd` (funciones y AppID), `project.godot:18, 73-74`, `docs/DEVELOPMENT.md:73-82` y los puertos de `tools/verify.ps1:121`. El resto viene de las fichas.
- Los otros diseños nombran módulos distintos (`FourPlayer`, `FourCreatures`, `FourWorld` frente a los cuatro de `metodo.md:40`): aquí se ha seguido `metodo.md`. Lo cierra el director.
