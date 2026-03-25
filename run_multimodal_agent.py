
#!/usr/bin/env python3
"""
run_multimodal_agent.py — Orchestratore Hybrid MGD-LLM Agent
=============================================================
Architettura a 4 thread:
  T1: WebcamThread   -> cattura frame, genera spike, inferenza SNN (10 FPS gate)
  T2: InputThread    -> ascolta input utente da tastiera (felice:<nome>, ask:<q>)
  T3: LLMThread      -> gestisce query Ollama (asincrona, non blocca T1)
  T4: VoiceThread    -> trascrizione vocale con Whisper locale (RTX accelerato)

Comandi vocali:
  "felice [nome]"  -> spike dopamina + binding oggetto corrente al nome
  "chiedi [testo]" -> invia domanda all'LLM con contesto visivo MGD
  qualsiasi altra frase -> inviata direttamente come ask:

Comandi da tastiera (InputThread):
  felice:<nome>   -> spike dopamina + binding oggetto corrente al nome
  ask:<domanda>   -> invia domanda all'LLM con contesto visivo MGD
  quit            -> spegne l'agente

Dipendenze:
  pip install opencv-python numpy requests torch openai-whisper sounddevice scipy
  ollama serve  (in un terminale separato)
"""

import os
import sys
import json
import time
import queue
import threading
import hashlib

import cv2
import numpy as np
import torch

# ──────────────────────────────────────────────────────────────────────────────
# Path setup
# ──────────────────────────────────────────────────────────────────────────────
_ROOT = os.path.dirname(os.path.abspath(__file__))
if _ROOT not in sys.path:
    sys.path.insert(0, _ROOT)

from cortical_mgd.neurons.spike_encoder import WebcamSpikeAdapter
from cortical_mgd.architecture.bio_mgd_brain import BioMGDBrain
from cortical_mgd.plasticity.bio_readout import DopamineController
from cortical_mgd.distillation.llm_interface import MGDLLMBridge

# ──────────────────────────────────────────────────────────────────────────────
# Persistenza oggetti su disco
# ──────────────────────────────────────────────────────────────────────────────
OBJECT_DB_PATH = os.path.join(_ROOT, "mgd_object_db.json")


def load_object_db() -> dict:
    if os.path.exists(OBJECT_DB_PATH):
        with open(OBJECT_DB_PATH, encoding="utf-8") as f:
            return json.load(f)
    return {}


def save_object_db(db: dict) -> None:
    with open(OBJECT_DB_PATH, "w", encoding="utf-8") as f:
        json.dump(db, f, indent=2, ensure_ascii=False)


# ──────────────────────────────────────────────────────────────────────────────
# Wrapper compatibilità BioMGDBrain
# ──────────────────────────────────────────────────────────────────────────────
def brain_infer(brain: BioMGDBrain, spike_train_np: np.ndarray,
                task_id: int = 0) -> torch.Tensor:
    """
    Converte spike_train numpy (784,) in tensore PyTorch,
    gestisce la registrazione del task_id al primo utilizzo,
    e ritorna l'output h3 (200-dim) come tensore CPU.
    """
    x = torch.tensor(spike_train_np, dtype=torch.float32).unsqueeze(0)  # (1, 784)
    with torch.no_grad():
        if task_id not in brain.task_routing:
            brain.route_by_srt(task_id, h_hip=None)
        _h_hip, _h1, _h2, h3 = brain.forward(x, task_id)
    return h3.squeeze(0)  # (200,)


def topology_signature(h3: torch.Tensor) -> str:
    """
    Genera un ID stabile dalla topologia SNN corrente.
    Usa l'argmax delle aree di attivazione come fingerprint leggero.
    """
    top_k = torch.topk(h3, k=10).indices.sort().values.tolist()
    key = "_".join(str(i) for i in top_k)
    return hashlib.md5(key.encode()).hexdigest()[:12]


def find_closest_object(object_db: dict, signature: str,
                         h3: torch.Tensor) -> tuple[str | None, str | None]:
    """
    Cerca corrispondenza nel DB (prima per signature esatta, poi per similarità).
    Ritorna (object_name, emotion) oppure (None, None).
    """
    # 1. Match esatto sulla firma
    if signature in object_db:
        entry = object_db[signature]
        return entry["name"], entry.get("emotion", "Felicita'")

    # 2. Fallback: coseno sulla h3 salvata (se disponibile)
    if not object_db:
        return None, None

    best_sim = 0.7  # soglia minima di riconoscimento
    best_name = None
    best_emotion = None
    for _sig, entry in object_db.items():
        saved_h3 = entry.get("h3")
        if saved_h3 is None:
            continue
        stored = torch.tensor(saved_h3, dtype=torch.float32)
        sim = float(torch.nn.functional.cosine_similarity(
            h3.unsqueeze(0), stored.unsqueeze(0)))
        if sim > best_sim:
            best_sim = sim
            best_name = entry["name"]
            best_emotion = entry.get("emotion", "Felicita'")

    # Se non supera la soglia o DB vuoto, restituisce None
    if best_name is None:
        return None, None

    return best_name, best_emotion


