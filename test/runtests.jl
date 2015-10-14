using BuildExecutable
using Base.Test
script = joinpath(dirname(@__FILE__), "test.jl")
@test isfile(script)
targetdir = joinpath(dirname(@__FILE__),"test_dir")
mkdir(targetdir)
exename="test_executable"
try
    @test build_executable(exename, script, targetdir, "native"; force=false) == 0
    run(`$(joinpath(targetdir,exename * @windows? ".exe" : ""))`)
finally
    rm(targetdir, recursive=true)
end
