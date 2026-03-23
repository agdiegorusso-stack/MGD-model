import numpy as np
from scipy.optimize import linprog

n = 6
W = np.zeros((n, n))
for i in range(1, 6):
    W[0, i] = 1.0
    W[i, 0] = 1.0

dist = np.zeros((n, n))
for i in range(n):
    for j in range(n):
        if i == j: dist[i, j] = 0
        elif i == 0 or j == 0: dist[i, j] = 1
        else: dist[i, j] = 2

C = dist.flatten()
A_eq = np.zeros((2*n, n*n))
for i in range(n):
    for j in range(n):
        A_eq[i, i*n+j] = 1
        A_eq[n+j, i*n+j] = 1

def solve_ot(m1, m2):
    b_eq = np.concatenate((m1, m2))
    res = linprog(C, A_eq=A_eq, b_eq=b_eq, bounds=(0, None), method='highs')
    return res.fun

alpha = 0.5
m_0 = np.zeros(n)
m_0[0] = alpha
for i in range(1, 6): m_0[i] = (1-alpha)/5

m_1 = np.zeros(n)
m_1[1] = alpha
m_1[0] = 1-alpha

w1 = solve_ot(m_0, m_1)
kappa = 1 - w1 / dist[0, 1]
print(f"Kappa: {kappa}")
