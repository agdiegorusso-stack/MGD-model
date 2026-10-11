"""Rebuild the small own reader assets from the immutable training artifact."""
import hashlib,json,shutil
from pathlib import Path
from reader import fit_coreference
from questions import main as questions
from audit import main as audit

ROOT=Path(__file__).resolve().parent
OUT=ROOT/'results'
APP=ROOT.parent.parent/'mgd-neural-0421'

def main():
    assert hashlib.sha256((OUT/'reader443.json').read_bytes()).hexdigest()=='b5f75ea69011b4dbb53a0d2bc17d64a066078d14de0a438b743ec03c379f0585'
    fit_coreference(OUT/'coreference443.json');questions(OUT);audit(OUT)
    assets=APP/'assets';assets.mkdir(exist_ok=True)
    shutil.copy2(OUT/'reader443-deploy.json',assets/'reader443.json')
    shutil.copy2(OUT/'coreference443.json',assets/'coreference443.json')
    fixtures=APP/'tool/fixtures';fixtures.mkdir(exist_ok=True)
    shutil.copy2(OUT/'runtime-reference443.json',fixtures/'runtime-reference443.json')
    model=json.loads((assets/'reader443.json').read_text());report=json.loads((OUT/'final-audit-results.json').read_text())
    weights=model['parameters'];params=sum(len(r)*len(r[0]) if isinstance(r[0],list) else len(r) for r in weights.values())
    params+=len(model['question_bag']['weight'])*len(model['questions'])
    receipt={'version':'0.42.21','transformer':False,'external_pretrained_weights':False,
      'reader_sha256':hashlib.sha256((assets/'reader443.json').read_bytes()).hexdigest(),
      'reader_bytes':(assets/'reader443.json').stat().st_size,'parameters_including_unused_legacy_question_head':params,
      'base_training_run':38176357502,'base_model_sha256':'b5f75ea69011b4dbb53a0d2bc17d64a066078d14de0a438b743ec03c379f0585',
      'experimental':True,'general_comprehension_solved':False,'fixed_own_semantic_weights_after_offline_training':True,
      'automatic_semantic_learning_from_reading_proven':False,'phone_energy_measured':False,
      'audit_correct':report['correct'],'audit_total':report['total'],'scope_questions_and_extractable_arguments_only':True}
    (OUT/'app-reader-manifest443.json').write_text(json.dumps(receipt,indent=2))
    print(json.dumps(receipt))

if __name__=='__main__':main()
