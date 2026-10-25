export const meta = {
  name: 'frente_resumen',
  description: 'Lanza el flujo frente con un JSON de encargos y devuelve solo un resumen corto (para no llenar el contexto del director)',
  whenToUse: 'Para construir un área cuyos encargos aprobó el director, cuando el contexto del director importa',
  phases: [
    { title: 'Frente', detail: 'flujo frente: Haiku 5.5 xhigh hace, Opus 5.5 high revisa, verify y costuras', model: 'haiku' },
  ],
}

// args: { area: 'nombre corto', archivo: '.claude/specs/encargos_<area>.json', unidades: [{id, archivos}], paralelo: false, integrar: true }
const A = args
phase('Frente')
const f = await workflow({ scriptPath: 'E:/Projects/The Four/.claude/workflows/frente.js' }, {
  area: A.area, archivo: A.archivo, unidades: A.unidades,
  paralelo: A.paralelo === true, integrar: A.integrar !== false,
})
const v = f && f.veredicto
return {
  estado: f ? f.estado : 'sin resultado',
  aceptadas: f ? f.aceptadas : [],
  pendientes: v ? v.correcciones.map(c => c.id + ': ' + c.que.slice(0, 300)) : [],
  al_director: v ? v.al_director.map(x => x.slice(0, 500)) : [],
  resumen: v ? v.resumen.slice(0, 1200) : '',
  costuras: f && f.costuras ? f.costuras.map(h => h.gravedad + ' ' + h.titulo + ' (' + h.archivo + ')') : [],
  verify: f && f.verificacion ? { verde: f.verificacion.verde, fallos: f.verificacion.fallos } : null,
}
