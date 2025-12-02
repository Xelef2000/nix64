{
  description = "Nix-Box64 x86 Emulation Prototype";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      # We assume we are running on ARM Linux
      system = "aarch64-linux";
      pkgs = import nixpkgs { inherit system; };

      # 1. Access the x86_64 package set
      # pkgsCross.gnu64 allows us to build/fetch packages for x86_64
      x86Pkgs = pkgs.pkgsCross.gnu64;

      # 2. Create a dummy x86 application
      # We compile this specifically for x86_64 to prove emulation works.
      myX86App = x86Pkgs.runCommand "hello-x86" { } ''
        mkdir -p $out/bin
        ${x86Pkgs.buildPackages.gcc}/bin/gcc -x c -o $out/bin/hello - <<EOF
        #include <stdio.h>
        #include <sys/utsname.h>

        int main() { 
            struct utsname buffer;
            uname(&buffer);
            
            printf("\n--- INSIDE THE MATRIX ---\n");
            printf("Success! I am an x86_64 binary running on ARM.\n");
            printf("System reports architecture as: %s\n", buffer.machine);
            printf("-------------------------\n");
            return 0; 
        }
        EOF
      '';

      # 3. Define the libraries needed
      # For a simple C app, we only need glibc.
      # For real apps, you would add x86Pkgs.openssl, x86Pkgs.gtk3, etc. here.
      libs = [ x86Pkgs.pkgs.glibc ];
      
      libPath = pkgs.lib.makeLibraryPath libs;

    in
    {
      # The default package simply runs the wrapper script
      packages.${system}.default = pkgs.writeShellScriptBin "run-x86-test" ''
        echo "1. Setting up environment..."
        
        # Point Box64 to the x86 libraries in the Nix store
        export LD_LIBRARY_PATH=${libPath}:$LD_LIBRARY_PATH
        
        # Optional: Enable Box64 info logs so we see it working
        export BOX64_LOG=1 
        
        echo "2. Launching Box64..."
        # Syntax: box64 [path-to-binary]
        exec ${pkgs.box64}/bin/box64 ${myX86App}/bin/hello
      '';
    };
}