from cortical_mgd.text.text_encoder import TextEncoder
from cortical_mgd.text.mgd_wrapper import MGDTextBrain

def main():
    print("Testing TextEncoder and MGDTextBrain...")
    encoder = TextEncoder(n_input_mgd=512)
    brain = MGDTextBrain(n_input_mgd=512)
    
    test_str = "Questa e' una prova di testo per l'encoder MGD."
    vec = encoder.encode_text(test_str)
    
    print(f"Encoded vector shape: {vec.shape}")
    assert vec.shape == (512,), "Shape mismatch"
    
    mgd_id = brain.encode_and_forward(vec)
    print(f"MGD ID generated: {mgd_id}")
    assert isinstance(mgd_id, str), "ID must be a string"
    print("Success!")

if __name__ == "__main__":
    main()
