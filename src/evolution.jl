@doc raw"""
    evolution(M, ρ0, Δt, steps; threshold, nonzero_tol, verbose, filename)
Solve the time evolution for auxiliary density operators based on propagator (generated by `FastExpm.jl`)
with initial state is given in the type of density-matrix (`ρ0`).

This method will return the time evolution of `ADOs` corresponds to `tlist = 0 : Δt : (Δt * steps)`

# Parameters
- `M::AbstractHEOMLSMatrix` : the matrix given from HEOM model
- `ρ0` : system initial state (density matrix)
- `Δt::Real` : A specific time step (time interval).
- `steps::Int` : The number of time steps
- `threshold::Real` : Determines the threshold for the Taylor series. Defaults to `1.0e-6`.
- `nonzero_tol::Real` : Strips elements smaller than `nonzero_tol` at each computation step to preserve sparsity. Defaults to `1.0e-14`.
- `verbose::Bool` : To display verbose output and progress bar during the process or not. Defaults to `true`.
- `filename::String` : If filename was specified, the ADOs at each time point will be saved into the JLD2 file "filename.jld2" during the solving process.

For more details, please refer to [`FastExpm.jl`](https://github.com/fmentink/FastExpm.jl)

# Returns
- `ADOs_list` : The auxiliary density operators of each time step.
"""
function evolution(
        M::AbstractHEOMLSMatrix, 
        ρ0, 
        Δt::Real,
        steps::Int;
        threshold   = 1.0e-6,
        nonzero_tol = 1.0e-14,
        verbose::Bool = true,
        filename::String = ""
    )
    return evolution(
        M, 
        ADOs(ρ0, M.N, M.parity), 
        Δt, 
        steps;
        threshold   = threshold,
        nonzero_tol = nonzero_tol,
        verbose     = verbose,
        filename    = filename
    )
end

@doc raw"""
    evolution(M, ados, Δt, steps; threshold, nonzero_tol, verbose, filename)
Solve the time evolution for auxiliary density operators based on propagator (generated by `FastExpm.jl`)
with initial state is given in the type of `ADOs`.

This method will return the time evolution of `ADOs` corresponds to `tlist = 0 : Δt : (Δt * steps)`

# Parameters
- `M::AbstractHEOMLSMatrix` : the matrix given from HEOM model
- `ados::ADOs` : initial auxiliary density operators
- `Δt::Real` : A specific time step (time interval).
- `steps::Int` : The number of time steps
- `threshold::Real` : Determines the threshold for the Taylor series. Defaults to `1.0e-6`.
- `nonzero_tol::Real` : Strips elements smaller than `nonzero_tol` at each computation step to preserve sparsity. Defaults to `1.0e-14`.
- `verbose::Bool` : To display verbose output and progress bar during the process or not. Defaults to `true`.
- `filename::String` : If filename was specified, the ADOs at each time point will be saved into the JLD2 file "filename.jld2" during the solving process.

For more details, please refer to [`FastExpm.jl`](https://github.com/fmentink/FastExpm.jl)

# Returns
- `ADOs_list` : The auxiliary density operators of each time step.
"""
@noinline function evolution(
        M::AbstractHEOMLSMatrix, 
        ados::ADOs,
        Δt::Real,
        steps::Int;
        threshold   = 1.0e-6,
        nonzero_tol = 1.0e-14,
        verbose::Bool = true,
        filename::String = ""
    )

    _check_sys_dim_and_ADOs_num(M, ados)
    _check_parity(M, ados)

    SAVE::Bool = (filename != "")
    if SAVE 
        FILENAME = filename * ".jld2"
        if isfile(FILENAME)
            error("FILE: $(FILENAME) already exist.")
        end
    end

    ADOs_list::Vector{ADOs} = [ados]
    if SAVE
        jldopen(FILENAME, "a") do file
            file["0"] = ados
        end
    end

    # Generate propagator
    if verbose
        print("Generating propagator...")
        flush(stdout)
    end
    exp_Mt = Propagator(M, Δt; threshold = threshold, nonzero_tol = nonzero_tol)
    if verbose
        println("[DONE]")
        flush(stdout)
    end

    # start solving
    ρvec = copy(ados.data)
    if verbose
        print("Solving time evolution for ADOs by propagator method...\n")
        flush(stdout)
        prog = Progress(steps + 1; start=1, desc="Progress : ", PROGBAR_OPTIONS...)
    end
    for n in 1:steps
        ρvec = exp_Mt * ρvec
        
        # save the ADOs
        ados = ADOs(ρvec, M.dim, M.N, M.parity)
        push!(ADOs_list, ados)
        
        if SAVE
            jldopen(FILENAME, "a") do file
                file[string(n * Δt)] = ados
            end
        end
        if verbose
            next!(prog)
        end
    end
    if verbose
        println("[DONE]\n")
        flush(stdout)
    end

    return ADOs_list
