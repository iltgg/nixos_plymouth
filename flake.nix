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
      themes = [
        "spin"
        "glow"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (
        pkgs:
        let
          inherit (nixpkgs) lib;
          branding = nixos-branding.legacyPackages.${pkgs.stdenv.hostPlatform.system}.nixos-branding;
          mkTheme = pkgs.callPackage ./themes/common/mk-theme.nix { };
          themePackage =
            name:
            pkgs.callPackage ./themes/${name}/package.nix {
              inherit mkTheme;
              logomark = branding.artifacts.internal.nixos-logomark-default-gradient-none;
            };
          perTheme = lib.listToAttrs (
            lib.concatMap (
              name:
              let
                theme = themePackage name;
              in
              [
                (lib.nameValuePair "nixos-plymouth-${name}" theme)
                (lib.nameValuePair "nixos-plymouth-${name}-preview" (
                  pkgs.callPackage ./themes/common/preview.nix { inherit theme; }
                ))
              ]
            ) themes
          );
        in
        perTheme
        // {
          default = perTheme.nixos-plymouth-spin;
          preview = perTheme.nixos-plymouth-spin-preview;
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
            theme = lib.mkOption {
              type = lib.types.enum themes;
              default = "spin";
              description = "Which theme to use.";
            };
            package = lib.mkOption {
              type = lib.types.package;
              default = self.packages.${pkgs.stdenv.hostPlatform.system}."nixos-plymouth-${cfg.theme}";
              defaultText = lib.literalExpression ''self.packages.''${system}."nixos-plymouth-''${theme}"'';
              description = "Theme package to install.";
            };
          };

          config = lib.mkIf cfg.enable {
            boot.plymouth = {
              enable = true;
              themePackages = [ cfg.package ];
              theme = cfg.package.themeName;
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
            pngquant
            python3
          ];
        };
      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt-tree);
    };
}
