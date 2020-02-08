# This file includes the Model object

using ProgressMeter

"""
    Model(blocks::AbstractVector)

Constructs a `Model` whose with components `blocks` which are of type `AbstractComponent`.

    Model()

Constructs a `Model` with empty components. After the construction, components can be added to `Model`.

!!! warning
    `Model`s are units that can be simulated. As the data flows through the connections i.e. input output busses of the components, its is important that the components must be connected to each other. See also: [`simulate`](@ref)
"""
mutable struct Model{BL<:AbstractVector, CLK, TM}
    blocks::BL
    clk::CLK
    taskmanager::TM
    callbacks::Vector{Callback}
    id::UUID
    function Model(blocks::AbstractVector)
        taskmanager = TaskManager()
        clk = Clock(NaN, NaN, NaN)
        new{typeof(blocks), typeof(clk), typeof(taskmanager)}(blocks, clk, taskmanager, Callback[], uuid4())
    end
end
Model(blocks::AbstractComponent...) = Model([blocks...])
Model() = Model([])

show(io::IO, model::Model) = print(io, "Model(blocks:$(model.blocks))")

##### Adding components to model 
"""
    addcomponent(model::Model, comp::AbstractComponent)

Adds `comp` to `model` components.

# Example
```jldoctest 
julia> m = Model()
Model(blocks:Any[])

julia> addcomponent(m, SinewaveGenerator())
1-element Array{Any,1}:
 SinewaveGenerator(amp:1.0, freq:1.0, phase:0.0, offset:0.0, delay:0.0)
```
"""
addcomponent(model::Model, comp::AbstractComponent...) = foreach(cmp -> push!(model.blocks, cmp), comp)

##### Model inspection.
function adjacency_matrix(model::Model)
    blocks = model.blocks
    n = length(model.blocks) 
    mat = zeros(Int, n, n)
    for i = 1 : n 
        for j = 1 : n 
            if isconnected(blocks[i].output, blocks[j].input)
                mat[i, j] = 1
            end
        end
    end
    mat
end

isterminated(output) = isa(output, Nothing) ? true : hasslaves(output)
has_unterminated_bus(model::Model) = 
    any([!isterminated(block.output) for block in model.blocks if !isa(block, AbstractSink)])

function terminate_securely!(model::Model)
    # TODO: Complete the function.
    nothing
end

function has_algeraic_loop(model::Model)
    # TODO: Complete the function
    false
end

function break_algebraic_loop!(model)
    # TODO: Complete the function
    nothing
end

"""
    inspect(model::Model)

Inspects the `model`. If `model` has some inconsistencies such as including algebraic loops or unterminated busses and error is thrown.
"""
function inspect(model)
    # TODO : Complete the function.
    # if has_unterminated_bus(model)
    #     msg = "Model has unterminated busses. Please check the model carefully for unterminated busses."
    #     throw(SimulationError(msg))
    # end
    if has_algeraic_loop(model)
        try
            break_algebraic_loop!(model)
        catch
            error("Algebric loop cannot be broken.")
        end
    end
end

##### Model initialization
"""
    initialize(model::Model)

Initializes `model` by launching component task for each of the component of `model`. The pairs component and component tasks are recordedin the task manager of the `model`. See also: [`ComponentTask`](@ref), [`TaskManager`](@ref). The `model` clock is [`set!`](@ref) and the files of [`Writer`](@ref) are openned.
"""
function initialize(model::Model)
    pairs = model.taskmanager.pairs
    blocks = model.blocks
    for block in blocks
        pairs[block] = typeof(block) <: AbstractSubSystem ? ComponentTask.(launch(block)) : ComponentTask(launch(block))
    end
    isrunning(model.clk) || set!(model.clk)  # Turnon clock internal generator.
    for writer in filter(block->isa(block, Writer), model.blocks)  # Open writer files.
        writer.file = jldopen(writer.file.path, "a")
    end
end

