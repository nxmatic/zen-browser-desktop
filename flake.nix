{
  description = "Zen Browser Flake";

  nixConfig = {
    substituters = [
      "https://cache.nixos.org"
    ];

    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
  };

  inputs = {
    nxmatic-flake-commons.url = "github:nxmatic/nix-flake-commons/develop";

    flake-utils.follows = "nxmatic-flake-commons/flake-utils";
    nixpkgs.follows = "nxmatic-flake-commons/nixpkgs";
    nvfetcher.follows = "nxmatic-flake-commons/nvfetcher";
  };

  outputs = { self, nixpkgs, flake-utils, nvfetcher }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import ./surfer-overlay.nix) ];
        pkgs = import nixpkgs {
          inherit system overlays;
        };
        nvfetcherBin = nvfetcher.packages.${system}.default;
        
        firefoxDmg = (pkgs.callPackage ./package-unwrapped.nix { inherit sources; }).passthru.firefoxDmg;
          
        mountEngineShadow = pkgs.writeShellScriptBin "mountEngineShadow" ''
          /usr/bin/hdiutil attach "${firefoxDmg}/firefox.dmg" -quiet -noverify -mountpoint engine -readwrite -nobrowse -shadow .engine-shadow
        '';

        # Function to generate sources
        generateSources = pkgs.writeShellScriptBin "generate-sources" ''
          ${nvfetcherBin}/bin/nvfetcher -c ${./nvfetcher.toml} -o _sources 
        '';

        # Import generated sources
        sources = import ./_sources/generated.nix { 
          inherit (pkgs) fetchgit fetchurl fetchFromGitHub;
          dockerTools = pkgs.dockerTools or {};
        };
      in
      {
        packages = {
          default = pkgs.callPackage ./package-unwrapped.nix { 
            inherit sources;
          };
          
          mountEngineShadow = mountEngineShadow;
          
          updateSources = generateSources;
        };

        apps = {

          mountEngineShadow = flake-utils.lib.mkApp {
            drv = mountEngineShadow;
          };

          updateSources = flake-utils.lib.mkApp {
            drv = generateSources;
          };
        };

        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [
            nodejs
            pnpm
            python311
            git
            pkg-config
          ];

          shellHook = ''
            echo "Welcome to Zen Browser development environment!"
            echo "Use 'surfer' commands to interact with the build process."
          '';
        };
      }
    ) // {
      nixosModule = import ./module.nix;
      darwinModule = import ./module.nix;
    };
}
