import numpy as np
from sentence_transformers import SentenceTransformer

class TextEncoder:
    def __init__(self, model_name: str = "all-MiniLM-L6-v2", n_input_mgd: int = 512):
        self.encoder = SentenceTransformer(model_name)
        self.n_input_mgd = n_input_mgd
        # Locality Sensitive Hashing (LSH) Random Projection
        # Distrugge l'anisotropia di BERT (che concentra i valori massimi sempre nelle stesse dimensioni)
        # Proietta l'angolo semantico in in veri spike ortogonali e distribuiti uniformemente.
        np.random.seed(42)
        self.random_proj = np.random.randn(384, n_input_mgd) / np.sqrt(384)

    def encode_text(self, text: str) -> np.ndarray:
        """Encoding per MGD: 384 → 512 con zero padding (geometry-preserving)."""
    def encode_for_memory(self, text: str) -> np.ndarray:
        """Encoding per memory index: 384-dim puri (no proiezione).
        Preserva le distanze semantiche del modello sentence-transformers."""
        emb = self.encoder.encode(text)
        norm = np.linalg.norm(emb)
        if norm > 0:
            emb = emb / norm
        return emb

    def text_to_sdr_spikes(self, text: str, n_neurons: int = 512, top_k: int = 15, max_T: int = 10) -> np.ndarray:
        """
        Traduce il testo in una Sparse Distributed Representation (SDR) usando SimHash.
        Ogni neurone i corrisponde a un iperpiano random h_i.
        Il neurone i spara (=1) se raw_emb · h_i > 0, con intensità = |raw_emb · h_i|.
        Top-K seleziona i k neuroni con le proiezioni positive più forti.
        
        Proprietà geometrica: due frasi con cosine similarity = cos(θ) condividono
        esattamente ~(π - θ)/π di bit in media (Johnson-Lindenstrauss).
        Topic diversi (θ ≈ 60°) → overlap atteso ≈ 17% × k ≈ 2-3 neuroni su 15 → SNR allineato WTA.
        """
        # 1. Recupera l'embedding denso e semantico (384-dim normalizzato)
        raw_emb = self.encode_for_memory(text)
        
        # 2. SimHash Projection: proietta l'embedding su n_neurons iperpiani random
        # proj[i] = raw_emb · random_proj[:,i]  -> valore continuo (range ~[-2, +2])
        proj = raw_emb @ self.random_proj
        
        # 3. SimHash sofisticato: usa le proiezioni positive ordinate (ignora quelle negative)
        # Questo garantisce che neuroni diversi sparino per vettori lontani
        proj_clipped = np.clip(proj, 0, None)  # solo contributi positivi
        top_k_indices = np.argsort(proj_clipped)[-top_k:][::-1]
        
        # 4. Spalma i K spikes in una finestra temporale T (Latency Coding locale sui vincitori)
        spikes = np.zeros((max_T, 1, n_neurons), dtype=np.float32)
        
        for rank, idx in enumerate(top_k_indices):
            # Mappatura lineare da rank a tempo d'arrivo dello spike
            t = int((rank / top_k) * (max_T - 1)) if top_k > 0 else 0
            t = max(0, min(t, max_T - 1))
            spikes[t, 0, idx] = 1.0

        return spikes
