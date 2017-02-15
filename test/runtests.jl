using Base.Test
using ECOS, MathProgBase, JuMP
import Convex
using ConicBenchmarkUtilities


dat = readcbfdata("example.cbf")

c, A, b, con_cones, var_cones, vartypes, dat.sense, dat.objoffset = cbftompb(dat)

@test_approx_eq c [1.0, 0.64]
@test_approx_eq A [-50.0 -31; -3.0 2.0]
@test_approx_eq b [-250.0, 4.0]
@test vartypes == [:Cont, :Cont]
@test dat.sense == :Max
@test dat.objoffset == 0.0
@test con_cones == [(:NonPos,[1]),(:NonNeg,[2])]

m = MathProgBase.ConicModel(ECOSSolver(verbose=0))
MathProgBase.loadproblem!(m, -c, A, b, con_cones, var_cones)
MathProgBase.optimize!(m)

x_sol = MathProgBase.getsolution(m)
objval = MathProgBase.getobjval(m)

mj = Model(solver=ECOSSolver(verbose=0))
@variable(mj, x[1:2])
@objective(mj, Max, x[1] + 0.64x[2])
@constraint(mj, 50x[1] + 31x[2] <= 250)
@constraint(mj, 3x[1] - 2x[2] >= -4)
status = solve(mj)

@test_approx_eq_eps x_sol getvalue(x) 1e-6
@test_approx_eq_eps -objval getobjectivevalue(mj) 1e-6

# test CBF writer
newdat = mpbtocbf("example", c, A, b, con_cones, var_cones, vartypes, dat.sense)
writecbfdata("example_out.cbf",newdat,"# Example C.4 from the CBF documentation version 2")
@test readstring("example.cbf") == readstring("example_out.cbf")
rm("example_out.cbf")

# test transformation utilities

# SOCRotated1 from MathProgBase conic tests
c = [ 0.0, 0.0, -1.0, -1.0]
A = [ 1.0  0.0   0.0   0.0
      0.0  1.0   0.0   0.0]
b = [ 0.5, 1.0]
con_cones = [(:Zero,1:2)]
var_cones = [(:SOCRotated,1:4)]
vartypes = fill(:Cont,4)
c, A, b, con_cones, var_cones, vartypes = socrotated_to_soc(c, A, b, con_cones, var_cones, vartypes)

@test c == [0.0,0.0,-1.0,-1.0]
@test b == [0.5,1.0,0.0,0.0,0.0,0.0]
@test_approx_eq A [1.0 0.0 0.0 0.0
                   0.0 1.0 0.0 0.0
                  -1.0 -1.0 0.0 0.0
                  -1.0 1.0 0.0 0.0
                   0.0 0.0 -1.4142135623730951 0.0
                   0.0 0.0 0.0 -1.4142135623730951]
@test var_cones == [(:Free,1:4)]
@test con_cones == [(:Zero,1:2),(:SOC,3:6)]

c = [-1.0,-1.0]
A = [0.0 0.0; 0.0 0.0; -1.0 0.0; 0.0 -1.0]
b = [0.5, 1.0, 0.0, 0.0]
con_cones = [(:SOCRotated,1:4)]
var_cones = [(:Free,1:2)]
vartypes = fill(:Cont,2)
c, A, b, con_cones, var_cones, vartypes = socrotated_to_soc(c, A, b, con_cones, var_cones, vartypes)

@test c == [-1.0,-1.0,0.0,0.0,0.0,0.0]
@test b == [0.5,1.0,0.0,0.0,0.0,0.0,0.0,0.0]
@test A == [0.0 0.0 1.0 0.0 0.0 0.0
 0.0 0.0 0.0 1.0 0.0 0.0
 -1.0 0.0 0.0 0.0 1.0 0.0
 0.0 -1.0 0.0 0.0 0.0 1.0
 0.0 0.0 -1.0 -1.0 0.0 0.0
 0.0 0.0 -1.0 1.0 0.0 0.0
 0.0 0.0 0.0 0.0 -1.4142135623730951 0.0
 0.0 0.0 0.0 0.0 0.0 -1.4142135623730951]
@test var_cones == [(:Free,1:2),(:Free,3:6)]
@test con_cones == [(:Zero,1:4),(:SOC,5:8)]

# SOCINT1
c = [ 0.0, -2.0, -1.0]
A = sparse([ 1.0   0.0   0.0])
b = [ 1.0]
con_cones = [(:Zero,1)]
var_cones = [(:SOC,1:3)]
vartypes = [:Cont,:Bin,:Bin]

c, A, b, con_cones, var_cones, vartypes = remove_ints_in_nonlinear_cones(c, A, b, con_cones, var_cones, vartypes)
@test c == [0.0,-2.0,-1.0,0.0,0.0]
@test b == [1.0,0.0,0.0]
@test A == [1.0 0.0 0.0 0.0 0.0
 0.0 1.0 0.0 -1.0 0.0
 0.0 0.0 1.0 0.0 -1.0]
@test var_cones == [(:SOC,[1,4,5]),(:Free,[2,3])]
@test con_cones == [(:Zero,[1]),(:Zero,[2,3])]



x = Convex.Variable()
problem = Convex.minimize( exp(x), x >= 1 )
ConicBenchmarkUtilities.convex_to_cbf(problem, "exptest", "exptest.cbf")

output = """
# Generated by ConicBenchmarkUtilities.jl
VER
2

OBJSENSE
MIN

VAR
3 1
F 3

CON
5 3
EXP 3
L= 1
L+ 1

OBJACOORD
1
2 1.0

ACOORD
5
2 0 1.0
4 0 1.0
0 1 1.0
3 1 1.0
3 2 -1.0

BCOORD
2
1 1.0
4 -1.0
"""

@test readstring("exptest.cbf") == output

c, A, b, con_cones, var_cones, vartypes, sense, objoffset = cbftompb(readcbfdata("exptest.cbf"))

@test sense == :Min
@test objoffset == 0.0
@test all(vartypes .== :Cont)
m = MathProgBase.ConicModel(ECOSSolver(verbose=0))
MathProgBase.loadproblem!(m, c, A, b, con_cones, var_cones)
MathProgBase.optimize!(m)
@test MathProgBase.status(m) == :Optimal
x_sol = MathProgBase.getsolution(m)
@test_approx_eq_eps x_sol [1.0,exp(1),exp(1)] 1e-5
@test_approx_eq_eps MathProgBase.getobjval(m) exp(1) 1e-5

rm("exptest.cbf")