{
  description = "FEX-Emu x86 RootFS (Auto-Discovery)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "aarch64-linux";
      pkgs = import nixpkgs { inherit system; };
      x86Pkgs = pkgs.pkgsCross.gnu64;

      # 1. The Application and Libraries
      targetApp = x86Pkgs.hello;
      baseLibs = [ x86Pkgs.glibc x86Pkgs.gcc.cc.lib ];

      # 2. Build the "RootFS"
      sysroot = pkgs.runCommand "fex-sysroot" { } ''
        mkdir -p $out/lib $out/lib64 $out/usr/lib $out/usr/bin $out/bin $out/etc
        
        # Helper to symlink libraries
        linkLibs() {
          for pkg in "$@"; do
             if [ -d "$pkg/lib" ]; then
               find "$pkg/lib" -type f -name "*.so*" -exec ln -s {} $out/usr/lib/ \;
             fi
          done
        }
        
        linkLibs ${pkgs.lib.concatStringsSep " " baseLibs}

        # Symlink the Loader
        ln -s ${x86Pkgs.glibc}/lib/ld-linux-x86-64.so.2 $out/lib64/ld-linux-x86-64.so.2
        
        # Copy the app (preserve permissions)
        cp -L ${targetApp}/bin/hello $out/usr/bin/hello
        chmod +x $out/usr/bin/hello
      '';

    in
    {
      packages.${system}.default = pkgs.writeShellScriptBin "run-fex-test" ''
        set -e
        
        echo "1. Locating FEX Binary..."
        FEX_BIN=$(find ${pkgs.fex}/bin -maxdepth 1 -executable -type f -name "FEX*" | head -n 1)
        
        if [ -z "$FEX_BIN" ]; then
          echo "ERROR: Could not find FEX binary in ${pkgs.fex}/bin"
          ls -la ${pkgs.fex}/bin
          exit 1
        fi

        echo "   Found: $FEX_BIN"
        echo "   RootFS: ${sysroot}"
        echo "--------------------------------"

        # Configure FEX
        export FEX_ROOTFS=${sysroot}
        
        # Run! (Use absolute path within the rootfs)
        exec "$FEX_BIN" /usr/bin/hello "$@"
      '';
    };
}
