> Manda docs/PORT_UNREAL.md donde este diseño diga otra cosa. Correcciones posteriores: .claude/specs/unreal/LEEME.md.

# Diseño del port: interfaz, menús, textos y entrada

15 de noviembre de 2026. Solo plan: no se ha ejecutado ni compilado nada.
Marcas: [G] leído hoy en el código de Godot. [F] dato de ficha (`fichas/ui.md`, `fichas/servicios.md`), sin repetir la lectura. [M] leído hoy en el motor 5.8.4 (`UE:` = `C:/Program Files (x86)/UnrealEngine/UE_5.8/Engine/`). [CAT] `mcp_catalogo.md`. [W] web.

## 1. Qué hay hoy en Godot

- **Todo se construye por código.** `game/ui/` son 14 `.gd` y 5 297 líneas [G, `wc`]; `hotel_ui.gd` (2 370) reconstruye cada pantalla en `menu(kind)` (`hotel_ui.gd:584-884` [F]). La única escena es `interface.tscn` (90 líneas): HUD con `Flash`, `Subtitle`, `InteractionHint`, `ExitProgress`, `Crosshair` y un `MenuOverlay` [F §2.1].
- **Tres capas** [F §2.2]: capa 4 (HUD, hoja, aviso de objetivo, marcas REW y SEÑAL PERDIDA), que queda grabada bajo el filtro de cinta de la capa 5; capa 6 (menús, carga, final, créditos, intro), fuera de la cinta.
- **Escala:** base 1280×720, `stretch/mode="canvas_items"`, `aspect="expand"` (`project.godot:32-38` [G]). Todas las medidas en píxeles de la ficha son a 720 de alto.
- **Estilo:** `osd_style.gd` (269) crea el `Theme`, la paleta (`INK`, `SOFT`, `FAINT`, `ALERT`, `AMBER`, `MUTED`, `VCR_BLUE`) y los tonos sintéticos [F §13]. La fuente `assets/fonts/vcr_osd_mono.ttf` no existe (no hay carpeta `assets/fonts` [G]): hoy se ve con la fuente monoespaciada del sistema.
- **Papeles:** `paper_sheet.gd` (546), `sheet_map.gd`, `hint_view.gd`, `hotel_form.gd`, `ruled_paper.gd`, `torn_letter.gd`, `handwork.gd` dibujan con `draw_*`, `Line2D` e `Image`, con desplazamiento sembrado por letra [F §5, §21.4].
- **Sombreadores de interfaz:** `signal_wash` (51 líneas), `tape_noise` (20), `typewriter_ink` (32) y, en 3D, `tv_screen` (101) [F §14].
- **Intro:** overlay de arranque de 8,45 s (`hotel_ui.gd:2281-2370`) y escena 3D de 39,6 s (`game/intro/`, 1 008 líneas); portada 3D (`game/title/title_scene.gd`, 165) [F §10-12].
- **Textos:** un solo idioma, español literal en el código; sin `tr()` ni tablas [F §16]. `docs/textos_juego.txt` cataloga 317 entradas con identificador (`[INTRO.04]`, `[ESC.01]`...) [G, recuento de líneas `CORRECCIÓN`] y recoge la regla: el juego no usa punto medio ni guion largo (`docs/textos_juego.txt:15-17` [G]).
- **Ajustes:** `game/services/settings_service.gd` (507). `DEFAULTS` (`:6`), `KEYS` (`:7`, 13 acciones), `PAD_KEYS` (`:19`), `PAD_RESERVED` Start, `UI_PAD` y `UI_STICK` para menús, `STICK_DEADZONE 0.15`, `WINDOW_MODES` (`:61`), revisiones `PAD_REVISION 2`, `AUDIO_CURVE 2`, `DISPLAY_REVISION 3` [G `:1-62`]. Pantalla de ajustes con 4 pestañas y unos 40 controles (`hotel_ui.gd:1530-1696` [F §4]). Confirmación de pantalla con cuenta atrás de 12 s [F].
- **Accesibilidad que ya existe:** subtítulos de sonidos, efectos reducidos, sobresaltos suaves, sangre, movimiento de cámara, vibración, invertir mirada, alternar correr y agacharse, reasignación de 13 acciones [F §4].
- **Pruebas que tocan la interfaz:** `intro_test.gd`, `scene_contract_test.gd`, `rules_test.gd`, `stages_test.gd:577-596`. Ninguna vigila textos ni aspecto [F].

## 2. Cómo queda en Unreal

### 2.1 Módulo y plugins

- Módulo `FourUI` (Runtime), en `Source/FourUI/`. Depende de `FourCore`, `UMG`, `Slate`, `SlateCore`, `EnhancedInput`. Si el director prefiere los cuatro módulos de `metodo.md` §2.2, es la carpeta `Source/TheFour/UI/` con las mismas clases.
- Plugins nuevos: ninguno. UMG y Enhanced Input vienen activos. CommonUI y MVVM no se activan (decisión D1).
- Assets binarios de este dominio: 3 materiales de dominio User Interface, 1 material de superficie para la tele, los iconos de logros (18 PNG) y los tonos. Todo lo demás es C++, `.ini`, `.csv` y `.ttf` sueltos.

