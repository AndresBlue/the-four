"""Summary of a performance trace of The Four (game/app/session_perf.gd).

    python -I tools/benchmarks/perf_report.py <trace.jsonl | its folder> [--out report.md]
    python -I tools/benchmarks/perf_report.py --self-test

Writes <trace>.report.md beside the trace (or --out) in Spanish, like the docs:
where the frame goes by phase, which named work eats it, every hitch with what
was going on, the worst rooms and seconds. docs/PERFORMANCE.md, section 14.
"""
import bisect
import json
import math
import os
import sys
import traceback
from collections import defaultdict

PHASES = ("física", "proceso", "dibujo", "resto")
# A hitch is a frame this many times the median, and never under 33 ms: on a
# slow machine every frame is slow, and that is the phases' table, not a hitch.
HITCH_TIMES = 2.5
HITCH_MIN_MS = 1000.0 / 30.0
# Spans this long that cross frames or run on other threads are named as what
# was going on during a hitch.
LONG_SPAN_US = 10_000
# What the game said (a probe made, a search ended) this long before a frame
# began counts as said for it: its cost often lands in the next frame's draw.
SIGNAL_BEFORE_US = 30_000
# Rows that are not something the game said.
NOT_SIGNALS = ("frame", "begin", "span", "main_stall", "session_start", "session_end", "dropped", "broken", "player_mark")
BUDGET_MS = 1000.0 / 60.0
# The parts of a frame no named work accounts for (frame_parts).
UNNAMED = ("física sin nombre", "proceso sin nombre", "dibujo", "resto")


def load(path):
    rows = []
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            try:
                rows.append(json.loads(line))
            except json.JSONDecodeError:
                rows.append({"event": "broken"})  # the last line of a game that died
    return rows


def pcts(values, wanted):
    """Linear-interpolated percentiles of values, one per entry of wanted."""
    ordered = sorted(values)
    out = []
    for p in wanted:
        if not ordered:
            out.append(0.0)
            continue
        k = (len(ordered) - 1) * p / 100.0
        low = math.floor(k)
        high = min(low + 1, len(ordered) - 1)
        out.append(ordered[low] + (ordered[high] - ordered[low]) * (k - low))
    return out


def mean(values):
    return sum(values) / len(values) if values else 0.0


def num(value, digits=1):
    return f"{value:.{digits}f}".replace(".", ",")


def timing(entry):
    """[calls, total, max, own, phase] (format 2) or [calls, total, max] (1)."""
    if len(entry) >= 5:
        return entry[0], entry[1], entry[2], entry[3], int(entry[4])
    return entry[0], entry[1], entry[2], entry[1], None


def frame_parts(frame):
    """Own time of each named work and of what nothing names, in microseconds."""
    parts = {}
    for name, entry in frame.get("timings", {}).items():
        parts[name] = timing(entry)[3]
    if "phys_us" in frame:
        spent = [frame["phys_us"], frame["proc_us"], frame["draw_us"]]
        named = frame.get("named_us", [0, 0, 0, 0])
        rest = frame["us"] - sum(spent)
        parts["física sin nombre"] = max(0, spent[0] - named[0])
        parts["proceso sin nombre"] = max(0, spent[1] - named[1])
        parts["dibujo"] = max(0, spent[2] - named[2])
        parts["resto"] = max(0, rest - named[3])
    return parts


def cause_of(frame, parts):
    name, us = max(parts.items(), key=lambda item: item[1]) if parts else ("?", 0)
    if name == "dibujo" and frame.get("compiles"):
        name = "dibujo con compilaciones de pipelines"  # how many, in the hitch's own row
    return name, us


def lamps(ctx):
    """(shown, within their fade, casting shadows); the traces of 20 Nov had no middle one."""
    l = ctx.get("lights")
    if not l:
        return None
    return (l[0], l[1], l[2]) if len(l) >= 3 else (l[0], None, l[1])


def context_of(frame):
    ctx = frame.get("ctx", {})
    room = ctx.get("room")
    where = "" if room is None else f"sala {room}" + (f" ({ctx['room_name']})" if ctx.get("room_name") else "")
    bits = [where, f"planta {ctx['planta']}" if "planta" in ctx and room is not None else "",
            f"etapa {frame.get('stage')}", "apagón" if ctx.get("blackout") else "",
            f"Lurker: {ctx['creature_beat']}" if ctx.get("creature_beat") else ""]
    return ", ".join(bit for bit in bits if bit)


