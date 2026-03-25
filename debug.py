import numpy as np
from cortical_mgd.text.text_encoder import TextEncoder

e = TextEncoder()
def get_idx(text):
    s = e.text_to_sdr_spikes(text, 512, 15, 1) # top_k=15
    return set(np.where(s[0]==1)[1])

i1 = get_idx("la fisica quantistica è affascinante")
i2 = get_idx("il mio nome è Diego")
i3 = get_idx("le rose son rosse le viole son blu")

print("Fisica vs Nome overlap:", len(i1 & i2))
print("Fisica vs Poesia overlap:", len(i1 & i3))
print("Nome vs Poesia overlap:", len(i2 & i3))
print(i1)
print(i2)
print(i3)
