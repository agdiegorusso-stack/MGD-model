"""Executable witnesses for the extended audit, not a complete theorem prover."""
from fractions import Fraction as Q
import json
import math
from pathlib import Path

import numpy as np
from plastic_memory import MGDPlasticMemory


def main():
    findings = {}
    # Main p10; C1 p29: reflected negative drift does not create absorption.
    c0, eps, nu, lam, p = Q(1, 10), Q(1), Q(1, 4), Q(1), Q(9, 10)
    pc = nu / lam
    assert p > 1 - pc and 2 * nu < lam
    trajectory = [c0]
    for _ in range(4):
        trajectory.append(max(c0, trajectory[-1] + nu))  # U=0
    assert trajectory[-1] > eps
    findings['negativeDriftNotAbsorption'] = {
        'p': float(p), 'p_c': float(pc), 'meanUnreflectedDrift': float(nu - lam * p),
        'zeroRunWeights': list(map(float, trajectory)),
        'probabilityOfEachIndependentFourZeroBlock': float((1 - p)**4),
        'expectedIncrementAtFloor': float((1 - p) * nu),
        'analyticConclusion': 'Independent disjoint zero blocks occur infinitely often almost surely; each forces the edge above epsilon.'}

    # The localized base graph becomes a line with at most two leaf rows.
    radii = [10, 100, 10000]
    findings['localizedGeometry'] = {
        'combBallFormulaForIntegerRadiusAtLeastOne': '6*r-1',
        'combDoublingRates': [math.log2((12*r-1)/(6*r-1)) for r in radii],
        'radii': radii, 'verticalOnlyComponentSize': 3,
        'verticalOnlyMacrodimension': 0,
        'assumption': 'Uniform finite initial weights, nearest-neighbour lattice; off-axis nonincident edges become inactive.'}
    # With off-axis initial memory zero, min(m_on,m_off)=0 on vertical edges.
    rho_mem, beta, eta, mu = .5, .5, .5, 0.
    true_vertical = .25 - (1-.9) + mu * beta * (1-.9)/(1-rho_mem)
    printed_vertical = .25 - (1-.9) - eta * beta * (1-.9)/(1-rho_mem)
    findings['verticalMemoryEndpoint'] = {'actualMeanDrift': true_vertical,
                                        'printedSymmetricDrift': printed_vertical}

    # A bounded level correction cannot add a constant drift at every step.
    base = np.array([2., 2.1, 2.2])
    corrected = np.maximum(.1, base - .3)
    assert np.allclose(np.diff(corrected), [.1, .1])
    findings['levelVersusIncrement'] = {'base': base.tolist(),
        'correctedWithConstantMaterial': corrected.tolist(),
        'correctedIncrements': np.diff(corrected).tolist(),
        'claimedExtraDriftMinusEta': -.3,
        'bound': 'For S5 with M in [0,1]: |full_weight-base_weight|<=eta_M.'}

    # C1 p14 Lemma9.3: taking a min cannot be replaced by following one field.
    rho, xi = .8, .15
    positive_root = (math.sqrt((1-rho-xi)**2+4*xi*(1-rho)*.5)-(1-rho-xi))/(2*xi)
    kappa = xi-(1-rho)/2
    outcomes = [[0., 1-rho], [1-rho, 0.]]
    assert all(min(x) == 0 for x in outcomes)
    assert kappa * positive_root > 0
    findings['minimumDrift'] = {'initialFields': [0., 0.], 'possibleNextFields': outcomes,
        'actualExpectedMinimumIncrement': 0.,
        'claimedPositiveLowerBoundUsingCorrectRoot': kappa*positive_root,
        'meaning': 'Counterexample also holds using any positive printed threshold.'}

    # C1 p5: exact cylinder sets inside the allegedly empty central window.
    alpha = Q(49, 100)
    intervals = []
    for prefix in ([0, 1, 1, 1], [1, 0, 0, 0]):
        lower = sum((1-alpha)*alpha**j*b for j, b in enumerate(prefix))
        upper = lower + alpha**len(prefix)
        assert Q(2,5) <= lower < upper <= Q(3,5)
        intervals.append({'prefix': prefix, 'lower': float(lower), 'upper': float(upper)})
    findings['ifsBelowHalf'] = {'alpha': float(alpha), 'window': [.4, .6],
        'cylinders': intervals, 'rigorousProbabilityLowerBound': .125,
        'printedProbability': 0.}

    # Main p38: the claimed uniform lower density bound fails near an endpoint.
    a = Q(3, 4)
    x = Q(99, 100) * (1-a) * a**4
    assert all((1-a)*a**j > x for j in range(5))
    upper_probability = Q(1, 32)  # first five bits must be zero
    claimed_lower = x/2
    assert upper_probability < claimed_lower
    findings['ifsDensityLowerBound'] = {'alpha': .75, 'normalizedBeta': .25,
        'interval': [0., float(x)], 'actualProbabilityAtMost': float(upper_probability),
        'claimedProbabilityAtLeast': float(claimed_lower)}

    # C2 p4: complementary memories have a deterministic stationary sum.
    a, b, prob = .6, .4, .5
    variance = b*b*prob*(1-prob)/(1-a*a)
    findings['complementaryMemories'] = {'stationarySum': b/(1-a),
        'varianceEach': variance, 'covariance': -variance, 'correlation': -1.,
        'meaning': 'The joint stationary law is not the product of its nondegenerate marginals.'}

    # C2 p12-15: exact quadratic conjugacy and invariant critical orbit.
    conjugacy = []
    for xi in [.05, .1, .1183]:
        rho, p = .8, .5
        b, d = rho+xi, (1-rho)*p
        c = b/2 - b*b/4 - xi*d
        phi = lambda z: -xi*z+b/2
        F = lambda z: -xi*z*z+b*z+d
        errors = [abs(phi(F(z))-(phi(z)**2+c)) for z in [-2., 0., .5, 1., 3.]]
        assert max(errors) < 1e-12 and 0 < c < .25
        w = 0.
        for _ in range(10000):
            w = w*w+c
            assert 0 <= w <= .5
        conjugacy.append({'xi': xi, 'correctMandelbrotParameter': c,
            'maxConjugacyResidual': max(errors), 'criticalOrbitAfter10000': w,
            'analyticCertificate': 'For 0<=c<=1/4, [0,1/2] is forward invariant for w^2+c.'})
    findings['julia'] = conjugacy

    # C2 p27/33: unbounded Gaussian noise invalidates a bounded state claim.
    findings['gaussianStateSpace'] = {'initialMaterial': 0., 'coupling': 0.,
        'p': .5, 'anyPositiveSigma': True,
        'oneStepProbabilityOfNegativeMaterialAtLeast': .25,
        'reason': 'On U=0, M_next equals centered Gaussian noise; P(U=0,noise<0)=1/4.'}

    # C2 p33/34: TV for equal-variance Gaussian mixtures is exact here.
    rho, coupling, sigma = .8, 1., .03
    shift = 1-rho
    gaussian_tv = math.erf(shift/(2*math.sqrt(2)*sigma))
    coeff = coupling/4*gaussian_tv
    findings['dobrushinArithmeticAndMetric'] = {
        'rho': rho, 'alpha': coupling, 'sigma': sigma,
        'printedEachCoefficient': (1-rho)*coupling/4,
        'sumOfFourPrintedCoefficients': (1-rho)*coupling,
        'printedRowSum': 4*(1-rho)*coupling,
        'actualOneStepKernelTvCoefficientWithOwnStateFixed': coeff,
        'actualFourNeighbourSumForThisKernel': 4*coeff,
        'scope': 'These are transition-kernel sensitivities, not a proof about a stationary Gibbs specification or full temporal contraction.'}

    # C1 p34: energy sums all horizontal edges, not only currently active ones.
    c0, eps, C, n, weight = .1, 1., 1., 1, 100.
    energy_density = (2*n)*(weight-c0)/(2*n+1)**2
    printed_bound = eps-c0+C
    assert energy_density > printed_bound
    findings['energyDensity'] = {'boxSide': 3, 'initialHorizontalWeight': weight,
        'gamma': 0., 'zeta': 0., 'allOtherEdgesInactive': True,
        'actualInitialDensity': energy_density, 'printedUniformBound': printed_bound,
        'lineSupportedCollapsedDensityScale': 'O((2*n+1)/(2*n+1)^2) -> 0, not a positive bulk density.'}

    # C2 p21: averaging capacities and finding a min-cut do not commute.
    states = np.array([[1., .1], [.1, 1.]])  # two edges in series
    expected_min = float(states.min(axis=1).mean())
    min_expected = float(states.mean(axis=0).min())
    assert expected_min < min_expected
    findings['minCutExpectation'] = {'equiprobableCapacityStates': states.tolist(),
        'expectedMinCut': expected_min, 'minCutOfExpectedCapacities': min_expected,
        'scope': 'Counterexample to the interchange used in the proof, not a simulation of the full MGD stationary distribution.',
        'rtNormalizedBoundaryCutUpperBound': 1.,
        'reportedNormalizedCutExamplesExceedingBound': [1.47, 1.56, 1.4]}

    def kl(m, v):
        return m*math.log(m/v)+(1-m)*math.log((1-m)/(1-v))
    ratios = [kl(.5, .5+d)/d for d in [.1, .01, .001, .0001]]
    correct_cubic = (2*.25-1)/(3*.25**2*(1-.25)**2)
    findings['kl'] = {'deltas': [.1, .01, .001, .0001],
        'klOverAbsoluteDisplacementAtMHalf': ratios,
        'limit': 0., 'correctSigmaForRhoPoint8PHalf': .1,
        'sigmaPrintedInC2Table7': .25,
        'correctCubicCoefficientAtMQuarter': correct_cubic,
        'printedCubicCoefficientAtMQuarter': -correct_cubic}

    # Check a proposed learning primitive's algebraic guarantee, not its utility.
    rng = np.random.default_rng(9262026)
    mem = MGDPlasticMemory(8, 4)
    max_residual = 0.
    increases = 0
    min_M, max_M = 1., 0.
    for _ in range(1000):
        key = rng.normal(size=8)
        value = rng.normal(size=4)
        result = mem.observe(key, value)
        residual = np.max(np.abs(result['after']-result['predicted_error_factor']*result['before']))
        max_residual = max(max_residual, float(residual))
        increases += int(np.linalg.norm(result['after']) > np.linalg.norm(result['before'])+1e-12)
        assert -1e-12 <= result['material'] <= 1+1e-12
        assert 0 < result['eta'] <= 1
        min_M, max_M = min(min_M, mem.M), max(max_M, mem.M)
    assert max_residual < 1e-12 and increases == 0
    findings['proposedPrimitiveOnly'] = {'updatesChecked': 1000,
        'maximumErrorIdentityResidual': max_residual,
        'currentObservationErrorIncreases': increases,
        'materialRangeObserved': [min_M, max_M],
        'NOTDemonstrated': ['Improved future prediction', 'Noise robustness', 'Language learning',
                           'Advantage over a delta rule with another gate', 'Superiority to Transformers']}
    out = {'dateEuropeRome': '2026-09-26', 'allAssertionsPassed': True,
           'scope': 'Targeted analytic witnesses and arithmetic checks; not exhaustive peer review.',
           'findings': findings}
    Path('results.json').write_text(json.dumps(out, indent=2))
    print(json.dumps(out, indent=2))


if __name__ == '__main__':
    main()
