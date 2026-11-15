> Manda docs/PORT_UNREAL.md donde este diseño diga otra cosa. Correcciones posteriores: .claude/specs/unreal/LEEME.md.

# Diseño del port: Audio

15 de noviembre de 2026. Solo plan: no se ejecutó ni compiló nada. Marcas: [G] leído por mí en el código de Godot; [F] dato de `fichas/audio.md` sin recomprobar; [M] leído por mí en el motor 5.8.4 (`UE:` = `C:/Program Files (x86)/UnrealEngine/UE_5.8/Engine`); [W] web; [D] deducción. Carpetas y órdenes del proyecto de Unreal (`<P>`, `FourCore`, `Tools/ue.ps1`): `diseno/metodo.md` §2.

## 1. Qué hay hoy en Godot

- **Un solo motor de sonido**: `game/audio/world_audio.gd` (816 líneas [G]) con `dread_aura.gd` (274), `theme_mood.gd` (115) y cuatro tablas generadas (`cue_timing`, `grunt_segments`, `footstep_segments`, `search_timing`) [G, `wc -l`].
- **Buses**: 11 en `default_bus_layout.tres` más `Ducts`, creado en ejecución (`world_audio.gd:527-547` [G]). Árbol [F §2]: Master (limitador −0,5 dB) ← Ambience (paso bajo «DreadMuffle»), Music (ancho estéreo y paso bajo, apagados), Effects (reverb), Threat (reverb), Steps (reverb); Aura → Threat; EffectsEcho → Effects y ThreatEcho → Threat (dos tomas de retardo y reverb); Creature → Threat y CreatureEcho → ThreatEcho (retardo «Ears» de dos tomas, una por oído); Ducts → Creature (EQ de 6 bandas y reverb).
- **El bus se elige por voz y cambia mientras suena**: `apply_route()` asigna `player.bus` al bus seco o al de eco según la ruta, y al de criatura si es ella (`world_audio.gd:507-515` [G]).
- **Propagación propia, no la del motor**: `route_source()` (`world_audio.gd:439-476` [F §3.3]) usa rayos y la ruta caminable de la navegación; el sonido tapado se coloca en la última abertura visible, con ganancia `−3 − 20·log10(1 + rodeo/5) − 8·puertas` dB y corte de 5200 a 900 Hz (1500 Hz con puerta cerrada). Límite 42 m de ruta, 8 voces, memo de ruta 0,3 s.
- **El filtro por voz es `attenuation_filter_cutoff_hz`** de `AudioStreamPlayer3D` (`world_audio.gd:521, 721, 767, 794` [G]), con `attenuation_filter_db` en su valor por defecto de −24 dB (`.claude/godot-api/doc/classes/AudioStreamPlayer3D.xml:46-48` [G]). La atenuación es la inversa de Godot con `unit_size` y `max_db` por voz; `3d_panning_strength=0.9` en `project.godot:28` [G].
- **Reverberación**: no es por volúmenes. `update_space()` (`world_audio.gd:168-186` [G]) mira la sala del oyente y lleva la reverb de Effects, Threat y Steps hacia uno de tres estados (normal 0,5/0,12/0,6; pasillo 0,86/0,24/0,42; suelo duro 0,42/0,2/0,25: tamaño/húmedo/amortiguación), a 0,8 y 0,3 por segundo; Steps al 30 % del húmedo.
- **Binaural de la criatura**: `update_ears()` reescribe cada tick las dos tomas del retardo de Creature y CreatureEcho: ITD 0,65 ms, sombra 18 dB, oído cercano +1,5 dB (`world_audio.gd:727-747` [F §3.6]).
- **Música**: una pista (`assets/audio/the_four_theme.mp3`) en bucle. **No hay música por compases**: el `.import` tiene `bpm=0` y ningún código lo lee [F §6.3]. `theme_mood.gd` lleva una tensión de 0 a 1 (sube 0,6/s, espera 5 a 15 s, vuelve en 10 s) que baja el volumen, cierra un paso bajo (700 Hz a 20 kHz) y estrecha el estéreo; activa los dos efectos de Music con `set_bus_effect_enabled` (`theme_mood.gd:112, 115` [G]). Volumen: `−24 + dB(gain × music_power) + duck` (`hotel_main.gd:1825` [F §6.2]).
- **Aura**: zumbido, respiración, chasquidos y latido (64 a 128 BPM, por temporizador) según la distancia por ruta a la criatura (`dread_aura.gd` [F §4.6]).
- **Cinta de muerte**: añade y quita efectos en Master (paso alto, paso bajo, ganancia) mientras dura (`game/app/death_tape.gd:532-547` [G]).
- **Archivos**: 202 (163 WAV, 37 OGG, 1 MP3, 1 M4A sin uso), 79 MB [F §7.1]. Los bucles se fijan por código, no en el archivo (`world_audio.gd:188-195` [F §7.3]). Tres sonidos se sintetizan en ejecución con `AudioStreamWAV.new()`: `hotel_locust.gd:476` y `game/ui/osd_style.gd:231, 247` [G].
- **Trozos de un archivo**: los gruñidos suenan con `voice.play(segment[0])` y un contador de duración (`hotel_locust.gd:526-530, 620` [G]).
- **Deslizadores**: `slider_db(v) = linear_to_db(max(2v, 0.0002))`; Steps sigue al de Effects (`settings_service.gd:428-436, 496-497` [F §2.1]).
- **Azar**: propio y sin semilla del mapa (`world_audio.gd:133` [F §10.4]); las voces de criatura viajan por red como índice de segmento y tono, no como audio [F §10.6].
- **Pruebas**: `tests/hotel/spatial_audio_test.gd`, `hotel_audio_test.gd`, `tests/office/office_audio_test.gd`, `lurker_mood_audio_test.gd`; tres van en reloj real y miden la energía del mezclador [F §11].