### 2.2 Clases (C++)

| Clase | Base | Qué hace |
|---|---|---|
| `UFourUIRoot` | `UGameInstanceSubsystem` | Dueño de las dos capas. API que hoy da `hotel_ui.gd`: `Menu(FName Kind)`, `ShowSettings(FName Back)`, `ShowCharacters(FName Back)`, `ShowTape(int32 Line)`, `Flash(FText, float)`, `ShowBrief(...)`, `ShowTransit(...)`, `ShowRewind/HideRewind`, `LostSignal`, `ShowSkip`, `Hold(float)`, `ShowHint`, `ShowDocument`, `ShowDossier`, `ShowLock`, `PlayIntro`. Delegado `OnActionRequested(FName Id)` (hoy la señal `action_requested`). |
| `UFourMenuLayer` | `UUserWidget` nativo | Capa 6. Marco (`backdrop`, márgenes 96/110/90, columna de 520, lateral, esquinas OSD, pie, ruido) y `Clear()` más reconstrucción por pantalla. Se añade al viewport. |
| `UFourTapeLayer` | `UUserWidget` nativo | Capa 4. No se añade al viewport: se dibuja cada fotograma a `RT_TapeUI` con `FWidgetRenderer::DrawWidget` (`UE:Source/Runtime/UMG/Public/Slate/WidgetRenderer.h:28-75` [M]) y `M_PP_UIComposite` la pone bajo la cinta (contrato `render.md:91`, R16). Las marcas REW y SEÑAL PERDIDA van a `RT_TapeMarks`. |
| `FFourOSD` | espacio de funciones | Port de `osd_style.gd`: paleta, `Font(int32 Size)`, `TypeFont`, `HandFont`, estilos de botón, casilla, deslizador y pestañas (`FButtonStyle`, `FSliderStyle`... en C++), constructores `Entry`, `Action`, `Title`, `Label`, `Paragraph`, `Spacer`, `Choice`, `Options`, `Slider`, `Check`, `Field`, `Stamp`, `Cell`, `Meter`. |
| `UFourScreen` y una subclase por familia | `UObject` | `Build(UFourMenuLayer&)`. Familias: `Main`, `Session` (pausa, carga, transición, fin), `Settings`, `Multiplayer`, `Lobby`, `Rules`, `Records`, `TapeReport`, `Achievements`, `Archive`, `Credits`, `Characters`. |
| `UFourPaperWidget` y subclases | `UUserWidget` nativo | Papeles pintados en `NativePaint` (`UE:Source/Runtime/UMG/Public/Blueprint/UserWidget.h:1592` [M]) con `FSlateDrawElement::MakeText`, `MakeLines` y `MakeBox`. Subclases `Form`, `Ruled`, `Torn`, `Hint`, `Sheet`, `SheetMap`. `FFourHandwork` porta `handwork.gd` con el azar de `FourCore`. |
| `UFourHoldRing`, `UFourBootIntro`, `UFourLockPad` | `UUserWidget` nativo | Anillo de mantener; overlay de arranque; teclado de la puerta. |
| `FFourUITween` | struct | Interpolaciones por tiempo (fundidos, cuenta ascendente de 1,1 s, transición de 0,28 s) avanzadas en `NativeTick`. Sustituye a `create_tween`. Sin `UWidgetAnimation`. |
| `UFourUserSettings` | `UGameUserSettings` | Ajustes del juego (2.5). |
| `FFourText` | espacio de funciones | `Get(FName Id) -> FText`, `Format(FName Id, ...)`; lee las tablas de 2.4. |
| `AFourTitleScene`, `AFourIntroSequence`, `UFourTvBroadcast` | `AActor`, `AActor`, `UActorComponent` | Portada y escena de entrada en 3D, con la tabla de tiempos de `intro_sequence.gd:39-43`. Geometría, luces y criatura dependen de `mundo.md`, `render.md` y `criaturas.md`. |

Los `UUserWidget` son clases nativas sin Widget Blueprint: el motor crea el árbol cuando la clase no viene de un Blueprint (`UE:Source/Runtime/UMG/Private/UserWidget.cpp:151-163` [M]) y la clase lo rellena con `WidgetTree->ConstructWidget` y `UPanelWidget::AddChild`. Los controles son los de UMG (`UE:Source/Runtime/UMG/Public/Components/`: `TextBlock`, `Button`, `CheckBox`, `Slider`, `ComboBoxString`, `EditableTextBox`, `ScrollBox`, `WidgetSwitcher`, `ProgressBar`, `Image`, `Overlay`, `CanvasPanel`, `RetainerBox` [M, listado]).

### 2.3 Tipografías, escala y materiales

