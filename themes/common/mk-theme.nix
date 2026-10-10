# Builds a Plymouth theme from a theme directory containing render-frames.py.
# Everything else (script, password cursor, .plymouth file) is shared.
{
  lib,
  stdenvNoCC,
  librsvg,
  pngquant,
  python3,
}:
{
  # Theme directory name under ./themes; installed as plymouth theme nixos-<name>.
  name,
  # Directory with the theme's render-frames.py.
  src,
  title,
  description,
  # nixos-branding logomark artifact (a directory with one SVG).
  logomark,
}:
let
  themeName = "nixos-${name}";
in
stdenvNoCC.mkDerivation {
  pname = "nixos-plymouth-${name}";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [
      ./frames.py
      ./theme.script
      ./cursor.svg
      ./bullet.svg
      (src + "/render-frames.py")
    ];
  };

  nativeBuildInputs = [
    librsvg
    pngquant
    python3
  ];

  # render-frames.py imports frames.py, so put them side by side.
  postUnpack = ''
    cp $sourceRoot/${baseNameOf src}/render-frames.py $sourceRoot/common/
    sourceRoot=$sourceRoot/common
  '';

  buildPhase = ''
    runHook preBuild

    mkdir build
    python3 render-frames.py ${logomark}/*.svg build
    # Palette PNGs are ~3x smaller with no visible loss; this all ends up in the initrd.
    pngquant --quality 80-98 --speed 1 --strip --force --ext .png build/frame-*.png

    # Rendered at 2x; the script scales these down to fit the screen.
    rsvg-convert -w 6 -h 48 cursor.svg -o build/cursor.png
    rsvg-convert -w 24 -h 24 bullet.svg -o build/bullet.png

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    theme=$out/share/plymouth/themes/${themeName}
    mkdir -p $theme
    cp build/*.png build/sequence.txt $theme/

    cat > $theme/${themeName}.plymouth <<PLYMOUTH
    [Plymouth Theme]
    Name=${title}
    Description=${description}
    ModuleName=script

    [script]
    ImageDir=$theme
    ScriptFile=$theme/${themeName}.script
    PLYMOUTH

    substitute theme.script $theme/${themeName}.script \
      --replace-fail '@frameCount@' "$(cat build/frame-count.txt)" \
      --replace-fail '@canvasScale@' "$(cat build/canvas-scale.txt)" \
      --replace-fail '@sequenceLength@' "$(wc -l < build/sequence.txt)" \
      --replace-fail '@sequence@' "$(cat build/sequence.script)"

    install -Dm644 ${../../LICENSE} $out/share/doc/nixos-plymouth-${name}/LICENSE

    runHook postInstall
  '';

  passthru = { inherit themeName; };

  meta = {
    inherit description;
    # Code is MIT; the logo frames are adapted from the NixOS logo (CC BY 4.0).
    license = with lib.licenses; [
      mit
      cc-by-40
    ];
    platforms = lib.platforms.linux;
  };
}
