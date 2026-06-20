# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

# core.nix (this file)
# home.nix via home-manager
# <machine-name>.nix derived from initial basic installations

{ config, lib, pkgs, ... }:

let 
  owner = "nixuser";
  initpass = "needtobechanged";
in 
{
  imports =
    [ 
      # Include the results of the hardware scan.
    ];

  # enable flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # filesystem
  fileSystems."/" = lib.mkForce {
	  device = "/dev/disk/by-partlabel/root";
	  fsType = "ext4";
  };

  fileSystems."/boot" = lib.mkForce {
	  device = "/dev/disk/by-partlabel/esp";
	  fsType = "vfat";
  };

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Latest kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # network
  #networking.hostName = "nixos";  # migrated to flake
  networking.wireless.iwd.enable = true;
  networking.useDHCP = false;
  networking.dhcpcd.enable = false;
  systemd.network = {
	  enable = true;
	  networks = {
        "30-wlan0" = {
          matchConfig.Name = "wlan0";
          networkConfig.DHCP = "yes";
        };
    };
	};

  # Set your time zone.
  time.timeZone = "Asia/Tokyo";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "ja_JP.UTF-8";
    LC_IDENTIFICATION = "ja_JP.UTF-8";
    LC_MEASUREMENT = "ja_JP.UTF-8";
    LC_MONETARY = "ja_JP.UTF-8";
    LC_NAME = "ja_JP.UTF-8";
    LC_NUMERIC = "ja_JP.UTF-8";
    LC_PAPER = "ja_JP.UTF-8";
    LC_TELEPHONE = "ja_JP.UTF-8";
    LC_TIME = "ja_JP.UTF-8";
  };

  # Define a user account. 
  # DON'T FORGET TO CHANGE a password to STRONG ONE with ‘sudo passwd $USER’.
  users.users.${owner} = {
    isNormalUser = true;
    initialPassword = ${initpass};
    extraGroups = [ "wheel" "video" "input" ];
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "26.05"; # Did you read the comment?

  # fonts
  fonts = {
    enableDefaultPackages = true;
    fontDir.enable = true;
    packages = with pkgs; [
      ipafont
      ];
    fontconfig = {
      defaultFonts = {
        serif = [ "IPAPGothic" ];
        sansSerif = [ "IPAPGothic" ];
        monospace = [ "Monospace" ];
        };
      };
    };

  # System Packages
  environment.systemPackages = with pkgs; [
    nano
    vim
    i3status
    wofi
    swaybg
    lxterminal
    firefox
    pkgs.thunar
    nextcloud-client
    cryptomator
    git
	];

  # sway999
  programs.sway.enable = true;
  programs.bash.loginShellInit = ''
    # 1. 現在のターミナルが "tty1"（通常のグラフィック起動用コンソール）であることを確認
    # 2. すでにグラフィック環境（Wayland/X11）が起動していないことを確認
    if [ "$(tty)" = "/dev/tty1" ] && [ -z "$WAYLAND_DISPLAY" ] && [ -z "$DISPLAY" ]; then
      
      # 3. 【超重要】Home Managerのファイル生成が完了するのを最大10秒だけ待つ
      for i in {1..10}; do
        if [ -f "$HOME/.config/sway/config" ]; then
          break
        fi
        sleep 1
      done

      # 4. 満を持して Sway を起動
      exec sway
    fi
  '';
	
  # fcitx5-mozc
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.addons = [ pkgs.fcitx5-mozc ];
  };

  # gnome-keyring
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.login.enableGnomeKeyring = true;

  # gvfs
  services.gvfs.enable = true;

}