end

@doc raw"""
    evolution(M, ρ0, tlist; solver, reltol, abstol, maxiters, save_everystep, verbose, filename, SOLVEROptions...)
Solve the time evolution for auxiliary density operators based on ordinary differential equations
with initial state is given in the type of density-matrix (`ρ0`).

# Parameters
- `M::AbstractHEOMLSMatrix` : the matrix given from HEOM model
- `ρ0` : system initial state (density matrix)
- `tlist::AbstractVector` : Denote the specific time points to save the solution at, during the solving process.
- `solver` : solver in package `DifferentialEquations.jl`. Default to `DP5()`.
- `reltol::Real` : Relative tolerance in adaptive timestepping. Default to `1.0e-6`.
- `abstol::Real` : Absolute tolerance in adaptive timestepping. Default to `1.0e-8`.
- `maxiters::Real` : Maximum number of iterations before stopping. Default to `1e5`.
- `save_everystep::Bool` : Saves the result at every step. Defaults to `false`.
- `verbose::Bool` : To display verbose output and progress bar during the process or not. Defaults to `true`.
- `filename::String` : If filename was specified, the ADOs at each time point will be saved into the JLD2 file "filename.jld2" during the solving process.
- `SOLVEROptions` : extra options for solver

For more details about solvers and extra options, please refer to [`DifferentialEquations.jl`](https://diffeq.sciml.ai/stable/)

# Returns
- `ADOs_list` : The auxiliary density operators in each time point.
"""
function evolution(
        M::AbstractHEOMLSMatrix, 
        ρ0, 
        tlist::AbstractVector;
        solver = DP5(),
        reltol::Real = 1.0e-6,
        abstol::Real = 1.0e-8,
        maxiters::Real = 1e5,
        save_everystep::Bool=false,
        verbose::Bool = true,
        filename::String = "",
        SOLVEROptions...
    )
    return evolution(
        M, 
        ADOs(ρ0, M.N, M.parity), 
        tlist;
        solver = solver,
        reltol = reltol,
        abstol = abstol,
        maxiters = maxiters,
        save_everystep = save_everystep,
        verbose  = verbose,
        filename = filename,
        SOLVEROptions...
    )
end

@doc raw"""
    evolution(M, ados, tlist; solver, reltol, abstol, maxiters, save_everystep, verbose, filename, SOLVEROptions...)
Solve the time evolution for auxiliary density operators based on ordinary differential equations
with initial state is given in the type of `ADOs`.

# Parameters
- `M::AbstractHEOMLSMatrix` : the matrix given from HEOM model
- `ados::ADOs` : initial auxiliary density operators
- `tlist::AbstractVector` : Denote the specific time points to save the solution at, during the solving process.
- `solver` : solver in package `DifferentialEquations.jl`. Default to `DP5()`.
- `reltol::Real` : Relative tolerance in adaptive timestepping. Default to `1.0e-6`.
- `abstol::Real` : Absolute tolerance in adaptive timestepping. Default to `1.0e-8`.
- `maxiters::Real` : Maximum number of iterations before stopping. Default to `1e5`.
- `save_everystep::Bool` : Saves the result at every step. Defaults to `false`.
- `verbose::Bool` : To display verbose output and progress bar during the process or not. Defaults to `true`.
- `filename::String` : If filename was specified, the ADOs at each time point will be saved into the JLD2 file "filename.jld2" during the solving process.
- `SOLVEROptions` : extra options for solver

For more details about solvers and extra options, please refer to [`DifferentialEquations.jl`](https://diffeq.sciml.ai/stable/)

# Returns
- `ADOs_list` : The auxiliary density operators in each time point.
"""
@noinline function evolution(
        M::AbstractHEOMLSMatrix, 
        ados::ADOs, 
        tlist::AbstractVector;
        solver = DP5(),
        reltol::Real = 1.0e-6,
        abstol::Real = 1.0e-8,
        maxiters::Real = 1e5,
        save_everystep::Bool=false,
        verbose::Bool = true,
        filename::String = "",
        SOLVEROptions...
    )

    _check_sys_dim_and_ADOs_num(M, ados)
    _check_parity(M, ados)

    SAVE::Bool = (filename != "")
    if SAVE 
        FILENAME = filename * ".jld2"
        if isfile(FILENAME)
            error("FILE: $(FILENAME) already exist.")
        end
    end

    ElType = eltype(M)
    Tlist = _HandleFloatType(ElType, tlist)
    ADOs_list::Vector{ADOs} = [ados]
    if SAVE
        jldopen(FILENAME, "a") do file
            file[string(Tlist[1])] = ados
        end
    end

    # problem: dρ/dt = L * ρ(t)
    prob  = ODEProblem{true}(MatrixOperator(M.data), _HandleVectorType(typeof(M.data), ados.data), (Tlist[1], Tlist[end]))

    # setup integrator
    integrator = init(
        prob,
        solver;
        reltol = _HandleFloatType(ElType, reltol),
        abstol = _HandleFloatType(ElType, abstol),
        maxiters = maxiters,
        save_everystep = save_everystep,
        SOLVEROptions...
    )

    # start solving ode
    if verbose
        print("Solving time evolution for ADOs by Ordinary Differential Equations method...\n")
        flush(stdout)
        prog = Progress(length(Tlist); start=1, desc="Progress : ", PROGBAR_OPTIONS...)
    end
    idx = 1
    dt_list = diff(Tlist)
    for dt in dt_list
        idx += 1
        step!(integrator, dt, true)
        
        # save the ADOs
        ados = ADOs(_HandleVectorType(integrator.u), M.dim, M.N, M.parity)
        push!(ADOs_list, ados)
        
        if SAVE
            jldopen(FILENAME, "a") do file
                file[string(Tlist[idx])] = ados
            end
        end
        if verbose
            next!(prog)
        end
    end
    if verbose
        println("[DONE]\n")
        flush(stdout)
    end

    return ADOs_list
