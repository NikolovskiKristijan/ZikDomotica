"""
bridge_unified.py  –  v2.0
Aggiornato per struttura reale Majordomo:
  - Formato messaggi: "metodo": "write_state" (compatibile con app Flutter)
  - STANZE: match tapparelle per codice.nome, digitali per nome/codice
  - CLIMA: struttura sonda + out[] + statoClima con 5 modi
  - SCENARI: pulsanti virtuali (porta=PV)
  - ANTIFURTO: zone inserimento

Avvio:
  python bridge_unified.py

Dipendenze:
  pip install flask flask-cors python-dotenv websocket-client
"""

import os
import json
import threading
import time

import websocket
from flask import Flask, jsonify, request
from flask_cors import CORS
from dotenv import load_dotenv

load_dotenv()

# ── Configurazione da .env ─────────────────────────────────────────────────────
WS_URL       = os.getenv("WS_URL",            "ws://localhost:8081")
PORT         = int(os.getenv("PORT",           3000))
API_KEY      = os.getenv("API_KEY",            "")
REFRESH_S    = float(os.getenv("STATE_REFRESH_MS", 5000)) / 1000
ALIASES_PATH = os.path.join(os.path.dirname(__file__), "aliases.json")

# ── Stato globale thread-safe ──────────────────────────────────────────────────
_lock       = threading.Lock()
_last_state = None
_ws_conn    = None
_ws_ok      = False

# ══════════════════════════════════════════════════════════════════════════════
#  LAYER WEBSOCKET
# ══════════════════════════════════════════════════════════════════════════════

def _on_open(ws):
    global _ws_ok, _ws_conn
    _ws_ok   = True
    _ws_conn = ws
    print("✅ WS connesso a", WS_URL)
    _get_state()

def _on_message(ws, raw):
    global _last_state
    try:
        obj = json.loads(raw)
        if obj.get("data", {}).get("STANZE"):
            with _lock:
                _last_state = obj
    except Exception:
        pass

def _on_close(ws, code, msg):
    global _ws_ok, _ws_conn
    _ws_ok, _ws_conn = False, None
    print(f"⚠  WS chiuso ({code}). Riconnessione tra 3s...")
    time.sleep(3)
    _start_ws()

def _on_error(ws, err):
    global _ws_ok
    _ws_ok = False
    print(f"❌ Errore WS: {err}")

def _get_state():
    if _ws_ok and _ws_conn:
        _ws_conn.send(json.dumps({
            "metodo": "get_state", "type": "*", "majordomo": "bridge"
        }))

def _send(payload: dict):
    if not _ws_ok or not _ws_conn:
        raise ConnectionError("WebSocket non connesso")
    _ws_conn.send(json.dumps(payload))

def _refresh_loop():
    while True:
        time.sleep(REFRESH_S)
        _get_state()

def _start_ws():
    app_ws = websocket.WebSocketApp(
        WS_URL,
        on_open=_on_open,
        on_message=_on_message,
        on_close=_on_close,
        on_error=_on_error,
    )
    threading.Thread(target=app_ws.run_forever, daemon=True).start()

# ══════════════════════════════════════════════════════════════════════════════
#  MATCHING / ALIASES
# ══════════════════════════════════════════════════════════════════════════════

def _load_aliases() -> dict:
    if not os.path.exists(ALIASES_PATH):
        return {}
    with open(ALIASES_PATH, "r", encoding="utf-8") as f:
        return json.load(f)

def _norm(s: str) -> str:
    return " ".join(str(s).lower().split()).strip()

def _tokenize(s: str) -> list:
    return [x for x in _norm(s).split() if x]

def _score(target: str, candidate: str) -> int:
    t, c = set(_tokenize(target)), set(_tokenize(candidate))
    return len(t & c) if t and c else 0

def _canonicalize(name: str) -> str:
    target  = _norm(name)
    aliases = _load_aliases()
    for canonical in aliases:
        if target == _norm(canonical):
            return _norm(canonical)
    for canonical, syns in aliases.items():
        for s in syns:
            if target == _norm(s):
                return _norm(canonical)
    return target

def _iter_devices(state: dict):
    for stanza, devs in state.get("data", {}).get("STANZE", {}).items():
        if isinstance(devs, list):
            for dev in devs:
                if isinstance(dev, dict):
                    yield stanza, dev

def _candidates(stanza: str, dev: dict) -> list:
    nome = _norm(dev.get("nome", ""))
    # Per tapparelle usa anche codice.nome
    codice_nome = _norm(dev.get("codice", {}).get("nome", ""))
    stanza_nome = _norm(f"{stanza} {dev.get('nome', '')}")
    return [x for x in [nome, codice_nome, stanza_nome] if x]

