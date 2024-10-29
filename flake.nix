{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs";

  # Flake returns Nix kernel for Pi 5
  outputs = { self, nixpkgs, ... }: {
    legacyPackages.aarch64-linux = with nixpkgs.legacyPackages.aarch64-linux; rec {

      # Custom kernel parameters for NixOS compatability on the Raspberry Pi 5
      linux_rpi5 =
        # Base kernel derivation for Raspberry Pi
        let baseLinux = buildLinux {
          version = "6.1.63-stable_20231123";
          modDirVersion = "6.1.63";

          # Raspberry Pi kernel source
          src = fetchFromGitHub {
            owner = "raspberrypi";
            repo = "linux";
            rev = "stable_20231123";
            hash = "sha256-4Rc57y70LmRFwDnOD4rHoHGmfxD9zYEAwYm9Wvyb3no=";
          };

          # Kernel config specific to Pi 5
          defconfig = "bcm2712_defconfig";

          # Disable UEFI boot stub so we can add our own
          features = {
            efiBootStub = false;
          };

          # Compatibility for Nix and ARM 64-bit architectures
          extraMeta = {
            platforms = with lib.platforms; arm ++ aarch64;
            hydraPlatforms = [ "aarch64-linux" ];
          };

          # Pi-specific hardware support
          kernelPatches = with kernelPackages; [
            bridge_stp_helper,
            request_key_helper
          ];
        };

        # Override kernel defaults to ensure Raspberry Pi 5 compatibility
        in lib.overrideDerivation(baseLinux) (oldAttrs: {
          # Clear the local version in the kernel config to avoid conflict
          postConfigure = ''
            sed -i $buildRoot/.config -e 's/^CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION=""/'
            sed -i $buildRoot/include/config/auto.conf -e 's/^CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION=""/'
          '';

          # Adjust the Device Tree Binary (DTB) for kernel patches
          postFixup = ''
            dtbDir="$out/dtbs/broadcom"
            rm $dtbDir/bcm283*.dtb
            copyDTB() {
              cp -v "$dtbDir/$1" "$dtbDir/$2"
            }
            copyDTB bcm2712-rpi-5-b.dtb bcm2838-rpi-5-b.dtb
          '';
        });

      # Package the kernel so it can be used in Nix configurations
      linuxPackages_rpi5 = linuxPackagesFor linux_rpi5;
    };
  };
}