end

@doc raw"""
    evolution(M, ρ0, tlist, H, param; solver, reltol, abstol, maxiters, save_everystep, verbose, filename, SOLVEROptions...)
Solve the time evolution for auxiliary density operators with time-dependent system Hamiltonian based on ordinary differential equations
with initial state is given in the type of density-matrix (`ρ0`).
# Parameters
- `M::AbstractHEOMLSMatrix` : the matrix given from HEOM model (with time-independent system Hamiltonian)
- `ρ0` : system initial state (density matrix)
- `tlist::AbstractVector` : Denote the specific time points to save the solution at, during the solving process.
- `H::Function` : a function for time-dependent part of system Hamiltonian. The function will be called by `H(param, t)` and should return the time-dependent part system Hamiltonian matrix at time `t` with `AbstractMatrix` type.
- `param::Tuple`: the tuple of parameters which is used to call `H(param, t)` for the time-dependent system Hamiltonian. Default to empty tuple `()`.
- `solver` : solver in package `DifferentialEquations.jl`. Default to `DP5()`.
- `reltol::Real` : Relative tolerance in adaptive timestepping. Default to `1.0e-6`.
- `abstol::Real` : Absolute tolerance in adaptive timestepping. Default to `1.0e-8`.
- `maxiters::Real` : Maximum number of iterations before stopping. Default to `1e5`.
- `save_everystep::Bool` : Saves the result at every step. Defaults to `false`.
- `verbose::Bool` : To display verbose output and progress bar during the process or not. Defaults to `true`.
- `filename::String` : If filename was specified, the ADOs at each time point will be saved into the JLD2 file "filename.jld2" during the solving process.
- `SOLVEROptions` : extra options for solver

For more details about solvers and extra options, please refer to [`DifferentialEquations.jl`](https://diffeq.sciml.ai/stable/)

# Returns
- `ADOs_list` : The auxiliary density operators in each time point.
"""
function evolution(
        M::AbstractHEOMLSMatrix,
        ρ0, 
        tlist::AbstractVector,
        H::Function,
        param::Tuple = ();
        solver = DP5(),
        reltol::Real = 1.0e-6,
        abstol::Real = 1.0e-8,
        maxiters::Real = 1e5,
        save_everystep::Bool=false,
        verbose::Bool = true,
        filename::String = "",
        SOLVEROptions...
    )
    return evolution(
        M,
        ADOs(ρ0, M.N, M.parity),
        tlist,
        H, 
        param;
        solver = solver,
        reltol = reltol,
        abstol = abstol,
        maxiters = maxiters,
        save_everystep = save_everystep,
        verbose  = verbose,
        filename = filename,
        SOLVEROptions...
    )
end