## 2. Cómo queda en Unreal

Idea: **se traslada la lógica, no se adopta el modelo de audio de Unreal**. Todo lo que decide cómo suena (ruta, ganancia, corte, bus, tensión, aura) sigue siendo código propio con las mismas cifras; Unreal pone el mezclador, los efectos y la panoramización. No hay MetaSounds, Sound Cues, Sound Classes, Sound Mixes, assets de atenuación ni Quartz. Los únicos assets binarios son los `USoundWave`, importados por guion.

### 2.1 En `FourCore` (C++ sin motor, se prueba en segundos)

| Cabecera | Origen | Contenido |
|---|---|---|
| `AudioRoute.h` | `world_audio.gd:439-521, 550-557` | `struct FAudioRoute { bool bAudible; FGdVec3 Position; double GainDb, CutoffHz, Distance; bool bEcho; FName Bus; }`; `FAudioRoute Route(const IAudioWorld&, FGdVec3 From, FGdVec3 Listener)`; `FVoiceMix Apply(const FAudioRoute&, double GainDb, EDryBus, bool bCreature, double Rear, …)` devuelve bus, dB, corte y paneo. `IAudioWorld`: `Occluded`, `WalkedRoute`, `PlantaOf`, `ShutDoorsOn` |
| `AudioEars.h` | `world_audio.gd:727-747` | `FEarTaps Ears(double Side)`: retardo y nivel de cada oído |
| `AudioSpace.h` | `world_audio.gd:168-186` | Los tres estados y su avance por tick |
| `ThemeMood.h` | `theme_mood.gd` | `Felt`, `Step`, `Gain`, `Drawn`, `MuffleHz` |
| `DreadAura.h` | `dread_aura.gd:126-274` | Intensidad, forma y niveles de cada capa; periodo del latido |
| `AudioTables.h` | las cuatro tablas generadas, `POOLS`, `GAIN`, `STEP_DB`, perfiles `locust.tres` y `lurker.tres` | `constexpr`, copiadas tal cual |
| `AudioMath.h` | `settings_service.gd:496` | `SliderDb`, `GodotInverseDb(dist, unit, maxDb)` y la curva del filtro de distancia de Godot |

### 2.2 En el módulo `TheFour`

