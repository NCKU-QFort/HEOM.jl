"""
# `M_Boson <: AbstractHEOMMatrix`
Heom matrix for bosonic bath

## Fields
- `data::SparseMatrixCSC{ComplexF64, Int64}` : the sparse matrix
- `tier::Int` : the tier (cutoff) for the bath
- `dim::Int`  : the dimension of system
- `N::Int`  : the number of total states
- `Nb::Int` : the number of bosonic states
- `Nf::Int` : the number of fermionic states (should be zero)
- `sup_dim::Int` : the dimension of system superoperator
- `parity::Symbol` : the parity of the density matrix (restrict to `:none` for boson)
- `ado2idx::OrderedDict{Vector{Int}, Int}` : the ADO-to-index dictionary

## Constructor
`M_Boson(Hsys, tier, bath; [progressBar])`

- `Hsys::AbstractMatrix` : The system Hamiltonian
- `tier::Int` : the tier (cutoff) for the bath
- `bath::Vector{T<:AbstractBosonBath}` : objects for different bosonic baths
- `progressBar::Bool` : Display progress bar during the process or not. Defaults to `true`.
"""
mutable struct M_Boson <: AbstractHEOMMatrix
    data::SparseMatrixCSC{ComplexF64, Int64}
    const tier::Int
    const dim::Int
    const N::Int
    const Nb::Int
    const Nf::Int
    const sup_dim::Int
    const parity::Symbol
    const ado2idx::OrderedDict{Vector{Int}, Int}
    
    function M_Boson(Hsys::AbstractMatrix, tier::Int, bath::T; progressBar::Bool=true) where T <: AbstractBosonBath
        return M_Boson(Hsys, tier, [bath], progressBar = progressBar)
    end
    
    function M_Boson(        
            Hsys::AbstractMatrix,
            tier::Int,
            bath::Vector{T};
            progressBar::Bool=true
        ) where T <: AbstractBosonBath

        Nsys,   = size(Hsys)
        sup_dim = Nsys ^ 2
        I_sup   = sparse(I, sup_dim, sup_dim)
        
        # the liouvillian operator for free Hamiltonian term
        Lsys = -1im * (spre(Hsys) - spost(Hsys))

        N_exp_term = 0
        for bB in bath
            if bB.dim != Nsys
                error("The dimension of system Hamiltonian is not consistent with bath coupling operators.")
            end
            N_exp_term += bB.Nterm
        end 

        # get ADOs dictionary
        N_he, ado2idx_ordered, idx2ado = ADOs_dictionary(fill((tier + 1), N_exp_term), tier)
        ado2idx = Dict(ado2idx_ordered)

        # start to construct the matrix
        L_row = distribute([Int[] for _ in procs()])
        L_col = distribute([Int[] for _ in procs()])
        L_val = distribute([ComplexF64[] for _ in procs()])
        channel = RemoteChannel(() -> Channel{Bool}(), 1) # for updating the progress bar
        
        println("Start constructing hierarchy matrix (using $(nprocs()) processors)...")
        if progressBar
            prog = Progress(N_he; desc="Processing: ", PROGBAR_OPTIONS...)
        else
            println("Processing...")
            flush(stdout)
        end
        @sync begin # start two tasks which will be synced in the very end
            # the first task updates the progress bar
            @async while take!(channel)
                if progressBar
                    next!(prog)
                else
                    put!(channel, false) # this tells the printing task to finish
                end
            end

            # the second task does the computation
            @async begin
                @distributed (+) for idx in 1:N_he
                    state = idx2ado[idx]
                    n_exc = sum(state)
                    if n_exc >= 1
                        sum_ω = sum_ω_boson(state, bath)
                        op = Lsys - sum_ω * I_sup
                    else
                        op = Lsys
                    end
                    add_operator!(op, L_row, L_col, L_val, N_he, idx, idx)

                    count = 0
                    state_neigh = copy(state)
                    for bB in bath
                        for k in 1:bB.Nterm
                            count += 1
                            n_k = state[count]
                            if n_k >= 1
                                state_neigh[count] = n_k - 1
                                idx_neigh = ado2idx[state_neigh]
                                
                                op = prev_grad_boson(bB, k, n_k)
                                add_operator!(op, L_row, L_col, L_val, N_he, idx, idx_neigh)

                                state_neigh[count] = n_k
                            end
                            if n_exc <= tier - 1
                                state_neigh[count] = n_k + 1
                                idx_neigh = ado2idx[state_neigh]
                                
                                op = next_grad_boson(bB)
                                add_operator!(op, L_row, L_col, L_val, N_he, idx, idx_neigh)
                                
                                state_neigh[count] = n_k
                            end
                        end
                    end
                    if progressBar
                        put!(channel, true) # trigger a progress bar update
                    end
                    1 # Here, returning some number 1 and reducing it somehow (+) is necessary to make the distribution happen.
                end
                put!(channel, false) # this tells the printing task to finish
            end
        end
        print("Constructing matrix...")
        flush(stdout)
        L_he = sparse(vcat(L_row...), vcat(L_col...), vcat(L_val...), N_he * sup_dim, N_he * sup_dim)
        println("[DONE]")

        return new(L_he, tier, Nsys, N_he, N_he, 0, sup_dim, :none, ado2idx_ordered)
    end
end