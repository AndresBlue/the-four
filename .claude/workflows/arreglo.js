export const meta = {
  name: 'arreglo',
  description: 'Ronda de arreglo tras un frente en rojo: un revisor diagnostica cada fallo y da el cambio exacto, la batería lo aplica, el revisor lo revisa y se corre verify; hasta dos rondas',
  whenToUse: 'Cuando un frente acaba en rojo y los fallos piden diagnóstico antes de arreglarlos',
  phases: [
    { title: 'Diagnóstico', detail: 'Opus 5.5 high encuentra la causa y el arreglo exacto de cada fallo (Godot en serie)', model: 'opus' },
    { title: 'Arreglo', detail: 'Haiku 5.5 xhigh aplica los arreglos y corre sus pruebas en serie', model: 'haiku' },
    { title: 'Revisión', detail: 'Opus 5.5 high lee el diff y repite las pruebas', model: 'opus' },
    { title: 'Verify', detail: 'Haiku 5.5 xhigh corre tools/verify.ps1, solo', model: 'haiku' },
  ],
}

// args: { contexto: 'qué área, qué cambios hay sin commit, reglas que importan', fallos: 'los fallos de verify con sus logs y lo que se sabe' }
const A = args
const R = { model: 'opus', effort: 'high' }
const W = { model: 'haiku', effort: 'xhigh' }
const RULES = 'Reglas: Godot siempre con --test-profile y después git restore default_bus_layout.tres assets/audio/the_four_theme.mp3.import; un solo Godot a la vez; el hotel no cambia ni un byte; no hagas commit. Orden de Godot: "D:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe" --headless --path . --script res://<script>.gd --log-file <archivo> -- --automation --test-profile --silent'
const CTX = `Proyecto E:/Projects/The Four (Godot 4, GDScript).\n${A.contexto}\n${RULES}`
const FIX = { type: 'object', properties: { arreglos: { type: 'array', items: { type: 'object', properties: {
  fallo: { type: 'string' }, causa: { type: 'string' }, archivo: { type: 'string' }, cambio: { type: 'string', description: 'el cambio exacto: función, fragmento literal de ahora y fragmento literal nuevo' }, prueba: { type: 'string' } },
  required: ['fallo', 'causa', 'archivo', 'cambio', 'prueba'] } }, al_director: { type: 'array', items: { type: 'string' } } }, required: ['arreglos', 'al_director'] }
const VER = { type: 'object', properties: { verde: { type: 'boolean' }, lineas: { type: 'array', items: { type: 'string' } }, fallos: { type: 'array', items: { type: 'object', properties: { nombre: { type: 'string' }, causa: { type: 'string' } }, required: ['nombre', 'causa'] } } }, required: ['verde', 'lineas', 'fallos'] }
const OK = { type: 'object', properties: { bien: { type: 'boolean' }, correcciones: { type: 'array', items: { type: 'string' } } }, required: ['bien', 'correcciones'] }

let fallos = A.fallos
let last = null
for (let round = 1; round <= 2; round++) {
  phase('Diagnóstico')
  const dx = await agent(`${CTX}\n\nEres el revisor (Opus, esfuerzo high). No lanzas agentes ni haces commit; puedes ejecutar Godot para sondear, de uno en uno. Encuentra la CAUSA de cada fallo y el arreglo mínimo y correcto, como lo haría el director, sin tocar el hotel ni bajar el listón de una prueba. Para cada uno da el cambio exacto (función, fragmento literal de ahora y el nuevo) para que un agente Haiku lo aplique sin decidir nada, y la orden de prueba que lo demuestra. Si un fallo no tiene arreglo dentro de las reglas, dilo en al_director.\n\n${fallos}`, { label: `diagnóstico r${round}`, phase: 'Diagnóstico', schema: FIX, ...R })
  if (!dx || !dx.arreglos.length) { last = { dx }; break }
  phase('Arreglo')
  const rep = await agent(`${CTX}\n\nEres un agente de la batería. Aplica EXACTAMENTE estos arreglos, en orden, y corre después la prueba de cada uno (de una en una, con el restore tras cada ejecución). No cambies nada más. Si un cambio no encaja con el código, dilo y sigue con los demás.\n${JSON.stringify(dx.arreglos, null, 1)}\nDevuelve qué aplicaste y el resultado de cada prueba.`, { label: `arreglo r${round}`, phase: 'Arreglo', ...W })
  phase('Revisión')
  const rv = await agent(`${CTX}\n\nEres el revisor (Opus, esfuerzo high). Lee el diff de los arreglos (git diff) contra lo que se pidió y repite sus pruebas, de una en una. Acepta solo si están bien resueltos (correctos, mínimos, en el estilo del código, sin tocar el hotel). Arreglos pedidos:\n${JSON.stringify(dx.arreglos, null, 1)}\nInforme del agente:\n${rep}`, { label: `revisión r${round}`, phase: 'Revisión', schema: OK, ...R })
  if (rv && !rv.bien) { fallos = A.fallos + '\n\nLa revisión de la ronda anterior pide:\n' + rv.correcciones.join('\n'); last = { dx, rv }; continue }
  phase('Verify')
  const ver = await agent(`Desde E:/Projects/The Four, en primer plano (tarda de 5 a 10 minutos; timeout 600000 ms): powershell -NoProfile -ExecutionPolicy Bypass -File tools/verify.ps1 ; después git restore default_bus_layout.tres assets/audio/the_four_theme.mp3.import. Copia cada línea «<nombre> : True/False». Para cada False, lee su log en evidence/verify_<nombre>.log y di la causa exacta. No edites nada.`, { label: `verify r${round}`, phase: 'Verify', schema: VER, ...W })
  last = { dx, rv, ver }
  if (ver && ver.verde) break
  fallos = 'Tras los arreglos, verify sigue con fallos:\n' + JSON.stringify(ver ? ver.fallos : [], null, 1) + '\n\nLos fallos originales eran:\n' + A.fallos
}
return {
  verde: !!(last && last.ver && last.ver.verde),
  fallos: last && last.ver ? last.ver.fallos : null,
  arreglos: last && last.dx ? last.dx.arreglos.map(a => a.fallo + ': ' + a.causa.slice(0, 250) + ' -> ' + a.archivo) : [],
  al_director: last && last.dx ? last.dx.al_director : [],
  revision: last && last.rv ? last.rv : null,
}
