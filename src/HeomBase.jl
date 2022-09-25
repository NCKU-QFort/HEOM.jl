abstract type AbstractHEOMMatrix end

# Parity for fermionic heom matrices
const odd  = 1;
const even = 0;
const none = nothing;

size(A::AbstractHEOMMatrix) = size(A.data)

function show(io::IO, M::AbstractHEOMMatrix)
    T = typeof(M)
    if T == M_Boson
        type = "Boson"
    elseif T == M_Fermion
        type = "Fermion"
    else
        type = "Boson-Fermion"
    end

    print(io, 
        type, " type HEOM matrix with (system) dim = $(M.dim) and parity = :$(M.parity)\n",
        "total-state     number N  = $(M.N)\n",
        "bosonic-state   number Nb = $(M.Nb)\n",
        "fermionic-state number Nf = $(M.Nf)\n",
        "data =\n"
    )
    show(io, MIME("text/plain"), M.data)
end

function show(io::IO, m::MIME"text/plain", M::AbstractHEOMMatrix) show(io, M) end

"""
# `addDissipator!(M, jumpOP)`
Adding dissipator to a given HEOM matrix.

## Parameters
- `M::AbstractHEOMMatrix` : the matrix given from HEOM model
- `jumpOP::Vector{T<:AbstractMatrix}` : The collapse (jump) operators to add. Defaults to empty vector `[]`.
"""
function addDissipator!(M::AbstractHEOMMatrix, jumpOP::Vector{T}=[]) where T <: AbstractMatrix
    if length(jumpOP) > 0
        for J in jumpOP
            if size(J) == (M.dim, M.dim)
                M.data += spre(J) * spost(J') - 0.5 * (spre(J' * J) + spost(J' * J))
            else
                error("The dimension of each jumpOP should be equal to \"($(M.dim), $(M.dim))\".")
            end
        end
    end
end

# generate index to ado vector
function ADO_number(dims::Vector{Int}, N_exc::Int)
    len = length(dims)
    state = zeros(Int, len)
    result = [copy(state)]
    nexc = 0

    while true
        idx = len
        state[end] += 1
        nexc += 1
        if state[idx] < dims[idx]
            push!(result, copy(state))
        end
        while (nexc == N_exc) || (state[idx] == dims[idx])
            #state[idx] = 0
            idx -= 1
            if idx < 1
                return result
            end

            nexc -= state[idx + 1] - 1
            state[idx + 1] = 0
            state[idx] += 1
            if state[idx] < dims[idx]
                push!(result, copy(state))
            end
        end
    end
end

function ADOs_dictionary(dims::Vector{Int}, N_exc::Int)
    ado2idx = OrderedDict{Vector{Int}, Int}()
    idx2ado = ADO_number(dims, N_exc)
    for (idx, ado) in enumerate(idx2ado)
        ado2idx[ado] = idx
    end

    return length(idx2ado), ado2idx, idx2ado
end

function pad_csc(A::SparseMatrixCSC{T, Int64}, row_scale::Int, col_scale::Int, row_idx=1::Int, col_idx=1::Int) where {T<:Number}
    (M, N) = size(A)

    # deal with values
    values = A.nzval
    if length(values) == 0
        return sparse([M * row_scale], [N * col_scale], [0.0im])
    else
        if T != ComplexF64
            values = convert.(ComplexF64, values)
        end

        # deal with colptr
        local ptrLen::Int         = N * col_scale + 1
        local ptrIn::Vector{Int}  = A.colptr
        local ptrOut::Vector{Int} = fill(1, ptrLen)
        if col_idx == 1
            ptrOut[1:(N+1)]   .= ptrIn            
            ptrOut[(N+2):end] .= ptrIn[end]

        elseif col_idx == col_scale         
            ptrOut[(ptrLen-N):end] .= ptrIn

        elseif (col_idx < col_scale) && (col_idx > 1)
            tmp1 = (col_idx - 1) * N + 1
            tmp2 = tmp1 + N
            ptrOut[tmp1:tmp2] .= ptrIn
            ptrOut[(tmp2+1):end] .= ptrIn[end]

        else
            error("col_idx must be \'>= 1\' and \'<= col_scale\'")
        end

        # deal with rowval
        if (row_idx > row_scale) || (row_idx < 1)
            error("row_idx must be \'>= 1\' and \'<= row_scale\'")
        end
        tmp1 = (row_idx - 1) * N

        return SparseMatrixCSC(
            M * row_scale,
            N * col_scale,
            ptrOut,
            A.rowval .+ tmp1, 
            values,
        )
    end
end

function csc2coo(A)
    len = length(A.nzval)

    if len == 0
        return A.m, A.n, [], [], []
    else        
        colidx = Vector{Int}(undef, len)
        @inbounds for i in 1:(length(A.colptr) - 1)
            @inbounds for j in A.colptr[i] : (A.colptr[i + 1] - 1)
                colidx[j] = i
            end
        end
        return A.m, A.n, A.rowval, colidx, A.nzval
    end
end

function pad_coo(A::SparseMatrixCSC{T, Int64}, row_scale::Int, col_scale::Int, row_idx=1::Int, col_idx=1::Int) where {T<:Number}
    # transform matrix A's format from csc to coo
    M, N, I, J, V = csc2coo(A)

    # deal with values
    if T != ComplexF64
        V = convert.(ComplexF64, V)
    end
    
    # deal with rowval
    if (row_idx > row_scale) || (row_idx < 1)
        error("row_idx must be \'>= 1\' and \'<= row_scale\'")
    end

    # deal with colval
    if (col_idx > col_scale) || (col_idx < 1)
        error("col_idx must be \'>= 1\' and \'<= col_scale\'")
    end

    @inbounds Inew = I .+ (M * (row_idx - 1))
    @inbounds Jnew = J .+ (N * (col_idx - 1))
    
    return Inew, Jnew, V
end

function add_operator!(op, I, J, V, N_he, row_idx, col_idx)
    row, col, val = pad_coo(op, N_he, N_he, row_idx, col_idx)
    push!(localpart(I)[1], row...)
    push!(localpart(J)[1], col...)
    push!(localpart(V)[1], val...)
end

# sum ω of bath for current gradient
function bath_sum_ω(adoLabel, bath::AbstractBath)
    count = 0
    sum_ω = 0.0
    for b in bath.bath
        for k in 1:b.Nterm
            count += 1
            if adoLabel[count] > 0
                sum_ω += adoLabel[count] * b.γ[k]
            end
        end
    end
    return sum_ω
end

# boson operator for previous gradient
function prev_grad_boson(bath::bosonRealImag, k, n_k)
    pre  = bath.η[k] * bath.spre
    post = conj(bath.η[k]) * bath.spost
    return -1im * n_k * (pre - post)
end

# absorption fermion operator for previous gradient
function prev_grad_fermion(bath::fermionAbsorb, k, n_exc, n_exc_before, parity)
    return -1im * ((-1) ^ n_exc_before) * (
        (-1) ^ eval(parity) * bath.η[k] * bath.spre - 
        (-1) ^ (n_exc - 1)  * conj(bath.η_emit[k]) * bath.spost
    )
end

# emission fermion operator for previous gradient
function prev_grad_fermion(bath::fermionEmit, k, n_exc, n_exc_before, parity)
    return -1im * ((-1) ^ n_exc_before) * (
        (-1) ^ eval(parity) * bath.η[k] * bath.spre - 
        (-1) ^ (n_exc - 1)  * conj(bath.η_absorb[k]) * bath.spost
    )
end

# boson operator for next gradient
function next_grad_boson(bath::T) where T <: AbstractBosonBath
    return -1im * bath.comm
end

# fermion operator for next gradient
function next_grad_fermion(bath::T, n_exc, n_exc_before, parity) where T <: AbstractFermionBath
    return -1im * ((-1) ^ n_exc_before) * (
        (-1) ^ eval(parity) * bath.spreD +
        (-1) ^ (n_exc - 1)  * bath.spostD
    )
end