- **Fuentes como archivos `.ttf` en `Content/Fonts/`**, cargadas con `FCompositeFont(Name, Filename, Hinting, LoadingPolicy)` (`UE:Source/Runtime/SlateCore/Public/Fonts/CompositeFont.h:442` [M]) y `FSlateFontInfo(TSharedPtr<const FCompositeFont>, Size, ...)` (`SlateFontInfo.h:227` [M]). Sin asset `UFont`. La carpeta se declara en `DefaultGame.ini` como directorio que se copia siempre al empaquetar.
- Tres familias: OSD (monoespaciada de vídeo), máquina de escribir y mano. Candidatas en el apartado 9.
- **Escala:** `DefaultEngine.ini`, `[/Script/Engine.UserInterfaceSettings]`: `UIScaleRule` por lado corto y `UIScaleCurve` con 720 → 1,0, 1080 → 1,5, 2160 → 3,0 (`UE:Source/Runtime/Engine/Classes/Engine/UserInterfaceSettings.h:174, 189` [M]). Así los píxeles de la ficha se usan sin convertir.
- **Materiales de interfaz** (dominio `MD_UI`, `UE:Source/Runtime/Engine/Public/MaterialDomain.h:25` [M]): `M_UI_TapeNoise`, `M_UI_SignalWash`, `M_UI_TypewriterInk`. Cada uno es un nodo Custom que incluye su `.ush` de `Shaders/UI/` (`UMaterialExpressionCustom::IncludeFilePaths`, `UE:Source/Runtime/Engine/Public/Materials/MaterialExpressionCustom.h:97` [M]): el HLSL vive en texto y el `.uasset` es un envoltorio que crea un guion (`Tools/assets/ui_materials.py`) o `MaterialTools` del MCP [CAT:528].
- `signal_wash` y `typewriter_ink` necesitan la imagen del widget como textura: `URetainerBox` con `SetEffectMaterial` y `SetTextureParameter` (`UE:Source/Runtime/UMG/Public/Components/RetainerBox.h:98, 104` [M]). Sustituye a los `SubViewport` de `hotel_ui.gd:2068-2143`.
- **Tele de la intro:** `M_TVScreen` (superficie, sin luces) con los parámetros de `tv_screen.gdshader:11-32`; la imagen sale de un `USceneCaptureComponent2D` a 640×480 y las grietas de una `UTexture2D` transitoria escrita por el port de `crack_pattern.gd`.
- **Tonos:** `Tools/assets/ui_tones.py` genera los WAV con las frecuencias de `osd_style.gd:230-269` (`tick` 2 400 Hz 0,018 s; `confirm` 1 250 Hz 0,07 s; teclado 1 900, 190, 1 046,5 y 1 568 Hz [F §8.7-8.8]) y el guion de importación los trae. El enrutado lo fija el diseño de audio.

### 2.4 Textos e idiomas

- **Tablas de texto en CSV**, una por sección del catálogo: `Content/Text/Menu.csv`, `Ajustes.csv`, `Hud.csv`, `Papeles.csv`, `Documentos.csv`, `Creditos.csv`, `Red.csv`, `Reglas.csv`. Columnas `Key`, `SourceString`, `Comment`. Se registran con `LOCTABLE_FROMFILE_GAME(ID, NAMESPACE, FILEPATH)` (`UE:Source/Runtime/Core/Public/Internationalization/StringTableRegistry.h:117` [M]) y se leen con `FText::FromStringTable`.
- **Clave = identificador del catálogo** (`INTRO.04`, `ESC.01`, `AJ.14`...). El autor sigue corrigiendo sobre el mismo identificador. Los textos que hoy no están en el catálogo (encargos de sector, reglas, dificultades, documentos) reciben clave nueva con el mismo patrón.
- **Idioma nativo: español.** Otro idioma no se construye ahora; cuando se pida, `GatherText` recoge las tablas y exporta `.po` (commandlets en `UE:Source/Editor/UnrealEd/Classes/Commandlets/GatherText*.h` [M, listado]) con una configuración en `Config/Localization/Game.ini`. No cambia ni una clase.
- **Regla sin «·» ni «—»:** prueba `TheFour.UI.Textos.Caracteres`, que recorre todas las tablas y falla si aparece U+00B7 o U+2014, si queda un `%s` o `%d` sin convertir a `{0}`, o si hay claves repetidas. Segunda prueba `TheFour.UI.Textos.Glifos`: todo carácter de las tablas existe en su fuente (hoy se usan ▶ ◀ ■ ❚ ▸ ★ ↑ ↓ − « » y otros [F §16]).
- Las mayúsculas de `entry()` se aplican al mostrar (`FText::ToUpper`), como hoy (`hotel_ui.gd:513` [F]).

### 2.5 Ajustes, entrada, mando y accesibilidad

