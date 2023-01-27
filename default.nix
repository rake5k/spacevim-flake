{ ripgrep
, git
, fzf
, makeWrapper
, vim-full
, vimPlugins
, fetchFromGitHub
, lib
, stdenv
, formats
, runCommand
, writeText
, spacevim_config ? import ./init.nix
, bootstrap_before ? ""
, bootstrap_after ? ""
}:

let
  format = formats.toml { };
  vim-customized = vim-full.customize {
    name = "vim";
    # Not clear at the moment how to import plugins such that
    # SpaceVim finds them and does not auto download them to
    # ~/.cache/vimfiles/repos
    vimrcConfig.packages.myVimPackage = with vimPlugins; { start = [ ]; };
  };
  bootstrapScript = ''
    function! myspacevim#before() abort
      ${bootstrap_before}
    endfunction
    function! myspacevim#after() abort
      ${bootstrap_after}
    endfunction
  '';
  spacevimConfig = lib.recursiveUpdate spacevim_config {
    options = {
      bootstrap_before = "myspacevim#before";
      bootstrap_after = "myspacevim#after";
    };
  };
  spacevimdir = runCommand "SpaceVim.d" { } ''
    mkdir -p $out
    cp ${format.generate "init.toml" spacevimConfig} $out/init.toml
    mkdir -p $out/autoload
    cp ${writeText "myspacevim.vim" bootstrapScript} $out/autoload/myspacevim.vim
  '';
in
stdenv.mkDerivation rec {
  pname = "spacevim";
  version = "1.8.0";
  src = fetchFromGitHub {
    owner = "SpaceVim";
    repo = "SpaceVim";
    rev = "v${version}";
    sha256 = "sha256:11snnh5q47nqhzjb9qya6hpnmlzc060958whqvqrh4hc7gnlnqp8";
  };

  nativeBuildInputs = [ makeWrapper vim-customized ];
  buildInputs = [ vim-customized ];

  buildPhase = ''
    runHook preBuild
    # generate the helptags
    vim -u NONE -c "helptags $(pwd)/doc" -c q
    runHook postBuild
  '';

  patches = [
    # Don't generate helptags at runtime into read-only $SPACEVIMDIR
    ./helptags.patch
  ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin

    cp -r $(pwd) $out/SpaceVim

    # trailing slash very important for SPACEVIMDIR
    makeWrapper "${vim-customized}/bin/vim" "$out/bin/spacevim" \
        --add-flags "-u $out/SpaceVim/vimrc" --set SPACEVIMDIR "${spacevimdir}/" \
        --prefix PATH : ${lib.makeBinPath [ fzf git ripgrep]}
    runHook postInstall
  '';

  meta = with lib; {
    description = "Modern Vim distribution";
    longDescription = ''
      SpaceVim is a distribution of the Vim editor that’s inspired by spacemacs.
    '';
    homepage = "https://spacevim.org/";
    license = licenses.gpl3Plus;
    maintainers = [ maintainers.fzakaria ];
    platforms = platforms.all;
  };
}
