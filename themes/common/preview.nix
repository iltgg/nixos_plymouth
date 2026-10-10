{
  runCommand,
  imagemagick,
  theme,
}:
# Animated GIF of one loop of a theme's logo animation on black, for a quick visual check.
runCommand "${theme.pname}-preview.gif" { nativeBuildInputs = [ imagemagick ]; } ''
  dir=${theme}/share/plymouth/themes/${theme.themeName}
  frames=()
  while read -r i; do frames+=("$dir/frame-$i.png"); done < $dir/sequence.txt
  magick -delay 2 "''${frames[@]}" -resize 256x256 -background black -alpha remove -loop 0 $out
''