- `UFourUserSettings` se declara en `DefaultEngine.ini`, `[/Script/Engine.Engine]`, `GameUserSettingsClassName` (`UE:Config/BaseEngine.ini:141` [M]). Sus `UPROPERTY(config)` llevan las claves de `DEFAULTS` con el mismo nombre y valor por defecto; se guardan en `GameUserSettings.ini` (texto).
- Lo que el motor ya hace (`UE:Source/Runtime/Engine/Classes/GameFramework/GameUserSettings.h` [M]): `SetFullscreenMode` (`:83`), `SetScreenResolution` (`:71`), `SetVSyncEnabled` (`:115`), `SetFrameRateLimit` (`:167`), `SetResolutionScaleNormalized` (`:196`), `ConfirmVideoMode` y `RevertVideoMode` (`:147, 151`), `ApplySettings` (`:49`). La cuenta atrás de 12 s es propia y llama a esos dos.
- Lo que es del juego: `Sanitize()` con los límites de `settings_service.gd:180-199`, `FirstRun()`, volúmenes con la curva `linear_to_db(max(v*2, 0.0002))` (`:496-497` [F]), efectos de cinta (`vhs`, `grain`, `chromatic`, `scanlines`), `bob`, `osd`, `reduced`, `startle_soft`, `gore`, `subtitles`, sensibilidades. Las revisiones (`PAD_REVISION`...) desaparecen: el archivo es nuevo; queda un solo `SettingsRevision`.
- **Las pestañas IMAGEN y GRÁFICOS cambian de contenido**: escalador, suavizado, presets y efectos pesados los fija `render.md`. La opción «Renderizador» desaparece (no hay modo Compatibilidad). La pantalla se construye desde una tabla `FFourSettingRow {Key, LabelId, Kind, Min, Max, Step, OptionIds, EnabledIf}` para que cambiar la lista no toque la pantalla.
- **Reasignación:** las teclas viven en `UFourUserSettings` como `TMap<FName, FKey> Keys` y `PadKeys`, y las aplica `UFourInputSubsystem::Bind` y `BindPad` (`diseno/jugador.md:45`, D9). La captura de tecla se hace en `NativeOnPreviewKeyDown` (`UserWidget.h:1608` [M]) con las reglas de `hotel_ui.gd:2250-2277`: Esc cancela, B cancela en mando, Esc, F9 y F11 reservadas, Start reservado, aviso «TECLA RESERVADA O EN USO».
- **Mando en menús:** Slate ya navega con cruceta y stick izquierdo (`bAnalogNavigation`, umbral 0,5; `UE:Source/Runtime/Slate/Private/Framework/Application/NavigationConfig.cpp:9-29` [M]), lo que sustituye a `UI_PAD` y `UI_STICK`. El orden explícito de `chain_settings()` (`hotel_ui.gd:1772-1816`) se porta con `SetNavigationRuleExplicit` solo donde el orden automático falle. Propio: B vuelve, LB y RB cambian de pestaña, Q y E también fuera de Ajustes, stick derecho desplaza a 900 px/s.
- **Nombres de botones:** tabla `PAD_NAMES` portada tal cual, en texto (A, B, X, Y...). Sin iconos.
- **Vibración:** `APlayerController::PlayDynamicForceFeedback` o efecto (`UE:Source/Runtime/Engine/Classes/GameFramework/PlayerController.h:1247-1255` [M]), con el ajuste `rumble`. Lo dispara el dominio del jugador.
- **Accesibilidad:** se porta lo que hay (apartado 1). No se añade nada nuevo sin que el autor lo pida (pregunta 4).

### 2.6 Cómo construyen y revisan los agentes sin trabajo manual

1. Escriben C++ y CSV. `ue.ps1 build` (`metodo.md` §2.3).
2. Pruebas de Automation `TheFour.UI.*` con `-nullrhi`: crean la pantalla, recorren el `WidgetTree` y comprueban textos, número de filas, foco inicial, orden de navegación y acciones emitidas.
3. Capturas: `UFourCaptureSubsystem` (`metodo.md:70`) admite tomas de interfaz (`"screen": "settings"`, `"tab": 2`) y deja el PNG en disco; el revisor lo compara con la captura de Godot de la misma pantalla.
4. El editor solo hace falta para crear los 4 materiales y traer iconos y tonos (una unidad, un operador).

## 3. Tabla de correspondencia

