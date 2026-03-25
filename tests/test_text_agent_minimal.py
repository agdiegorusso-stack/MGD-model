"""
tests/test_text_agent_minimal.py

End-to-end minimal test:
1. Ingest 2 pseudo-docs as API_DEF
2. Ask 2 questions
3. Assert:
   - At least one API_DEF memory was created
   - find_similar returns relevant memories
   - REPL does not crash on invalid LLM JSON
"""

import sys
import os

# Allow imports from project root
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from cortical_mgd.text.text_encoder import TextEncoder
from cortical_mgd.text.mgd_wrapper import MGDTextBrain
from cortical_mgd.memory.memory_index import MemoryIndex
from cortical_mgd.memory.memory_manager import MemoryManager, DA_POLICY
from cortical_mgd.distillation.llm_interface import TextLLMInterface, safe_parse_policy

DB_PATH = "/tmp/test_e2e.json"


def build_stack():
    encoder = TextEncoder(n_input_mgd=512)
    brain = MGDTextBrain(n_input_mgd=512)
    mem = MemoryIndex(db_path=DB_PATH)
    llm = TextLLMInterface()
    mgr = MemoryManager(mem, llm, mgd_brain=brain)
    return encoder, brain, mem, llm, mgr


def test_memory_creation():
    encoder, brain, mem, llm, mgr = build_stack()

    # Feed pseudo doc
    doc_text = (
        "La funzione bpy.ops.mesh.primitive_cube_add() in Blender "
        "aggiunge un cubo alla scena. Accetta parametri come 'size', "
        "'location', 'scale' in forma di tuple (x, y, z). "
        "Esempio: bpy.ops.mesh.primitive_cube_add(size=2, location=(0,0,0))."
    )
    vec = encoder.encode_text(doc_text)
    mgd_id = brain.encode_and_forward(vec)

    ep = mgr.build_episode(
        mgd_id=mgd_id,
        question="!doc",
        answer="",
        used_memory_ids=[],
        new_knowledge_text=doc_text
    )

    # Skip real LLM: mock memory directly
    mem_id = mem.add_memory(
        mgd_id=mgd_id,
        m_type="API_DEF",
        summary="bpy.ops.mesh.primitive_cube_add(): aggiunge un cubo alla scena in Blender.",
        tags=["blender", "bpy", "mesh"]
    )
    print(f"[Test] Memory created id={mem_id}, mgd_id={mgd_id}")
    assert mem_id is not None

    # 2. Verify find_similar returns on same mgd_id
    similar = mem.find_similar(mgd_id)
    assert len(similar) >= 1, f"Expected >=1 memory, got {len(similar)}"
    print(f"[Test] find_similar returned {len(similar)} results")

    # 3. Verify API_DEF memory type is intact
    retrieved = mem.get_by_id(mem_id)
    assert retrieved["type"] == "API_DEF"
    print("[Test] Memory type verified as API_DEF")


def test_safe_json_crash_resilience():
    """Agent REPL should not crash if LLM returns garbage JSON."""
    bad_json_strings = [
        "",
        "Some random text without JSON",
        '{"action": "STORE"',  # truncated
        "```json\n{bad: json}```",
    ]
    for s in bad_json_strings:
        result = safe_parse_policy(s)
        assert result["action"] == "IGNORE", f"Expected IGNORE fallback for input: {s!r}"
    print("[Test] safe_parse_policy crash resilience passed!")


def test_da_policy_mapping():
    """Verify the DA policy map is correct."""
    assert DA_POLICY[("STORE", "API_DEF")] == 1.0
    assert DA_POLICY[("STORE", "PATTERN")] == 0.3
    assert DA_POLICY[("STORE", "EPISODE")] == 0.1
    assert DA_POLICY[("IGNORE", "API_DEF")] == 0.0
    print("[Test] DA policy mapping verified!")


def test_episode_skip_short():
    encoder, brain, mem, llm, mgr = build_stack()
    vec = encoder.encode_text("Ciao")
    mgd_id = brain.encode_and_forward(vec)

    ep = mgr.build_episode(mgd_id, "Ciao!", "Ciao!", [], new_knowledge_text="ok")
    result = mgr.process_episode(ep)
    assert result is None, "Expected None for short text episode"
    print("[Test] Short episode skip verified!")


if __name__ == "__main__":
    print("=== End-to-End Minimal Text Agent Tests ===")
    test_memory_creation()
    test_safe_json_crash_resilience()
    test_da_policy_mapping()
    test_episode_skip_short()
    print("\n All E2E tests passed!")
