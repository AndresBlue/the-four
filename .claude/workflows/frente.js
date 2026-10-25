export const meta = {
  name: 'frente',
  description: 'Un frente de área: la batería Haiku hace las unidades, un revisor Opus da cada una por buena o manda corregirla, y la integración verifica el conjunto y sus costuras',
  whenToUse: 'Para construir un área ya diseñada cuyas unidades cerradas aprobó el director (salen del flujo encargos)',
  phases: [
    { title: 'Unidades', detail: 'Haiku 5.5 xhigh; en paralelo solo si los archivos son disjuntos y no ejecutan Godot', model: 'haiku' },
    { title: 'Revisión', detail: 'Opus 5.5 high lee cada diff, repite la verificación y da veredicto', model: 'opus' },
    { title: 'Correcciones', detail: 'Haiku 5.5 xhigh, hasta dos rondas', model: 'haiku' },
    { title: 'Verificación', detail: 'Haiku 5.5 xhigh corre tools/verify.ps1 (uno a la vez)', model: 'haiku' },
    { title: 'Costuras', detail: 'Opus 5.5 high: revisión adversarial y refutación', model: 'opus' },
    { title: 'Arreglos', detail: 'Haiku 5.5 xhigh', model: 'haiku' },
  ],
}

// args: {
//   area: 'nombre corto del área',
//   contexto: 'lo que toda unidad debe saber (diseño, contratos, rutas de las fichas)',
//   paralelo: true | false,          // true: las unidades no comparten archivos ni ejecutan Godot
//   aceptacion: 'la prueba de aceptación del área (qué se ve funcionando)',
//   pruebas: 'las pruebas de Godot del área que el revisor repite (órdenes exactas)',
//   unidades: [{ id, encargo, archivos: [..], no_tocar: [..], verificar: 'órdenes y resultado esperado' }],
//   integrar: true | false,          // false: solo unidades y revisión (para áreas que se integran juntas)
//   archivo: '.claude/specs/encargos_<area>.json',  // opcional: el JSON que dejó el flujo encargos
//   primero: [ids],                  // opcional: unidades que van antes y solas, en orden
// }
// Con `archivo`, contexto, aceptación, pruebas y el texto de cada unidad se leen de ese JSON (no se copian
// en los argumentos) y `unidades` solo necesita {id, archivos}.
const A = args
const SRC = A.archivo ? `E:/Projects/The Four/${A.archivo}` : null
const CONTEXTO = SRC ? `Está en ${SRC} (JSON), campo "contexto": léelo entero antes de nada.` : A.contexto
const ACEPTACION = SRC ? `la del campo "aceptacion" de ${SRC}` : A.aceptacion
const PRUEBAS = SRC ? `las del campo "pruebas" de ${SRC}` : A.pruebas
const UNIDADES = SRC ? `Están en ${SRC}, campo "unidades".` : JSON.stringify(A.unidades, null, 1)
const unitText = (u, field) => SRC ? `el campo "${field}" de la unidad ${u.id} en ${SRC}` : u[field]
const WORKER = { model: 'haiku', effort: 'xhigh' }
const REVIEWER = { model: 'opus', effort: 'high' }
const UNIT = { type: 'object', properties: {
  hecho: { type: 'boolean' }, archivos: { type: 'array', items: { type: 'string' } },
  ejecutado: { type: 'string' }, resultado: { type: 'string' },
  no_encaja: { type: 'string', description: 'vacío si el encargo encaja con el código; si no, por qué' } },
  required: ['hecho', 'archivos', 'ejecutado', 'resultado', 'no_encaja'] }
const VERDICT = { type: 'object', properties: {
  aceptadas: { type: 'array', items: { type: 'string' } },
  correcciones: { type: 'array', items: { type: 'object', properties: {
    id: { type: 'string' }, que: { type: 'string' }, archivos: { type: 'array', items: { type: 'string' } } },
    required: ['id', 'que', 'archivos'] } },
  al_director: { type: 'array', items: { type: 'string' } },
  resumen: { type: 'string' } },
  required: ['aceptadas', 'correcciones', 'al_director', 'resumen'] }
const FINDINGS = { type: 'object', properties: { hallazgos: { type: 'array', items: { type: 'object', properties: {
  titulo: { type: 'string' }, archivo: { type: 'string' }, linea: { type: 'integer' },
  gravedad: { type: 'string', enum: ['alta', 'media', 'baja'] }, detalle: { type: 'string' }, arreglo: { type: 'string' } },
  required: ['titulo', 'archivo', 'gravedad', 'detalle', 'arreglo'] } } }, required: ['hallazgos'] }
