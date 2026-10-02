from pathlib import Path
import sys
root=Path(sys.argv[1] if len(sys.argv)>1 else 'mgd-neuro-app')
def edit(path, marker, changes):
 p=root/path; s=p.read_text()
 if marker in s:return
 for old,new in changes:
  if s.count(old)!=1:raise ValueError((path,old[:100],s.count(old)))
  s=s.replace(old,new,1)
 p.write_text('// '+marker+'\n'+s)
edit('lib/book_lab_page_v0342.dart','BOOK_SCROLL_KEYS_0350',[
 ("Widget _questions() => ListView(padding: const EdgeInsets.all(16), children: [", "Widget _questions() => ListView(key: const PageStorageKey('book-questions342'), padding: const EdgeInsets.all(16), children: ["),
 ("Widget _exam() => ListView.builder(\n      padding:", "Widget _exam() => ListView.builder(\n      key: const PageStorageKey('book-exam342'),\n      padding:"),
 ("return ListView.builder(\n        padding:", "return ListView.builder(\n        key: const PageStorageKey('book-results342'),\n        padding:"),
])
edit('integration_test/book_understanding_android_v0342_test.dart','BOOK_ANDROID_SCROLL_0350',[
 ("void main() {", """Future<void> reveal342(WidgetTester tester, Finder target, String page) async {
  await tester.scrollUntilVisible(target, 180,
    scrollable: find.descendant(of: find.byKey(PageStorageKey(page)),
      matching: find.byType(Scrollable)).first);
  await tester.pumpAndSettle();
}

void main() {"""),
 ("await tester.ensureVisible(find.byKey(const ValueKey('book-lab-open')));", "await tester.scrollUntilVisible(find.byKey(const ValueKey('book-lab-open')), 180,\n      scrollable: find.byType(Scrollable).first);"),
 *[(f"await tester.ensureVisible(find.byKey(const ValueKey('{key}')));", f"await reveal342(tester, find.byKey(const ValueKey('{key}')), 'book-questions342');") for key in ('book-question','book-hypotheses','book-ask','book-answer')],
 ("await tester.ensureVisible(find.text('Esegui esame indipendente'));", "await reveal342(tester, find.text('Esegui esame indipendente'), 'book-exam342');"),
])
edit('integration_test/runtime_android_v0319_test.dart','RUNTIME_VERSION_ASSERT_0350',[
 ("find.text('Memorie MGD 0.34.2')", "find.text('Memorie MGD $mgdAppVersion319')")
])
print('Retained every Android assertion; keyed legacy scroll panes and robustly revealed lazy controls.')
