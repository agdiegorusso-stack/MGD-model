"""Reproducible equation checks, not a complete peer review of all three PDFs."""
import json,math
from pathlib import Path
import numpy as np

def update(M,rho,xi,chi):return rho*M+(1-rho)*chi+xi*M*(1-M)
def printed_root(rho,xi,chi):
    return (xi+1-rho-math.sqrt((xi+1-rho)**2-4*xi*(1-rho)*chi))/(2*xi)
def corrected_root(rho,xi,chi):
    b=1-rho-xi
    return (math.sqrt(b*b+4*xi*(1-rho)*chi)-b)/(2*xi)

def run(out):
    # Parameters in the displayed figure on page 18, inside its stated domain.
    rho=.9;xi=.05;chi=.5
    wrong=printed_root(rho,xi,chi);right=corrected_root(rho,xi,chi)
    M=0.
    for _ in range(10000):M=update(M,rho,xi,chi)
    assert abs(update(wrong,rho,xi,chi)-wrong)>.02
    assert abs(update(right,rho,xi,chi)-right)<1e-12
    assert abs(M-right)<1e-12
    # Exact counterexample to Lemma9.2's stated sufficient condition.
    r=.2;x=.6;m=.5;c=1.
    assert x<=1-r and update(m,r,x,c)>1.
    # Correct necessity/sufficiency for this nonnegative map:
    # 1-F(M,1)=(1-M)*(rho-xi*M), so invariance for all M requires xi<=rho.
    grid=np.linspace(0,1,1001)
    for r0 in [.1,.2,.5,.8,.99]:
        for x0 in [0.,r0/2,r0]:
            for c0 in [0.,1.]:
                y=update(grid,r0,x0,c0)
                assert y.min()>=-1e-12 and y.max()<=1+1e-12
    # At stationary stochastic forcing the quadratic involves E[M^2].
    # Replacing E[M^2] with E[M]^2 is a mean-field approximation.
    rng=np.random.default_rng(9024);values=[];m=.5
    for t in range(210000):
        m=update(m,rho,xi,float(rng.random()<.5))
        if t>=10000:values.append(m)
    values=np.asarray(values)
    # Boundary state permitted by Lemma9.2, contradicting Prop23.4 for all t.
    flux=sum(abs(update(1.,.9,.05,1.)-1.) for _ in range(2))
    assert flux==0.
    # Companion 2 p38 uses the CORRECT polynomial, but lambda>0 is not
    # equivalent to |f'(M*)|<1 for a discrete-time map without further bounds.
    srho,sxi,sp=.8,3.,.5
    sroot=corrected_root(srho,sxi,sp)
    derivative=srho+sxi*(1-2*sroot)
    lam=1-derivative
    assert lam>0 and abs(derivative)>1
    report={
      'scope':'Targeted algebraic and computational checks of the supplied PDFs, not a full proof audit.',
      'mainPaperSha256':'d13ca7349a4a9e86f59a4de295c8b28fa844d78f2a7548f735bf62b6b5e03228',
      'equilibrium':{'reference':'Main paper pages17-18, Eq6 versus Eq7-9; figure uses rho=.90,xi=.05,p=.50',
        'companionCorrection':'Companion 2 p38 Theorem13.1 already uses the correct fixed-point polynomial; the supplied texts are inconsistent.',
        'rho':rho,'xi':xi,'constantChi':chi,'printedFixedPoint':wrong,'printedResidual':update(wrong,rho,xi,chi)-wrong,
        'correctedFixedPoint':right,'correctedResidual':update(right,rho,xi,chi)-right,
        'deterministicSimulationLimit':M,'stochasticMean':float(values.mean()),'stochasticVariance':float(values.var()),
        'correctPolynomial':'xi*M^2+(1-rho-xi)*M-(1-rho)*chi=0',
        'stationaryMomentIdentity':'xi*E[M^2]+(1-rho-xi)*E[M]-(1-rho)*E[chi]=0'},
      'invariance':{'reference':'Main paper p17 Lemma9.2','rho':r,'xi':x,'M':.5,'chi':1.,
        'statedConditionSatisfied':x<=1-r,'nextM':update(.5,r,x,1.),
        'correctCondition':'0<=xi<=rho for all M,chi in [0,1], rho in (0,1)'},
      'flux':{'reference':'Main paper p44 Proposition23.4','initialM':[1.,1.],'initialChi':[1.,1.],
        'firstStepFlux':flux,'meaning':'Local recurrence at a boundary permitted by Lemma9.2 yields zero flux. The lemma alone does not establish strict positivity; this is not a full coupled-graph simulation.'},
      'discreteStability':{'reference':'Companion 2 p38 Theorem13.1, claimed equivalence following lambda positivity',
        'rho':srho,'xi':sxi,'p':sp,'fixedPoint':sroot,'lambda':lam,'derivativeAtFixedPoint':derivative,
        'correctCondition':'For the deterministic mean-field map: |f_prime(M*)|<1, equivalently 0<sqrt((1-rho-xi)^2+4*xi*(1-rho)*p)<2.',
        'meaning':'Lambda positivity is true; its claimed equivalence to discrete-time local attraction for every xi>=0 is false. The xi<=rho invariance restriction excludes this counterexample.'},
      'entropy':{'reference':'Main paper p44 Remark23.3','correctStatement':'Binary entropy is maximized only at M=1/2, not at an arbitrary M*.',
        'derivativeAtCorrectedFixedPoint':math.log2((1-right)/right)},
      'validUsefulComponents':['Exponential memory recursion and its exact decay law.',
        'Positive weighted shortest-path distance on a connected component.',
        'Bounded material dynamics under a correct parameter restriction.',
        'Path-dependent state can be used as an algorithmic inductive bias; predictive utility still requires evaluation.'],
      'notEstablished':['A theorem of language learning or Transformer dominance.',
        'Automatic transfer of lattice theorems to typed semantic graphs.',
        'General validity of every theorem in the three papers.']}
    out.mkdir(exist_ok=True)
    (out/'math_checks.json').write_text(json.dumps(report,indent=2))
    print(json.dumps(report,indent=2))
    return report

if __name__=='__main__':run(Path('results'))
