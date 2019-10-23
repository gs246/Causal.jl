# This file includes RODESystems

import ....Components.Base: @generic_system_fields, @generic_dynamic_system_fields, AbstractRODESystem

const RODESolver = Solver(RandomEM())
const RODENoise = Noise(WienerProcess(0.,0.))


mutable struct RODESystem{IB, OB, T, H, SF, OF, ST, S, N} <: AbstractRODESystem
    @generic_dynamic_system_fields
    noise::N
    function RODESystem(input, output, statefunc, outputfunc, state, t, noise, solver=RODESolver)
        trigger = Link()
        handshake = Link{Bool}()
        new{typeof(input), typeof(output), typeof(trigger), typeof(handshake), typeof(statefunc), typeof(outputfunc), 
            typeof(state), typeof(solver), typeof(noise)}(input, output, trigger, Callback[], uuid4(), statefunc, 
            outputfunc, state, t, solver, noise)
    end
end

show(io::IO, ds::RODESystem) = print(io, "RODESystem(state:$(ds.state), t:$(ds.t), input:$(checkandshow(ds.input)), ",  
    "output:$(checkandshow(ds.output)), noise:$(checkandshow(ds.noise)))")

