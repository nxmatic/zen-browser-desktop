{
  description = "A flake to create a symbolic link for gtar";

  nixConfig = {
    substituters = [
      "https://cache.nixos.org"
      "https://cache.flox.dev"
      "https://nxmatic.cachix.org"
    ];

    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "flox-cache-public-1:7F4OyH7ZCnFhcze3fJdfyXYLQw/aV7GEed86nQ7IsOs="
      "nxmatic.cachix.org-1:huMghYiwDpPa1PMXHXK4G1Dp4QOZjgsNqxcjf/AjuJ0="
    ];
  };

  inputs = {
    nxmatic-flake-commons.url = "github:nxmatic/nix-flake-commons/develop";
    nixpkgs.follows = "nxmatic-flake-commons/nixpkgs";
  };

  outputs = { self, nxmatic-flake-commons, nixpkgs }: {
    packages = {
      default = nixpkgs.lib.mkShell {
        buildInputs = with nixpkgs; [ coreutils gnutar ];

        shellHook = ''
          mkdir -p $out/bin
          ln -s ${nixpkgs.gnutar}/bin/tar $out/bin/gtar
        '';
      };
    };
  };
}
