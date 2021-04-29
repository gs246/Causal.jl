# This file includes DAESystems


import DifferentialEquations: DAEProblem
import Sundials: IDA 
import UUIDs: uuid4

"""
    @def_dae_system ex 

where `ex` is the expression to define to define a new AbstractDAESystem component type. The usage is as follows:
```julia
@def_dae_system mutable struct MyDAESystem{T1,T2,T3,...,TN,OP,RH,RO,ST,IP,OP} <: AbstractDAESystem
    param1::T1 = param1_default                 # optional field 
    param2::T2 = param2_default                 # optional field 
    param3::T3 = param3_default                 # optional field
        ⋮
    paramN::TN = paramN_default                 # optional field 
    righthandside::RH = righthandside_function  # mandatory field
    readout::RO = readout_function              # mandatory field
    state::ST = state_default                   # mandatory field
    stateder::ST = stateder_default             # mandatory field
    diffvars::Vector{Bool} = diffvars_default   # mandatory field
    input::IP = input_default                   # mandatory field
    output::OP = output_default                 # mandatory field
end
```
Here, `MyDAESystem` has `N` parameters. `MyDAESystem` is represented by the `righthandside` and `readout` function. `state`, 'stateder`, `diffvars`, `input` and `output` is the initial state, initial value of differential variables, vector signifing differetial variables, input port and output port of `MyDAESystem`.

!!! warning 
    `righthandside` must have the signature 
    ```julia
    function righthandside(out, dx, x, u, t, args...; kwargs...)
        out .= .... # update out
    end
    ```
    and `readout` must have the signature 
    ```julia
    function readout(x, u, t)
        y = ...
        return y
    end
    ```

!!! warning 
    New DAE system must be a subtype of `AbstractDAESystem` to function properly.

# Example 
```julia 
julia> @def_dae_system mutable struct MyDAESystem{RH, RO, ST, IP, OP} <: AbstractDAESystem
        righthandside::RH = function sfuncdae(out, dx, x, u, t)
                out[1] = x[1] + 1 - dx[1]
                out[2] = (x[1] + 1) * x[2] + 2
            end 
        readout::RO = (x,u,t) -> x 
        state::ST = [1., -1]
        stateder::ST = [2., 0]
        diffvars::Vector{Bool} = [true, false]
        input::IP = nothing 
        output::OP = Outport(1)
        end

julia> ds = MyDAESystem();
```
"""
macro def_dae_system(ex) 
    checksyntax(ex, :AbstractDAESystem)
    appendcommonex!(ex)
    foreach(nex -> appendex!(ex, nex), [
        :( alg::$ALG_TYPE_SYMBOL = Causal.IDA() ), 
        :( integrator::$INTEGRATOR_TYPE_SYMBOL = Causal.construct_integrator(
            Causal.DAEProblem, input, righthandside, state, t, modelargs, solverargs; alg=alg, 
            stateder=stateder, 
            modelkwargs=(; zip((keys(modelkwargs)..., :differential_vars), (values(modelkwargs)..., diffvars))...), 
            solverkwargs=solverkwargs, numtaps=3) ) 
        ])
    quote 
        Base.@kwdef $ex 
    end |> esc 
end


##### Defien DAE system library 

"""
    DAESystem(; righthandside, readout, state, stateder, diffvars, input, output)

Constructs a generic DAE system.

# Example
```jldoctest
julia> function sfuncdae(out, dx, x, u, t)
           out[1] = x[1] + 1 - dx[1]
           out[2] = (x[1] + 1) * x[2] + 2
       end;

julia> ofuncdae(x, u, t) = x;

julia> x0 = [1., -1];

julia> dx0 = [2., 0.];

julia> DAESystem(righthandside=sfuncdae, readout=ofuncdae, state=x0, input=nothing, output=Outport(1), diffvars=[true, false], stateder=dx0)
DAESystem(righthandside:sfuncdae, readout:ofuncdae, state:[1.0, -1.0], t:0.0, input:nothing, output:Outport(numpins:1, eltype:Outpin{Float64}))
```
"""
@def_dae_system mutable struct DAESystem{RH, RO, ST, IP, OP} <: AbstractDAESystem
    righthandside::RH 
    readout::RO 
    state::ST 
    stateder::ST 
    diffvars::Vector{Bool}
    input::IP 
    output::OP 
end