def _find_one(state: dict, name: str):
    target = _canonicalize(name)
    for stanza, dev in _iter_devices(state):
        if target in _candidates(stanza, dev):
            return stanza, dev
    best, best_sc = None, 0
    for stanza, dev in _iter_devices(state):
        sc = max(_score(target, c) for c in _candidates(stanza, dev))
        if sc > best_sc:
            best_sc, best = sc, (stanza, dev)
    return best if best and best_sc >= 2 else (None, None)

def _find_many(state: dict, name: str, tipo=None) -> list:
    target = _canonicalize(name)
    found, seen = [], set()
    for stanza, dev in _iter_devices(state):
        if tipo is not None and dev.get("tipo") != tipo:
            continue
        cands = _candidates(stanza, dev)
        hit = any(target and target in c for c in cands) or \
              max(_score(target, c) for c in cands) >= 2
        if hit:
            key = (stanza, _norm(dev.get("codice", {}).get("nome", "") or dev.get("nome", "")))
            if key not in seen:
                seen.add(key)
                found.append((stanza, dev))
    return found

def _is_generic_blind(name: str, state: dict) -> bool:
    t = set(_tokenize(name))
    if "tapparella" not in t and "tapparelle" not in t:
        return False
    specific = {"sud","nord","est","ovest","lavandino","portafinestra","finestra","botola","ingresso"}
    if t & specific:
        return False
    for stanza in state.get("data", {}).get("STANZE", {}):
        if set(_tokenize(stanza)).issubset(t):
            return True
    return False

def _blinds_in_room(state: dict, room_query: str) -> list:
    t = set(_tokenize(room_query))
    for stanza, devs in state.get("data", {}).get("STANZE", {}).items():
        if set(_tokenize(stanza)).issubset(t) and isinstance(devs, list):
            return [(stanza, d) for d in devs
                    if isinstance(d, dict) and d.get("tipo") == 1]
    return []

def _canon_name(stanza: str, dev: dict) -> str:
    return dev.get("codice", {}).get("nome") or f"{stanza} {dev.get('nome', '')}"

# ── Matching CLIMA ─────────────────────────────────────────────────────────────

def _find_clima(state: dict, name: str):
    """
    Cerca una stanza clima dal testo.
    Ritorna (stanza, zona_dict) oppure None.
    """
    target = _canonicalize(name)
    clima  = state.get("data", {}).get("CLIMA", {})

    # match esatto sul nome stanza
    for stanza in clima:
        if _norm(stanza) == target:
            return stanza, clima[stanza]

    # fuzzy
    best, best_sc = None, 0
    for stanza in clima:
        sc = _score(target, _norm(stanza))
        if sc > best_sc:
            best_sc, best = sc, stanza
    if best and best_sc >= 1:
        return best, clima[best]
    return None, None

# ── Matching SCENARI ───────────────────────────────────────────────────────────

def _find_scenario(state: dict, name: str):
    target   = _canonicalize(name)
    scenari  = state.get("data", {}).get("SCENARI", [])

    # match esatto
    for sc in scenari:
        if _norm(sc.get("nome", "")) == target:
            return sc

    # fuzzy
    best, best_sc = None, 0
    for sc in scenari:
        s2 = _score(target, _norm(sc.get("nome", "")))
        if s2 > best_sc:
            best_sc, best = s2, sc
    return best if best and best_sc >= 1 else None

# ══════════════════════════════════════════════════════════════════════════════
#  FLASK  –  REST API
# ══════════════════════════════════════════════════════════════════════════════

app = Flask(__name__)
CORS(app)

@app.before_request
def _check_api_key():
    if request.method == "OPTIONS":
        return
    if API_KEY and request.headers.get("x-api-key") != API_KEY:
        return jsonify({"ok": False, "error": "Unauthorized"}), 403

# ── GET / ──────────────────────────────────────────────────────────────────────
@app.get("/")
def _home():
    return jsonify({
        "status": "OK",
        "ws_connected": _ws_ok,
        "endpoints": [
            "GET  /state",
            "POST /device/power      {name, on}",
            "POST /blind/set         {name, value}",
            "POST /climate/set       {name, modo, tTarget?, durata?, crono?}",
            "GET  /climate/state",
            "POST /scenario/run      {name}",
            "POST /antifurto/set     {name, stato}",
        ]
    })

# ── GET /state ─────────────────────────────────────────────────────────────────
@app.get("/state")
def _state():
    with _lock:
        s = _last_state
    if not s:
        return jsonify({"error": "state not ready"}), 503
    return jsonify(s)

