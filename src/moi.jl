
function cbftomoi_cones(cname, csize::Int)
    if cname == "L="
        # equal to
        return MOI.Zeros(csize)
    elseif cname == "F"
        # free
        return MOI.Reals(csize)
    elseif cname == "L-"
        # nonpositive
        return MOI.Nonpositives(csize)
    elseif cname == "L+"
        # nonnegative
        return MOI.Nonnegatives(csize)
    elseif cname == "Q"
        # second-order cone
        return MOI.SecondOrderCone(csize)
    elseif cname == "QR"
        # rotated second-order cone
        return MOI.RotatedSecondOrderCone(csize)
    elseif cname == "EXP"
        # exponential
        @assert csize == 3
        return MOI.ExponentialCone()
    elseif cname == "EXP*"
        # dual exponential
        @assert csize == 3
        return MOI.DualExponentialCone()
    # elseif cname in ("POWER", "POWER*")
    #     # power (parametrized)
    #     if csize != 3 || length(params) != 2
    #         error("currently cannot handle power cones that aren't equivalent to MathOptInterface's 3D-PowerCone definition (or its dual cone)")
    #     end
    #     sigma = sum(params)
    #     exponent = params[1]/sigma
    #     if cname == "POWER"
    #         return MOI.PowerCone(exponent)
    #     else
    #         return MOI.DualPowerCone(exponent)
    #     end
    else
        error("cone type $cname is not recognized")
    end
end

function cbftomoi!(model::MOI.ModelLike, dat::CBFData)
    @assert dat.nvar == (isempty(dat.var) ? 0 : sum(c -> c[2], dat.var))
    @assert dat.ncon == (isempty(dat.con) ? 0 : sum(c -> c[2], dat.con))

    if !MOI.is_empty(model)
        error("MOI model object is not empty")
    end

    # objective sense
    if dat.sense == :Min
        MOI.set(model, MOI.ObjectiveSense(), MOI.MinSense)
    elseif dat.sense == :Max
        MOI.set(model, MOI.ObjectiveSense(), MOI.MaxSense)
    else
        error("objective sense $(dat.sense) not recognized")
    end

    # variables
    x = MOI.add_variables(model, dat.nvar)
    for j in dat.intlist
        MOI.add_constraint(model, MOI.SingleVariable(x[j]), MOI.Integer())
    end

    # objective terms
    objaterms = [MOI.ScalarAffineTerm(v, x[a]) for ((a,), v) in dat.objacoord]

    # variable cones
    k = 0
    for (cname, csize) in dat.var
        S = cbftomoi_cones(cname, csize)
        F = MOI.VectorOfVariables(x[k+1:k+csize])
        MOI.add_constraint(model, F, S)
        k += csize
    end
    @assert k == dat.nvar

    # constraint cones
    terms = [Vector{Tuple{Int, Float64}}() for i in 1:dat.ncon]
    for ((a, b), v) in dat.acoord
        push!(terms[a], (b, v))
    end

    offs = zeros(dat.ncon)
    for ((a,), v) in dat.bcoord
        offs[a] = v
    end

    k = 0
    for (cname, csize) in dat.con
        vats = Vector{MOI.VectorAffineTerm{Float64}}()
        for l in 1:csize
            for (b, v) in terms[k+l]
                push!(vats, MOI.VectorAffineTerm(l, MOI.ScalarAffineTerm(v, x[b])))
            end
        end

        F = MOI.VectorAffineFunction(vats, offs[k+1:k+csize])
        S = cbftomoi_cones(cname, csize)
        MOI.add_constraint(model, F, S)
        k += csize
    end
    @assert k == dat.ncon

    # TODO power cones


    # TODO PSD cones

    # objfcoord::Vector{Tuple{NTuple{3, Int}, Float64}}
    # fcoord::Vector{Tuple{NTuple{4, Int}, Float64}}
    # hcoord::Vector{Tuple{NTuple{4, Int}, Float64}}
    # dcoord::Vector{Tuple{NTuple{3, Int}, Float64}}

    # objective terms
    objfterms = []

    # variable cones

    # constraint cones


    # final objective function
    objterms = append!(objaterms, objfterms)
    MOI.set(model, MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(),
        MOI.ScalarAffineFunction(objterms, dat.objoffset))

    return model
