from cortical_mgd.memory.memory_index import MemoryIndex
import os

def main():
    print("Testing MemoryIndex...")
    index = MemoryIndex()
    
    # 1. Add
    mem_id = index.add_memory(
        mgd_id="L3_cluster_42",
        m_type="API_DEF",
        summary="Test API per MGD text index.",
        tags=["test", "mgd"],
    )
    print(f"Added memory with ID: {mem_id}")
    
    # 2. Get
    rec = index.get_by_id(mem_id)
    assert rec is not None
    assert rec["summary"] == "Test API per MGD text index."
    print("Memory retrieval passed.")
    
    # 3. Update
    index.update_memory(mem_id, {"summary": "Updated summary"})
    rec2 = index.get_by_id(mem_id)
    assert rec2["summary"] == "Updated summary"
    print("Memory update passed.")
    
    # 4. Find similar
    sim = index.find_similar("L3_cluster_42")
    assert len(sim) > 0
    print(f"Found {len(sim)} similar memories (Version 0 matching passed).")
    
    print("Success MemoryIndex test!")

if __name__ == "__main__":
    main()
