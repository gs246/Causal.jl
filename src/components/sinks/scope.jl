# This file includes the scope


mutable struct Scope{IB, DB, TB, P, L, PLT} <: AbstractSink
    @generic_sink_fields
    plt::PLT
end
function Scope(input::Bus{Union{Missing, T}}, buflen::Int=64, plugin=nothing, args...; kwargs...) where T
    # Construct the plot 
    plt = plot(args...; kwargs...)
    foreach(sp -> plot!(sp, zeros(1)), plt.subplots)  # Plot initialization 
    # Construct the buffers
    timebuf = Buffer(buflen)
    databuf = Buffer(T, buflen)
    trigger = Link()
    addplugin(Scope(input, databuf, timebuf, plugin, trigger, Callback[], uuid4(), plt), update!)
end

show(io::IO, scp::Scope) = print(io, "Scope(nin:$(length(scp.input)))")

clear(sp::Plots.Subplot) = popfirst!(sp.series_list)  # Delete the old series 
function update!(s::Scope, x, y)
    plt = s.plt
    subplots = plt.subplots
    clear.(subplots)
    plot!(plt, x, y, xlim=(x[1], x[end]), label="")  # Plot the new series
    gui()
end

close(sink::Scope) = closeall()
open(sink::Scope) = Plots.isplotnull() ? (@warn "No current plots") : gui()