# ──────────────────────────────────────────────────────────────────────────────
# Stato condiviso (thread-safe)
# ──────────────────────────────────────────────────────────────────────────────
class SharedState:
    def __init__(self):
        self.lock = threading.Lock()
        self.current_object_name: str | None = None
        self.current_emotion: str | None = None
        self.pending_label: str | None = None       # nome in attesa di binding
        self.last_h3: torch.Tensor | None = None    # topologia corrente
        self.llm_queue: queue.Queue = queue.Queue(maxsize=5)
        self.shutdown: threading.Event = threading.Event()


# ──────────────────────────────────────────────────────────────────────────────
# T1: WEBCAM THREAD
# ──────────────────────────────────────────────────────────────────────────────
def webcam_thread(state: SharedState, brain: BioMGDBrain,
                  da_ctrl: DopamineController, object_db: dict):
    adapter = WebcamSpikeAdapter(target_size=(28, 28), threshold=30)
    cap = cv2.VideoCapture(0)
    cap.set(cv2.CAP_PROP_FPS, 10)

    if not cap.isOpened():
        print("[CAM] ERRORE: impossibile aprire la webcam (device 0).")
        state.shutdown.set()
        return

    print("[CAM] Webcam avviata. Premi Q sulla finestra per uscire.")
    frame_interval = 1.0 / 10
    task_id = 0  # task univoco per questo agente (routing singolo-task)

    while not state.shutdown.is_set():
        t0 = time.time()
        ret, frame = cap.read()
        if not ret:
            time.sleep(0.05)
            continue

        spike_train, motion_density = adapter.process_frame(frame)

        # ── Keyframe: elabora SNN solo se c'è movimento ──────────────────────
        if spike_train is not None:
            try:
                h3 = brain_infer(brain, spike_train, task_id)
                sig = topology_signature(h3)
                obj_name, emotion = find_closest_object(object_db, sig, h3)

                with state.lock:
                    state.current_object_name = obj_name
                    state.current_emotion = emotion
                    state.last_h3 = h3

                # ── Binding Felicità -> Memoria ───────────────────────────────
                if da_ctrl.is_plastic():
                    with state.lock:
                        label = state.pending_label
                    if label:
                        object_db[sig] = {
                            "name": label,
                            "emotion": "Felicita'",
                            "h3": h3.tolist(),
                        }
                        save_object_db(object_db)
                        print(f"[MGD] ✅ Memorizzato: sig={sig} -> '{label}'")
                        with state.lock:
                            state.pending_label = None

            except Exception as e:
                print(f"[CAM] Errore inferenza SNN: {e}")

        # Decadimento DA ogni frame
        da_ctrl.decay_step()

        # ── Overlay visivo ───────────────────────────────────────────────────
        with state.lock:
            obj_display = state.current_object_name or "---"
        da_val = da_ctrl.eta_mgd
        label_str = f"DA={da_val:.2f} | obj={obj_display} | mot={motion_density:.3f}"
        cv2.putText(frame, label_str, (10, 30),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 0), 2)
        cv2.imshow("MGD Agent Vision", frame)
        if cv2.waitKey(1) & 0xFF == ord("q"):
            state.shutdown.set()
            break

        elapsed = time.time() - t0
        sleep_t = frame_interval - elapsed
        if sleep_t > 0:
            time.sleep(sleep_t)

    cap.release()
    cv2.destroyAllWindows()
    print("[CAM] Thread terminato.")


