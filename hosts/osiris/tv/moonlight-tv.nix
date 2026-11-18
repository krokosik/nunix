{
  lib,
  stdenv,
  fetchgit,
  cmake,
  pkg-config,
  gettext,
  makeWrapper,
  SDL2,
  SDL2_image,
  expat,
  fontconfig,
  freetype,
  curl,
  mbedtls,
  opus,
  inih,
  libuuid,
  libcec,
  libpulseaudio,
  alsa-lib,
  moonlight-embedded,
}:
let
  inherit (lib.strings) makeBinPath;
  inherit (lib.licenses) gpl3Only;
  inherit (lib.platforms) linux;
in
stdenv.mkDerivation {
  pname = "moonlight-tv";
  version = "1.6.37-unstable-2026-11-18";

  src = fetchgit {
    url = "https://github.com/mariotaku/moonlight-tv.git";
    rev = "72500d920b19e399ff1c99ad27a888fd76b0d183";
    hash = "sha256-rKPrg5LBfLMGQBGkOp9LE+CsPXfznWFnwXWdPyvRoIY=";
    fetchSubmodules = true;
  };

  nativeBuildInputs = [
    cmake
    pkg-config
    gettext
    makeWrapper
  ];
  buildInputs = [
    SDL2
    SDL2_image
    expat
    fontconfig
    freetype
    curl
    mbedtls
    opus
    inih
    libuuid
    libcec
    libpulseaudio
    alsa-lib
  ];

  # Upstream otherwise queries GitHub for a version and installs under /usr.
  postPatch = /* bash */ ''
    sed -i '4,18c\set(MOONLIGHT_VERSION "1.6.37")' CMakeLists.txt
    substituteInPlace CMakeLists.txt \
      --replace-fail 'set(CMAKE_INSTALL_PREFIX /usr)' "set(CMAKE_INSTALL_PREFIX $out)"
  '';

  cmakeFlags = [
    "-DBUILD_TESTS=OFF"
    "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
  ];

  # Desktop Linux uses the external moonlight-embedded streaming backend.
  postFixup = /* bash */ ''
    wrapProgram "$out/bin/moonlight-tv" \
      --prefix PATH : ${makeBinPath [ moonlight-embedded ]}
  '';

  meta = {
    description = "Moonlight client with a TV remote interface";
    homepage = "https://github.com/mariotaku/moonlight-tv";
    license = gpl3Only;
    platforms = linux;
    mainProgram = "moonlight-tv";
  };
}
