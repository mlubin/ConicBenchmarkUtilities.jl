
mutable struct CBFData
    name::String
    sense::Symbol
    objoffset::Float64

    nvar::Int
    var::Vector{Tuple{String, Int}}
    psdvar::Vector{Int}
    intlist::Vector{Int}

    ncon::Int
    con::Vector{Tuple{String, Int}}
    psdcon::Vector{Int}

    objacoord::Vector{Tuple{NTuple{1, Int}, Float64}}
    acoord::Vector{Tuple{NTuple{2, Int}, Float64}}
    bcoord::Vector{Tuple{NTuple{1, Int}, Float64}}
    objfcoord::Vector{Tuple{NTuple{3, Int}, Float64}}
    fcoord::Vector{Tuple{NTuple{4, Int}, Float64}}
    hcoord::Vector{Tuple{NTuple{4, Int}, Float64}}
    dcoord::Vector{Tuple{NTuple{3, Int}, Float64}}
end

CBFData() = CBFData("", :xxx, 0.0, 0, [], [], [], 0, [], [], [], [], [], [], [], [], [])

function parse_matblock(fd, outputmat::Vector{Tuple{NTuple{N, Int}, Float64}}) where N
    numnz = parse(Int, strip(readline(fd)))
    for k in 1:numnz
        linesplit = split(strip(readline(fd)))
        idxs = NTuple{N, Int}(parse(Int, linesplit[i]) + 1 for i in 1:N)
        val = parse(Float64, linesplit[end])
        push!(outputmat, (idxs, val))
    end
end

function readcbfdata(filename)
    if endswith(filename, "cbf.gz")
        fd = GZip.gzopen(filename, "r")
    elseif endswith(filename, "cbf")
        fd = open(filename, "r")
    else
        error("filename $filename does not end with .cbf or .cbf.gz")
    end

    dat = CBFData()
    dat.name = split(basename(filename), ".")[1]

    while !eof(fd)
        line = strip(readline(fd))

        if startswith(line, "#") || length(line) == 1 # comments or blank lines
            continue
        end

        if startswith(line, "VER")
            nextline = strip(readline(fd))
            @assert startswith(nextline, "1") || startswith(nextline, "2") || startswith(nextline, "3")
            continue
        end

        if startswith(line, "OBJSENSE")
            dat.sense = (strip(readline(fd)) == "MIN") ? :Min : :Max
            continue
        end

        if startswith(line, "VAR")
            (numtotalvars, numvarlines) = (parse(Int, strip(i)) for i in split(strip(readline(fd))))
            varcount = 0
            for k in 1:numvarlines
                cone_conesize = split(strip(readline(fd)))
                conesize = parse(Int, cone_conesize[2])
                push!(dat.var, (cone_conesize[1], conesize))
                varcount += conesize
            end
            @assert numtotalvars == varcount
            dat.nvar = varcount
            continue
        end

        if startswith(line, "INT")
            numintvar = parse(Int, strip(readline(fd)))
            for k in 1:numintvar
                idx = parse(Int, strip(readline(fd)))
                push!(dat.intlist, idx+1)
            end
            continue
        end

        if startswith(line, "CON")
            (numtotalcons, numconlines) = (parse(Int, strip(i)) for i in split(strip(readline(fd))))
            concount = 0
            for k in 1:numconlines
                cone_conesize = split(strip(readline(fd)))
                conesize = parse(Int, cone_conesize[2])
                push!(dat.con, (cone_conesize[1], conesize))
                concount += conesize
            end
            @assert numtotalcons == concount
            dat.ncon = concount
            continue
        end

        if startswith(line, "PSDVAR")
            numpsdvar = parse(Int, strip(readline(fd)))
            for k in 1:numpsdvar
                conesize = parse(Int, strip(readline(fd)))
                push!(dat.psdvar, conesize)
            end
            continue
        end

        if startswith(line, "PSDCON")
            numpsdcon = parse(Int, strip(readline(fd)))
            for k in 1:numpsdcon
                conesize = parse(Int, strip(readline(fd)))
                push!(dat.psdcon, conesize)
            end
            continue
        end

        if startswith(line, "OBJACOORD")
            parse_matblock(fd, dat.objacoord)
        end

        if startswith(line, "OBJBCOORD")
            dat.objoffset = parse(Float64, strip(readline(fd)))
            println("instance has objective offset")
        end

        if startswith(line, "BCOORD")
            parse_matblock(fd, dat.bcoord)
        end

        if startswith(line, "ACOORD")
            parse_matblock(fd, dat.acoord)
        end

        if startswith(line, "OBJFCOORD")
            parse_matblock(fd, dat.objfcoord)
        end

        if startswith(line, "FCOORD")
            parse_matblock(fd, dat.fcoord)
        end

        if startswith(line, "HCOORD")
            parse_matblock(fd, dat.hcoord)
        end

        if startswith(line, "DCOORD")
            parse_matblock(fd, dat.dcoord)
        end
    end

    close(fd)
    return dat
