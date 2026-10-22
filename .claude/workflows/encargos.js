export const meta = {
  name: 'encargos',
  description: 'De una nota de diseño a unidades cerradas: la batería levanta fichas de hechos del código, un revisor redacta los encargos y dos críticos los atacan antes de que el director los apruebe',
  whenToUse: 'Antes de un frente: cuando el diseño de un área está decidido y hay que partirlo en unidades que un Haiku pueda hacer sin decidir nada',
  phases: [
    { title: 'Fichas', detail: 'Haiku 5.5 xhigh copia firmas y fragmentos literales del código (solo lectura)', model: 'haiku' },
    { title: 'Encargos', detail: 'Opus 5.5 high redacta las unidades', model: 'opus' },
    { title: 'Crítica', detail: 'dos críticos Opus 5.5 high intentan tumbarlas', model: 'opus' },
    { title: 'Revisión', detail: 'Opus 5.5 high aplica la crítica', model: 'opus' },
  ],
}

// args: {
//   area: 'nombre corto',
//   nota: 'la nota de diseño del área, o la ruta de un archivo con ella (p. ej. .claude/specs/spec_f1_generator.md §1a)',
//   preguntas: ['qué hechos del código hay que levantar, uno por ficha'],
//   salida: 'ruta donde escribir el resultado (.claude/specs/encargos_<area>.json)',
// }
const A = args
const WORKER = { model: 'haiku', effort: 'xhigh' }
const REVIEWER = { model: 'opus', effort: 'high' }
const PLAN = { type: 'object', properties: {
  contexto: { type: 'string' }, paralelo: { type: 'boolean' }, aceptacion: { type: 'string' }, pruebas: { type: 'string' },
  unidades: { type: 'array', items: { type: 'object', properties: {
    id: { type: 'string' }, encargo: { type: 'string' }, archivos: { type: 'array', items: { type: 'string' } },
    no_tocar: { type: 'array', items: { type: 'string' } }, verificar: { type: 'string' } },
    required: ['id', 'encargo', 'archivos', 'no_tocar', 'verificar'] } },
  al_director: { type: 'array', items: { type: 'string' } } },
  required: ['contexto', 'paralelo', 'aceptacion', 'pruebas', 'unidades', 'al_director'] }

phase('Fichas')
const sheets = await parallel(A.preguntas.map((q, i) => () => agent(`SOLO LECTURA en E:/Projects/The Four (no edites nada, no ejecutes Godot). Levanta una ficha de hechos para preparar los encargos del área "${A.area}".
Pregunta: ${q}
Copia literal (con archivo y número de línea) las firmas, constantes y fragmentos del código que respondan; no resumas el código con tus palabras ni propongas cambios. Si algo no existe, dilo. Devuelve la ficha como texto.`, { label: `ficha ${i + 1}`, phase: 'Fichas', ...WORKER })))

phase('Encargos')
const ask = (extra) => `Eres quien redacta los encargos del área "${A.area}" (Opus, esfuerzo high). No lanzas agentes. Lee la nota de diseño y las fichas, y comprueba en el código lo que dudes (E:/Projects/The Four, solo lectura).
Nota de diseño:
${A.nota}
Fichas de hechos:
${sheets.map((s, i) => `--- ficha ${i + 1}: ${A.preguntas[i]}\n${s || '(vacía)'}`).join('\n')}

Parte el área en unidades pequeñas y cerradas que un agente Haiku pueda hacer sin decidir nada: qué archivos escribe y cuáles no toca, las firmas exactas y los fragmentos literales que necesita, cómo se verifica (órdenes exactas; Godot siempre con --test-profile) y qué resultado se espera. Las unidades que comparten archivos o necesitan Godot van en serie (paralelo=false si alguna lo hace). Escribe el contexto común que toda unidad debe leer, la prueba de aceptación del área (qué se ve funcionando) y las pruebas que el revisor repetirá. Lo que cambia el diseño o un contrato va en al_director, no se decide aquí.${extra || ''}`
let plan = await agent(ask(), { label: 'redacta', phase: 'Encargos', schema: PLAN, ...REVIEWER })

phase('Crítica')
const critiques = await parallel([
  'HACERLO: ¿podría un Haiku cumplir cada unidad sin decidir nada? Firmas que faltan, fragmentos sin copiar, órdenes de verificación vagas, archivos compartidos entre unidades paralelas, Godot en paralelo.',
  'ACERTAR: ¿hacen las unidades, juntas, lo que pide la nota de diseño sin romper el hotel? Lo que falta, lo que contradice el diseño o el código real, pruebas que pasarían aunque estuviese mal.',
].map((lens, i) => () => agent(`Crítico de encargos (Opus, esfuerzo high; solo lectura). Intenta tumbar estos encargos del área "${A.area}".
Enfoque: ${lens}
Encargos:
${JSON.stringify(plan, null, 1)}
Nota de diseño:
${A.nota}
Devuelve una lista numerada de correcciones concretas (unidad y qué cambiar). Una lista vacía es válida.`, { label: `crítico ${i + 1}`, phase: 'Crítica', ...REVIEWER })))

phase('Revisión')
plan = await agent(ask(`

Ya redactaste esta versión:
${JSON.stringify(plan, null, 1)}
Dos críticos la atacaron:
${critiques.filter(Boolean).join('\n---\n')}
Aplica lo que tenga razón y devuelve la versión final completa.`), { label: 'revisa', phase: 'Revisión', schema: PLAN, ...REVIEWER })

if (A.salida) {
  await agent(`Escribe exactamente este JSON (con sangría de 2 espacios) en el archivo E:/Projects/The Four/${A.salida}, creando la carpeta si falta. No cambies nada del contenido.
${JSON.stringify(plan)}`, { label: 'guarda', phase: 'Revisión', ...WORKER })
}
return { area: A.area, plan, criticas: critiques }
