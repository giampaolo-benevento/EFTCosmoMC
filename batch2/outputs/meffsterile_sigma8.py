import planckStyle as s
import os
from  pylab import *

g = s.getSinglePlotter()
g.make_figure(1, xstretch=1.3)

outdir = ''
roots = ['base_nnu_meffsterile_' + s.defdata]

mmax = 1.7
nmax = 4.49
g.plot_3d(roots, ['meffsterile', 'nnu', 'sigma8'])


m = np.arange(0, mmax, 0.01)
N = np.arange(3.047, nmax, 0.01)
N, m = np.meshgrid(N, m)
z = m / (N - 3.046) ** 0.75
CS = contour(m, N, z, origin='lower', levels=[0.5, 1, 2, 5], colors='k', linestyles='--', linewidths=0.3, extent=[0, 3, 3.046, nmax])
clabel(CS, CS.levels, inline=True, fmt='%1.1f', fontsize=7)

z = m / (N - 3.046)
CS = contour(m, N, z, origin='lower', levels=[0.5, 1, 2, 5], colors='gray', linestyles=':', linewidths=0.3, extent=[0, 3, 3.046, nmax])
# clabel(CS, CS.levels, inline=True,fmt='%1.1f',fontsize=7)

m = np.arange(0, mmax * 1.1, 0.01)
fill_between(m, 0, (m / 10) ** (4. / 3) + 3.046, color='gray')


xlim([0, mmax])
ylim([3.046, nmax])

g.export()
