from flask import Flask, jsonify, request
from flask_cors import CORS
import json
import os

app = Flask(__name__)
CORS(app)

STATE_PATH = os.path.join(os.path.dirname(__file__), "state_clean.json")
ALIASES_PATH = os.path.join(os.path.dirname(__file__), "aliases.json")


# -------------------- file helpers --------------------

def load_state():
    with open(STATE_PATH, "r", encoding="utf-8") as f:
        return json.load(f)

def save_state(state):
    with open(STATE_PATH, "w", encoding="utf-8") as f:
        json.dump(state, f, ensure_ascii=False, indent=2)

def load_aliases():
    if not os.path.exists(ALIASES_PATH):
        return {}
    with open(ALIASES_PATH, "r", encoding="utf-8") as f:
        return json.load(f)


# -------------------- normalization / matching --------------------

def norm(s):
    return " ".join(str(s).lower().split()).strip()

def iter_stanze_devices(state):
    stanze = state.get("data", {}).get("STANZE", {})
    for stanza, devices in stanze.items():
        if isinstance(devices, list):
            for dev in devices:
                if isinstance(dev, dict):
                    yield stanza, dev

def is_generic_blind_request(name, state):
    """
    True se l'utente dice una cosa tipo:
    - "tapparella cucina"
    - "tapparelle cucina"
    e NON specifica quale (sud/lavandino/portafinestra/finestra...).
    """
    t = set(tokenize(name))

    # deve contenere tapparella/e
    if "tapparella" not in t and "tapparelle" not in t:
        return False

    # parole che rendono la richiesta "specifica"
    specific_words = {"sud", "nord", "est", "ovest", "lavandino", "portafinestra", "finestra", "botola", "ingresso"}
    if len(t & specific_words) > 0:
        return False

    # se contiene il nome di una stanza, allora è generica per quella stanza
    stanze = state.get("data", {}).get("STANZE", {})
    for stanza in stanze.keys():
        stanza_tokens = set(tokenize(stanza))
        if stanza_tokens and stanza_tokens.issubset(t):
            return True

    return False

def blinds_in_room(state, room_query):
    """
    Ritorna tutte le tapparelle (tipo==1) della stanza indicata nel testo.
    """
    t = set(tokenize(room_query))
    matches = []
    stanze = state.get("data", {}).get("STANZE", {})

    for stanza, devices in stanze.items():
        stanza_tokens = set(tokenize(stanza))
        if stanza_tokens and stanza_tokens.issubset(t):
            # stanza matchata: prendi tutte le tapparelle
            if isinstance(devices, list):
                for dev in devices:
                    if isinstance(dev, dict) and dev.get("tipo") == 1:
                        matches.append((stanza, dev))
            break

    return matches


def tokenize(s):
    return [x for x in norm(s).split(" ") if x]

def score_match(target, candidate):
    # punteggio: quante parole del target sono presenti nel candidate
    t = set(tokenize(target))
    c = set(tokenize(candidate))
    if not t or not c:
        return 0
    return len(t & c)

def canonicalize_with_aliases(name):
    target = norm(name)
    aliases = load_aliases()

    # se l’utente dice già il canonico
    for canonical in aliases.keys():
        if target == norm(canonical):
            return norm(canonical)

    # se l’utente dice un sinonimo
    for canonical, syns in aliases.items():
        for s in syns:
            if target == norm(s):
                return norm(canonical)

    return target

def device_candidates(stanza, dev):
    dev_nome = norm(dev.get("nome", ""))
    cod_nome = norm(dev.get("codice", {}).get("nome", ""))
    stanza_nome = norm(f"{stanza} {dev.get('nome','')}")
    return [dev_nome, cod_nome, stanza_nome]

def find_device(state, name):
    """
    Trova 1 device "migliore" (usato per device/power e per query precise).
    """
    target = canonicalize_with_aliases(name)

    # 1) match esatto
    for stanza, dev in iter_stanze_devices(state):
        cands = device_candidates(stanza, dev)
        if target in cands:
            return stanza, dev

    # 2) fuzzy per parole
    best = None
    best_score = 0

    for stanza, dev in iter_stanze_devices(state):
        for cand in device_candidates(stanza, dev):
            sc = score_match(target, cand)
            if sc > best_score:
                best_score = sc
                best = (stanza, dev)

    # soglia per evitare match sbagliati
    if best and best_score >= 2:
        return best[0], best[1]

    return None, None

