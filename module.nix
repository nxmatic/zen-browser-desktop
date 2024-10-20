{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.zen-browser;
in {
  options.programs.zen-browser = {
    enable = mkEnableOption "Zen Browser";
    package = mkOption {
      type = types.package;
      default = pkgs.zen-browser-unwrapped;
      description = "The Zen Browser package to use";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
  };
}
