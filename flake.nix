{
    description = "My NixOS Flake Configuration";

    # 外部リポジトリの取得先
    inputs = {
        # nixosのリポジトリ
        nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
        #nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";

        # home-managerのリポジトリ
        home-manager = {
            url = "github:nix-community/home-manager/master";
            #url = "github:nix-community/home-manager/release-26.05";
            inputs.nixpkgs.follows = "nixpkgs"; # nixpkgsのバージョン固定
        };
    };

    outputs = { self, nixpkgs, home-manager, ... }@inputs: {
        nixosConfigurations = {
            # エイリアス名はhostnameに合わせる
            micropc = nixpkgs.lib.nixosSystem {
                system = "x86_64-linux";
                modules = [
                    { networking.hostName = "micropc"; }
                    ./common/core.nix
                    ./specific/micropc.nix
                    ./specific/slowcpu.nix
                    #./specific/brightness.nix

                    # home-managerをnixosのモジュールとして読み込む
                    home-manager.nixosModules.home-manager {
                        home-manager.useGlobalPkgs = true;
                        home-manager.useUserPackages = true;
                        home-manager.users.masaki = import ./common/home.nix;
                    }
                ];
            };
        };
    };
}