| Godot | Unreal | Dónde |
|---|---|---|
| `interface.tscn` capa 4 (HUD) | `UFourTapeLayer` dibujada a `RT_TapeUI` | C++ |
| `marks_view` (SubViewport de marcas) | `RT_TapeMarks`, mismo `FWidgetRenderer` | C++ |
| Capa 6 `Outside` y `MenuOverlay` | `UFourMenuLayer` en el viewport, por encima del posprocesado | C++ |
| `build_frame()`, `clear()`, `transition(0.35)` | `UFourMenuLayer::BuildFrame`, `Clear`, `Transition` | C++ |
| `osd_style.gd` (`Theme`, paleta, figuras) | `FFourOSD` | C++ |
| `main`, `pause`, `loading`, `transition` | `UFourScreen_Main`, `_Session` | C++ y `Menu.csv` |
| `won`, `failed`, `online_won`, `online_failed`, `tape` | `UFourScreen_TapeReport` (port de `tape_report.gd`) | C++ |
| `records`, `achievements` | `UFourScreen_Records`, `_Achievements` | C++; iconos importados |
| `archive`, `show_dossier`, `show_document` | `UFourScreen_Archive` y `UFourPaper_*` | C++ y `Documentos.csv` |
| `multiplayer`, `mp_steam`, `mp_ip`, `host_ip`, `join`, `join_steam`, `steam_invite`, `steam_wait` | `UFourScreen_Multiplayer` (un `Build` por id) | C++; datos del dominio de red |
| `lobby`, `difficulty`, `rules`, `online_pause` | `UFourScreen_Lobby`, `_Rules` | C++ |
| `credits` | `UFourScreen_Credits` desde `Creditos.csv` | datos |
| `show_settings` | `UFourScreen_Settings` desde `FFourSettingRow` | C++ y tabla |
| `show_characters` | `UFourScreen_Characters` | C++; vista 3D del dominio del jugador |
| `show_lock` | `UFourLockPad` | C++ |
| `show_transit`, `show_brief`, `show_rewind`, `lost_signal`, `show_skip`, `flash` | Métodos de `UFourTapeLayer` | C++ |
| `hold_ring.gd` | `UFourHoldRing` (`NativePaint`) | C++ |
| `paper_sheet.gd`, `sheet_map.gd` | `UFourPaper_Sheet`, `_SheetMap` más un receptor de ratón invisible en el viewport | C++ |
| `hint_view`, `hotel_form`, `ruled_paper`, `torn_letter`, `handwork` | `UFourPaper_Hint`, `_Form`, `_Ruled`, `_Torn`, `FFourHandwork` | C++ |
| `signal_wash.gdshader` | `M_UI_SignalWash` en `URetainerBox` | `.ush` y asset |
| `tape_noise.gdshader` | `M_UI_TapeNoise` en un `UImage` | `.ush` y asset |
| `typewriter_ink.gdshader` | `M_UI_TypewriterInk` en `URetainerBox` | `.ush` y asset |
| `tv_screen.gdshader`, `tv_broadcast.gd`, `crack_pattern.gd` | `M_TVScreen`, `UFourTvBroadcast` | `.ush`, asset y C++ |
| `play_intro` (8,45 s) | `UFourBootIntro` con la tabla de `hotel_ui.gd:2342-2362` | C++ |
| `intro_sequence.gd` (39,6 s) | `AFourIntroSequence` | C++ |
| `title_scene.gd` | `AFourTitleScene` | C++ |
| `SystemFont`, `FontVariation` | `.ttf` en `Content/Fonts/` y `FCompositeFont` | archivos |
| Literales en español | `Content/Text/*.csv` y `FFourText` | datos |
| `settings_service.gd` | `UFourUserSettings` | C++ e `.ini` |
| `InputMap`, `KEYS`, `PAD_KEYS` | `UFourInputSubsystem` (jugador) con los mapas de `UFourUserSettings` | C++ |
| `ui_accept`, `ui_cancel`, `focus_neighbor_*` | Navegación de Slate y `SetNavigationRuleExplicit` | motor y C++ |
| `AudioStreamWAV` sintetizado | WAV generados por guion | guion y asset |
| `process_mode = ALWAYS` | Los widgets siguen activos en pausa; en línea no hay pausa real | motor |

## 4. Decisiones

**D1. UMG con clases nativas en C++, sin Widget Blueprints.** Es la traducción directa de lo que hay (pantallas construidas por código) y deja toda la interfaz en texto: se revisa por diff, se prueba sin editor y varias unidades van en paralelo. Descartado:
- *Widget Blueprints creados por el MCP con base en C++.* `UMGToolSet` existe y sirve (23 herramientas: `CreateWidgetBlueprint(FolderPath, AssetName, ParentClass)`, `AddWidget`, `MoveWidget`, `CompileWidgetBlueprint`, `BindToEventProperty` [CAT:342-367; `UE:Plugins/Experimental/Toolsets/UMGToolSet/Source/UMGToolSet/Private/UMGToolSet.h:287, 300` [M]]). Pero cada pantalla sería un binario sin diff, pediría el único editor de la máquina y dejaría fuera las pantallas que se reconstruyen según los datos (sala, records, ajustes). Queda como recurso si alguna pieza resulta inviable en C++.
- *Slate puro.* También es texto, pero pierde `URetainerBox`, la reflexión que usan las pruebas y los controles de UMG ya hechos. Slate se usa solo dentro de `NativePaint`.
- *CommonUI.* No es beta, pero viene apagado (`UE:Plugins/Runtime/CommonUI/CommonUI.uplugin:13-15` [M]) y su valor (pilas de pantallas activables, estilos, iconos por plataforma) se apoya en assets de estilo y de datos. El juego tiene una sola pantalla de menú cada vez y ya resuelve foco y vuelta atrás. Se reconsidera solo si hay port a consola.
- *MVVM.* Beta (`UE:Plugins/Runtime/ModelViewViewModel/ModelViewViewModel.uplugin:13` [M]) y fuera de `AllToolsets`. No aporta nada a pantallas que se reconstruyen enteras.

