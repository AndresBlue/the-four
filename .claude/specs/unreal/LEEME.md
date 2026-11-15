# Investigación del port a Unreal: qué hay aquí y qué manda

**Manda `docs/PORT_UNREAL.md`.** Es el plan, ya pasado por tres críticos (15 de noviembre de 2026). Donde un documento de esta carpeta diga otra cosa, vale el plan: sus apartados 2.3 (contradicciones resueltas) y 6.2 (fases) recogen cada caso.

| Carpeta o archivo | Qué es | Quién lo escribió |
|---|---|---|
| `fichas/` | 19 fichas de hechos del repo de Godot, una por área | Haiku. Comprobarlas contra el código al usarlas |
| `briefs/` | 3 informes: estado de Unreal 5.8, trabajo con agentes, experiencias y assets | Fable |
| `indice.md` | Resúmenes de las fichas y los informes | Generado del diario del flujo |
| `diseno/` | 12 diseños por dominio, con sus unidades de trabajo | Fable, esfuerzo medio |
| `criticas/` | Objeciones de los tres críticos (motor, cobertura, prueba y método) | Opus |
| `mcp_catalogo.md` y `mcp_catalogo_vivo.json` | Catálogo real del servidor MCP del editor: 52 toolsets y 830 herramientas | Volcado en vivo |

## Correcciones que los diseños no llevan

El cierre corrigió el plan y no tocó los diseños. Estos puntos siguen mal en `diseno/`:

- **Caché de pieles** (`render.md`): falta `r.SkinCache.CompileShaders=True`. Sin él, las mallas con esqueleto no entran en el trazado y no dan sombra con MegaLights.
- **Plugin del MCP en el `.uproject`** (`metodo.md`, `plataforma.md`): tiene módulos Runtime y es NoRedist. Su entrada lleva `TargetAllowList` con `Editor`, igual que `PythonScriptPlugin`.
- **Niagara** (`render.md`, `criaturas.md` C14): sale del plan. Sus herramientas del MCP no se pueden llamar desde un guion; las motas y el polvo se hacen con instancias desde C++.
- **Vista de Lumen** (`metodo.md`, `poc.md`): se comprueba en el juego con `r.Lumen.Visualize`, no con el MCP.
- **Orden del paso fijo** (`criaturas.md:88`): el orden real es el del código de Godot (nivel, servicios, jugador, audio, puertas y armarios, director, criatura), como dice `aplicacion.md`.
- **Perfil de pruebas** (`metodo.md`, `aplicacion.md`): el argumento es `-FourProfile=` con `Profiles/auto/` forzado en ejecuciones desatendidas, no `-FourTestProfile`.
- **Módulos** (`mundo.md`, `jugador.md`, `criaturas.md`, `ui.md`): son cuatro (`FourCore`, `TheFour`, `TheFourRender`, `TheFourEditor`), con carpetas por dominio dentro de `TheFour`. `FourWorld`, `FourPlayer`, `FourCreatures`, `FourBots` y `FourUI` son carpetas, no módulos.
- **Unidades de `aplicacion.md`**: se citan como AP0 a AP24, para no chocar con las A de audio.

## Comprobado en la máquina

- Unreal 5.8.4 con código fuente en `C:\Program Files (x86)\UnrealEngine\UE_5.8`.
- Con el SDK de .NET Framework 4.8 y el compilador MSVC 14.50 añadidos a las Build Tools 2026, la plantilla `TP_Blank` compila con `Build.bat` en 78 s. Sin el SDK, UnrealBuildTool no arranca.
- El editor abre sin ventana (`-unattended -nullrhi`) en 10 a 30 s y su servidor MCP responde (`-ModelContextProtocolStartServer -ModelContextProtocolPort=<puerto>`).
- Plugin de Claude Code de Epic instalado: `unreal-engine-skills-for-claude-code@claude-plugins-official` 3.1.2.

Nada más de lo que dicen estos documentos sobre Unreal está ejecutado: rendimiento, memoria de vídeo, importación por guion y capturas sin ventana se miden en la prueba de concepto.
