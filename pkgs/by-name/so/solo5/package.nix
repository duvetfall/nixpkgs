{ lib, stdenv, fetchurl, dosfstools, libseccomp, makeWrapper, mtools, parted
, pkg-config, qemu, syslinux, util-linux }:

let
  version = "0.8.1";
  # list of all theoretically available targets
  targets = [
    "genode"
    "hvt"
    "muen"
    "spt"
    "virtio"
    "xen"
  ];
in stdenv.mkDerivation {
  pname = "solo5";
  inherit version;

  nativeBuildInputs = [ makeWrapper pkg-config ];
  buildInputs = lib.optional (stdenv.hostPlatform.isLinux) libseccomp;

  src = fetchurl {
    url = "https://github.com/Solo5/solo5/releases/download/v${version}/solo5-v${version}.tar.gz";
    sha256 = "sha256-J1xcL/AdcLQ7Ph3TFwEaS9l4cWjDQsTaXTdBDcT7p6E=";
  };

  hardeningEnable = [ "pie" ];

  configurePhase = ''
    runHook preConfigure
    sh configure.sh --prefix=/
    runHook postConfigure
  '';

  enableParallelBuilding = true;

  separateDebugInfo = true;
    # debugging requires information for both the unikernel and the tender

  installPhase = ''
    runHook preInstall
    export DESTDIR=$out
    export PREFIX=$out
    make install

    substituteInPlace $out/bin/solo5-virtio-mkimage \
      --replace "/usr/lib/syslinux" "${syslinux}/share/syslinux" \
      --replace "/usr/share/syslinux" "${syslinux}/share/syslinux" \
      --replace "cp " "cp --no-preserve=mode "

    wrapProgram $out/bin/solo5-virtio-mkimage \
      --prefix PATH : ${lib.makeBinPath [ dosfstools mtools parted syslinux ]}

    runHook postInstall
  '';

  doCheck = stdenv.hostPlatform.isLinux;
  nativeCheckInputs = [ util-linux qemu ];
  checkPhase = ''
    runHook preCheck
    patchShebangs tests
    ./tests/bats-core/bats ./tests/tests.bats
    runHook postCheck
  '';

  meta = {
    description = "Sandboxed execution environment";
    homepage = "https://github.com/solo5/solo5";
    license = lib.licenses.isc;
    maintainers = with lib.maintainers; [ ehmry ];
    platforms = builtins.map ({arch, os}: "${arch}-${os}")
      (lib.cartesianProductOfSets {
        arch = [ "aarch64" "x86_64" ];
        os = [ "freebsd" "genode" "linux" "openbsd" ];
      });
  };

}