def analyse(rows):
    start = next((r for r in rows if r.get("event") == "session_start"), {})
    info = start.get("detail", {})
    main_thread = info.get("main_thread", 1)
    t0 = start.get("at_us") or next((r["at_us"] for r in rows if "at_us" in r), 0)
    frames, samples, spans, marks, stalls, signals = [], [], [], [], [], []
    ctx = {}
    for row in rows:
        kind = row.get("event")
        if kind not in NOT_SIGNALS and "at_us" in row:
            signals.append((row["at_us"], row["name"] if kind == "end" else kind))
        if kind == "frame":
            if "sample" in row:
                ctx = row["sample"]
                samples.append((row, ctx))
            row["ctx"] = ctx
            if row.get("us", 0) > 0:
                frames.append(row)
        elif kind == "end":
            spans.append(row)
        elif kind == "player_mark":
            marks.append(row)
        elif kind == "main_stall":
            stalls.append(row)
    playing = [f for f in frames if f.get("state") == "PLAYING" and f.get("focused", True)]
    unfocused = not playing
    if unfocused:  # a bench or a capture runs in the background
        playing = [f for f in frames if f.get("state") == "PLAYING"]
    pool = playing or frames
    ms = [f["us"] / 1000.0 for f in pool]
    p50 = pcts(ms, [50])[0]
    hitch_ms = max(HITCH_MIN_MS, HITCH_TIMES * p50)
    signals.sort()
    signal_at = [t for t, _ in signals]

    def said(f):
        lo = bisect.bisect_left(signal_at, f["start_us"] - SIGNAL_BEFORE_US)
        return {signals[i][1] for i in range(lo, bisect.bisect_right(signal_at, f["at_us"]))}
    long_spans = sorted((s for s in spans if s.get("us", 0) >= LONG_SPAN_US), key=lambda s: s["start_us"])
    starts = [s["start_us"] for s in long_spans]
    hitches = []
    for f in frames:
        if f["us"] / 1000.0 < hitch_ms:
            continue
        parts = frame_parts(f)
        cause, cause_us = cause_of(f, parts)
        top = sorted(parts.items(), key=lambda item: -item[1])[:3]
        during = []
        for s in long_spans[:bisect.bisect_left(starts, f["at_us"])]:
            if s["at_us"] <= f["start_us"]:
                continue
            inside = s["start_us"] >= f["start_us"] and s["at_us"] <= f["at_us"]
            if inside and s.get("tid") == main_thread:
                continue  # already in the frame's own timings
            where = "" if s.get("tid") == main_thread else " en otro hilo"
            during.append(f"{s['name']}{where} ({num(s['us'] / 1000.0)} ms)")
        hitches.append({"frame": f, "ms": f["us"] / 1000.0, "cause": cause, "cause_ms": cause_us / 1000.0,
                        "top": top, "during": during[:4], "said": sorted(said(f)), "t": (f["at_us"] - t0) / 1e6})
    # What the game said before the hitches played, against the other frames.
    in_hitch, in_rest = defaultdict(int), defaultdict(int)
    hitch_ids = {id(h["frame"]) for h in hitches}
    played_hitches = sum(1 for f in playing if id(f) in hitch_ids)
    for f in playing:
        for name in said(f):
            (in_hitch if id(f) in hitch_ids else in_rest)[name] += 1
    rest_count = max(1, len(playing) - played_hitches)
    before = []
    for name, count in in_hitch.items():
        share, other = count / max(1, played_hitches), in_rest[name] / rest_count
        if count >= 3 and share >= 3 * other:
            before.append({"name": name, "hitches": count, "share": share, "other": other})
    before.sort(key=lambda b: -b["hitches"])
    # Named work over the frames played.
    totals = defaultdict(lambda: {"own": 0, "frames": 0, "calls": 0, "max_call": 0, "worst_frame": 0, "phase": None, "per_frame": []})
    for f in pool:
        parts = frame_parts(f)
        for name, own in parts.items():
            t = totals[name]
            t["own"] += own
            t["per_frame"].append(own)
            t["worst_frame"] = max(t["worst_frame"], own)
            if name in f.get("timings", {}):
                calls, _, longest, _, phase = timing(f["timings"][name])
                t["calls"] += calls
                t["max_call"] = max(t["max_call"], longest)
                t["phase"] = phase
            if own > 0:
                t["frames"] += 1
    work = []
    for name, t in totals.items():
        per = t["per_frame"] + [0] * (len(pool) - len(t["per_frame"]))
        work.append({"name": name, "own_ms": t["own"] / 1000.0 / max(1, len(pool)),
                     "p99_ms": pcts(per, [99])[0] / 1000.0, "worst_ms": t["worst_frame"] / 1000.0,
                     "max_call_ms": t["max_call"] / 1000.0, "share": t["frames"] / max(1, len(pool)),
                     "calls": t["calls"] / max(1, t["frames"]), "phase": t["phase"]})
    work.sort(key=lambda w: -w["own_ms"])
    # Phases.
    phases = []
    if pool and "phys_us" in pool[0]:
        for index, key in enumerate(("phys_us", "proc_us", "draw_us", None)):
            values = [(f[key] if key else max(0, f["us"] - f["phys_us"] - f["proc_us"] - f["draw_us"])) / 1000.0 for f in pool]
            phases.append({"name": PHASES[index], "mean": mean(values), "p95": pcts(values, [95])[0], "max": max(values)})
    gpu = [f.get("gpu_ms", f["ctx"].get("gpu_ms", 0.0)) for f in pool]
    # Rooms, by what was played in each.
    rooms = defaultdict(list)
    for f in playing:
        if f["ctx"].get("room") is not None:
            rooms[f["ctx"]["room"]].append(f)
    room_rows = []
    for room, group in rooms.items():
        values = [f["us"] / 1000.0 for f in group]
        ctxs = [f["ctx"] for f in group]
        lit = [l for l in map(lamps, ctxs) if l]
        room_rows.append({"room": room, "name": ctxs[-1].get("room_name", ""), "planta": ctxs[-1].get("planta"),
                          "seconds": sum(f["us"] for f in group) / 1e6, "mean": mean(values),
                          "over": sum(max(0.0, v - BUDGET_MS) for v in values) / 1000.0,
                          "p95": pcts(values, [95])[0], "max": max(values),
                          "hitches": sum(1 for f in group if id(f) in hitch_ids),
                          "gpu": mean([f.get("gpu_ms", f["ctx"].get("gpu_ms", 0.0)) for f in group]),
                          "draws": mean([c.get("draw_calls", 0) for c in ctxs]),
                          "shadow_draws": mean([c.get("shadow_draw_calls", 0) for c in ctxs]),
                          "lights": mean([l[0] for l in lit]),
                          "reached": mean([l[1] for l in lit]) if lit and lit[0][1] is not None else None,
                          "shadows": mean([l[2] for l in lit])})
    # Where the time over a 60 FPS frame went: a room of one bad second ranks
    # below one walked through for minutes a little over budget.
    room_rows.sort(key=lambda r: -r["over"])
    # Seconds of the game, the worst by their mean frame.
    seconds = defaultdict(list)
    for f in playing:
        seconds[int((f["at_us"] - t0) // 1_000_000)].append(f)
    worst_seconds = sorted(seconds.items(), key=lambda item: -mean([f["us"] for f in item[1]]))[:10]
    # Groups: stage, blackout, planta, preset.
    groups = {}
    for label, key in (("Etapa", lambda f: f.get("stage")), ("Apagón", lambda f: "sí" if f["ctx"].get("blackout") else "no"),
                       ("Planta", lambda f: f["ctx"].get("planta")), ("Preset", lambda f: f["ctx"].get("preset", f["ctx"].get("quality")))):
        split = defaultdict(list)
        for f in playing:
            split[key(f)].append(f["us"] / 1000.0)
        groups[label] = sorted(split.items(), key=lambda item: str(item[0]))
    # Long operations, wherever they ran.
    ops = defaultdict(lambda: {"count": 0, "total": 0, "max": 0, "main": False})
    for s in spans:
        o = ops[s["name"]]
        o["count"] += 1
        o["total"] += s.get("us", 0)
        o["max"] = max(o["max"], s.get("us", 0))
        o["main"] = o["main"] or s.get("tid") == main_thread
    play_samples = [c for row, c in samples if row.get("state") == "PLAYING"]
    return {"info": info, "t0": t0, "rows": rows, "frames": frames, "playing": playing, "pool": pool, "ms": ms,
            "hitch_ms": hitch_ms, "hitches": hitches, "before": before, "work": work, "phases": phases, "gpu": gpu, "rooms": room_rows,
            "worst_seconds": worst_seconds, "groups": groups, "ops": ops, "marks": marks, "stalls": stalls,
            "samples": play_samples, "unfocused": unfocused and bool(playing), "ended": any(r.get("event") == "session_end" for r in rows),
            "dropped": sum(r.get("count", 0) for r in rows if r.get("event") == "dropped"),
            "broken": sum(1 for r in rows if r.get("event") == "broken")}


def table(head, rows):
    lines = ["| " + " | ".join(head) + " |", "|" + "---|" * len(head)]
    lines += ["| " + " | ".join(str(cell) for cell in row) + " |" for row in rows]
    return "\n".join(lines)


def render(a, source):
    info, pool, ms = a["info"], a["pool"], a["ms"]
    out = [f"# Informe de rendimiento: {os.path.basename(source)}", ""]
    first = a["samples"][0] if a["samples"] else (a["frames"][0]["ctx"] if a["frames"] else {})
    duration = (a["frames"][-1]["at_us"] - a["t0"]) / 1e6 if a["frames"] else 0.0
    played = sum(f["us"] for f in a["playing"]) / 1e6
    view = first.get("viewport", [0, 0, 1])
    window = first.get("window")
    size = (f"ventana {window[0]}×{window[1]}, 3D a {num(view[2], 2)} ({int(window[0] * view[2])}×{int(window[1] * view[2])})" if window
            else f"{int(view[0])}×{int(view[1])} a escala {num(view[2], 2)}")
    out.append(f"Versión {info.get('version', '?')}, Godot {info.get('godot', '?')}, {info.get('renderer', '?')} ({info.get('driver', '?')}), "
               f"{info.get('gpu', '?')}, {info.get('cpu', '?')} ({info.get('cores', '?')} hilos), {info.get('os', '?')}. "
               f"Preset {first.get('preset', first.get('quality', '?'))}, {size}, "
               f"VSync {'sí' if first.get('vsync') else 'no'}, límite {first.get('fps_cap', '?')} FPS, dificultad {first.get('difficulty', '?')}, "
               f"semilla {first.get('seed')}. Traza de {num(duration, 0)} s, {num(played, 0)} s en partida con foco "
               f"({len(a['playing'])} fotogramas).")
    warnings = []
    if not a["ended"]:
        warnings.append("la traza no tiene `session_end`: el juego se cerró de golpe o sigue abierto")
    if a["dropped"]:
        warnings.append(f"se perdieron {a['dropped']} filas (cola llena)")
    if a["broken"]:
        warnings.append(f"{a['broken']} líneas rotas")
    if not a["playing"]:
        warnings.append("no hay fotogramas en partida: las cifras son de todos los fotogramas")
    elif a["unfocused"]:
        warnings.append("la ventana no tuvo el foco en ningún momento de la partida (un banco o una captura): se cuentan igual")
    if warnings:
        out.append("")
        out.append("**Ojo:** " + "; ".join(warnings) + ".")
    p50, p90, p95, p99, p999 = pcts(ms, [50, 90, 95, 99, 99.9])
    avg = mean(ms)
    hitches_play = [h for h in a["hitches"] if h["frame"].get("state") == "PLAYING"]
    # Quick reading.
    out += ["", "## Lectura rápida", ""]
    out.append(f"- Fotograma en partida: media {num(avg, 2)} ms ({num(1000 / avg if avg else 0, 0)} FPS), p50 {num(p50, 2)}, "
               f"p99 {num(p99, 2)}, máximo {num(max(ms) if ms else 0, 1)} ms.")
    if hitches_play:
        every = played / len(hitches_play) if played else 0
        out.append(f"- {len(hitches_play)} tirones en partida (≥ {num(a['hitch_ms'], 1)} ms), uno cada {num(every, 0)} s de media.")
        causes = defaultdict(int)
        for h in hitches_play:
            causes[h["cause"]] += 1
        common = sorted(causes.items(), key=lambda item: -item[1])[:3]
        out.append("- Lo que más se come los tirones: " + ", ".join(f"{name} ({count})" for name, count in common) + ".")
    for b in a["before"][:2]:
        out.append(f"- Antes de los tirones: `{b['name']}` en el {num(100 * b['share'], 0)} % de ellos (en el {num(100 * b['other'], 1)} % del resto de fotogramas).")
    if a["phases"]:
        top = max(a["phases"], key=lambda p: p["mean"])
        out.append(f"- La fase que más pesa es {top['name']}: {num(top['mean'], 2)} ms de {num(avg, 2)} "
                   f"({num(100 * top['mean'] / avg if avg else 0, 0)} %). GPU media {num(mean(a['gpu']), 2)} ms."
                   + (" El resto es casi todo espera del límite de FPS o del VSync." if top["name"] == "resto" else ""))
    # What runs in most frames; a load or a one-off search shows among the hitches.
    steady = [w for w in a["work"] if w["name"] not in UNNAMED and w["share"] >= 0.1]
    if steady:
        out.append("- Trabajo con nombre de cada fotograma que más pesa: " + ", ".join(
            f"`{w['name']}` {num(w['own_ms'], 2)} ms" for w in steady[:3]) + ".")
    loose = {w["name"]: w["own_ms"] for w in a["work"] if w["name"] in ("física sin nombre", "proceso sin nombre")}
    if loose:
        out.append("- Sin nombre, por fotograma: " + ", ".join(f"{name.split()[0]} {num(value, 2)} ms" for name, value in loose.items())
                   + " (motor, nodos y scripts sin medir; si pesa más que lo medido, falta ponerles nombre).")
    trace = next((w for w in a["work"] if w["name"] == "trace"), None)
    if trace:
        out.append(f"- La traza misma cuesta {num(trace['own_ms'], 3)} ms por fotograma (`trace`).")
    if a["rooms"]:
        r = a["rooms"][0]
        named_room = f" ({r['name']})" if r["name"] else ""
        out.append(f"- Sala que más tiempo pierde sobre 16,7 ms: {r['room']}{named_room}, {num(r['over'], 1)} s en {num(r['seconds'], 0)} s, p95 {num(r['p95'], 1)} ms.")
    plantas = [(key, values) for key, values in a["groups"].get("Planta", []) if key is not None]
    if len(plantas) > 1:
        out.append("- Por planta, fotograma medio: " + ", ".join(f"{key}: {num(mean(values), 2)} ms (p99 {num(pcts(values, [99])[0], 1)})" for key, values in plantas) + ".")
    # Distribution.
    out += ["", "## Fotograma en partida", ""]
    over = [(limit, sum(1 for v in ms if v > limit)) for limit in (1000 / 60, 1000 / 30, 50, 100)]
    out.append(table(["Media", "p50", "p90", "p95", "p99", "p99,9", "Máx."],
                     [[num(v, 2) for v in (avg, p50, p90, p95, p99, p999, max(ms) if ms else 0)]]))
    out.append("")
    out.append("Fotogramas por encima de: " + ", ".join(
        f"{num(limit, 1)} ms {count} ({num(100 * count / len(ms) if ms else 0, 1)} %)" for limit, count in over) + ".")
    if a["phases"]:
        out += ["", "## Dónde se va el fotograma", "",
                "Física: los ticks de `_physics_process`, el motor de física y la navegación. Proceso: `_process`, señales y colas. "
                "Dibujo: el render en el hilo principal, que incluye esperar a la GPU y al VSync. Resto: eventos del sistema, entrada y la espera del límite de FPS. "
                "La GPU va en paralelo y llega con uno o dos fotogramas de retraso.", ""]
        out.append(table(["Fase", "Media (ms)", "p95 (ms)", "Máx. (ms)", "% de la media"],
                         [[p["name"], num(p["mean"], 2), num(p["p95"], 2), num(p["max"], 1), num(100 * p["mean"] / avg if avg else 0, 0)] for p in a["phases"]]
                         + [["GPU", num(mean(a["gpu"]), 2), num(pcts(a["gpu"], [95])[0], 2), num(max(a["gpu"]) if a["gpu"] else 0, 1), ""]]))
    out += ["", "## Qué se come el fotograma", "",
            "Tiempo propio: lo que tardó menos lo que tardaron otros trabajos con nombre dentro de él, así que las filas se suman sin contar dos veces. "
            "«sin nombre» es lo que la fase gastó fuera de todo trabajo con nombre: si pesa, falta instrumentar algo ahí.", ""]
    out.append(table(["Trabajo", "Fase", "Propio medio (ms/fot.)", "p99 (ms)", "Peor fotograma (ms)", "Mayor llamada (ms)", "En % de fotogramas", "Llamadas/fot."],
                     [[w["name"] if w["name"] in UNNAMED else f"`{w['name']}`",
                       PHASES[w["phase"]] if w["phase"] is not None else "", num(w["own_ms"], 3), num(w["p99_ms"], 2), num(w["worst_ms"], 1),
                       num(w["max_call_ms"], 1) if w["max_call_ms"] else "", num(100 * w["share"], 0), num(w["calls"], 1) if w["calls"] else ""]
                      for w in a["work"][:30]]))
    # Hitches.
    out += ["", f"## Tirones en partida (≥ {num(a['hitch_ms'], 1)} ms)", ""]
    if hitches_play:
        causes = defaultdict(lambda: [0, 0.0, 0.0])
        for h in hitches_play:
            c = causes[h["cause"]]
            c[0] += 1
            c[1] += h["ms"]
            c[2] = max(c[2], h["ms"])
        out.append(table(["Causa principal", "Tirones", "Tiempo total (ms)", "Peor (ms)"],
                         [[name, c[0], num(c[1], 0), num(c[2], 1)] for name, c in sorted(causes.items(), key=lambda item: -item[1][1])]))
        out += ["", "Los peores, con lo que pasaba:", ""]
        rows = []
        for h in sorted(hitches_play, key=lambda h: -h["ms"])[:30]:
            f = h["frame"]
            phases = "/".join(num(f.get(k, 0) / 1000.0, 0) for k in ("phys_us", "proc_us", "draw_us")) if "phys_us" in f else ""
            rows.append([num(h["t"], 1), num(h["ms"], 1), h["cause"], ", ".join(f"{n} {num(us / 1000.0, 1)}" for n, us in h["top"]),
                         phases, f.get("compiles", ""), f.get("physics_ticks", ""), context_of(f), "; ".join(h["during"]),
                         ", ".join(f"`{n}`" for n in h["said"][:4])])
        out.append(table(["s", "ms", "Causa", "Los tres mayores (ms)", "Fís./proc./dib. (ms)", "Compil.", "Ticks", "Dónde", "En curso", "Señales"], rows))
    if a["before"]:
        out += ["", "### Lo que pasa justo antes de los tirones", "",
                f"Lo que el juego dijo (un evento, una operación acabada) en el fotograma o en los {SIGNAL_BEFORE_US // 1000} ms anteriores, "
                "en los tirones frente al resto de fotogramas en partida; solo lo que sale al menos tres veces más en los tirones. "
                "Un coste que ningún tiempo del fotograma nombra (una sonda de reflejo que se dibuja fuera del viewport) asoma aquí.", ""]
        out.append(table(["Señal", "Tirones con ella", "% de los tirones", "% del resto"],
                         [[f"`{b['name']}`", b["hitches"], num(100 * b["share"], 0), num(100 * b["other"], 1)] for b in a["before"][:15]]))
    else:
        out.append("Ninguno.")
    others = [h for h in a["hitches"] if h["frame"].get("state") != "PLAYING"]
    if others:
        states = defaultdict(list)
        for h in others:
            states[h["frame"].get("state")].append(h["ms"])
        out += ["", "Fuera de partida (cargas, menús, pausas): " + ", ".join(
            f"{state} {len(v)} (peor {num(max(v), 0)} ms)" for state, v in states.items()) + "."]
    # Rooms.
    if a["rooms"]:
        out += ["", "## Salas, por el tiempo que pierden", "",
                "Ordenadas por lo que sus fotogramas pasaron de 16,7 ms, sumado. Luces: las que están en el árbol, las que quedan al alcance "
                "de su distancia de desvanecido (las que se dibujan, si caen en la vista) y, de estas, las que dan sombra.", ""]
        out.append(table(["Sala", "Nombre", "Planta", "s", "Sobre 16,7 ms (s)", "Media", "p95", "Máx.", "Tirones", "GPU", "Llamadas", "Llamadas de sombra", "Luces", "Al alcance", "Con sombra"],
                         [[r["room"], r["name"], r["planta"], num(r["seconds"], 0), num(r["over"], 2), num(r["mean"], 2), num(r["p95"], 2), num(r["max"], 1), r["hitches"],
                           num(r["gpu"], 2), num(r["draws"], 0), num(r["shadow_draws"], 0), num(r["lights"], 0),
                           num(r["reached"], 0) if r["reached"] is not None else "", num(r["shadows"], 0)]
                          for r in a["rooms"]][:20]))
    # Seconds.
    if a["worst_seconds"]:
        out += ["", "## Los peores segundos", ""]
        out.append(table(["Segundo", "Media (ms)", "Peor (ms)", "Fotogramas", "Dónde"],
                         [[second, num(mean([f["us"] for f in group]) / 1000.0, 2), num(max(f["us"] for f in group) / 1000.0, 1), len(group),
                           context_of(max(group, key=lambda f: f["us"]))] for second, group in a["worst_seconds"]]))
    # Groups.
    out += ["", "## Por etapa, apagón, planta y preset", ""]
    rows = []
    for label, split in a["groups"].items():
        for key, values in split:
            p = pcts(values, [50, 95, 99])
            rows.append([label, key, len(values), num(mean(values), 2), num(p[0], 2), num(p[1], 2), num(p[2], 2)])
    out.append(table(["Grupo", "Valor", "Fotogramas", "Media", "p50", "p95", "p99"], rows))
    # Render.
    if a["samples"]:
        out += ["", "## Render (muestras en partida)", ""]
        rows = []
        for label, key, scale in (("Llamadas de dibujo", "draw_calls", 1), ("Llamadas de sombra", "shadow_draw_calls", 1), ("Objetos", "objects", 1),
                                  ("Primitivas (miles)", "primitives", 1e-3), ("Primitivas de sombra (miles)", "shadow_primitives", 1e-3),
                                  ("Memoria de vídeo (MB)", "vram_bytes", 1 / 1048576), ("CPU del render (ms)", "render_cpu_ms", 1), ("GPU (ms)", "gpu_ms", 1)):
            values = [c[key] * scale for c in a["samples"] if key in c]
            if values:
                p = pcts(values, [50, 95])
                rows.append([label, num(mean(values), 1), num(p[0], 1), num(p[1], 1), num(max(values), 1)])
        for label, index in (("Luces en el árbol", 0), ("Luces al alcance", 1), ("Luces con sombra", 2)):
            values = [lamps(c)[index] for c in a["samples"] if lamps(c) and lamps(c)[index] is not None]
            if values:
                p = pcts(values, [50, 95])
                rows.append([label, num(mean(values), 1), num(p[0], 0), num(p[1], 0), max(values)])
        out.append(table(["", "Media", "p50", "p95", "Máx."], rows))
    # Long operations.
    if a["ops"]:
        out += ["", "## Operaciones con principio y fin", "", "Cargas, horneados, búsquedas de ruta: cada una con su tiempo entero, aunque cruce fotogramas o vaya en otro hilo.", ""]
        out.append(table(["Operación", "Hilo", "Veces", "Total (ms)", "Mayor (ms)"],
                         [[f"`{name}`", "principal" if o["main"] else "otro", o["count"], num(o["total"] / 1000.0, 0), num(o["max"] / 1000.0, 1)]
                          for name, o in sorted(a["ops"].items(), key=lambda item: -item[1]["total"])[:20]]))
    # Marks and stalls.
    if a["marks"]:
        out += ["", "## Marcas F8", ""]
        for mark in a["marks"]:
            near = [h for h in a["hitches"] if 0 <= mark["at_us"] - h["frame"]["at_us"] <= 5_000_000]
            if near:
                h = max(near, key=lambda h: h["ms"])
                out.append(f"- {num((mark['at_us'] - a['t0']) / 1e6, 1)} s: el peor de los 5 s anteriores, {num(h['ms'], 1)} ms a los {num(h['t'], 1)} s, {h['cause']}; {context_of(h['frame'])}.")
            else:
                out.append(f"- {num((mark['at_us'] - a['t0']) / 1e6, 1)} s: ningún tirón en los 5 s anteriores.")
    if a["stalls"]:
        out += ["", f"El hilo principal se quedó parado al menos {num(max(s['us'] for s in a['stalls']) / 1e6, 1)} s "
                f"({len(a['stalls'])} avisos de `main_stall`)."]
    return "\n".join(out) + "\n"


def self_test():
    def frame(at, us, stage=1, room=5, name="Sala A", phys=2000, proc=3000, draw=4000, timings=None, named=None, compiles=0, state="PLAYING"):
        row = {"event": "frame", "at_us": at, "start_us": at - us, "us": us, "state": state, "focused": True, "stage": stage,
               "phys_us": phys, "proc_us": proc, "draw_us": draw, "named_us": named or [0, 1000, 0, 0], "gpu_ms": 3.0, "physics_ticks": 1,
               "timings": timings if timings is not None else {"a": [1, 1000, 1000, 1000, 1]},
               "sample": {"room": room, "room_name": name, "planta": 1, "preset": "Alto", "lights": [10, 6, 2], "draw_calls": 500}}
        if compiles:
            row["compiles"] = compiles
        return row
    rows = [{"event": "session_start", "at_us": 0, "detail": {"main_thread": 1, "renderer": "forward_plus"}}]
    at = 0
    for _ in range(100):
        at += 10_000
        rows.append(frame(at, 10_000))
    for _ in range(40):
        at += 20_000
        rows.append(frame(at, 20_000, room=6, name="Sala B", phys=12_000))
    at += 120_000
    rows.append(frame(at, 120_000, room=6, name="Sala B", phys=110_000, named=[100_000, 0, 0, 0],
                      timings={"lurker.physics": [1, 100_000, 100_000, 30_000, 0], "lurker.brain": [1, 70_000, 70_000, 70_000, 0]}))
    at += 80_000
    rows.append(frame(at, 80_000, room=6, name="Sala B", draw=75_000, timings={}, named=[0, 0, 0, 0], compiles=12))
    rows.append({"event": "end", "name": "bounce.room", "at_us": at - 1000, "start_us": at - 60_000, "us": 59_000, "tid": 7})
    rows.append({"event": "geometry.probe_created", "at_us": at - 90_000, "tid": 1, "detail": {}})  # 10 ms before it began
    rows.append({"event": "geometry.probe_created", "at_us": 500_000, "tid": 1, "detail": {}})  # in an ordinary frame
    at += 10_000
    rows.append(frame(at, 500_000, state="LOADING"))
    rows.append({"event": "session_end", "at_us": at})
    a = analyse(rows)
    assert len(a["playing"]) == 142, len(a["playing"])
    assert abs(pcts([1, 2, 3, 4], [50])[0] - 2.5) < 1e-9
    assert abs(a["hitch_ms"] - HITCH_MIN_MS) < 1e-9, a["hitch_ms"]  # 2.5 × 10 ms is under the floor
    causes = [h["cause"] for h in a["hitches"] if h["frame"]["state"] == "PLAYING"]
    assert causes == ["lurker.brain", "dibujo con compilaciones de pipelines"], causes
    assert a["hitches"][1]["during"] == ["bounce.room en otro hilo (59,0 ms)"], a["hitches"][1]["during"]
    assert a["rooms"][0]["room"] == 6 and a["rooms"][0]["hitches"] == 2, a["rooms"][0]
    over = (40 * (20 - BUDGET_MS) + (120 - BUDGET_MS) + (80 - BUDGET_MS)) / 1000
    assert abs(a["rooms"][0]["over"] - over) < 1e-9, a["rooms"][0]["over"]
    assert a["hitches"][1]["said"] == ["bounce.room", "geometry.probe_created"], a["hitches"][1]["said"]
    assert a["rooms"][0]["reached"] == 6, a["rooms"][0]
    by_name = {w["name"]: w for w in a["work"]}
    # Own times add up: lurker.physics keeps 30 of its 100 ms, and the 10 ms
    # its tick spent outside both are physics nobody names.
    assert abs(by_name["lurker.physics"]["own_ms"] * 142 - 30) < 1e-6
    assert abs(by_name["física sin nombre"]["worst_ms"] - 12.0) < 1e-6, by_name["física sin nombre"]
    text = render(a, "prueba.jsonl")
    assert "| 6 | Sala B |" in text and "lurker.brain (1)" in text and "Fuera de partida" in text, text
    # A trace of format 1 (no phases, timings of three) still reads.
    old = [rows[0]] + [{k: v for k, v in r.items() if k not in ("phys_us", "proc_us", "draw_us", "named_us")} for r in rows[1:]]
    for r in old:
        if r.get("event") == "frame":
            r["timings"] = {n: e[:3] for n, e in r["timings"].items()}
    render(analyse(old), "vieja.jsonl")
    print("PERF_REPORT_SELF_TEST ok")


def main(argv):
    if "--self-test" in argv:
        try:
            self_test()
        except AssertionError:
            traceback.print_exc(file=sys.stdout)  # verify.ps1 reads stdout only
            return 1
        return 0
    args = [a for a in argv if not a.startswith("--out=")]
    if len(args) != 1:
        print(__doc__)
        return 2
    source = args[0]
    if os.path.isdir(source):
        traces = sorted((os.path.join(source, n) for n in os.listdir(source) if n.endswith(".jsonl") and not n.endswith(".hitches.jsonl")), key=os.path.getmtime)
        if not traces:
            print(f"No hay ninguna traza .jsonl en {source}")
            return 1
        source = traces[-1]
    out = next((a[len("--out="):] for a in argv if a.startswith("--out=")), os.path.splitext(source)[0] + ".report.md")
    text = render(analyse(load(source)), source)
    with open(out, "w", encoding="utf-8") as handle:
        handle.write(text)
    print(f"Informe: {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