| Clase | Base | Qué hace |
|---|---|---|
| `UFourAudioBuses` | `UObject` del subsistema | Crea los 12 submixes con `NewObject<USoundSubmix>` y los cuelga con `DynamicConnect` (`UE:/Source/Runtime/Engine/Classes/Sound/SoundSubmix.h:305` [M]); crea sus presets de efecto y los añade con `AddSubmixEffect` (`UE:/Source/Runtime/AudioMixer/Public/AudioMixerBlueprintLibrary.h:240` [M]). `USoundSubmix* Bus(EFourBus)`. Volumen por `SetSubmixOutputVolume` (`SoundSubmix.h:463` [M]) |
| `UFourWorldAudio` | `UWorldSubsystem` | Port de `world_audio.gd`: `PlayAt`, `PlayEverywhere`, `PlayLong`, `StopLong`, `DoorCue`, `HideCue`, `ApplyRoute`, `Duck`, `ShowCaption`, `Reset`, `Hush`. Lo llama el reloj fijo de 60 Hz del juego (`TickFixed(double Dt)`), no el tick variable. Implementa `IAudioWorld` con trazas y navegación |
| `UFourVoice` | envoltorio de `UAudioComponent` | Una voz: `SetBus(EFourBus)`, `SetDb`, `SetCutoffHz`, `SetPitch`, `PlayFrom(Start)`. Guarda `BaseGain`, `Emitter`, `Start` |
| `UFourDreadAura`, `UFourThemeMood` | `UObject` | Aplican al mezclador lo que calculan `DreadAura.h` y `ThemeMood.h` |
| `UFourCreatureVoice` | `UActorComponent` | Lo común de `hotel_locust.gd:415-620` y `lurker_voice.gd`: segmento, tono, ruta binaural; emite la llamada de red |
| `FFourEarsEffect` (solo si hace falta, R3) | `FSoundEffectSubmix` | Dos líneas de retardo fraccionario, una por oído |

Cómo se hace cada cosa con el motor:

- **Bus por voz**: en Unreal el submix base es del asset (`USoundBase::SoundSubmixObject`, `UE:/Source/Runtime/Engine/Classes/Sound/SoundBase.h:226-227` [M]), no de la instancia; no hay sobrescritura por componente [M, búsqueda en `AudioComponent.h` y `ActiveSound.h`]. Por eso todos los `USoundWave` se importan con `bEnableBaseSubmix=false` (`SoundBase.h:145` [M]) y cada voz se manda a **un** bus con `UAudioComponent::SetSubmixSend(Bus, 1)` (`UE:/Source/Runtime/Engine/Classes/Components/AudioComponent.h:644` [M]); cambiar de bus es poner un envío a 0 y otro a 1. Es lo primero que se prueba (A1, R1).
- **Volumen y distancia**: la atenuación del motor va apagada; `UFourVoice` calcula `GodotInverseDb` más la ganancia de ruta y lo aplica con `SetVolumeMultiplier` (`AudioComponent.h:626` [M]). Del motor solo se usa la panoramización, vía `AttenuationOverrides` (`AudioComponent.h:387` [M]) rellenado en código.
- **Filtro por voz**: `SetLowPassFilterEnabled` y `SetLowPassFilterFrequency` (`AudioComponent.h:702, 715` [M]).
- **Efectos de bus** (todos con `SetSettings` o setters en ejecución [M]):
  - reverb: `USubmixEffectReverbPreset` (`UE:/Source/Runtime/AudioMixer/Classes/SubmixEffects/AudioMixerSubmixEffectReverb.h:29-89, 159`);
  - limitador: `USubmixEffectDynamicsProcessorPreset` en modo `Limiter` (`AudioMixerSubmixEffectDynamicsProcessor.h:26-29, 345`);
  - EQ de Ducts: `USubmixEffectSubmixEQPreset` (`AudioMixerSubmixEffectEQ.h:23-51`);
  - pasos bajos de Ambience y Music: `USubmixEffectFilterPreset` (`UE:/Plugins/Runtime/Synthesis/Source/Synthesis/Classes/SubmixEffects/SubmixEffectFilter.h:42-85`);
  - ecos y oídos: `USubmixEffectTapDelayPreset`, con retardo, ganancia y paneo por toma y `SetTap` en ejecución (`SubmixEffectTapDelay.h:52-70, 183-207`);
  - ancho de la música: `USourceEffectMidSideSpreaderPreset` en una cadena creada en código y puesta en `UAudioComponent::SourceEffectChain` (`SourceEffectMidSideSpreader.h:31-43`; `AudioComponent.h:353`).
