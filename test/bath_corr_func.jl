@time @testset "Bath correlation functions" begin
    λ = 0.1450
    W = 0.6464
    kT = 0.7414
    μ = 0.8787
    N = 4
    op = Qobj([0 0; 0 0])

    # Boson DrudeLorentz Matsubara
    b = Boson_DrudeLorentz_Matsubara(op, λ, W, kT, N)
    η = [
        0.20121058848333528 - 0.09372799999999999im,
        0.06084056770606083 + 0.0im,
        0.029978857835967165 + 0.0im,
        0.019932342919420813 + 0.0im,
        0.014935247906482648 + 0.0im,
    ]
    γ = [
        0.6464 + 0.0im,
        4.658353586742945 + 0.0im,
        9.31670717348589 + 0.0im,
        13.975060760228835 + 0.0im,
        18.63341434697178 + 0.0im,
    ]
    @test length(b) == 5
    for (i, e) in enumerate(b)
        @test e.η ≈ η[i] atol = 1.0e-10
        @test e.γ ≈ γ[i] atol = 1.0e-10
    end

    # Boson DrudeLorentz Pade
    b = Boson_DrudeLorentz_Pade(op, λ, W, kT, N)
    η = [
        0.20121058848333528 - 0.09372799999999999im,
        0.060840591418808695 + 0.0im,
        0.03040476731148852 + 0.0im,
        0.03480693463462283 + 0.0im,
        0.11731872688143469 + 0.0im,
    ]
    γ = [
        0.6464 + 0.0im,
        4.658353694331594 + 0.0im,
        9.326775214941103 + 0.0im,
        15.245109836566387 + 0.0im,
        42.84397872069647 + 0.0im,
    ]
    @test length(b) == 5
    for (i, e) in enumerate(b)
        @test e.η ≈ η[i] atol = 1.0e-10
        @test e.γ ≈ γ[i] atol = 1.0e-10
    end

    # Boson Underdamped Matsubara
    b = Boson_Underdamped_Matsubara(op, λ, W, μ, kT, N)
    η = [
        -0.00018928791202842962 + 0.0im,
        -2.459796602810069e-5 + 0.0im,
        -7.340987667241645e-6 + 0.0im,
        -3.1048013140938362e-6 + 0.0im,
        0.004830164921597723 - 0.0035513512668150157im,
        0.017695757954237043 + 0.0035513512668150157im,
    ]
    γ = [
        4.658353586742945 + 0.0im,
        9.31670717348589 + 0.0im,
        13.975060760228835 + 0.0im,
        18.63341434697178 + 0.0im,
        0.3232 - 0.8171018602353075im,
        0.3232 + 0.8171018602353075im,
    ]
    types = [
        "bR",
        "bR",
        "bR",
        "bR",
        "bRI",
        "bRI",
    ]
    @test length(b) == 6
    for (i, e) in enumerate(b)
        @test e.η ≈ η[i] atol = 1.0e-10
        @test e.γ ≈ γ[i] atol = 1.0e-10
        @test e.types == types[i]
    end

    # Fermion Lorentz Matsubara
    b = Fermion_Lorentz_Matsubara(op, λ, μ, W, kT, N)
    η = [
        0.023431999999999998 - 0.010915103984112131im,
        0.0 + 0.008970684904033346im,
        0.0 + 0.0009279154410418598im,
        0.0 + 0.0003322143470478503im,
        0.0 + 0.00016924095164942202im,
        0.023431999999999998 - 0.010915103984112131im,
        0.0 + 0.008970684904033346im,
        0.0 + 0.0009279154410418598im,
        0.0 + 0.0003322143470478503im,
        0.0 + 0.00016924095164942202im,
    ]
    γ = [
        0.6464 - 0.8787im,
        2.3291767933714724 - 0.8787im,
        6.987530380114418 - 0.8787im,
        11.645883966857362 - 0.8787im,
        16.304237553600306 - 0.8787im,
        0.6464 + 0.8787im,
        2.3291767933714724 + 0.8787im,
        6.987530380114418 + 0.8787im,
        11.645883966857362 + 0.8787im,
        16.304237553600306 + 0.8787im,
    ]
    @test length(b) == 10
    for (i, e) in enumerate(b)
        @test e.η ≈ η[i] atol = 1.0e-10
        @test e.γ ≈ γ[i] atol = 1.0e-10
    end

    # Fermion Lorentz Pade
    b = Fermion_Lorentz_Pade(op, λ, μ, W, kT, N)
    η = [
        0.023431999999999998 - 0.01091510398411206im,
        0.0 + 0.008970684906245254im,
        0.0 + 0.0009302651094118784im,
        0.0 + 0.0004641563759947782im,
        0.0 + 0.0005499975924601513im,
        0.023431999999999998 - 0.01091510398411206im,
        0.0 + 0.008970684906245254im,
        0.0 + 0.0009302651094118784im,
        0.0 + 0.0004641563759947782im,
        0.0 + 0.0005499975924601513im,
    ]
    γ = [
        0.6464 - 0.8787im,
        2.329176793410983 - 0.8787im,
        6.988999607574685 - 0.8787im,
        12.311922289624265 - 0.8787im,
        34.341283736701214 - 0.8787im,
        0.6464 + 0.8787im,
        2.329176793410983 + 0.8787im,
        6.988999607574685 + 0.8787im,
        12.311922289624265 + 0.8787im,
        34.341283736701214 + 0.8787im,
    ]
    @test length(b) == 10
    for (i, e) in enumerate(b)
        @test e.η ≈ η[i] atol = 1.0e-10
        @test e.γ ≈ γ[i] atol = 1.0e-10
    end
end
