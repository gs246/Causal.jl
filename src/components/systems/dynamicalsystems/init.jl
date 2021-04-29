# This file includes intregrator construction


function construct_integrator(deproblem, input, righthandside, state, t, modelargs=(), solverargs=(); 
    alg=nothing, stateder=state, modelkwargs=NamedTuple(), solverkwargs=NamedTuple(), numtaps=3)
    # If needed, construct interpolant for input.
    interpolant = input === nothing ? nothing : Interpolant(numtaps, length(input))

    # Construct the problem 
    if deproblem == SDEProblem 
        problem = deproblem(righthandside[1], righthandside[2], state, (t, Inf), interpolant, modelargs...; 
        modelkwargs...)
    elseif deproblem == DDEProblem
        problem = deproblem(righthandside[1], state, righthandside[2], (t, Inf), interpolant, modelargs...;
         modelkwargs...)
    elseif deproblem == DAEProblem
        problem = deproblem(righthandside, stateder, state, (t, Inf), interpolant, modelargs...; 
        modelkwargs...)
    else
        problem = deproblem(righthandside, state, (t, Inf), interpolant, modelargs...; 
        modelkwargs...)
    end

    # Initialize the integrator
    init(problem, alg, solverargs...; save_everystep=false, dense=true, solverkwargs...)
end

#= This function checks whether the syntax is of the form 
    
    @my_macro_to_define_new_dynamical_system mutable struct NewSystem{T, S} <: SuperTypeName 
        # fields 
    end 
    
    where @my_macro_to_define_new_dynamical_system is any macro used to define new dynamical system such as @def_ode_system, @def_sde_system, etc.   
=#
function checksyntax(ex::Expr, supertypename::Symbol)
    ex.head == :struct && ex.args[1] || 
        error("Invalid usage. The expression should start with `mutable struct`.\n$ex")
    ex.args[2].head == :(<:) && ex.args[2].args[2] == supertypename || 
        error("Invalid usage. The type should be a subtype of $supertypename.\n$ex")
end

function appendcommonex!(ex)
    foreach(nex -> appendex!(ex, nex), [
    :( trigger::$TRIGGER_TYPE_SYMBOL = Inpin() ),
    :( handshake::$HANDSHAKE_TYPE_SYMBOL = Outpin{Bool}() ),
    :( callbacks::$CALLBACKS_TYPE_SYMBOL = nothing ),
    :( name::Symbol = Symbol() ),
    :( id::$ID_TYPE_SYMBOL = Causal.uuid4() ),
    :( t::Float64 = 0. ),
    :( modelargs::$MODEL_ARGS_TYPE_SYMBOL = ()  ),
    :( modelkwargs::$MODEL_KWARGS_TYPE_SYMBOL = NamedTuple()  ), 
    :( solverargs::$SOLVER_ARGS_TYPE_SYMBOL = ()  ), 
    :( solverkwargs::$SOLVER_KWARGS_TYPE_SYMBOL = NamedTuple()  ), 
    ])
    ex 
end

# For syntactic-sugar: ds.interpolant
function getproperty(ds::AbstractDynamicSystem, name::Symbol)
    name == :interpolant ? ds.integrator.sol.prob.p : getfield(ds, name) 
end