##### Model running
"""
    run(model::Model)

Runs the `model` by triggering the components of the `model`. This triggering is done by generating clock tick using the model clock `model.clk`. Triggering starts with initial time of model clock, goes on with a step size of the sampling period of the model clock, and finishes at the finishing time of the model clock. 

!!! warning 
    The `model` must first be initialized to be `run`. See also: [`initialize`](@ref).
```
"""
function run(model::Model)
    taskmanager = model.taskmanager
    components = model.blocks
    clk = model.clk
    @showprogress clk.dt for t in clk
        foreach(component -> drive(component, t), components)
        all(approve.(components)) || @warn "Could not be approved"
        checktaskmanager(taskmanager)          
        model.callbacks(model)                           
    end
end

##### Model termination
""" 
    release(model::Model)

Releaes the each component of `model`, i.e., the input and output bus of each component is released.
"""
release(model::Model) = foreach(release, model.blocks)

"""
    terminate(model::Model)

Terminates `model` by terminating all the components of the `model`, i.e., the components tasks in the task manager of the `model` is terminated. See also: [`ComponentTask`](@ref), [`TaskManager`](@ref).
"""
function terminate(model::Model)
    isempty(model.taskmanager.pairs) || foreach(terminate, model.blocks)
    isrunning(model.clk) && stop!(model.clk)
    return
end


function _simulate!(sim::Simulation, reportsim::Bool)
    model = sim.model
    try
        @siminfo "Started simulation..."
        sim.state = :running

        @siminfo "Inspecting model..."
        inspect(model)
        @siminfo "Done."

        @siminfo "Initializing the model..."
        initialize(model)
        @siminfo "Done..."

        @siminfo "Running the simulation..."
        run(model)
        sim.state = :done
        sim.retcode = :success
        @siminfo "Done..."
    catch e
        sim.state = :halted
        sim.retcode = :fail
        @info e
    end

    @siminfo "Releasing model components..."
    release(model)
    @siminfo "Done."
   
    @siminfo "Terminating the simulation..."
    terminate(model)
    @siminfo "Done."

    reportsim && report(sim)

    return sim
end

"""
    simulate(model::Model;  simdir::String="/tmp", logtofile::Bool=false, reportsim::Bool=false)

Simulates `model`. `simdir` is the path of the directory into which simulation files are saved. If `logtofile` is `true`, a log file for the simulation is constructed. If `reportsim` is `true`, model components are saved into files.
"""
function simulate(model::Model;  simdir::String=tempdir(), logtofile::Bool=false, reportsim::Bool=false)
    sim = Simulation(model, simdir)
    if logtofile
        sim.logger = setlogger(sim.path, "log.txt", setglobal=false)
        with_logger(sim.logger) do
            _simulate!(sim, reportsim)
        end
        flush(sim.logger.stream)  # Close logger file stream.
    else
        _simulate!(sim, reportsim)
    end
    return sim
end

""" 
    simulate(model::Model, t0::Real, dt::Real, tf::Real; kwargs...)

Simulates the `model` starting from the initial time `t0` until the final time `tf` with the sampling interval of `tf`. For `kwargs` are 

* `logtofile::Bool`: If `true`, a log file is contructed logging each step of the simulation. 
* `reportsim::Bool`: If `true`, `model` components are written files after the simulation. When this file is read back, the model components can be consructed back with their status at the end of the simulation.
* `simdir::String`: The path of the directory in which simulation file are recorded. 
"""
function simulate(model::Model, t0::Real, dt::Real, tf::Real; kwargs...)
    set!(model.clk, t0, dt, tf)
    simulate(model; kwargs...)
end


""" 
    findin(model::Model, id::UUID)

Returns the component of the `model` corresponding whose id is `id`.

    findin(model::Model, comp::AbstractComponent)

Returns the compeonent whose variable name is `comp`.
"""
function findin end
findin(model::Model, id::UUID) = model.blocks[findfirst(block -> block.id == id, model.blocks)]
findin(model::Model, comp::AbstractComponent) = model.blocks[findfirst(block -> block.id == comp.id, model.blocks)]
