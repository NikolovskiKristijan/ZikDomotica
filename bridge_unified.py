"""
bridge_unified.py  –  v1.0
Sostituisce bridge.js  e  bridge_flask.py

Cosa fa:
  - Si connette a sim-ws.js tramite WebSocket (come bridge.js)
  - Esegue il matching fuzzy + aliases + disambiguation (come bridge_flask.py)
  - Espone le stesse REST API sulla porta 3000
  - Include il codice Modbus nella risposta → pronto per il passaggio al reale

Avvio:
  python bridge_unified.py

Dipendenze:
  pip install flask flask-cors python-dotenv websocket-client
"""

import os
import json
import threading
import time

import websocket          # pip install websocket-client
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
_last_state = None          # dict con data.STANZE aggiornato via WS
_ws_conn    = None          # websocket.WebSocketApp attivo
_ws_ok      = False         # True se connesso

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
    """Richiede lo stato aggiornato al simulatore."""
    if _ws_ok and _ws_conn:
        _ws_conn.send(json.dumps({
            "method": "get_state", "type": "*", "majordomo": "bridge"
        }))

def _send(payload: dict):
    """Invia un comando al WS. Lancia ConnectionError se non connesso."""
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
    """Risolve un alias nel nome canonico."""
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
    """Nomi alternativi per il matching di un device."""
    return [
        _norm(dev.get("nome", "")),
        _norm(dev.get("codice", {}).get("nome", "")),
        _norm(f"{stanza} {dev.get('nome', '')}"),
    ]

def _find_one(state: dict, name: str):
    """Trova il device più probabile (1 risultato)."""
    target = _canonicalize(name)

    # 1) match esatto
    for stanza, dev in _iter_devices(state):
        if target in _candidates(stanza, dev):
            return stanza, dev

    # 2) fuzzy (almeno 2 token in comune)
    best, best_sc = None, 0
    for stanza, dev in _iter_devices(state):
        sc = max(_score(target, c) for c in _candidates(stanza, dev))
        if sc > best_sc:
            best_sc, best = sc, (stanza, dev)

    return best if best and best_sc >= 2 else (None, None)

def _find_many(state: dict, name: str, tipo=None) -> list:
    """Trova tutti i device compatibili (usato per disambiguation)."""
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
    """True se la richiesta è generica (es. 'tapparelle cucina' senza specificare quale)."""
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
        "endpoints": ["GET /state", "POST /device/power", "POST /blind/set"]
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

    codice = dev.get("codice", {})

    try:
        _send({
            "method": "set_state",
            "type":   "*",
            "majordomo": "bridge",
            "data": {
                "codice": codice,        # ← usato dal layer Modbus reale
                "nome":   dev.get("nome"),
                "stato":  on
            }
        })
    except ConnectionError as e:
        return jsonify({"error": str(e)}), 503

    return jsonify({
        "ok":     True,
        "stanza": stanza,
        "nome":   dev.get("nome"),
        "on":     on,
        "codice": codice                 # ← utile per debug / futuro
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

    # Richiesta generica (es. "tapparelle cucina") → controlla se ambigua
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

    # Ricerca specifica
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
    codice = dev.get("codice", {})

    try:
        _send({
            "method": "set_state",
            "type":   "*",
            "majordomo": "bridge",
            "data": {
                "codice": codice,
                "nome":   dev.get("nome"),
                "stato":  value
            }
        })
    except ConnectionError as e:
        return jsonify({"error": str(e)}), 503

    return jsonify({
        "ok":     True,
        "stanza": stanza,
        "nome":   dev.get("nome"),
        "value":  value,
        "codice": codice
    })

# ── POST /climate/set ─────────────────────────────────────────────────────────
@app.post("/climate/set")
def _climate():
    with _lock:
        state = _last_state
    if not state:
        return jsonify({"error": "state not ready"}), 503

    body  = request.get_json(silent=True) or {}
    name  = body.get("name", "")
    on    = body.get("on", None)
    temp  = body.get("temperature", None)
    mode  = body.get("mode", None)

    if not name:
        return jsonify({"error": "name mancante"}), 400

    # Trova termostato (tipo 2)
    target = _canonicalize(name)
    found_stanza, found_dev = None, None

    for stanza, dev in _iter_devices(state):
        if dev.get("tipo") != 2:
            continue
        cands = _candidates(stanza, dev)
        if target in cands or max(_score(target, c) for c in cands) >= 1:
            found_stanza, found_dev = stanza, dev
            break

    if not found_dev:
        return jsonify({"error": f"termostato non trovato: {name}"}), 404

    codice = found_dev.get("codice", {})

    # Costruisce il payload di aggiornamento
    update = {"codice": codice, "nome": found_dev.get("nome")}
    if on is not None:
        update["attivo"] = bool(on)
    if temp is not None:
        try:
            update["temperatura_target"] = round(float(temp), 1)
        except Exception:
            return jsonify({"error": "temperatura non valida"}), 400
    if mode in ("riscaldamento", "raffrescamento"):
        update["modo"] = mode

    try:
        _send({
            "method":    "set_climate",
            "type":      "*",
            "majordomo": "bridge",
            "data":      update
        })
    except ConnectionError as e:
        return jsonify({"error": str(e)}), 503

    return jsonify({
        "ok":     True,
        "stanza": found_stanza,
        "nome":   found_dev.get("nome"),
        **update
    })

# ── GET /climate/state ─────────────────────────────────────────────────────────
@app.get("/climate/state")
def _climate_state():
    with _lock:
        state = _last_state
    if not state:
        return jsonify({"error": "state not ready"}), 503

    termostati = []
    for stanza, dev in _iter_devices(state):
        if dev.get("tipo") == 2:
            termostati.append({
                "stanza":              stanza,
                "nome":                dev.get("nome"),
                "attivo":              dev.get("attivo", False),
                "modo":                dev.get("modo", "riscaldamento"),
                "temperatura_target":  dev.get("temperatura_target"),
                "temperatura_attuale": dev.get("temperatura_attuale"),
            })

    return jsonify({"termostati": termostati})

# ── Avvio ──────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    _start_ws()
    threading.Thread(target=_refresh_loop, daemon=True).start()
    print(f"🚀 Bridge unificato su http://0.0.0.0:{PORT}")
    app.run(host="0.0.0.0", port=PORT, debug=False)