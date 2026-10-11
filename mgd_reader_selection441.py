"""Apply frozen eligibility rules; neither pass count nor quotes prove semantics."""
def qualify(scores, *, quotes=False):
    a,b=scores.get('development24',{}),scores.get('diagnostic16',{})
    field='passed_with_quote_provenance' if quotes else 'passed'
    return (a.get('total')==24 and b.get('total')==16
        and a.get('exact_choices_correct',0)>=21 and a.get(field,0)>=17
        and b.get('exact_choices_correct',0)>=11 and b.get(field,0)>=9
        and (a.get('exact_choices_correct',0)>=23 or b.get('exact_choices_correct',0)>=13))

def fresh_adopt(baseline,candidate):
    b,c=baseline.get('fresh16',{}),candidate.get('fresh16',{})
    return (b.get('total')==16 and c.get('total')==16
        and c.get('exact_choices_correct',0)>=b.get('exact_choices_correct',0)
        and c.get('passed',0)>=b.get('passed',0)
        and (c.get('exact_choices_correct',0)>b.get('exact_choices_correct',0)
             or c.get('passed',0)>b.get('passed',0)))
