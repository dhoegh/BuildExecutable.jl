using BuildExecutable
using Base.Test
script = joinpath(dirname(@__FILE__), "test.jl")
@test isfile(script)
targetdir = joinpath(dirname(@__FILE__),"test_dir")
mkdir(targetdir)
exename="test_executable"
try
    @test build_executable(exename, script, targetdir, "native"; force=false) == 0
    mv(targetdir, targetdir*"1")
    targetdir = targetdir*"1"
    run(`$(joinpath(targetdir,exename * @windows? ".exe" : "")) -arg1 arg2 -arg3 arg4`)
finally
    rm(targetdir, recursive=true)
end