def find_devices(state, name, *, tipo=None):
    """
    Trova PIÙ possibili device (utile per disambiguazione).
    - tipo: se impostato, filtra per tipo (es. 1 = tapparella)
    """
    target = canonicalize_with_aliases(name)

    found = []
    for stanza, dev in iter_stanze_devices(state):
        if tipo is not None and dev.get("tipo") != tipo:
            continue

        # matching più permissivo: contiene oppure fuzzy
        cands = device_candidates(stanza, dev)

        contains_hit = any(target and (target in cand) for cand in cands)
        fuzzy_hit = max(score_match(target, cand) for cand in cands) >= 2

        if contains_hit or fuzzy_hit:
            found.append((stanza, dev))

    # rimuove duplicati (capita se due regole colpiscono uguale)
    unique = []
    seen = set()
    for stanza, dev in found:
        key = (stanza, norm(dev.get("codice", {}).get("nome", "")) or norm(dev.get("nome", "")))
        if key not in seen:
            seen.add(key)
            unique.append((stanza, dev))

    return unique


# -------------------- routes --------------------

@app.get("/")
def home():
    return jsonify({
        "status": "OK",
        "message": "bridge attivo",
        "endpoints": [
            "GET /state",
            "POST /device/power  {name, on}",
            "POST /blind/set     {name, value}"
        ]
    })

@app.get("/state")
def get_state():
    return jsonify(load_state())

@app.post("/device/power")
def device_power():
    payload = request.get_json(silent=True) or {}
    name = payload.get("name", "")
    on = bool(payload.get("on", False))

    if not name:
        return jsonify({"error": "name mancante"}), 400

    state = load_state()
    stanza, dev = find_device(state, name)
    if not dev:
        return jsonify({"error": f"dispositivo non trovato: {name}"}), 404

    # Solo dispositivi non-tapparella
    if dev.get("tipo") == 1:
        return jsonify({"error": "questo è una tapparella: usa /blind/set"}), 400

    dev["stato"] = on
    dev["statoDevice"] = True

    save_state(state)
    return jsonify({"ok": True, "stanza": stanza, "name": name, "on": on})

@app.post("/blind/set")
def blind_set():
    payload = request.get_json(silent=True) or {}
    name = payload.get("name", "")
    value = payload.get("value", None)

    if not name:
        return jsonify({"error": "name mancante"}), 400
    if value is None:
        return jsonify({"error": "value mancante"}), 400

    try:
        value = int(round(float(value)))
    except Exception:
        return jsonify({"error": "value non numerico"}), 400

    value = max(0, min(100, value))

    state = load_state()

    # DISAMBIGUAZIONE: "tapparella cucina" -> tutte le tapparelle della stanza
    if is_generic_blind_request(name, state):
        matches = blinds_in_room(state, name)

        if len(matches) > 1:
            options = []
            for stanza, dev in matches:
                canon = dev.get("codice", {}).get("nome") or f"{stanza} {dev.get('nome','')}"
                options.append({"stanza": stanza, "nome": canon})

            return jsonify({
                "error": "ambiguous",
                "message": "più tapparelle nella stanza",
                "requestedValue": value,
                "options": options
            }), 409


    # Qui facciamo disambiguazione: cerca TUTTE le tapparelle compatibili
    matches = find_devices(state, name, tipo=1)

    if len(matches) == 0:
        return jsonify({"error": f"tapparella non trovata: {name}"}), 404

    if len(matches) > 1:
        options = []
        for stanza, dev in matches:
            # nome "canonico" umano: preferisci codice.nome, altrimenti stanza+nome
            canon = dev.get("codice", {}).get("nome") or f"{stanza} {dev.get('nome','')}"
            options.append({
                "stanza": stanza,
                "nome": canon
            })

        return jsonify({
            "error": "ambiguous",
            "message": "più tapparelle corrispondono",
            "requestedValue": value,
            "options": options
        }), 409

    stanza, dev = matches[0]

    # sicurezza: se per qualche motivo non è tapparella, blocca
    if dev.get("tipo") != 1:
        return jsonify({"error": "questo non è una tapparella: usa /device/power"}), 400

    dev["stato"] = value
    dev["statoDevice"] = True

    save_state(state)
    return jsonify({"ok": True, "stanza": stanza, "name": name, "value": value})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)
