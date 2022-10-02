module Heom
    import Reexport: @reexport
    
    export 
        Bath, HeomBase, Spectrum

    const PROGBAR_OPTIONS = Dict(:barlen=>20, :color=>:green, :showspeed=>true)
    
    # sub-module Bath for Heom
    module Bath
        import Base: show
        import LinearAlgebra: I, kron
        import SparseArrays: sparse

        export 
            AbstractBath, BosonBath, FermionBath, CombinedBath,
            AbstractBosonBath, bosonReal, bosonImag, bosonRealImag,
            AbstractFermionBath, fermionAbsorb, fermionEmit,
            spre, spost

        include("Bath.jl")
    end
    @reexport using .Bath

    # sub-module CorrelationFunc for Heom
    module CorrelationFunc
        import ..Bath: BosonBath, FermionBath
        import LinearAlgebra: eigvals

        export 
            Boson_DrudeLorentz_Matsubara, Boson_DrudeLorentz_Pade, 
            Fermion_Lorentz_Matsubara, Fermion_Lorentz_Pade

        include("correlations/CorrelationFunc.jl")
    end
    @reexport using .CorrelationFunc
    
    # sub-module HeomBase for Heom
    module HeomBase
        using ..Bath
        import Base: size, show
        import LinearAlgebra: I, kron
        import OrderedCollections: OrderedDict
        import SparseArrays: sparse, spzeros, sparsevec, reshape, SparseVector, SparseMatrixCSC, AbstractSparseMatrix
        import Distributed: @everywhere, @distributed, procs, nprocs, RemoteChannel, Channel
        import DistributedArrays: distribute, localpart
        import ProgressMeter: Progress, next!
        import ..Heom: PROGBAR_OPTIONS

        export
            AbstractHEOMMatrix, M_Fermion, M_Boson, M_Boson_Fermion,
            odd, even, none,
            ADOs, getRho, getADO,
            addDissipator!, addTerminator!

        include("HeomBase.jl")
        include("ADOs.jl")
        include("M_fermion.jl")
        include("M_boson.jl")
        include("M_boson_fermion.jl")
    end
    @reexport using .HeomBase

    # sub-module evolution for Heom
    module Evolution
        import ..HeomBase: AbstractHEOMMatrix, ADOs
        import OrdinaryDiffEq: ODEProblem, init, DP5, step!
        import SparseArrays: sparse, sparsevec, SparseVector
        import ProgressMeter: Progress, next!
        import ..Heom: PROGBAR_OPTIONS

        export evolution

        include("evolution.jl")
    end
    @reexport using .Evolution

    # sub-module SteadyState for Heom
    module SteadyState
        import ..HeomBase: AbstractHEOMMatrix, ADOs
        import SparseArrays: sparse, sparsevec
        import LinearSolve: LinearProblem, solve, UMFPACKFactorization

        export Steadystate

        include("SteadyState.jl")
    end
    @reexport using .SteadyState

    # sub-module Spectrum for Heom
    module Spectrum
        import ..HeomBase: AbstractHEOMMatrix, ADOs, spre
        import LinearAlgebra: I, kron
        import SparseArrays: sparse, sparsevec, SparseVector
        import LinearSolve: LinearProblem, solve, UMFPACKFactorization
        import ProgressMeter: Progress, next!        
        import ..Heom: PROGBAR_OPTIONS

        export PSD, DOS

        include("PowerSpectralDensity.jl")
        include("DensityOfStates.jl")
    end
    @reexport using .Spectrum
end