**D2. La revisión es por pruebas y capturas, no por `SlateInspectorToolset`.** Ese toolset es de editor y experimental (`UE:Plugins/Experimental/Toolsets/SlateInspectorToolset/SlateInspectorToolset.uplugin:15-27` [M]), automatiza la interfaz al estilo Playwright (14 herramientas [CAT:318-334]) y `metodo.md:150` lo deja bloqueado por seguridad. No hace falta: las pruebas recorren el árbol de widgets y las capturas van a disco.

**D3. La capa grabada en la cinta se dibuja a textura; los menús van encima.** Respeta el contrato de `render.md:91, 142`. Descartado: materiales de posprocesado que lean la interfaz ya compuesta (sin vía comprobada) y renunciar a que el OSD quede bajo la cinta (cambia el aspecto actual).

**D4. Fuentes como archivos, no como assets.** Cero binarios y cambio de fuente editando una ruta. Descartado: importar `UFont` por guion (queda como plan B si la carga desde archivo falla empaquetado, riesgo 3).

**D5. Textos en CSV con las claves del catálogo; español nativo; `.po` solo cuando haya segundo idioma.** Descartado: `NSLOCTEXT` en el código (el autor no podría corregir sin tocar C++), `UStringTable` como asset (binario; `StringTableTools` del MCP existe [CAT:659-669] pero no hace falta) y montar ya la cadena de `.po` (nadie la ha pedido).

**D6. `UFourUserSettings` hereda de `UGameUserSettings`; las teclas no usan `UEnhancedInputUserSettings`.** El motor ya resuelve ventana, resolución, sincronización, límite de FPS y confirmar o revertir. `UEnhancedInputUserSettings` es un `USaveGame` (`UE:Plugins/EnhancedInput/Source/EnhancedInput/Public/UserSettings/EnhancedInputUserSettings.h:516` [M]) pensado para acciones en assets; aquí las acciones se crean en C++ (`jugador.md` D9) y un mapa en el `.ini` basta.

**D7. Papeles con `NativePaint`, no con texturas pintadas ni widgets por letra.** Reproduce el desplazamiento por tecla y el lápiz con las mismas coordenadas y semillas. Descartado: un `UTextBlock` por carácter (miles de widgets) y dibujar a `UCanvasRenderTarget2D` (otra API para lo mismo).

**D8. No se migran los ajustes de Godot.** El perfil de Unreal nace limpio. Records, descubrimientos y partida guardada son del dominio de servicios.

**D9. Intro, portada y tele en C++ con tabla de tiempos, sin Sequencer.** Hoy son código con tiempos fijos y pruebas (`intro_test.gd`). Un Level Sequence sería un binario que solo se edita en el editor.

## 5. Prueba de concepto visual

- **No entra nada de este dominio.** `poc.md:155` deja fuera interfaz y OSD, y la interfaz no decide si el port mejora las visuales.
- **Única excepción recomendable, si sobra una hora:** la unidad U1 reducida (un `UUserWidget` nativo con un texto en la fuente desde archivo y una captura). Valida D1 y D4 antes de partir el resto.
- El contrato de `RT_TapeUI` con `M_PP_UIComposite` se prueba en R16 de `render.md`, no en la prueba de concepto.

## 6. Unidades de trabajo del port completo

`∥` = puede ir en paralelo con las demás marcadas del mismo bloque (archivos disjuntos, sin editor). Las pruebas se nombran `TheFour.UI.<Caso>`.