# ── POST /device/power ─────────────────────────────────────────────────────────
@app.post("/device/power")
def _power():
    with _lock:
        state = _last_state
    if not state:
        return jsonify({"error": "state not ready"}), 503

    body = request.get_json(silent=True) or {}
    name = body.get("name", "")
    on   = bool(body.get("on", False))

    if not name:
        return jsonify({"error": "name mancante"}), 400

    stanza, dev = _find_one(state, name)
    if not dev:
        return jsonify({"error": f"dispositivo non trovato: {name}"}), 404
    if dev.get("tipo") == 1:
        return jsonify({"error": "è una tapparella: usa /blind/set"}), 400

    # Controlla se è già nello stato richiesto
    stato_attuale = dev.get("stato")
    if isinstance(stato_attuale, bool) and stato_attuale == on:
        return jsonify({
            "ok":      True,
            "already": True,
            "stanza":  stanza,
            "nome":    dev.get("nome"),
            "on":      on,
        })

    try:
        _send({
            "metodo": "write_state",
            "dest":   "STANZE",
            "codice": dev.get("codice", {}),
            "nome":   dev.get("nome"),
            "stato":  on
        })
    except ConnectionError as e:
        return jsonify({"error": str(e)}), 503

    # Aggiorna subito lo stato in memoria senza aspettare il refresh
    with _lock:
        dev["stato"] = on
        dev["statoDevice"] = True

    return jsonify({
        "ok":     True,
        "already": False,
        "stanza": stanza,
        "nome":   dev.get("nome"),
        "on":     on,
        "codice": dev.get("codice", {})
    })

# ── POST /blind/set ────────────────────────────────────────────────────────────
@app.post("/blind/set")
def _blind():
    with _lock:
        state = _last_state
    if not state:
        return jsonify({"error": "state not ready"}), 503

    body  = request.get_json(silent=True) or {}
    name  = body.get("name", "")
    value = body.get("value")

    if not name:
        return jsonify({"error": "name mancante"}), 400
    if value is None:
        return jsonify({"error": "value mancante"}), 400

    try:
        value = max(0, min(100, int(round(float(value)))))
    except Exception:
        return jsonify({"error": "value non numerico"}), 400

    # Richiesta generica → disambigua per stanza
    if _is_generic_blind(name, state):
        matches = _blinds_in_room(state, name)
        if len(matches) > 1:
            options = [{"stanza": s, "nome": _canon_name(s, d)} for s, d in matches]
            return jsonify({
                "error":          "ambiguous",
                "message":        "più tapparelle nella stanza",
                "requestedValue": value,
                "options":        options
            }), 409

    matches = _find_many(state, name, tipo=1)

    if not matches:
        return jsonify({"error": f"tapparella non trovata: {name}"}), 404

    if len(matches) > 1:
        options = [{"stanza": s, "nome": _canon_name(s, d)} for s, d in matches]
        return jsonify({
            "error":          "ambiguous",
            "message":        "più tapparelle corrispondono",
            "requestedValue": value,
            "options":        options
        }), 409

    stanza, dev = matches[0]

    try:
        _send({
            "metodo": "write_state",
            "dest":   "STANZE",
            "codice": dev.get("codice", {}),   # contiene codice.nome per tapparelle
            "nome":   dev.get("nome"),
            "stato":  value
        })
    except ConnectionError as e:
        return jsonify({"error": str(e)}), 503

    return jsonify({
        "ok":     True,
        "stanza": stanza,
        "nome":   dev.get("nome"),
        "value":  value,
        "codice": dev.get("codice", {})
    })

# ── POST /climate/set ──────────────────────────────────────────────────────────
@app.post("/climate/set")
def _climate():
    with _lock:
        state = _last_state
    if not state:
        return jsonify({"error": "state not ready"}), 503

    body    = request.get_json(silent=True) or {}
    name    = body.get("name", "")
    on      = body.get("on", None)
    modo    = body.get("modo", None)
    tTarget = body.get("temperature", body.get("tTarget", None))
    durata  = body.get("durata", None)
    crono   = body.get("crono", None)

    if not name:
        return jsonify({"error": "name mancante"}), 400

    # Determina modo se non passato esplicitamente
    if modo is None:
        if on is False:
            modo = 0   # OFF
        elif tTarget is not None:
            modo = 4   # temperatura fissa
        elif durata is not None:
            modo = 2   # on per N ore
        elif crono is not None:
            modo = 3   # crono
        else:
            modo = 1   # ON semplice

    stanza, zona = _find_clima(state, name)
    if not zona:
        return jsonify({"error": f"zona clima non trovata: {name}"}), 404

    # Primo out della stanza
    out_nome = zona["out"][0]["nome"] if zona.get("out") else None
    out      = zona["out"][0] if zona.get("out") else None

    # Controlla se è già nello stato richiesto
    if out:
        modo_attuale = out.get("statoClima", {}).get("modo", 0)
        if modo == modo_attuale:
            # Stesso modo — controlla anche tTarget se modo 4
            if modo == 4:
                t_attuale = out.get("statoClima", {}).get("tTarget")
                if t_attuale == tTarget:
                    return jsonify({"ok": True, "already": True, "stanza": stanza, "modo": modo})
            elif modo in (0, 1):
                return jsonify({"ok": True, "already": True, "stanza": stanza, "modo": modo})

    codice_clima = {
        "stanza": stanza,
        "nome":   out_nome,
        "modo":   modo,
    }
    if modo == 2 and durata is not None:
        codice_clima["durata"] = str(durata)
    if modo == 3 and crono is not None:
        codice_clima["crono"] = str(crono)
    if modo == 4 and tTarget is not None:
        codice_clima["tTarget"] = tTarget

    try:
        _send({
            "metodo": "write_state",
            "dest":   "CLIMA",
            "codice": codice_clima,
        })
    except ConnectionError as e:
        return jsonify({"error": str(e)}), 503

    # Aggiorna subito lo stato in memoria
    if out:
        with _lock:
            sc = out.get("statoClima", {})
            sc["modo"] = modo
            if modo == 0: out["stato"] = False
            elif modo in (1, 2, 3, 4): out["stato"] = True
            if modo == 4 and tTarget is not None: sc["tTarget"] = tTarget
            if modo == 2 and durata  is not None: sc["durata"]  = str(durata)
            if modo == 3 and crono   is not None: sc["crono"]   = str(crono)

    return jsonify({
        "ok":     True,
        "stanza": stanza,
        "modo":   modo,
        **({} if tTarget is None else {"tTarget": tTarget}),
        **({} if durata  is None else {"durata": durata}),
        **({} if crono   is None else {"crono": crono}),
    })

