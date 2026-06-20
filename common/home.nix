{ config, pkgs, ... }:

let
  owner = "nixuser";
in
{
  # ターゲットとするユーザー名とホームディレクトリ
  home.username = ${owner};
  home.homeDirectory = "/home/${owner}";

  # 状態の互換性バージョン（基本はそのままでOK）
  home.stateVersion = "26.05";

  # ユーザー環境にインストールしたいパッケージ
  home.packages = with pkgs; [
    #git
  ];

  # home-manager 自体の有効化
  programs.home-manager.enable = true;

  # Dotfilesなどのファイル配置例 ( ~/.config/foo/bar.conf として配置される )
  # home.file.".config/foo/bar.conf".text = ''
  #   setting = true
  # '';

  home.file.".config/sway/config".text = ''
    # i3 config file (v4)

    ## fonts 
    font pango:IPAPGothic 11

    ## title bar and border config
    client.focused          #000000 #000000 #ffffff #000000 #000000
    client.focused_inactive #000000 #000000 #666666 #000000 #000000
    client.unfocused        #000000 #000000 #666666 #000000 #000000
    client.urgent           #000000 #000000 #666666 #000000 #000000
    client.placeholder      #000000 #000000 #666666 #000000 #000000

    ## i3status
    bar {
        status_command i3status
        position top
        tray_output none
        colors {
        focused_workspace  #000000 #000000 #ffffff
        active_workspace   #000000 #000000 #ffffff
        inactive_workspace #000000 #000000 #666666
        }
    }

    ## variables
    ## Mod1 is Alt key
    ## Mod4 is Win key
    set $mod Mod4
    set $nsi --no-startup-id
    set $ws workspace
    set $mc move container to workspace

    ## keybinds
    ## apps
    bindsym $mod+Return exec $nsi wofi --show run
    bindsym $mod+BackSpace kill
    bindsym $mod+t floating toggle

    bindsym $mod+f exec $nsi firefox
    bindsym $mod+l exec $nsi lxterminal
    bindsym $mod+n exec $nsi nextcloud
    bindsym $mod+c exec $nsi flatpak run org.cryptomator.cryptomator

    ## volumes
    bindsym XF86AudioMute exec $nsi pactl set-sink-mute @DEFAULT_SINK@ toggle
    bindsym XF86AudioRaiseVolume exec $nsi pactl set-sink-volume @DEFAULT_SINK@ +1%
    bindsym XF86AudioLowerVolume exec $nsi pactl set-sink-volume @DEFAULT_SINK@ -1%
    bindsym F2 exec $nsi pactl set-sink-volume @DEFAULT_SINK@ +1%
    bindsym F1 exec $nsi pactl set-sink-volume @DEFAULT_SINK@ -1%

    ## brightness
    bindsym XF86MonBrightnessDown exec $nsi echo `expr $(cat /sys/class/backlight/intel_backlight/brightness) - 100` > /sys/class/backlight/intel_backlight/brightness
    bindsym XF86MonBrightnessUp exec $nsi echo `expr $(cat /sys/class/backlight/intel_backlight/brightness) + 100` > /sys/class/backlight/intel_backlight/brightness

    ## workspaces
    bindsym $mod+1 $ws 1
    bindsym $mod+2 $ws 2
    bindsym $mod+3 $ws 3
    bindsym $mod+q $mc 1; $ws 1
    bindsym $mod+w $mc 2; $ws 2
    bindsym $mod+e $mc 3; $ws 3

    ## autostart
    exec $nsi fcitx5
    exec $nsi swaybg -i ~/Wallpapers/wallpaper.jpg
    exec $nsi eval $(/usr/bin/gnome-keyring-daemon --start --components=pkcs11,secrets,ssh,gpg)
    exec $nsi export SSH_AUTH_SOCK

    ## window settings
    floating_maximum_size 960 x 540
    for_window [floating] move position center

    for_window [window_role="dialog"] floating enable
    for_window [window_role="pop-up"] floating enable
    for_window [window_role="bubble"] floating enable
    for_window [window_role="task_dialog"] floating enable
    for_window [window_role="menu"] floating enable

    for_window [title="^Settings$"] floating enable
    for_window [title="^Preferences$"] floating enable
    for_window [title="^Settings$"] floating enable

    for_window [title="^About Mozilla Firefox$" app_id="firefox"] floating enable
    for_window [title="Extension:" app_id="firefox"] floating enable
    for_window [app_id="com.nextcloud.desktopclient.nextcloud"] floating enable
    for_window [instance="org.cryptomator.launcher.Cryptomator"] floating enable
  '';

  home.file.".config/i3status/config".text = ''
    general {
         colors = false
         }

        order += "volume master"
        order += "ethernet _first_"
        order += "wireless wlan0"
        order += "battery 0"
        order += "time"

        volume master {
         format = "VOL.%volume"
         format_muted = "VOL.muted"
         device = "default"
         mixer = "Master"
         mixer_idx = 0
         }

        ethernet _first_ {
         format_up = "Ethernet"
         format_down = ""
        }

        wireless wlan0 {
         format_up = "%essid"
         format_down = "No connection"
        }

        battery 0 {
         format = "%percentage %status"
         last_full_capacity = true
         format_percentage = "%.00f%s"
         ## this is for GPD Win1 or Pocket1
         ## path = "/sys/class/power_supply/max170xx_battery/uevent"
        }

        time {
         format = "%Y/%m/%d %H:%M"
        }
  '';
}