{
  description = "Snagboot - A tool for recovering and flashing embedded platforms";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        python = pkgs.python3;
        
        # Define the snagboot package directly based on package.nix
        snagbootPackage = python.pkgs.buildPythonApplication {
          pname = "snagboot";
          version = "2.2";
          pyproject = true;
          
          src = ./.;  # Use local source
          
          nativeBuildInputs = with python.pkgs; [
            setuptools
          ];
          
          # Remove problematic dependencies
          pythonRemoveDeps = [
            "pylibfdt"
            "swig"
            "xmodem"
            "tftpy"
            "crccheck"
          ];
          
          propagatedBuildInputs = with python.pkgs; [
            pyyaml
            pyusb
            pyserial
            tftpy
            crccheck
            packaging
            kivy  # Add Kivy as a direct dependency
          ];
          
          # Optional GUI dependencies
          passthru.optional-dependencies = with python.pkgs; {
            gui = [ kivy ];
          };
          
          # Install udev rules on Linux
          postInstall = pkgs.lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
            rules="src/snagrecover/50-snagboot.rules"
            if [ ! -f "$rules" ]; then
                echo "$rules is missing, must update the Nix file."
                exit 1
            fi
            
            mkdir -p "$out/lib/udev/rules.d"
            cp "$rules" "$out/lib/udev/rules.d/50-snagboot.rules"
          '';
          
          # No tests
          doCheck = false;
          
          meta = {
            homepage = "https://github.com/bootlin/snagboot";
            description = "Generic recovery and reflashing tool for embedded platforms";
            license = pkgs.lib.licenses.gpl2;
          };
        };
      in
      {
        packages.default = snagbootPackage;

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Include the locally built snagboot package
            snagbootPackage
            # Include dependencies for development
            python
            libusb1
            python.pkgs.kivy  # Add Kivy to the development shell
          ];

          shellHook = ''
            echo "Entering Snagboot development environment"
            echo "Local snagboot package is installed in this environment"
            echo "Run 'snagrecover --list-socs' to see the supported SoCs, including Ambarella"
            echo "To test Ambarella SoC support, run:"
            echo "snagrecover -s cv22 -f src/snagrecover/templates/ambarella-cv22.yaml"
          '';
        };
      }
    );
}
