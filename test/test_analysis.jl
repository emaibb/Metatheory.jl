using MatchCore

# example assuming * operation is always binary

# ENV["JULIA_DEBUG"] = Metatheory

abstract type NumberFold <: AbstractAnalysis end

# This should be auto-generated by a macro
function EGraphs.make(an::Type{NumberFold}, g::EGraph, n::ENode)
    n.head isa Number && return n.head

    if ariety(n) == 2
        l = g.M[n.args[1]]
        r = g.M[n.args[2]]
        ldata = getdata(l, an, nothing)
        rdata = getdata(r, an, nothing)

        if ldata isa Number && rdata isa Number
            if n.head == :*
                return ldata * rdata
            elseif n.head == :+
                return ldata + rdata
            end
        end
    end

    return nothing
end

function EGraphs.join(an::Type{NumberFold}, from, to)
    if from isa Number
        if to isa Number
            @assert from == to
        else return from
        end
    end
    return to
end

function EGraphs.modify!(an::Type{NumberFold}, g::EGraph, id::Int64)
    # !haskey(an, id) && return nothing
    eclass = g.M[id]
    d = getdata(eclass, an, nothing)
    if d isa Number
        newclass = addexpr!(g, d)
        merge!(g, newclass.id, id)
    end
end

EGraphs.islazy(x::Type{NumberFold}) = false

comm_monoid = @theory begin
    a * b => b * a
    a * 1 => a
    a * (b * c) => (a * b) * c
end

G = EGraph(:(3 * 4))
analyze!(G, NumberFold)

# exit(0)

@testset "Basic Constant Folding Example - Commutative Monoid" begin
    # addanalysis!(G, NumberFold())
    @test (true == @areequalg G comm_monoid 3 * 4 12)

    @test (true == @areequalg G comm_monoid 3 * 4 12 4*3  6*2)
end


@testset "Basic Constant Folding Example 2 - Commutative Monoid" begin
    ex = :(a * 3 * b * 4)
    G = EGraph(cleanast(ex))
    addanalysis!(G, NumberFold)
    @test (true == @areequalg G comm_monoid (3 * a) * (4 * b) (12*a)*b ((6*2)*b)*a)
end

@testset "Basic Constant Folding Example - Adding analysis after saturation" begin
    G = EGraph(:(3 * 4))
    # addexpr!(G, 12)
    saturate!(G, comm_monoid)
    addexpr!(G, :(a * 2))
    addanalysis!(G, NumberFold)
    saturate!(G, comm_monoid)

    # display(G.M); println()
    # println(G.root)
    # display(G.analyses[1].data); println()

    @test (true == areequal(G, comm_monoid, :(3 * 4), 12, :(4*3), :(6*2)))

    ex = :(a * 3 * b * 4)
    G = EGraph(cleanast(ex))
    addanalysis!(G, NumberFold)
    params=SaturationParams(timeout=15)
    @test areequal(G, comm_monoid, :((3 * a) * (4 * b)), :((12*a)*b),
        :(((6*2)*b)*a); params=params)
end

@testset "Infinite Loops analysis" begin
    boson = @theory begin
        1 * x => x
    end

    G = EGraph(Util.cleanast( :(1 * x) ))
    params=SaturationParams(timeout=100)
    saturate!(G,boson, params)
    ex = extract!(G, ExtractionAnalysis{astsize})

    # println(ex)

    using Metatheory.EGraphs
    boson = @theory begin
        (:c * :cdag) => :cdag * :c + 1
        a * (b + c) => (a * b) + (a * c)
        (b + c) * a => (b * a) + (c * a)
        # 1 * x => x
        (a * b) * c => a * (b * c)
        a * (b * c) => (a * b) * c
    end

    G = EGraph(Util.cleanast( :(c * c * cdag * cdag) ))
    saturate!(G,boson)
    ex = extract!(G, astsize_inv)

    # println(ex)
end