| N.º | Unidad | Origen | Resultado | Prueba de aceptación |
|---|---|---|---|---|
| U1 | Esqueleto | `osd_style.gd`, `hotel_ui.gd:383-581`, `interface.tscn` | Módulo `FourUI`, `UFourUIRoot`, `UFourMenuLayer`, `FFourOSD`, escala 720, fuentes | `UI.Humo`: el menú principal muestra título y opciones; captura a 1280×720 y a 2560×1440 con la misma composición que la de Godot |
| U2 ∥ | Tablas de texto | `docs/textos_juego.txt`, literales de `game/ui`, `game/intro`, `game/floors`, `game/app` | `Content/Text/*.csv`, `FFourText` | `UI.Textos.Caracteres` y `UI.Textos.Glifos` en verde; 317 claves del catálogo presentes |
| U3 ∥ | Ajustes (servicio) | `settings_service.gd` | `UFourUserSettings`, `FFourSettingRow` | Casos de ajustes de `scene_contract_test.gd` y `rules_test.gd` portados: valores por defecto, límites, confirmar y revertir a los 12 s |
| U4 | Materiales, iconos y tonos (operador del editor, en serie) | 4 `.gdshader`, `assets/ui/achievements/`, `osd_style.gd:230-269` | 4 `.ush`, 4 materiales, 18 texturas, WAV | Prueba con render: cada material compila; captura de `tape_noise` a 0, 0,35 y 1 |
| U5 ∥ | Menús de sesión | `hotel_ui.gd:594-642, 866-918, 1917-1980` | `Main`, `Session`, `Credits`, dificultad, personaje | Cada id de `menu()` construye; cada opción emite su `OnActionRequested`; capturas |
| U6 | Pantalla de ajustes y reasignación (tras U3 y J7 de `jugador.md`) | `hotel_ui.gd:1530-1910, 2250-2277` | `UFourScreen_Settings` | Reasignar una tecla y un botón, tecla reservada rechazada, restaurar controles; captura de las 4 pestañas |
| U7 | HUD y capa de cinta (tras U1 y U4; con R16) | `hotel_ui.gd:1984-2239`, `hold_ring.gd` | `UFourTapeLayer`, `UFourHoldRing`, `RT_TapeUI`, `RT_TapeMarks` | El aviso de objetivo entra en 0,45 s y sale en 1,5 s; «REC» muestra grano y el menú de pausa no (misma prueba que R16) |
| U8 ∥ | Papeles | `handwork.gd`, `hotel_form.gd`, `ruled_paper.gd`, `torn_letter.gd`, `hint_view.gd`, `hotel_ui.gd:1186-1360` | `UFourPaper_*`, `FFourHandwork` | Para una semilla fija, las posiciones de las letras coinciden con las de Godot (tabla dorada); captura de cada papel junto a la de Godot |
| U9 | Hoja compartida y plano (tras U8 y el dominio de red) | `paper_sheet.gd`, `sheet_map.gd` | `UFourPaper_Sheet`, `_SheetMap`, receptor de ratón y de mando | Un trazo de 200 puntos se envía en trozos de 96 y se dibuja igual en otro cliente; tope de 3 000 operaciones |
| U10 ∥ | Parte de la cinta, records y logros (datos de servicios) | `tape_report.gd`, `records_board.gd`, `achievements_board.gd` | 3 pantallas | Con un parte de ejemplo, las cinco pestañas muestran las mismas cifras que Godot; caso de `stages_test.gd:577-596` |
| U11 | Multijugador, sala y reglas (tras el dominio de red) | `hotel_ui.gd:694-863, 960-1064`, `rules_screen.gd` | `Multiplayer`, `Lobby`, `Rules` | Casos de interfaz de `rules_test.gd`; captura de la sala con 4 asientos |
| U12 ∥ | Teclado de la puerta | `hotel_ui.gd:1366-1407` | `UFourLockPad` | Código correcto e incorrecto con teclado y con mando; tonos correctos |
| U13 ∥ | Intro de arranque | `hotel_ui.gd:2281-2370` | `UFourBootIntro` | `intro_test.gd` portado: dura 8,45 s, una tecla la salta, el ratón no |
| U14 | Portada y escena de entrada 3D (tras mundo, render y criaturas) | `game/title/`, `game/intro/` | `AFourTitleScene`, `AFourIntroSequence`, `UFourTvBroadcast`, `M_TVScreen` | Golpes en 26,4, 28,0, 29,5 y 32,95 s; salto con la tecla mantenida 0,8 s; capturas de 5 momentos |
| U15 | Mando en toda la interfaz (tras U5 a U12) | `hotel_ui.gd:1765-1816, 2241-2277`, `settings_service.gd:19-48, 256-283` | Navegación, pestañas, desplazamiento, nombres | Prueba que recorre cada pantalla solo con cruceta, A y B y llega a todas las opciones |
| U16 | Segundo idioma (solo si el autor lo pide) | U2 | `Config/Localization/Game.ini`, `.po` | Cambiar de cultura cambia el menú principal |

Orden: U1; después U2, U3, U5, U8, U10, U12 y U13 en paralelo; U4 cuando el editor esté libre; U6, U7, U9, U11; U14; U15.

## 7. Riesgos y cómo se detectan pronto

1. **Un `UUserWidget` nativo sin Blueprint no se construye como se espera** (momento exacto de rellenar el árbol, foco). Se detecta en U1, primer día. Plan B: `RebuildWidget` (`UserWidget.h:1576` [M]) devolviendo Slate, o Widget Blueprints por MCP.
2. **`FWidgetRenderer` cada fotograma**: coste, gamma o alfa distintos de los del viewport. Se detecta en U7 con una captura del HUD sobre gris medio y la medida de tiempo de R16.
3. **Fuentes desde archivo en el juego empaquetado** (ruta dentro del `.pak`, política `LazyLoad`, `CompositeFont.h:42-46` [M]). Se detecta en la primera ejecución de `ue.ps1 package` (M16). Plan B: `UFont` importado por guion.
4. **Glifos que faltan en la fuente elegida** (▶ ❚ ▸ ★). Lo detecta `UI.Textos.Glifos` en U2.
5. **Navegación automática de Slate distinta del orden de Godot** en ajustes y sala. Lo detecta U15; se corrige con reglas explícitas.
6. **Familia del mando** (Sony, Nintendo por fabricante USB, `settings_service.gd:265-283`): en Windows el motor puede no distinguirla. Lo detecta U15 con un mando real del autor.
7. **Perfil de pruebas:** hoy `--test-profile` aparta los archivos. Las pruebas de U3 no deben escribir el `GameUserSettings.ini` real; hay que fijar la vía con `metodo.md` antes de U3.
8. **Textos formateados:** `%s` y `%d` pasan a `{0}`; un olvido se ve en pantalla. Lo detecta `UI.Textos.Caracteres`.
9. **Licencias a la vista en créditos:** The Locust (CC BY-NC-ND) y Realistic Female (CC BY-SA) siguen bloqueando la venta [F §21.6; `indice.md:79`]; la portada usa `locust.glb`. No es de este dominio, pero U14 depende de que se resuelva.