# ──────────────────────────────────────────────────────────────────────────────
# T2: INPUT THREAD
# ──────────────────────────────────────────────────────────────────────────────
def input_thread(state: SharedState, da_ctrl: DopamineController):
    """
    Legge comandi dal terminale.
    Futuro: sostituire input() con Whisper STT locale.

    Comandi:
      felice:<nome>  -> spike DA + binding oggetto corrente
      ask:<domanda>  -> invia domanda all'LLM con contesto MGD
      quit           -> shutdown
    """
    print("[INPUT] Thread attivo.")
    print("  Comandi: 'felice:<nome>' | 'ask:<domanda>' | 'quit'")
    while not state.shutdown.is_set():
        try:
            cmd = input().strip()
        except EOFError:
            break

        if not cmd:
            continue

        if cmd.lower() == "quit":
            state.shutdown.set()
            break

        elif cmd.lower().startswith("felice:"):
            label = cmd[7:].strip()
            if not label:
                print("[INPUT] Specifica un nome dopo 'felice:'")
                continue
            with state.lock:
                state.pending_label = label
            da_ctrl.trigger_happiness(label)

        elif cmd.lower().startswith("ask:"):
            question = cmd[4:].strip()
            with state.lock:
                obj_name = state.current_object_name
                emotion = state.current_emotion
            try:
                state.llm_queue.put_nowait({
                    "question": question,
                    "object": obj_name,
                    "emotion": emotion or "Felicita'",
                })
            except queue.Full:
                print("[LLM] Queue piena, riprova tra un momento.")

        else:
            print(f"[INPUT] Comando non riconosciuto: '{cmd}'")
            print("  Comandi validi: 'felice:<nome>' | 'ask:<domanda>' | 'quit'")

    print("[INPUT] Thread terminato.")


# ──────────────────────────────────────────────────────────────────────────────
# T3: LLM THREAD
# ──────────────────────────────────────────────────────────────────────────────
def llm_thread(state: SharedState, bridge: MGDLLMBridge):
    print("[LLM] Thread Ollama attivo.")
    while not state.shutdown.is_set():
        try:
            task = state.llm_queue.get(timeout=1.0)
        except queue.Empty:
            continue

        question = task["question"]
        obj_name = task.get("object")
        emotion = task.get("emotion", "Felicita'")

        if obj_name:
            print(f"[LLM] Domanda: '{question}' | oggetto in vista: '{obj_name}'")
        else:
            print(f"[LLM] Domanda: '{question}' | nessun oggetto riconosciuto")

        response = bridge.query(user_text=question, object_name=obj_name,
                                emotion=emotion)
        print(f"\n{'='*60}\n[AGENTE]: {response}\n{'='*60}\n")

        state.llm_queue.task_done()

    print("[LLM] Thread terminato.")


