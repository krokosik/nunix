{
  lib,
  runCommand,
  fetchurl,
  python3,
  _7zz,
  cameraSource,
}:
let
  driverPackage = fetchurl {
    url = "https://download.microsoft.com/download/6a5b8acd-9bb2-4813-8cdd-09f603f91ee5/SurfacePro8_Win11_22631_26.073.32221.0.msi";
    hash = "sha256-BAo+6ip1B+AkGDJa99wPJAQ4w64l0LMRavV0Pu+Reoc=";
  };
in
runCommand "surface-pro-8-camera-tuning"
  {
    pname = "surface-pro-8-camera-tuning";
    outputs = [
      "out"
      "blobs"
    ];
    nativeBuildInputs = [
      python3
      _7zz
    ];
    # The OEM calibration is not licensed for redistribution.
    preferLocalBuild = true;
    allowSubstitutes = false;
    meta.license = lib.licenses.unfree;
  }
  /* bash */ ''
    7zz e ${driverPackage} cab1.cab
    # MSI File-table identifiers are specific to the hash-pinned package above.
    7zz e cab1.cab fil6B21914C352FF5C35CDC9441C0CC04BB fil14A896A763FC2C79E54442A7F8223A4A
    mkdir --parents "$out" "$blobs"
    cp fil6B21914C352FF5C35CDC9441C0CC04BB "$blobs/OV5693_MSHW0260_TGL.aiqb"
    cp fil14A896A763FC2C79E54442A7F8223A4A "$blobs/OV13858_MSHW0261_TGL.aiqb"

    for sensor in OV5693_MSHW0260 OV13858_MSHW0261; do
      blob="$blobs/''${sensor}_TGL.aiqb"
      test "$(head --bytes=4 "$blob")" = CPFF
      name="''${sensor%%_*}"
      python3 ${cameraSource}/tools/factory-tuning.py "$blob" - "$out/''${name,,}.yaml"
    done
  ''