@doc raw"""
    RobertsonSystem() 

Constructs a Robertson systme with the dynamcis 
```math
\begin{array}{l}
    \dot{x}_1 = -k_1 x_1 + k_3 x_2 x_3 \\[0.25cm]
    \dot{x}_2 = k_1 x_1 - k_2 x_2^2 - k_3 x_2 x_3 \\[0.25cm]
    1 = x_1 + x_2 + x_3 
\end{array}
```
"""
@def_dae_system mutable struct RobertsonSystem{RH, RO, IP, OP} <: AbstractDAESystem 
    k1::Float64 = 0.04   
    k2::Float64 = 3e7 
    k3::Float64 = 1e4 
    righthandside::RH = function robertsonrhs(out, dx, x, u, t)
        out[1] = -k1 * x[1] + k3 * x[2] * x[3] - dx[1] 
        out[2] = k1 * x[1] - k2 * x[2]^2 - k3 * x[2] * x[3] - dx[2] 
        out[3] = x[1] + x[2] + x[3] - 1
    end
    rightout::RO = (x, u, t) -> x[1:2]
    state::Vector{Float64} = [1., 0., 0.]
    stateder::Vector{Float64} = [-k1, k1, 0.]
    diffvars::Vector{Bool} = [true, true, false]
    input::IP = nothing 
    output::OP = Outport(2)
end

@doc raw"""
    PendulumSystem() 

Constructs a Pendulum systme with the dynamics
```math
\begin{array}{l}
    \dot{x}_1 = x_3 \\[0.25cm]
    \dot{x}_2 = x_4 \\[0.25cm]
    \dot{x}_3 = -\dfrac{F}{m l} x_1 \\[0.25cm]
    \dot{x}_4 = g \dfrac{F}{l} x_2 \\[0.25cm]
    0 = x_1^2 + x_2^2 - l^2 
\end{array}
```
where ``F`` is the external force, ``l`` is the length, ``m`` is the mass and ``g`` is the accelaration of gravity.
"""
@def_dae_system mutable struct PendulumSystem{RH, RO, IP, OP} <: AbstractDAESystem
    F::Float64 = 1. 
    l::Float64 = 1.
    g::Float64 = 9.8 
    m::Float64 = 1.
    righthandside::RH = function pendulumrhs(out, dx, x, u, t)
        out[1] = x[3] - dx[1]  
        out[2] = x[4] - dx[2] 
        out[3] = - F / (m * l) * x[1] - dx[3]
        out[4] = g * F / l  * x[2] - dx[4]
        out[5] = x[1]^2 + x[2]^2 - l^2
    end
    readout::RO = (x, u, t) -> x[1:4]
    state::Vector{Float64} = [1., 0., 0., 0., 0.]
    stateder::Vector{Float64} = [0., 0., -1., 0., 0.]
    diffvars::Vector{Bool} = [true, true, true, true, false]
    input::IP = nothing
    output::OP = Outport(4)
end


@doc raw"""
    RLCSystem() 

Construsts a RLC system with the dynamics
```math
\begin{array}{l}
    \dot{x}_1 = x_3 \\[0.25cm]
    \dot{x}_2 = x_4 \\[0.25cm]
    \dot{x}_3 = -\dfrac{F}{m l} x_1 \\[0.25cm]
    \dot{x}_4 = g \dfrac{F}{l} x_2 \\[0.25cm]
    0 = x_1^2 + x_2^2 - l^2 
\end{array}
```
where ``F`` is the external force, ``l`` is the length, ``m`` is the mass and ``g`` is the accelaration of gravity.
"""
@def_dae_system mutable struct RLCSystem{RH, RO, IP, OP} <: AbstractDAESystem
    R::Float64 = 1. 
    L::Float64 = 1.
    C::Float64 = 1.
    righthandside::RH = function pendulumrhs(out, dx, x, u, t)
        out[1] = 1 / C * x[4] - dx[1]  
        out[2] = 1 / L * x[4] - dx[2]  
        out[3] = x[3] + R * x[5]  
        out[4] = x[1] + x[2] + x[3] + u[1](t)
        out[5] = x[4] - x[5]  
    end
    readout::RO = (x, u, t) -> x[1:2]
    state::Vector{Float64} = [0., 0., 0., 0., 0.]
    stateder::Vector{Float64} = [0., 0., 0., 0., 0.]
    diffvars::Vector{Bool} = [true, true, false, false, false]
    input::IP = Inport(1)
    output::OP = Outport(2)
end

##### Pretty printing 

show(io::IO, ds::DAESystem) = print(io, 
    "DAESystem(righthandside:$(ds.righthandside), readout:$(ds.readout), state:$(ds.state), t:$(ds.t), ", 
    "input:$(ds.input), output:$(ds.output))")
show(io::IO, ds::RobertsonSystem) = print(io, 
    "RobersonSystem(k1:$(ds.k1), k2:$(ds.k2), k2:$(ds.k3), state:$(ds.state), t:$(ds.t), ", 
    "input:$(ds.input), output:$(ds.output))")
show(io::IO, ds::PendulumSystem) = print(io, 
    "PendulumSystem(F:$(ds.F), m:$(ds.m), l:$(ds.l), g:$(ds.g), state:$(ds.state), t:$(ds.t), ", 
    "input:$(ds.input), output:$(ds.output))")
show(io::IO, ds::RLCSystem) = print(io, 
    "RLCSystem(R:$(ds.R), L:$(ds.L), C:$(ds.C), state:$(ds.state), t:$(ds.t), ", 
    "input:$(ds.input), output:$(ds.output))")
