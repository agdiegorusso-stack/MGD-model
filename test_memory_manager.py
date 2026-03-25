from cortical_mgd.memory.memory_index import MemoryIndex
from cortical_mgd.memory.memory_manager import MemoryManager
from cortical_mgd.distillation.llm_interface import TextLLMInterface, safe_parse_policy

def test_da_policy():
    mem = MemoryIndex(db_path="/tmp/test_manager.json")
    llm = TextLLMInterface()
    mgr = MemoryManager(mem, llm)
        
    # Simulate a mock STORE/API_DEF policy
    from cortical_mgd.memory.memory_manager import DA_POLICY
    delta = DA_POLICY.get(("STORE", "API_DEF"), -1)
    assert delta == 1.0, f"Expected 1.0, got {delta}"
    delta2 = DA_POLICY.get(("STORE", "PATTERN"), -1)
    assert delta2 == 0.3, f"Expected 0.3, got {delta2}"
    delta3 = DA_POLICY.get(("IGNORE", "EPISODE"), -1)
    assert delta3 == 0.0, f"Expected 0.0, got {delta3}"
    print("DA policy mapping test passed!")

def test_skip_short_text():
    mem = MemoryIndex(db_path="/tmp/test_manager.json")
    llm = TextLLMInterface()
    mgr = MemoryManager(mem, llm)
    
    ep = mgr.build_episode("id_test", "Ciao!", "Ciao a te!", [], new_knowledge_text="Breve.")
    result = mgr.process_episode(ep)
    assert result is None, "Expected None for short text"
    print("Short text skip test passed!")

def test_safe_parse_fallback():
    result = safe_parse_policy("Not JSON at all!!!")
    assert result["action"] == "IGNORE"
    assert result["type"] == "EPISODE"
    print("Safe parse fallback test passed!")

if __name__ == "__main__":
    test_da_policy()
    test_skip_short_text()
    test_safe_parse_fallback()
    print("All MemoryManager tests passed!")
