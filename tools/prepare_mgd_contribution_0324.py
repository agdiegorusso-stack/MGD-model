"""Remove only relational MGD evolution and ranking from the pinned app.
Generated code is an experimental control; it is never built into the APK.
"""
from pathlib import Path
import hashlib,json,subprocess
app=Path("mgd-neuro-app")
source=app/"lib/relational_memory_v0324.dart"
frozen="336848c817d3fbed5c6b5906ff085d262d21e914"
raw=source.read_bytes()
assert raw==subprocess.check_output(["git","show",frozen+":"+str(source)])
s=raw.decode()
def replace_block(text,start,end,replacement):
    assert text.count(start)==1 and text.count(end)==1
    a=text.index(start);b=text.index(end,a)
    return text[:a]+replacement+text[b:]
s=s.replace("import 'native_mgd_engine_v09.dart';\n","")
s=replace_block(s,"  static void _evolve(","  static void _bump(",
    "  static void _evolve(Map<String,dynamic> r,{required double reward}) {}\n")
s=replace_block(s,"  static List<Map<String,dynamic>> find(","  /// Preserve the pre-existing",
    """  static List<Map<String,dynamic>> find(ResearchMemory11 m,Frame324 q,
      {bool mgd=true}) {
    final index=_indexes[m]??=_FrameIndex324(rows(m,includeHistory:false));
    final candidates=index.find(q);
    candidates.sort((a,b)=>(b['sequence'] as num).compareTo(a['sequence'] as num));
    return candidates;
  }
""")
s=s.replace("RelationalMemory324","NoMgdMemory324")
assert "MgdMath09" not in s
assert "native_mgd_engine" not in s
out=app/"lib/ablation_no_mgd_v0324.dart"
out.write_text(s)
test=Path("tools/mgd_contribution_0324_test.dart")
(app/"tool/mgd_contribution_0324_test.dart").write_bytes(test.read_bytes())
metadata={
    "frozenAppCommit":frozen,
    "sourceSha256":hashlib.sha256(raw).hexdigest(),
    "ablatedSha256":hashlib.sha256(out.read_bytes()).hexdigest(),
    "ablatedComponents":["MgdMath09.evolve on every insert and correction","MgdMath09.strength in ranking"],
    "retainedComponents":["reader and weights","fact extraction","versioning","deduplication","source provenance","indices","conflict handling","query formatting","serialization"],
    "scope":"Only RelationalMemory324, not all graph or brain subsystems",
}
Path("mgd-contribution-manifest-0324.json").write_text(json.dumps(metadata,indent=2))
print("ABLATION_MANIFEST "+json.dumps(metadata),flush=True)