- **Cinta de muerte**: `AddMasterSubmixEffect` y `RemoveMasterSubmixEffect` (`AudioMixerBlueprintLibrary.h:228, 232` [M]).
- **Trozos de archivo**: `UAudioComponent::Play(float StartTime)` (`AudioComponent.h:517` [M]) y el mismo contador de duración.
- **Música**: un `UAudioComponent` 2D al bus Music con el tema en bucle; `UFourThemeMood` aplica volumen, corte y ancho. Otro para el menú.
- **Plugins del motor que hay que tener activos**: Synthesis (activo por defecto, sin marca de beta, `UE:/Plugins/Runtime/Synthesis/Synthesis.uplugin:13-15` [M]). Nada más.

### 2.3 Datos y assets

- `Tools/assets/audio.json`: una entrada por archivo (`src`, `dst`, `loop`, `compression`, `license`, `source`). `Tools/assets/import_audio.py` lo recorre con `unreal.AssetImportTask` automatizado, fija `bLooping` (`UE:/Source/Runtime/Engine/Classes/Sound/SoundWave.h:451` [M]), `bEnableBaseSubmix=false` y la compresión, y guarda en `Content/Gen/Audio/`. Se lanza con `ue.ps1` (pythonscript sin interfaz, `briefs/agentes.md` vía índice).
- Formatos que acepta la fábrica: wav, aif, aiff, ogg, flac, opus y mp3 (`UE:/Source/Editor/AudioEditor/Private/Factories/SoundFactory.cpp:152-160` [M]). El M4A no entra y no se usa.
- Un archivo que suena con y sin bucle (por ejemplo `intro/tv_static.wav`, `world_audio.gd:108` [F]) se importa dos veces (`X` y `X_Loop`): el bucle es del asset.
- Los tres sonidos sintetizados se vuelcan una vez desde Godot a WAV y entran como archivos normales.

## 3. Correspondencia pieza a pieza

| Godot | Unreal | Tipo |
|---|---|---|
| `default_bus_layout.tres` y `ensure_duct_bus()` | `UFourAudioBuses` (submixes dinámicos) | C++ |
| `AudioEffectReverb` (Effects, Threat, Steps, ecos, Ducts) | `USubmixEffectReverbPreset`; tabla de equivalencia de parámetros (A3) | C++ |
| `AudioEffectDelay` «EchoTaps» y «Ears» | `USubmixEffectTapDelayPreset` (o `FFourEarsEffect`) | C++ |
| `AudioEffectLowPassFilter` de bus | `USubmixEffectFilterPreset` | C++ |
| `AudioEffectStereoEnhance` | `USourceEffectMidSideSpreaderPreset` en la voz del tema | C++ |
| `AudioEffectHardLimiter` | `USubmixEffectDynamicsProcessorPreset` (Limiter, −0,5 dB, 120 ms) | C++ |
| `AudioEffectEQ6` | `USubmixEffectSubmixEQPreset` | C++ |
| Efectos de micro de la cinta | Tres presets añadidos al submix maestro | C++ |
| `AudioStreamPlayer3D` | `UFourVoice` sobre `UAudioComponent` espacializado | C++ |
| `AudioStreamPlayer` | `UAudioComponent` con `bAllowSpatialization=false` | C++ |
| `player.bus = X` | `SetSubmixSend` a un solo bus | C++ |
| `unit_size`, `max_db`, `max_distance` | `GodotInverseDb` en `FourCore` | C++ |
| `attenuation_filter_cutoff_hz` | `SetLowPassFilterFrequency` más la curva de Godot | C++ |
| `panning_strength` (0, 1,15, 1,4) × 0,9 | Paneo del motor; 0 = sin espacializar | C++, se calibra |
| `route_source`, `apply_route`, `behind`, `mask_db` | `AudioRoute.h` | `FourCore` |
| `walked_route` y rayos | `IAudioWorld` sobre navegación y trazas del mundo | C++ |
| `update_space` | `AudioSpace.h` y `SetSettings` de la reverb | C++ |
| `theme_mood.gd` | `ThemeMood.h` y `UFourThemeMood` | C++ |
| `dread_aura.gd` | `DreadAura.h` y `UFourDreadAura` | C++ |
| `creature_audio_profile.gd` y `.tres` | `struct FCreatureAudioProfile` `constexpr` | `FourCore` |
| Tablas `cue_timing`, `grunt_segments`, etc. | `AudioTables.h` | `FourCore` |
| `slider_db` y `settings_service` (audio) | `SliderDb` y `SetSubmixOutputVolume` | C++ |
| `loop_stream()` | `bLooping` en la importación | guion |
| `*.import` | `Tools/assets/audio.json` | datos |
| `claw_sound()` y los dos de `osd_style.gd` | WAV volcados una vez | archivo |
| `voice.play(start)` | `Play(StartTime)` | C++ |
| `finished.connect` | `OnAudioFinished` | C++ |
| `Time.get_ticks_msec` (5 usos) | Reloj real del juego, el mismo en todos | C++ |
| `tools/audio/*.py` | Se quedan en el repo de Godot; no se portan | — |
| `tools/audio/measure_*.gd`, `analyze_*.gd` | No se portan; sus tablas ya están generadas | — |
| Pruebas de audio | Automation sobre parámetros, más una de energía por bus (A12) | C++ |