const REAL = { type: 'object', properties: { real: { type: 'boolean' }, por_que: { type: 'string' } }, required: ['real', 'por_que'] }
const VERIFY = { type: 'object', properties: { verde: { type: 'boolean' }, lineas: { type: 'array', items: { type: 'string' } },
  fallos: { type: 'array', items: { type: 'object', properties: { nombre: { type: 'string' }, causa: { type: 'string' } }, required: ['nombre', 'causa'] } } },
  required: ['verde', 'lineas', 'fallos'] }

const WORKER_NOTE = `Eres un agente de la batería. Cumple exactamente tu encargo: no rediseñes, no toques archivos fuera de los tuyos, no hagas commit. Si el encargo no encaja con el código, dilo en no_encaja y para. Las reglas del proyecto están en CLAUDE.md (Godot siempre con --test-profile y git restore después).`
const NO_GODOT = A.paralelo ? ' Vas en paralelo con otras unidades: NO ejecutes Godot; tu revisor ejecuta las pruebas después.' : ''

function unitPrompt(u, extra) {
  return `${WORKER_NOTE}${NO_GODOT}

Área: ${A.area}
Contexto común:
${CONTEXTO}

Tu unidad: ${u.id}
Encargo:
${unitText(u, 'encargo')}
Archivos que escribes: ${(u.archivos || []).join(', ')}
No toques: ${SRC ? unitText(u, 'no_tocar') : (u.no_tocar || []).join(', ') || 'nada fuera de tus archivos'}
Cómo se verifica y qué se espera: ${unitText(u, 'verificar')}${extra ? '\n\n' + extra : ''}`
}

phase('Unidades')
const reports = {}
// args.primero: ids de las unidades que van antes y solas, en orden (p. ej. la que crea el archivo que leen las demás).
const firsts = A.unidades.filter(u => (A.primero || []).includes(u.id))
const wave = A.unidades.filter(u => !(A.primero || []).includes(u.id))
for (const u of firsts) reports[u.id] = await agent(unitPrompt(u), { label: `unidad ${u.id}`, phase: 'Unidades', schema: UNIT, ...WORKER })
if (A.paralelo) {
  const done = await parallel(wave.map(u => () => agent(unitPrompt(u), { label: `unidad ${u.id}`, phase: 'Unidades', schema: UNIT, ...WORKER })))
  wave.forEach((u, i) => { reports[u.id] = done[i] })
} else {
  for (const u of wave) reports[u.id] = await agent(unitPrompt(u), { label: `unidad ${u.id}`, phase: 'Unidades', schema: UNIT, ...WORKER })
}
const misfits = A.unidades.filter(u => reports[u.id] && reports[u.id].no_encaja)
if (misfits.length) log(`${misfits.length} unidades dicen que su encargo no encaja`)

let verdict = null
let accepted = new Set()
for (let round = 1; round <= 3; round++) {
  phase('Revisión')
  verdict = await agent(`Eres el revisor del área "${A.area}" (Opus, esfuerzo high). No lanzas agentes ni haces commit.
Encargo completo del área:
${CONTEXTO}
Unidades y sus encargos:
${UNIDADES}
Informes de la batería (no te fíes de ellos):
${JSON.stringify(reports, null, 1)}
Prueba de aceptación del área: ${ACEPTACION}
Lee el cambio real de cada unidad (git -C "E:/Projects/The Four" diff y los archivos nuevos), repite la verificación (estas pruebas, de una en una: ${PRUEBAS}) y acepta solo lo resuelto como lo habría resuelto el director: correcto, mínimo, fiel al diseño y en el estilo del código de alrededor. Ya aceptadas en rondas anteriores: ${[...accepted].join(', ') || 'ninguna'}. Ronda ${round}.
Devuelve las aceptadas, las correcciones concretas (con sus archivos), lo que no te corresponde decidir (al_director) y un resumen.`, { label: `revisor ${A.area} r${round}`, phase: 'Revisión', schema: VERDICT, ...REVIEWER })
  if (!verdict) break
  verdict.aceptadas.forEach(id => accepted.add(id))
  if (!verdict.correcciones.length || round === 3) break
  phase('Correcciones')
  const serial = !A.paralelo
  const fix = c => agent(`${WORKER_NOTE}${A.paralelo ? ' No ejecutes Godot.' : ''}

Área: ${A.area}. Contexto:
${CONTEXTO}
Corrección que manda el revisor para la unidad ${c.id}:
${c.que}
Archivos: ${c.archivos.join(', ')}
Encargo original de la unidad: ${SRC ? `la unidad ${c.id} en ${SRC}` : JSON.stringify(A.unidades.find(u => u.id === c.id) || {})}`, { label: `corrige ${c.id} r${round}`, phase: 'Correcciones', schema: UNIT, ...WORKER })
  if (serial) { for (const c of verdict.correcciones) reports[c.id] = await fix(c) }
  else { const out = await parallel(verdict.correcciones.map(c => () => fix(c))); verdict.correcciones.forEach((c, i) => { reports[c.id] = out[i] }) }
}
const pending = verdict ? verdict.correcciones : []
if (pending.length || !A.integrar) {
  return { area: A.area, estado: pending.length ? 'al_director' : 'revisada', veredicto: verdict, aceptadas: [...accepted], informes: reports }
}

