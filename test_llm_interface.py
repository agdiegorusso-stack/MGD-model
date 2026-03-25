from cortical_mgd.distillation.llm_interface import TextLLMInterface

def main():
    print("Testing TextLLMInterface...")
    llm = TextLLMInterface()
    
    # Test query_dialogue
    ans = llm.query_dialogue("Ciao!", "[MEMORIE_RILEVANTI]\nNessuna.")
    print(f"Dialogue response: {ans}")
    
    # Test Policy Parsing
    meta_prompt = "Test fallback policy parsing."
    pol = llm.query_memory_policy(meta_prompt)
    print(f"Policy parsed dict: {pol}")
    
    # The output should be a valid dict matching MemoryPolicyResponse structure
    assert isinstance(pol, dict)
    assert "action" in pol
    assert "summary" in pol
    assert "type" in pol
    assert "tags" in pol
    assert "target_memory_id" in pol
    print("Success LLM interface basic test!")

if __name__ == "__main__":
    main()