## 4. Decisiones

**D1. Se conserva la propagación propia; no se usa la oclusión de Unreal ni Steam Audio.** La regla «el sonido sale por el vano, con rodeo y puertas» es gameplay (criterio 2) y sus pruebas existen. Descartado: la oclusión de `FSoundAttenuationSettings` (un rayo, sin ruta); Steam Audio: el del motor está obsoleto y remite al de Valve (`UE:/Plugins/Runtime/Steam/SteamAudio/SteamAudio.uplugin:6` [M]), y el de Valve sigue en 4.8.1, de febrero de 2026, anterior a 5.8 (API de versiones de GitHub, consultada hoy [W] https://api.github.com/repos/ValveSoftware/steam-audio/releases); habría que compilarlo como plugin del proyecto, alimentarlo con geometría generada en ejecución y sustituiría justo lo que hay que conservar. Tampoco Resonance Audio (Beta, de Google, `ResonanceAudio.uplugin:15` [M]).

**D2. Reverberación: el mismo sistema de tres estados por sala del oyente, sin volúmenes.** Es lo que hay hoy y no depende de la geometría. Descartado: Audio Gameplay Volumes (Beta, `UE:/Plugins/AudioGameplayVolume/AudioGameplayVolume.uplugin:14` [M]): exigiría un volumen por sala generada para dar lo que ya da una consulta a la sala. La mejora (D8) se monta encima, no en su lugar.

**D3. Submixes y efectos creados en C++ al arrancar, sin assets.** Criterio 4: cero binarios y todas las cifras en texto. Descartado: assets de submix creados por guion (binarios sin diff para 12 objetos triviales); queda como plan B si `DynamicConnect` falla (R2).

**D4. Sin Sound Classes, Sound Mixes ni AudioModulation.** Los deslizadores son cinco volúmenes de bus y el «duck» ya es código. Añadir otra capa de volumen duplicaría la que hay.

**D5. Sin MetaSounds.** Ningún sonido del juego necesita un grafo: son archivos con volumen, tono y filtro. Así se evita el problema de los assets binarios. Si algún día hiciera falta, existe la API de constructores (`UMetaSoundBuilderSubsystem::CreateSourceBuilder`, `UE:/Plugins/Runtime/Metasound/Source/MetasoundEngine/Public/MetasoundBuilderSubsystem.h:182` [M]) para generarlos desde C++.

**D6. Música: se traslada `theme_mood` tal cual; sin Quartz.** Hoy no hay compases que conservar (§1). El latido del aura y el de la intro siguen por temporizador en el reloj fijo. Quartz existe (`UAudioComponent::PlayQuantized`, `AudioComponent.h:521` [M]) y Harmonix es Experimental (`UE:/Plugins/Runtime/Harmonix/Harmonix.uplugin:16` [M]); solo tendrían sentido si el autor quiere música nueva por capas o compases (pregunta 1).

**D7. La atenuación y el filtro de distancia se calculan a mano con las fórmulas de Godot.** Así las cifras (`unit_size`, `max_db`, cortes) se copian sin traducir a curvas de Unreal. Descartado: assets `USoundAttenuation` con curvas aproximadas (binarios y sin garantía de igualdad).

**D8. Lo que mejora y lo que solo se traslada (pregunta d).** Casi todo es traslado: el audio ya es propio y Unreal no lo hace sonar mejor por sí solo. Mejoras reales, todas después del traslado y apagables:
1. Reverb de convolución con respuestas de sala reales (`USubmixEffectConvolutionReverbPreset`, `UE:/Plugins/Runtime/Synthesis/Source/Synthesis/Classes/SubmixEffects/SubmixEffectConvolutionReverb.h` [M, existe]) en lugar de la algorítmica para pasillo, sala y conducto: es lo que más acerca a «una grabación de la época».
2. Los tres estados de reverb pasan a depender del tamaño real de la sala (dato que el manifiesto ya tiene).
3. Más fuentes de ambiente localizadas (hoy solo los dos fluorescentes y las dos teles más cercanos, `world_audio.gd:751-798` [F]): ayuda contra «ambientes vacíos», pero cambia la mezcla (pregunta 2).
4. Herramientas: Audio Insights (`UE:/Plugins/AudioInsights` [M, existe]) para ver voces y buses en vivo.

**D9. Importación por guion desde un JSON, con el bucle como dato.** Descartado: importar a mano o por el MCP (no tiene herramientas de audio: `mcp_catalogo.md` sin entradas de audio y `diseno/metodo.md:146`).

**D10. Pruebas sobre parámetros, no sobre la señal.** Lo que se decide (audible o no, bus, dB, corte, posición) se prueba en `FourCore` sin motor. Solo una prueba de humo mide energía por bus con `StartEnvelopeFollowing` (`SoundSubmix.h:402` [M]). Descartado: portar las mediciones en reloj real, que ya son las frágiles en Godot (tres reintentos en `verify.ps1` [F §11.3]).

## 5. Prueba de concepto visual

**No entra nada de audio**: `diseno/poc.md:155` deja el sonido fuera. Lo único que conviene hacer a la vez, porque es barato y quita el riesgo mayor, es **A1** (una voz que cambia de bus por envíos), dentro del proyecto de la prueba y sin ocupar el editor más de una sesión corta.

## 6. Unidades de trabajo

∥ = puede ir en paralelo con las demás ∥ de su bloque (archivos disjuntos, sin motor). Las demás van en serie porque necesitan compilar o el editor.

| N.º | Unidad | Origen | Resultado | Prueba de aceptación |
|---|---|---|---|---|
| A1 | Enrutado por envíos | — | `UFourAudioBuses` mínimo (Master, Effects, EffectsEcho) y `UFourVoice` | Automation: una voz pasa de Effects a EffectsEcho; el seguidor de envolvente de cada bus sube y baja; con todos los envíos a 0 Master queda en silencio |
| A2 ∥ | Matemática de ruta | `world_audio.gd:424-562` | `AudioRoute.h`, `AudioMath.h` | `ue.ps1 core`: vectores sacados de `spatial_audio_test.gd` (directo, rodeo, puerta cerrada, otra planta, 42 y 52 m) dan los mismos dB y Hz |
| A2b ∥ | Oídos y espacio | `world_audio.gd:168-186, 727-747` | `AudioEars.h`, `AudioSpace.h` | Core: lado ±1 da 0,70 ms y −18 dB en el oído lejano; los tres estados convergen a sus cifras |
| A2c ∥ | Tensión de la música | `theme_mood.gd` | `ThemeMood.h` | Core: port de los casos de `lurker_mood_audio_test.gd` y `theme_checks` |
| A2d ∥ | Aura | `dread_aura.gd` | `DreadAura.h` | Core: intensidad y niveles a 30, 15 y 4 m; latido de 64 a 128 BPM |
| A2e ∥ | Tablas y perfiles | tablas generadas, `POOLS`, `.tres` | `AudioTables.h` | Core: mismos recuentos (10 segmentos de gruñido, 6 agresivos, 3 de 2 s o más) |
| A3 | Árbol completo de buses y efectos | `default_bus_layout.tres`, `world_audio.gd:527-547` | Los 12 submixes con sus efectos y la tabla Godot → Unreal de la reverb | Automation: 12 buses con su padre correcto; grabación de un clic por cada bus comparada con la de Godot (`tools/audio/measure_mix.gd`) dentro de ±2 dB y ±20 % de cola |
| A4 | Importación | `assets/audio/`, `*.import`, `world_audio.gd:188-195` | `audio.json`, `import_audio.py`, `Content/Gen/Audio/` | El guion importa los 201 archivos sin error; los de bucle tienen `bLooping`; ninguno tiene submix base |
| A5 | Voces de mundo | `world_audio.gd:206-421, 574-630` | `UFourWorldAudio`: `PlayAt`, `PlayEverywhere`, `PlayLong`, puertas, escondites, subtítulos | Automation: tope de 8 voces, descarte a más de 42 m, cue largo mudo y no parado, cierre lento cerca y lejos |
| A6 | Ambiente | `presentation_rig.gd:445-480`, `world_audio.gd:751-816` | Cama, ventilación, fluorescentes, teles | Automation: dos fuentes más cercanas, apagón las calla, nivel sigue a la luz |
| A7 | Reverb por sala y deslizadores | `world_audio.gd:168-186`, `settings_service.gd:428-436` | `UFourWorldAudio::UpdateSpace`, volúmenes de bus | Automation: pasillo, suelo duro y normal; 50 % = 0 dB, 100 % = +6,02 dB; Steps sigue a Effects |
| A8 | Aura y presencia | `dread_aura.gd`, `world_audio.gd:689-722` | `UFourDreadAura`, presencia | Port de los casos `aura` y `presence` de `office_audio_test.gd` |
| A9 | Voces de criatura y oídos | `hotel_locust.gd:415-620`, `lurker_voice.gd`, `world_audio.gd:727-747` | `UFourCreatureVoice`, oídos en Creature | Las tomas del retardo valen lo que da `AudioEars.h`; el segmento y el tono recibidos por red suenan igual en otra máquina |
| A10 | Música | `theme_mood.gd`, `presentation_rig.gd:456-488`, `hotel_main.gd:1819-1825` | `UFourThemeMood`, tema y menú | Con tensión 0,5 la música está fuera; vuelve en 10 s; quien lleva a la criatura conserva el tema |
| A11 | Cinta de muerte e intro | `death_tape.gd:532-549`, `intro_sequence.gd:400-461` | Efectos en el maestro; voces de la intro | Los tres efectos entran y salen sin dejar restos en el maestro |
| A12 | Humo de señal y calibración A/B | `tools/audio/measure_*.gd` | Una prueba de energía por bus y un guion que graba la misma escena en los dos motores | Diferencia de nivel por bus de ±2 dB en cinco escenas fijas |
| A13 | Mejoras (D8) | — | Convolución y reverb por tamaño, tras un interruptor | El autor compara con y sin |

Orden: A1; después A2 a A2e en paralelo mientras A3 y A4 van en serie; A5; A6, A7 y A8; A9 y A10; A11; A12; A13. Los pasos y sonidos del equipo son de `diseno/jugador.md` (J15) y usan `UFourVoice`.

## 7. Riesgos y cómo se detectan pronto

| N.º | Riesgo | Detección | Salida |
|---|---|---|---|
| R1 | Que el envío a submix no lleve el volumen, el filtro o el paneo de la voz, o que `bEnableBaseSubmix=false` no calle el maestro | A1, antes de nada | Un `USoundCue` transitorio por pareja archivo y bus, o duplicar el asset por bus en la importación |
| R2 | Submixes dinámicos con comportamiento distinto de los de asset (autodesactivado: `bAutoDisable`, `SoundSubmix.h:185` [M]) | A1 y A3 | Crear los 12 por guion como assets en `Content/Gen/` |
| R3 | El retardo de tomas no admite 0,05 a 0,7 ms o hace ruido al mover la toma cada tick (interpola en 400 ms por defecto, `SubmixEffectTapDelay.h:96` [M]) | A9: barrido de lado a 6 por segundo y escucha | `FFourEarsEffect` propio |
| R4 | La reverb de Unreal no tiene los parámetros de la de Godot (tamaño, amortiguación, spread) | A3: clic grabado en ambos | Tabla ajustada de oído y con medición; o convolución (D8) |
| R5 | El filtro de distancia de Godot (−24 dB) mal reproducido: todo suena más brillante u oscuro | A12 | Ajustar la curva en `AudioMath.h` |
| R6 | `Play(StartTime)` impreciso con audio comprimido en streaming: los gruñidos empiezan tarde | A9: medir el arranque | Compresión PCM o ADPCM para los archivos con segmentos, o trocearlos al importar |
| R7 | El WAV de 8 bits y 11025 Hz (`hotel/ambience.wav` [F §7.1]) o el MP3 no importan | A4 | Convertir a WAV de 16 bits en el guion |
| R8 | Paneo distinto (Godot 0,9 × 1,15 o 1,4) | A12 | Ajustar el paneo del motor o panoramizar a mano |
| R9 | Sin dispositivo de audio en pruebas sin ventana no hay señal que medir | A1 | Las pruebas de señal van con el editor con ventana; las demás no dependen de ello |
| R10 | Licencias: algún audio no apto para vender | A4: el guion rechaza entradas sin `license` apta | Sustituir; `docs/AUDIO.md:23` ya retiró dos por no comerciales [G] |
| R11 | Latencia o sincronía de pasos (1,05 fotogramas, `diseno/jugador.md:191`) | J15 | Cebar con `PrimeSoundForPlayback` (`AudioMixerBlueprintLibrary.h:360` [M]) |

## 8. Preguntas para el autor

1. ¿Quieres que la música pase a ser por capas o por compases en el port (música nueva), o se queda el tema único con la tensión de hoy? El diseño asume lo segundo.
2. ¿Aceptas más fuentes de ambiente por sala (más fluorescentes, ventilación, aparatos) para llenar los espacios, aunque cambie la mezcla que ya conoces?
3. ¿Quieres que el sonido lleve también carácter de cinta de 1987 (banda limitada, fluctuación) fuera de la cinta de muerte, o el sonido se queda limpio?

## 9. Qué conviene instalar o bajar

- **Nada obligatorio.** Todo lo usado viene en el motor (AudioMixer, Synthesis).
- Para D8.1: respuestas de impulso de salas con licencia CC0 (por ejemplo las de OpenAIR con esa licencia, https://www.openair.hosted.york.ac.uk/, revisando cada una: muchas son CC BY o BY-SA y las SA no valen). Sin cuenta.
- `ffmpeg` solo si R7 se cumple; `tools/audio/decode_media.ps1` ya existe en el repo de Godot [G, listado].
- No instalar: Steam Audio, Resonance, Wwise, FMOD (licencias y dependencias que el diseño no necesita).

## 10. Sin comprobar

- Todo lo que depende de ejecutar: que un submix creado con `NewObject` y `DynamicConnect` funcione como uno de asset; que `SetSubmixSend` lleve la señal ya con volumen, filtro y paneo; que `bEnableBaseSubmix=false` deje la voz muda sin envíos; que los presets creados en código acepten `SetSettings` antes de sonar.
- La fórmula exacta de la atenuación inversa y del filtro de distancia de Godot (cómo se combina `attenuation_filter_db` con la distancia): la recuerdo, no la he leído en el código de Godot.
- La equivalencia entre `pan_pullout` de Godot y `SpreadAmount`, y entre los parámetros de las dos reverb.
- Si la fábrica importa WAV de 8 bits, y qué compresión aplica por defecto el proyecto; la precisión de `Play(StartTime)` por códec.
- Nombres exactos en Python de las propiedades (`enable_base_submix`, `looping`) y que `AssetImportTask` importe audio sin ventana.
- Si `-nullrhi` deja el mezclador con dispositivo; solo vi el aviso de `-nosound` (`UE:/Source/Runtime/Engine/Private/AudioDeviceManager.cpp:795` [M]).
- Que Steam Audio 4.8.1 compile o cargue en 5.8 (no hace falta para este diseño).
- Las licencias archivo por archivo de `docs/ASSETS.md` y qué archivos suenan con y sin bucle a la vez (solo un ejemplo, de la ficha).
- De la ficha y sin recomprobar por mí: las cifras de `route_source`, del aura, de los perfiles y de `theme_mood`, los recuentos de archivos y el orden padre e hijo del procesado (el tema lee el aura del tick anterior). Cada unidad las lee del código al portar.
- No leídos: `kit_sounds.gd`, `remote_player.gd`, `lifts.gd`, `televisions.gd`, `phantom_passage.gd`, `executions.gd` ni el audio de `game/floors/`; sus llamadas a `world_audio` entran por la API de A5.
- Las respuestas de impulso de OpenAIR: no he abierto la página ni sus licencias.