end


# TODO moitocbf function

# TODO remove old code
#
# function cbftompb(dat::CBFData)
#     @assert dat.nvar == (isempty(dat.var) ? 0 : sum(c->c[2],dat.var))
#     @assert dat.nconstr == (isempty(dat.con) ? 0 : sum(c->c[2],dat.con))
#
#     c = zeros(dat.nvar)
#     for (i,v) in dat.objacoord
#         c[i] = v
#     end
#
#     var_cones = cbfcones_to_mpbcones(dat.var, dat.nvar)
#     con_cones = cbfcones_to_mpbcones(dat.con, dat.nconstr)
#
#     I_A, J_A, V_A = unzip(dat.acoord)
#     b = zeros(dat.nconstr)
#     for (i,v) in dat.bcoord
#         b[i] = v
#     end
#
#     psdvarstartidx = Int[]
#     for i in 1:length(dat.psdvar)
#         if i == 1
#             push!(psdvarstartidx,dat.nvar+1)
#         else
#             push!(psdvarstartidx,psdvarstartidx[i-1] + psd_len(dat.psdvar[i-1]))
#         end
#         push!(var_cones,(:SDP,psdvarstartidx[i]:psdvarstartidx[i]+psd_len(dat.psdvar[i])-1))
#     end
#     nvar = (length(dat.psdvar) > 0) ? psdvarstartidx[end] + psd_len(dat.psdvar[end]) - 1 : dat.nvar
#
#     psdconstartidx = Int[]
#     for i in 1:length(dat.psdcon)
#         if i == 1
#             push!(psdconstartidx,dat.nconstr+1)
#         else
#             push!(psdconstartidx,psdconstartidx[i-1] + psd_len(dat.psdcon[i-1]))
#         end
#         push!(con_cones,(:SDP,psdconstartidx[i]:psdconstartidx[i]+psd_len(dat.psdcon[i])-1))
#     end
#     nconstr = (length(dat.psdcon) > 0) ? psdconstartidx[end] + psd_len(dat.psdcon[end]) - 1 : dat.nconstr
#
#     c = [c;zeros(nvar-dat.nvar)]
#     for (matidx,i,j,v) in dat.objfcoord
#         ix = psdvarstartidx[matidx] + idx_to_offset(dat.psdvar[matidx],i,j)
#         @assert c[ix] == 0.0
#         scale = (i == j) ? 1.0 : sqrt(2)
#         c[ix] = scale*v
#     end
#
#     for (conidx,matidx,i,j,v) in dat.fcoord
#         ix = psdvarstartidx[matidx] + idx_to_offset(dat.psdvar[matidx],i,j)
#         push!(I_A,conidx)
#         push!(J_A,ix)
#         scale = (i == j) ? 1.0 : sqrt(2)
#         push!(V_A,scale*v)
#     end
#
#     for (conidx,varidx,i,j,v) in dat.hcoord
#         ix = psdconstartidx[conidx] + idx_to_offset(dat.psdcon[conidx],i,j)
#         push!(I_A,ix)
#         push!(J_A,varidx)
#         scale = (i == j) ? 1.0 : sqrt(2)
#         push!(V_A,scale*v)
#     end
#
#     b = [b;zeros(nconstr-dat.nconstr)]
#     for (conidx,i,j,v) in dat.dcoord
#         ix = psdconstartidx[conidx] + idx_to_offset(dat.psdcon[conidx],i,j)
#         @assert b[ix] == 0.0
#         scale = (i == j) ? 1.0 : sqrt(2)
#         b[ix] = scale*v
#     end
#
#     A = sparse(I_A,J_A,-V_A,nconstr,nvar)
#
#     vartypes = fill(:Cont, nvar)
#     vartypes[dat.intlist] .= :Int
#
#     return c, A, b, con_cones, var_cones, vartypes, dat.sense, dat.objoffset
# end



