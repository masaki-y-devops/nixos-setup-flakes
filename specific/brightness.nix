{ config, pkgs, ... }:

{
    # add groups and udev rules to to control internal display brightness as user privileges
    users.groups.video.members = [ "nixos" ];
    
    services.udev = {
        enable = true;
        extraRules = ''
            ACTION=="add", SUBSYSTEM=="backlight", RUN+="\${pkgs.coreutils}/bin/chgrp video \$sys\$devpath/brightness", RUN+="\${pkgs.coreutils}/bin/chmod g+w \$sys\$devpath/brightness"
        '';
    };
} 