# ── GET /climate/state ─────────────────────────────────────────────────────────
@app.get("/climate/state")
def _climate_state():
    with _lock:
        state = _last_state
    if not state:
        return jsonify({"error": "state not ready"}), 503

    result = []
    for stanza, zona in state.get("data", {}).get("CLIMA", {}).items():
        sonda = zona.get("sonda", {})
        for out in zona.get("out", []):
            result.append({
                "stanza":      stanza,
                "nome":        out.get("nome"),
                "temperatura": sonda.get("temperatura"),
                "statoClima":  out.get("statoClima", {}),
                "stato":       out.get("stato", False),
            })

    return jsonify({"termostati": result})

# ── POST /scenario/run ─────────────────────────────────────────────────────────
@app.post("/scenario/run")
def _scenario():
    with _lock:
        state = _last_state
    if not state:
        return jsonify({"error": "state not ready"}), 503

    body = request.get_json(silent=True) or {}
    name = body.get("name", "")

    if not name:
        return jsonify({"error": "name mancante"}), 400

    sc = _find_scenario(state, name)
    if not sc:
        return jsonify({"error": f"scenario non trovato: {name}"}), 404

    try:
        _send({
            "metodo":         "write_state",
            "dest":           "SCENARI",
            "codice":         sc.get("codice", {}),
            "nome_scenario":  sc.get("nome"),   # ← inviamo il nome per match preciso in sim-ws
            "autorizzazione": "clic",
        })
    except ConnectionError as e:
        return jsonify({"error": str(e)}), 503

    return jsonify({"ok": True, "nome": sc.get("nome")})

# ── POST /antifurto/set ────────────────────────────────────────────────────────
@app.post("/antifurto/set")
def _antifurto():
    with _lock:
        state = _last_state
    if not state:
        return jsonify({"error": "state not ready"}), 503

    body   = request.get_json(silent=True) or {}
    name   = body.get("name", "")
    stato  = body.get("stato", 1)
    pw     = body.get("password", "")

    if not name:
        return jsonify({"error": "name mancante"}), 400

    target   = _norm(name)
    antifurto = state.get("data", {}).get("ANTIFURTO", [])
    found    = next((a for a in antifurto if _norm(a.get("nome", "")) == target), None)

    if not found:
        return jsonify({"error": f"zona antifurto non trovata: {name}"}), 404

    # Controlla se è già nello stato richiesto
    if found.get("stato") == stato:
        return jsonify({"ok": True, "already": True, "nome": found.get("nome"), "stato": stato})

    try:
        _send({
            "metodo":   "write_state",
            "dest":     "ANTIFURTO",
            "codice":   found.get("codice", {}),
            "stato":    stato,
            "password": pw,
        })
    except ConnectionError as e:
        return jsonify({"error": str(e)}), 503

    # Aggiorna subito lo stato in memoria
    with _lock:
        found["stato"] = stato

    return jsonify({"ok": True, "nome": found.get("nome"), "stato": stato})

# ── Avvio ──────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    _start_ws()
    threading.Thread(target=_refresh_loop, daemon=True).start()
    print(f"🚀 Bridge v2.0 su http://0.0.0.0:{PORT}")
    app.run(host="0.0.0.0", port=PORT, debug=False)