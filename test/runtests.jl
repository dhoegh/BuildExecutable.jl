using BuildExecutable
using Base.Test
using Compat
script = joinpath(dirname(@__FILE__), "test.jl")
@test isfile(script)
targetdir = joinpath(dirname(@__FILE__),"test_dir")
mkdir(targetdir)
exename="test_executable"
try
    @test build_executable(exename, script, targetdir, "native"; force=false) == 0
    mv(targetdir, targetdir*"1")
    targetdir = targetdir*"1"
    out = readstring(`$(joinpath(targetdir,exename * (is_windows() ? ".exe" : ""))) -arg1 arg2 -arg3 arg4`)
    @test contains(out, "-arg1,arg2,-arg3,arg4")
    @test contains(out, "It works")
finally
    rm(targetdir, recursive=true)
end
