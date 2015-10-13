using BinDeps
@windows_only begin
    using WinRPM
    gcc = library_dependency("gcc.exe")
    provides(WinRPM.RPM, "gcc", gcc, os = :Windows )
end