async function verifyAll(tag) {
  phase('Verificación')
  return await agent(`Corre la verificación completa del proyecto y reporta. Desde E:/Projects/The Four, en primer plano (tarda de 5 a 8 minutos; usa un timeout de 600000 ms):
powershell -NoProfile -ExecutionPolicy Bypass -File tools/verify.ps1
Después: git restore default_bus_layout.tres assets/audio/the_four_theme.mp3.import
Copia cada línea "<nombre> : True/False". Para cada False, lee su log en evidence/verify_<nombre>.log y di la causa exacta. No edites nada.`, { label: `verify ${tag}`, phase: 'Verificación', schema: VERIFY, ...WORKER })
}

phase('Costuras')
const LENSES = [
  'EL HOTEL: algo de este cambio que pueda alterar cómo se genera, se ve, suena, se juega, se guarda o va en red el piso 1.',
  'COSTURAS: defectos donde el área toca código que ya existía o a otras áreas; casos límite que ninguna unidad tenía encargados.',
  'DISEÑO Y DOCUMENTOS: lo que el área no hace de su diseño (docs/OFICINAS.md y el contexto), y documentos que ya no dicen la verdad.',
]
const found = await parallel(LENSES.map((l, i) => () => agent(`Revisión adversarial (SOLO LECTURA: no edites, no ejecutes Godot) de los cambios sin commit del área "${A.area}" (git -C "E:/Projects/The Four" status y diff). Contexto:
${CONTEXTO}
Tu enfoque: ${l}
Solo problemas concretos y comprobables, con archivo y línea. Una lista vacía es una buena respuesta.`, { label: `costura ${i + 1}`, phase: 'Costuras', schema: FINDINGS, ...REVIEWER })))
const seen = new Set()
const claims = found.filter(Boolean).flatMap(r => r.hallazgos).filter(h => h.gravedad !== 'baja')
  .filter(h => { const k = `${h.archivo}:${h.linea || 0}:${h.titulo.slice(0, 40)}`; if (seen.has(k)) return false; seen.add(k); return true })
const judged = await parallel(claims.map(h => () => agent(`SOLO LECTURA. Un revisor afirma este problema en los cambios sin commit del área "${A.area}":
${JSON.stringify(h)}
Intenta REFUTARLO leyendo el código de verdad. real=true solo si existe y importa.`, { label: `refuta ${h.titulo.slice(0, 24)}`, phase: 'Costuras', schema: REAL, ...REVIEWER }).then(v => ({ h, v }))))
const real = judged.filter(x => x && x.v && x.v.real).map(x => x.h)
log(`${real.length} defectos confirmados en las costuras`)
if (real.length) {
  phase('Arreglos')
  await agent(`${WORKER_NOTE}

Arregla estos defectos confirmados en los cambios del área "${A.area}" (si uno no lo es, explica por qué y déjalo):
${JSON.stringify(real, null, 1)}
Contexto:
${CONTEXTO}
Corre de una en una las pruebas que toquen. No corras verify.ps1.`, { label: 'arregla costuras', phase: 'Arreglos', ...WORKER })
}
// Seams first, then one verify: the fixes the seam review asks for go into the same pass.
let ver = await verifyAll(`${A.area} 1`)
for (let attempt = 1; ver && !ver.verde && attempt <= 2; attempt++) {
  phase('Arreglos')
  await agent(`${WORKER_NOTE}

La verificación completa falló tras el área "${A.area}". Fallos:
${JSON.stringify(ver.fallos, null, 1)}
Contexto del área:
${CONTEXTO}
Encuentra la causa en los cambios sin commit (o demuestra que la prueba es inestable corriéndola dos veces sola) y arréglala bien. Corre las pruebas que fallaron, de una en una, hasta que pasen. No corras verify.ps1.`, { label: `arregla verify ${attempt}`, phase: 'Arreglos', ...WORKER })
  ver = await verifyAll(`${A.area} ${attempt + 1}`)
}

return { area: A.area, estado: ver && ver.verde ? 'verde' : 'rojo', veredicto: verdict, aceptadas: [...accepted], costuras: real, verificacion: ver, informes: reports }