# function mpbtocbf(name, c, A, b, con_cones, var_cones, vartypes, sense=:Min)
#     num_scalar_var = 0
#     for (cone, idx) in var_cones
#         if cone != :SDP
#             num_scalar_var += length(idx)
#         end
#     end
#     num_scalar_con = 0
#     for (cone, idx) in con_cones
#         if cone != :SDP
#             num_scalar_con += length(idx)
#         end
#     end
#
#     # need to shuffle rows and columns to put them in order
#     var_idx_old_to_new = zeros(Int, length(c))
#     con_idx_old_to_new = zeros(Int, length(b))
#     var_idx_new_to_old = zeros(Int, num_scalar_var)
#     con_idx_new_to_old = zeros(Int, num_scalar_con)
#
#     # CBF fields
#     var = Vector{Tuple{String, Int}}()
#     con = Vector{Tuple{String, Int}}()
#
#     i = 1
#     for (cone, idx) in var_cones
#         if cone == :ExpPrimal
#             @assert all(var_idx_old_to_new[idx] .== 0)
#             @assert length(idx) == 3
#             # MPB: (x,y,z) : y*exp(x/y) <= z
#             # CBF: (z,y,x) : y*exp(x/y) <= z
#             var_idx_old_to_new[idx] = i+2:-1:i
#             var_idx_new_to_old[i+2:-1:i] = idx
#             i += 3
#             push!(var, (conemap_rev[cone], length(idx)))
#         elseif cone != :SDP
#             for k in idx
#                 var_idx_old_to_new[k] = i
#                 var_idx_new_to_old[i] = k
#                 i += 1
#             end
#             push!(var, (conemap_rev[cone], length(idx)))
#         end
#     end
#     @assert i - 1 == num_scalar_var
#
#     i = 1
#     for (cone, idx) in con_cones
#         if cone == :ExpPrimal
#             @assert all(con_idx_old_to_new[idx] .== 0)
#             @assert length(idx) == 3
#             con_idx_old_to_new[idx] = i+2:-1:i
#             con_idx_new_to_old[i+2:-1:i] = idx
#             i += 3
#             push!(con, (conemap_rev[cone], length(idx)))
#         elseif cone != :SDP
#             for k in idx
#                 @assert con_idx_old_to_new[k] == 0
#                 con_idx_old_to_new[k] = i
#                 con_idx_new_to_old[i] = k
#                 i += 1
#             end
#             push!(con, (conemap_rev[cone], length(idx)))
#         end
#     end
#     @assert i - 1 == num_scalar_con
#
#     objacoord = collect(zip(findnz(sparse(c[var_idx_new_to_old]))...))
#     bcoord = collect(zip(findnz(sparse(b[con_idx_new_to_old]))...))
#     # MPB is b - Ax ∈ K, CBF is b + Ax ∈ K
#     Acbf = -A[con_idx_new_to_old,var_idx_new_to_old]
#
#     acoord = collect(zip(findnz(Acbf)...))::Vector{Tuple{Int,Int,Float64}}
#
#     intlist = Int[]
#     for i in 1:length(vartypes)
#         if var_idx_old_to_new[i] == 0 && vartypes[i] != :Cont
#             error("CBF format does not support integer restrictions on PSD variables")
#         end
#         if vartypes[i] == :Cont
#         elseif vartypes[i] == :Int
#             push!(intlist,var_idx_old_to_new[i])
#         elseif vartypes[i] == :Bin
#             # TODO: Check if we need to add variable bounds also
#             push!(intlist,var_idx_old_to_new[i])
#         else
#             error("Unrecognized variable category $(vartypes[i])")
#         end
#     end
#
#     psdvar = Int[]
#     psdcon = Int[]
#
#     # Map from MPB linear variable index to (psdvar,i,j)
#     psdvar_idx_old_to_new = fill((0,0,0), length(c))
#     # Map from MPB linear constraint index to (psdcon,i,j)
#     psdcon_idx_old_to_new = fill((0,0,0), length(b))
#
#     for (cone, idx) in var_cones
#         if cone == :SDP
#             y = length(idx)
#             conedim = round(Int, sqrt(0.25 + 2y) - 0.5)
#             push!(psdvar, conedim)
#             k = 1
#             for i in 1:conedim, j in i:conedim
#                 psdvar_idx_old_to_new[idx[k]] = (length(psdvar), i, j)
#                 k += 1
#             end
#             @assert length(idx) == k - 1
#         end
#     end
#
#     for (cone, idx) in con_cones
#         if cone == :SDP
#             y = length(idx)
#             conedim = round(Int, sqrt(0.25 + 2y) - 0.5)
#             push!(psdcon, conedim)
#             k = 1
#             for i in 1:conedim, j in i:conedim
#                 psdcon_idx_old_to_new[idx[k]] = (length(psdcon), i, j)
#                 k += 1
#             end
#             @assert length(idx) == k - 1
#         end
#     end
#
#     objfcoord = Vector{Tuple{Int,Int,Int,Float64}}()
#     for i in 1:length(c)
#         if c[i] != 0.0 && psdvar_idx_old_to_new[i] != (0,0,0)
#             varidx, vari, varj = psdvar_idx_old_to_new[i]
#             scale = (vari == varj) ? 1.0 : sqrt(2)
#             push!(objfcoord, (varidx, vari, varj, c[i]/scale))
#         end
#     end
#     dcoord = Vector{Tuple{Int,Int,Int,Float64}}()
#     for i in 1:length(b)
#         if b[i] != 0.0 && psdcon_idx_old_to_new[i] != (0,0,0)
#             conidx, coni, conj = psdcon_idx_old_to_new[i]
#             scale = (coni == conj) ? 1.0 : sqrt(2)
#             push!(dcoord, (conidx, coni, conj, b[i]/scale))
#         end
#     end
#
#     A_I, A_J, A_V = findnz(A)
#     fcoord = Vector{Tuple{Int,Int,Int,Int,Float64}}()
#     hcoord = Vector{Tuple{Int,Int,Int,Int,Float64}}()
#
#     for (i,j,v) in zip(A_I,A_J,A_V)
#         if psdvar_idx_old_to_new[j] != (0,0,0)
#             if psdcon_idx_old_to_new[i] != (0,0,0)
#                 error("CBF format does not allow PSD variables to appear in affine expressions defining PSD constraints")
#             end
#             newrow = con_idx_old_to_new[i]
#             @assert newrow != 0
#             varidx, vari, varj = psdvar_idx_old_to_new[j]
#             scale = (vari == varj) ? 1.0 : sqrt(2)
#             push!(fcoord, (newrow, varidx, vari, varj, -v/scale))
#         elseif psdcon_idx_old_to_new[i] != (0,0,0)
#             newcol = var_idx_old_to_new[j]
#             conidx, coni, conj = psdcon_idx_old_to_new[i]
#             scale = (coni == conj) ? 1.0 : sqrt(2)
#             push!(hcoord, (conidx, newcol, coni, conj, -v/scale))
#         end
#     end
#
#     return CBFData(name,sense,var,psdvar,con,psdcon,objacoord,objfcoord,0.0,fcoord,acoord,bcoord,hcoord,dcoord,intlist,num_scalar_var,num_scalar_con)
# end

