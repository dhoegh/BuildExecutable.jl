@windows_only begin
    using WinRPM
    # Windows note:
    # gcc is required to compile the program. gcc can is installed using WinRPM.
    Pkg.add("WinRPM")
    WinRPM.install("gcc")
end