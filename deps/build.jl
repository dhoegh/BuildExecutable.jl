@windows_only begin
    using WinRPM
    WinRPM.install("gcc",yes=true)
end

@linux_only begin
    using BinDeps
    run(@build_steps begin
        `sudo add-apt-repository ppa:staticfloat/julia-deps -y`
        `sudo apt-get update -qq -y`
        `sudo apt-get install patchelf`
    end)
end

    
