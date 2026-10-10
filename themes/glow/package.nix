{ mkTheme, logomark }:
mkTheme {
  name = "glow";
  src = ./.;
  title = "NixOS Glow";
  description = "NixOS logomark with a glowing light chasing clockwise around the lambdas, with a password cursor";
  inherit logomark;
}
