{
  lib,
  stdenvNoCC,
  librsvg,
  python3,
  logomark,
}:
stdenvNoCC.mkDerivation {
  pname = "nixos-plymouth-default";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./render-frames.py
      ./cursor.svg
      ./bullet.svg
      ./nixos-default.plymouth
      ./nixos-default.script
    ];
  };

  nativeBuildInputs = [
    librsvg
    python3
  ];

  buildPhase = ''
    runHook preBuild

    mkdir build
    python3 render-frames.py ${logomark}/nixos-logomark-default-gradient-none.svg build

    # Rendered at 2x; the script scales these down to fit the screen.
    rsvg-convert -w 6 -h 48 cursor.svg -o build/cursor.png
    rsvg-convert -w 24 -h 24 bullet.svg -o build/bullet.png

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    theme=$out/share/plymouth/themes/nixos-default
    mkdir -p $theme
    cp build/*.png build/sequence.txt $theme/

    substitute nixos-default.plymouth $theme/nixos-default.plymouth --subst-var-by theme $theme
    substitute nixos-default.script $theme/nixos-default.script \
      --replace-fail '@frameCount@' "$(cat build/frame-count.txt)" \
      --replace-fail '@sequenceLength@' "$(wc -l < build/sequence.txt)" \
      --replace-fail '@sequence@' "$(cat build/sequence.script)"

    install -Dm644 ${../../LICENSE} $out/share/doc/nixos-plymouth-default/LICENSE

    runHook postInstall
  '';

  meta = {
    description = "NixOS logomark Plymouth theme: wind-up and spin with a password cursor";
    # Code is MIT; the logo frames are adapted from the NixOS logo (CC BY 4.0).
    license = with lib.licenses; [
      mit
      cc-by-40
    ];
    platforms = lib.platforms.linux;
  };
}
