using BinDeps

@BinDeps.setup

@windows_only begin
    using WinRPM
    WinRPM.install("gcc",yes=true)
end

@linux_only begin
    patchelf = library_dependency("patchelf")
    
    version = "0.9"
    provides(Sources, URI("https://nixos.org/releases/patchelf/patchelf-0.9/patchelf-$version.tar.gz"), patchelf, unpacked_dir="patchelf")
    @BinDeps.install Dict(:patchelf_dep => :patchelf)
end