# ──────────────────────────────────────────────────────────────────────────────
# T4: VOICE THREAD (Whisper STT locale)
# ──────────────────────────────────────────────────────────────────────────────
def voice_thread(state: SharedState, da_ctrl: DopamineController,
                 model_size: str = "base"):
    """
    Registra audio dal microfono in chunk da 5 secondi, trascrive con Whisper
    (locale, RTX-accelerato se CUDA disponibile), ed esegue la logica:
      - frase con 'felice' / 'felicita'  -> trigger DA + nome estratto
      - frase con 'chiedi' / 'domanda'   -> invia all'LLM
      - qualsiasi altra frase            -> inviata come ask: all'LLM
    """
    try:
        import whisper
        import sounddevice as sd
        import scipy.io.wavfile as wavfile
        import tempfile
    except ImportError as e:
        print(f"[VOICE] Dipendenza mancante: {e}. Installa: pip install openai-whisper sounddevice scipy")
        return

    device = "cuda" if torch.cuda.is_available() else "cpu"
    print(f"[VOICE] Carico modello Whisper '{model_size}' su {device}...")
    model = whisper.load_model(model_size, device=device)
    print("[VOICE] Whisper pronto. Sto ascoltando... (parla liberamente!)")

    SAMPLE_RATE = 16000
    CHUNK_SECS = 5

    while not state.shutdown.is_set():
        try:
            # Registra CHUNK_SECS secondi di audio
            audio = sd.rec(int(CHUNK_SECS * SAMPLE_RATE), samplerate=SAMPLE_RATE,
                           channels=1, dtype='float32')
            sd.wait()

            if state.shutdown.is_set():
                break

            # Trascrivi con Whisper
            audio_np = audio.squeeze()
            result = model.transcribe(audio_np, language="it", fp16=(device == "cuda"))
            text = result["text"].strip()

            if not text:
                continue

            # Filtro base per le allucinazioni di Whisper sul silenzio
            text_lower = text.lower()
            if len(text) < 3:
                continue
            if any(hallucination in text_lower for hallucination in [
                "sottotitoli creati da", "sottotitoli di", "iscriviti al canale",
                "amara.org", "grazie per la visione", "mentre", "樂", "»", "€", "$"
            ]) or text.count(".") > 4 or text.count("£") > 0:
                print(f"[VOICE] Ignorato (probabile silenzio/rumore): '{text}'")
                continue

            print(f"[VOICE] Trascritto: '{text}'")

            # Parsing comandi vocali
            if any(kw in text_lower for kw in ["felice", "felicit", "mi rende felice", "sono felice"]):
                # Estrai il nome: tutto quello dopo 'questo e'' / 'si chiama' / 'e'' / 'felice'
                import re
                # Pattern: "questo è [nome]" / "si chiama [nome]" / "[nome] mi rende felice"
                patterns = [
                    r"questo[\s\w]*(?:si chiama|è|e')\s+([\w\s]+?)(?:\s+mi|\s+e|$)",
                    r"([\w\s]+?)\s+mi rende felice",
                    r"(?:chiama|chiamato|chiamata)\s+([\w\s]+)",
                ]
                label = None
                for pat in patterns:
                    m = re.search(pat, text_lower)
                    if m:
                        label = m.group(1).strip().title()
                        break
                if not label:
                    # Fallback: chiedi all'utente
                    print("[VOICE] Non ho capito il nome. Digita 'felice:<nome>' nel terminale.")
                    continue
                with state.lock:
                    state.pending_label = label
                da_ctrl.trigger_happiness(label)

            elif any(kw in text_lower for kw in ["chiedi", "domanda", "dimmi", "sai"]):
                # Rimuovi la parola trigger e invia il resto
                for kw in ["chiedi", "domanda", "dimmi"]:
                    text = text.replace(kw, "").replace(kw.capitalize(), "").strip()
                with state.lock:
                    obj_name = state.current_object_name
                    emotion = state.current_emotion
                try:
                    state.llm_queue.put_nowait({
                        "question": text,
                        "object": obj_name,
                        "emotion": emotion or "Felicita'",
                    })
                except queue.Full:
                    print("[VOICE] LLM Queue piena.")

            else:
                # Qualsiasi altra frase -> invia come domanda con contesto visivo
                with state.lock:
                    obj_name = state.current_object_name
                    emotion = state.current_emotion
                try:
                    state.llm_queue.put_nowait({
                        "question": text,
                        "object": obj_name,
                        "emotion": emotion or "Felicita'",
                    })
                except queue.Full:
                    pass

        except Exception as e:
            if not state.shutdown.is_set():
                print(f"[VOICE] Errore: {e}")

    print("[VOICE] Thread terminato.")


# ──────────────────────────────────────────────────────────────────────────────
# MAIN
# ──────────────────────────────────────────────────────────────────────────────
def main():
    print("=" * 60)
    print("  Hybrid MGD-LLM Multimodal Agent — avvio...")
    print("=" * 60)

    object_db = load_object_db()
    state = SharedState()

    brain = BioMGDBrain(input_dim=784, device="cpu")
    da_ctrl = DopamineController(base_da=0.1, happy_boost=0.9, decay_rate=0.015)
    llm_bridge = MGDLLMBridge(model="gpt-oss")

    if llm_bridge.is_available():
        print("[LLM] Ollama disponibile. Bridge attivo.")
    else:
        print("[LLM] ATTENZIONE: Ollama non disponibile. Risposte LLM disabilitate.")

    threads = [
        threading.Thread(
            target=webcam_thread,
            args=(state, brain, da_ctrl, object_db),
            name="WebcamThread",
            daemon=True,
        ),
        threading.Thread(
            target=input_thread,
            args=(state, da_ctrl),
            name="InputThread",
            daemon=False,  # non-daemon: aspetta che l'utente esca
        ),
        threading.Thread(
            target=llm_thread,
            args=(state, llm_bridge),
            name="LLMThread",
            daemon=True,
        ),
        threading.Thread(
            target=voice_thread,
            args=(state, da_ctrl, "base"),
            name="VoiceThread",
            daemon=True,
        ),
    ]

    for t in threads:
        t.start()

    try:
        while not state.shutdown.is_set():
            time.sleep(0.5)
    except KeyboardInterrupt:
        print("\n[MAIN] Interruzione manuale (CTRL+C).")
        state.shutdown.set()

    try:
        for t in threads:
            t.join(timeout=4.0)
    except KeyboardInterrupt:
        pass  # secondo CTRL+C: esci subito

    print("[MAIN] Agente terminato. Ciao!")


if __name__ == "__main__":
    main()