# # converts an MPB solution to CBF solution
# # no transformation needed unless PSD vars present
# function moitocbf_solution(dat::CBFData, x::Vector)
#     scalarsol = x[1:dat.nvar]
#     psdvarsols = Vector{Matrix{Float64}}()
#     startidx = dat.nvar+1
#     for i in eachindex(dat.psdvar)
#         endidx = startidx + psd_len(dat.psdvar[i]) - 1
#         vecsol = x[startidx:endidx]
#         matsol = Matrix{Float64}(undef, dat.psdvar[i], dat.psdvar[i])
#         mat!(matsol, vecsol)
#         push!(psdvarsols, matsol)
#         startidx = endidx + 1
#     end
#
#     return (scalarsol, psdvarsols)
# end
#
# # Copied from Pajarito.jl
# function mat!(m::Matrix{Float64}, v::Vector{Float64})
#     dim = size(m, 1)
#     kSD = 1
#     for jSD in 1:dim, iSD in jSD:dim
#         if jSD == iSD
#             m[iSD, jSD] = v[kSD]
#         else
#             m[iSD, jSD] = m[jSD, iSD] = v[kSD]
#         end
#         kSD += 1
#     end
#     return m
# end

# psd_len(n) = div(n*(n+1), 2)
#
# # returns offset from starting index for (i,j) term in n x n matrix
# function idx_to_offset(n, i, j)
#     @assert 1 <= i <= n
#     @assert 1 <= j <= n
#     # upper triangle
#     if i > j
#         i,j = j,i
#     end
#     # row major
#     return psd_len(n) - psd_len(n-i+1) + (j-i)
# end
