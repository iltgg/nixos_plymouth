{
  runCommand,
  imagemagick,
  theme,
}:
# Animated GIF of one loop of the logo animation on black, for a quick visual check.
runCommand "nixos-plymouth-default-preview.gif" { nativeBuildInputs = [ imagemagick ]; } ''
  dir=${theme}/share/plymouth/themes/nixos-default
  frames=()
  while read -r i; do frames+=("$dir/frame-$i.png"); done < $dir/sequence.txt
  magick -delay 2 "''${frames[@]}" -resize 256x256 -background black -alpha remove -loop 0 $out
''
