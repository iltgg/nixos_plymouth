{ mkTheme, logomark }:
mkTheme {
  name = "spin";
  src = ./.;
  title = "NixOS Spin";
  description = "NixOS logomark that winds up and spins, with a password cursor";
  inherit logomark;
}
