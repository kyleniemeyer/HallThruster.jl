"""
    freq_electron_neutral(model::ElectronNeutralModel, nn, Tev)
Effective frequency of electron scattering caused by collisions with neutrals
"""
function freq_electron_neutral(collisions::Vector{ElasticCollision{T}}, nn::Number, Tev::Number) where T
    νen = 0.0
    @inbounds for c in collisions
        νen += c.rate_coeff(3/2 * Tev) * nn
    end
    return νen
end

function freq_electron_neutral(U::AbstractArray, params::NamedTuple, i::Int)
    nn = params.cache.nn_tot[i]
    Tev = params.cache.Tev[i]
    return freq_electron_neutral(params.electron_neutral_collisions, nn, Tev)
end

"""
    freq_electron_ion(ne, Tev, Z)
Effective frequency at which electrons are scattered due to collisions with ions
"""
@inline freq_electron_ion(ne::Number, Tev::Number, Z::Number) = 2.9e-12 * Z^2 * ne * coulomb_logarithm(ne, Tev, Z) / Tev^1.5

function compute_Z_eff(U, params, i::Int)
    (;index) = params
    mi = params.config.propellant.m
    # Compute effective charge state
    ne = electron_density(U, params, i)
    ni_sum = sum(U[index.ρi[Z], i]/mi for Z in 1:params.config.ncharge)
    Z_eff = ne / ni_sum
    return Z_eff
end

function freq_electron_ion(U, params, i::Int)
    if params.config.electron_ion_collisions
        # Compute effective charge state
        ne = params.cache.ne[i]
        Z_eff = params.cache.Z_eff[i]
        Tev = params.cache.Tev[i]
        νei = Tev ≤ 0.0 || ne ≤ 0.0 || Z_eff < 1 ? 0.0 : freq_electron_ion(ne, Tev, Z_eff)
        return νei
    else
        return 0.0
    end
end

"""
    freq_electron_electron(ne, Tev)
Effective frequency at which electrons are scattered due to collisions with other electrons
"""
@inline freq_electron_electron(ne::Number, Tev::Number) = 5e-12 * ne * coulomb_logarithm(ne, Tev) / Tev^1.5

function freq_electron_electron(U, params, i)
    ne = params.cache.ne[i]
    Tev = params.cache.Tev[i]
    return freq_electron_electron(ne, Tev)
end

"""
    coulomb_logarithm(ne, Tev, Z = 1)

calculate coulomb logarithm for electron-ion collisions as a function of ion
charge state Z, electron number density in m^-3, and electron temperature in eV.
"""
@inline function coulomb_logarithm(ne, Tev, Z = 1)
    if Tev < 10 * Z^2
        ln_Λ = 23 - 0.5 * log(1e-6 * ne * Z^2 / Tev^3)
    else
        ln_Λ = 24 - 0.5 * log(1e-6 * ne / Tev^2)
    end

    return ln_Λ
end

"""
    electron_mobility(νan::Float64, νc::Float64, B::Float64)

calculates electron transport according to the generalized Ohm's law
as a function of the classical and anomalous collision frequencies
and the magnetic field.
"""
@inline function electron_mobility(νan, νc, B)
    νe = νan + νc
    return electron_mobility(νe, B)
end

@inline function electron_mobility(νe, B)
    Ω = e * B / (me * νe)
    return e / (me * νe * (1 + Ω^2))
end

@inline electron_sound_speed(Tev) = sqrt(8 * e * Tev / π / me)