## 8. Preguntas para el autor

1. **Fuente del OSD.** El juego apunta a «VCR OSD Mono», que nunca estuvo en el repositorio y cuya licencia no está comprobada. ¿Vale una libre parecida (VT323 o Share Tech Mono, licencia OFL) o prefieres aportar tú una con licencia de venta?
2. **Segundo idioma.** ¿El juego saldrá también en inglés? Si sí, U16 entra en el plan y alguien tiene que traducir 317 entradas más documentos.
3. **Textos pendientes.** ¿Aplicamos al portar las correcciones que tengas escritas en `docs/textos_juego.txt`, o se porta el texto actual tal cual?
4. **Accesibilidad nueva.** Unreal da casi gratis un filtro para daltonismo (`UE:Source/Runtime/UMG/Public/Blueprint/WidgetBlueprintLibrary.h:344` [M]) y una escala de interfaz (`UserInterfaceSettings.h:168` [M]). ¿Los añadimos a Ajustes o se deja lo que hay?

## 9. Qué conviene bajar o instalar

| Qué | Fuente | Licencia | Nota |
|---|---|---|---|
| VT323 (candidata OSD) | `github.com/google/fonts`, carpeta `ofl/vt323` | OFL [W, `METADATA.pb` leído hoy] | Sin cuenta |
| Share Tech Mono (candidata OSD) | `ofl/sharetechmono` | OFL [W] | Sin cuenta |
| Courier Prime (máquina de escribir) | `ofl/courierprime` | OFL [W] | Sustituye a «Courier New» del sistema |
| Reenie Beanie (candidata para letra a mano) | `ofl/reeniebeanie` | OFL [W] | Hoy se usa la fuente de respaldo de Godot inclinada |
| Plugins o herramientas | ninguno | | UMG, Slate, Enhanced Input y los toolsets ya vienen con 5.8.4 |

La OFL permite incluir la fuente en un juego que se vende; no es NC, ND ni SA. No se ha descargado nada.

## 10. Sin comprobar

- Nada se ha compilado ni ejecutado: el punto exacto en que una clase nativa rellena su `WidgetTree`, el foco inicial y la reconstrucción en caliente quedan para U1.
- Que `FWidgetRenderer` dibuje widgets UMG fuera del viewport cada fotograma con coste bajo y con alfa correcto para `M_PP_UIComposite`.
- Que `FCompositeFont` desde archivo funcione dentro de un `.pak` y el nombre exacto del ajuste de empaquetado que copia `Content/Fonts/` y `Content/Text/`.
- Que un nodo Custom con `IncludeFilePaths` compile en dominio User Interface y que el directorio de sombreadores del proyecto esté mapeado como espera `render.md`.
- El formato exacto del CSV de tablas de texto (columnas y escapes) y que `LOCTABLE_FROMFILE_GAME` lo cargue en juego empaquetado; la configuración de `GatherText` para tablas en CSV.
- Si `SlateInspectorToolset` ve los widgets del juego en PIE (no se leyó su código, solo el `.uplugin`); si `UMGToolSet` fija propiedades por sí mismo o depende de `ObjectTools`.
- La cobertura de glifos de VT323, Share Tech Mono, Courier Prime y Reenie Beanie; la licencia real de «VCR OSD Mono».
- Cómo distingue Unreal en Windows un mando de Sony o Nintendo, y si Steam Input cambia eso.
- La vía para que las pruebas no toquen el `GameUserSettings.ini` real.
- El comportamiento de `UIScaleCurve` con ventana más alta que ancha frente a `aspect="expand"` de Godot.
- De las fichas no se releyó en el código: los números de línea de `hotel_ui.gd`, los tiempos de las intros, los tamaños de los papeles y los detalles de la hoja compartida. Sí se comprobaron hoy: `settings_service.gd:1-62`, `project.godot:28-38`, la ausencia de `assets/fonts`, el recuento de `game/ui` y el formato y recuento del catálogo de textos.
- La lista final de ajustes de imagen y gráficos (depende de `render.md`), y el reparto definitivo de módulos (`metodo.md` nombra cuatro; `jugador.md` usa `FourPlayer` y `FourWorld`).