end

function writecbfdata(filename, dat::CBFData, comments="")
    if endswith(filename, "cbf.gz")
        fd = GZip.gzopen(filename, "w")
    elseif endswith(filename, "cbf")
        fd = open(filename, "w")
    else
        error("filename $filename does not end with .cbf or .cbf.gz")
    end

    if comments == ""
        println(fd, "# Generated by ConicBenchmarkUtilities.jl")
    else
        println(fd, comments)
    end
    println(fd, "VER\n2\n")

    println(fd, "OBJSENSE")
    if dat.sense == :Min
        println(fd, "MIN")
    else
        @assert dat.sense == :Max
        println(fd, "MAX")
    end
    println(fd)

    if length(dat.psdvar) > 0
        println(fd, "PSDVAR")
        println(fd, length(dat.psdvar))
        for v in dat.psdvar
            println(fd, v)
        end
        println(fd)
    end

    println(fd, "VAR")
    println(fd, dat.nvar, " ", length(dat.var))
    for (cone, nvar) in dat.var
        println(fd, cone, " ", nvar)
    end
    println(fd)

    if length(dat.intlist) > 0
        println(fd, "INT")
        println(fd, length(dat.intlist))
        for k in dat.intlist
            println(fd, k - 1)
        end
        println(fd)
    end

    if length(dat.psdcon) > 0
        println(fd, "PSDCON")
        println(fd, length(dat.psdcon))
        for v in dat.psdcon
            println(fd, v)
        end
        println(fd)
    end

    println(fd, "CON")
    println(fd, dat.ncon, " ", length(dat.con))
    for (cone, ncon) in dat.con
        println(fd, cone, " ", ncon)
    end
    println(fd)

    if length(dat.objfcoord) > 0
        println(fd, "OBJFCOORD")
        println(fd, length(dat.objfcoord))
        for ((a, b, c), v) in dat.objfcoord
            println(fd, a-1, " ", b-1, " ", c-1, " ", v)
        end
        println(fd)
    end

    if length(dat.objacoord) > 0
        println(fd, "OBJACOORD")
        println(fd, length(dat.objacoord))
        for ((a,), v) in dat.objacoord
            println(fd, a-1, " ", v)
        end
        println(fd)
    end

    if !iszero(dat.objoffset)
        println(fd, "OBJBCOORD")
        println(fd, dat.objoffset)
        println(fd)
    end

    if length(dat.fcoord) > 0
        println(fd, "FCOORD")
        println(fd, length(dat.fcoord))
        for ((a, b, c, d), v) in dat.fcoord
            println(fd, a-1, " ", b-1, " ", c-1, " ", d-1, " ", v)
        end
        println(fd)
    end

    if length(dat.acoord) > 0
        println(fd, "ACOORD")
        println(fd, length(dat.acoord))
        for ((a, b), v) in dat.acoord
            println(fd, a-1, " ", b-1, " ", v)
        end
        println(fd)
    end

    if length(dat.hcoord) > 0
        println(fd, "HCOORD")
        println(fd, length(dat.hcoord))
        for ((a, b, c, d), v) in dat.hcoord
            println(fd, a-1, " ", b-1, " ", c-1, " ", d-1, " ", v)
        end
        println(fd)
    end

    if length(dat.dcoord) > 0
        println(fd, "DCOORD")
        println(fd, length(dat.dcoord))
        for ((a, b, c), v) in dat.dcoord
            println(fd, a-1, " ", b-1, " ", c-1, " ", v)
        end
        println(fd)
    end

    if length(dat.bcoord) > 0
        println(fd, "BCOORD")
        println(fd, length(dat.bcoord))
        for ((a,), v) in dat.bcoord
            println(fd, a-1, " ", v)
        end
        println(fd)
    end

    close(fd)
    return nothing
end