@doc raw"""
    evolution(M, ados, tlist, H, param; solver, reltol, abstol, maxiters, save_everystep, verbose, filename, SOLVEROptions...)
Solve the time evolution for auxiliary density operators with time-dependent system Hamiltonian based on ordinary differential equations
with initial state is given in the type of `ADOs`.
# Parameters
- `M::AbstractHEOMLSMatrix` : the matrix given from HEOM model (with time-independent system Hamiltonian)
- `ados::ADOs` : initial auxiliary density operators
- `tlist::AbstractVector` : Denote the specific time points to save the solution at, during the solving process.
- `H::Function` : a function for time-dependent part of system Hamiltonian. The function will be called by `H(param, t)` and should return the time-dependent part system Hamiltonian matrix at time `t` with `AbstractMatrix` type.
- `param::Tuple`: the tuple of parameters which is used to call `H(param, t)` for the time-dependent system Hamiltonian. Default to empty tuple `()`.
- `solver` : solver in package `DifferentialEquations.jl`. Default to `DP5()`.
- `reltol::Real` : Relative tolerance in adaptive timestepping. Default to `1.0e-6`.
- `abstol::Real` : Absolute tolerance in adaptive timestepping. Default to `1.0e-8`.
- `maxiters::Real` : Maximum number of iterations before stopping. Default to `1e5`.
- `save_everystep::Bool` : Saves the result at every step. Defaults to `false`.
- `verbose::Bool` : To display verbose output and progress bar during the process or not. Defaults to `true`.
- `filename::String` : If filename was specified, the ADOs at each time point will be saved into the JLD2 file "filename.jld2" during the solving process.
- `SOLVEROptions` : extra options for solver

For more details about solvers and extra options, please refer to [`DifferentialEquations.jl`](https://diffeq.sciml.ai/stable/)

# Returns
- `ADOs_list` : The auxiliary density operators in each time point.
"""
@noinline function evolution(
        M::AbstractHEOMLSMatrix,
        ados::ADOs, 
        tlist::AbstractVector,
        H::Function,
        param::Tuple = ();
        solver = DP5(),
        reltol::Real = 1.0e-6,
        abstol::Real = 1.0e-8,
        maxiters::Real = 1e5,
        save_everystep::Bool=false,
        verbose::Bool = true,
        filename::String = "",
        SOLVEROptions...
    )

    _check_sys_dim_and_ADOs_num(M, ados)
    _check_parity(M, ados)

    SAVE::Bool = (filename != "")
    if SAVE 
        FILENAME = filename * ".jld2"
        if isfile(FILENAME)
            error("FILE: $(FILENAME) already exist.")
        end
    end

    ElType = eltype(M)
    Tlist  = _HandleFloatType(ElType, tlist)
    ADOs_list::Vector{ADOs} = [ados]
    if SAVE
        jldopen(FILENAME, "a") do file
            file[string(Tlist[1])] = ados
        end
    end
    
    Ht  = H(param, Tlist[1])
    _Ht = HandleMatrixType(Ht, M.dim, "H (Hamiltonian) at t=$(Tlist[1])")
    L0  = MatrixOperator(M.data)
    Lt  = MatrixOperator(HEOMSuperOp(minus_i_L_op(_Ht), M.parity, M, "LR").data, update_func! = _update_Lt!)

    if verbose
        print("Solving time evolution for ADOs with time-dependent Hamiltonian by Ordinary Differential Equations method...\n")
        flush(stdout)
        prog = Progress(length(Tlist); start=1, desc="Progress : ", PROGBAR_OPTIONS...)
    end

    parameters = (H = H, param = param, dim = M.dim, N = M.N, parity = M.parity)

    # problem: dρ/dt = L(t) * ρ(t)
    ## M.dim will check whether the returned time-dependent Hamiltonian has the correct dimension
    prob = ODEProblem{true}(L0 + Lt, _HandleVectorType(typeof(M.data), ados.data), (Tlist[1], Tlist[end]), parameters)

    # setup integrator
    integrator = init(
        prob,
        solver;
        reltol = _HandleFloatType(ElType, reltol),
        abstol = _HandleFloatType(ElType, abstol),
        maxiters = maxiters,
        save_everystep = save_everystep,
        SOLVEROptions...
    )

    # start solving ode
    if verbose
        print("Solving time evolution for ADOs with time-dependent Hamiltonian by Ordinary Differential Equations method...\n")
        flush(stdout)
        prog = Progress(length(Tlist); start=1, desc="Progress : ", PROGBAR_OPTIONS...)
    end
    idx = 1
    dt_list = diff(Tlist)
    for dt in dt_list
        idx += 1
        step!(integrator, dt, true)
        
        # save the ADOs
        ados = ADOs(_HandleVectorType(integrator.u), M.dim, M.N, M.parity)
        push!(ADOs_list, ados)
        
        if SAVE
            jldopen(FILENAME, "a") do file
                file[string(Tlist[idx])] = ados
            end
        end
        if verbose
            next!(prog)
        end
    end
    if verbose
        println("[DONE]\n")
        flush(stdout)
    end

    return ADOs_list
end

# define the update function for evolution with time-dependent system Hamiltonian H(param, t)
function _update_Lt!(L, u, p, t)

    # check system dimension of Hamiltonian
    Ht  = p.H(p.param, t)
    _Ht = HandleMatrixType(Ht, p.dim, "H (Hamiltonian) at t=$(t)")

    # update the block diagonal terms of L
    copy!(L, HEOMSuperOp(minus_i_L_op(_Ht), p.parity, p.dim, p.N, "LR").data)
    nothing
end