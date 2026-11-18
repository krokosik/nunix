{
  moonlight-embedded,
  libglvnd,
  libx11,
}:
moonlight-embedded.overrideAttrs (old: {
  pname = "moonlight-embedded-vaapi";

  buildInputs = old.buildInputs ++ [
    libglvnd
    libx11
  ];

  postPatch = (old.postPatch or "") + /* bash */ ''
    substituteInPlace src/video/ffmpeg_vaapi.c \
      --replace-fail 'AV_HWDEVICE_TYPE_VAAPI, ":0", NULL, 0' 'AV_HWDEVICE_TYPE_VAAPI, NULL, NULL, 0'

    # Fail configuration rather than silently building a software-only client.
    substituteInPlace CMakeLists.txt \
      --replace-fail 'pkg_check_modules(LIBVA libva)' 'pkg_check_modules(LIBVA REQUIRED libva)' \
      --replace-fail 'pkg_check_modules(EGL egl)' 'pkg_check_modules(EGL REQUIRED egl)' \
      --replace-fail 'pkg_check_modules(GLES glesv2)' 'pkg_check_modules(GLES REQUIRED glesv2)' \
      --replace-fail 'pkg_check_modules(XLIB x11)' 'pkg_check_modules(XLIB REQUIRED x11)' \
      --replace-fail 'pkg_check_modules(LIBVA_X11 libva-x11)' 'pkg_check_modules(LIBVA_X11 REQUIRED libva-x11)'
  '';
})
