{
  description = "Plymouth boot splash themes built from the official NixOS branding";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    nixos-branding.url = "github:NixOS/branding";
    nixos-branding.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixos-branding,
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      # Directory names under ./themes; each provides packages
      # nixos-plymouth-<name> and nixos-plymouth-<name>-preview.
      themes = [ "default" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (
        pkgs:
        let
          branding = nixos-branding.legacyPackages.${pkgs.stdenv.hostPlatform.system}.nixos-branding;
          nixos-plymouth-default = pkgs.callPackage ./themes/default/package.nix {
            logomark = branding.artifacts.internal.nixos-logomark-default-gradient-none;
          };
        in
        {
          inherit nixos-plymouth-default;
          nixos-plymouth-default-preview = pkgs.callPackage ./themes/default/preview.nix {
            theme = nixos-plymouth-default;
          };
          default = nixos-plymouth-default;
          preview = self.packages.${pkgs.stdenv.hostPlatform.system}.nixos-plymouth-default-preview;
        }
      );

      # Writes each theme's preview GIF to themes/<name>/preview.gif.
      apps = forAllSystems (pkgs: {
        update-preview = {
          type = "app";
          program = nixpkgs.lib.getExe (
            pkgs.writeShellApplication {
              name = "update-preview";
              runtimeInputs = [ pkgs.git ];
              text = ''
                root=$(git rev-parse --show-toplevel)
              ''
              + nixpkgs.lib.concatMapStrings (theme: ''
                install -m 644 ${
                  self.packages.${pkgs.stdenv.hostPlatform.system}."nixos-plymouth-${theme}-preview"
                } "$root/themes/${theme}/preview.gif"
                echo "wrote themes/${theme}/preview.gif"
              '') themes;
            }
          );
        };
      });

      nixosModules.default =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          cfg = config.services.nixos-plymouth;
        in
        {
          options.services.nixos-plymouth = {
            enable = lib.mkEnableOption "the NixOS Plymouth boot splash theme";
            package = lib.mkOption {
              type = lib.types.package;
              default = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
              description = "Theme package to install.";
            };
          };

          config = lib.mkIf cfg.enable {
            boot.plymouth = {
              enable = true;
              themePackages = [ cfg.package ];
              theme = "nixos-default";
            };
          };
        };

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          # For iterating on render-frames.py and previews by hand. Live testing uses the
          # system plymouth, which the NixOS module rebuilds with this theme installed.
          packages = with pkgs; [
            librsvg
            imagemagick
            python3
          ];
        };
      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt-tree);
    };
}
