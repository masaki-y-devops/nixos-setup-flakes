## これは何？

[NixOS](https://nixos.org)をインストールするための **``flakes``リポジトリ一式** に加え、

インターネット接続済みの[Linux Mint](https://linuxmint.com)か[manjaro](https://manjaro.org)の **ライブ環境上で実行し、再起動するだけでSway環境のシンプルなNixOSをクリーンインストールできる``install.sh``** です。

## なぜ作ったか

原点は _**「環境を完全に言語化(コード化)して、環境構築の非効率排除、ユーザー操作による不可避的なミスを回避すること」**_ にあります。

細かい経緯としては、

元々nix-channelsでNixOSを自動構築するスクリプトを自作して使用していましたが、

**時間の経過により、channelsのバージョンのずれ、構築時期によって出力が異なる** 可能性があることが課題でした。

この点、flakesを利用すれば、構成が``flake.lock``ファイルによりバージョン含め完全に固定されるため、

「もしかしたら動かないかも？」という不安を限りなくゼロに近づけることができます。

元々命令的な構築手順であるArch Linuxの熱烈なファンで、こちらもスクリプトを自作して利用しておりましたが、

やはり時間の経過とともに「副作用」、言い換えれば **環境が構築タイミングにより変動する** 、というリスクを抱えています。

また、nix-channels構成のNixOSとも異なり、 **破壊的な変更を伴うため、ロールバックも不可能** という欠点を抱えています。

以上の検討により、最近はサブのUMPCでは、

``flakes + home-manager``

による環境構築を好んで行っております。

nix-channel時代には、Swayの設定等のdotfilesをヒアドキュメントで書き込んで後に権限変更していたところ、

``home-manager``によりこれすらもNixの管理下に置くことが出来た、という副次的なメリットもありました。

## 実行方法

ライブ環境をUSBブートしてインターネット接続した上で、

実行例:

~~~bash

git clone https://github.com/masaki-y-devops/nixos-setup-flakes.git

cd ./nixos-setup-flakes

bash install.sh micropc mint

~~~

と実行すると、この場合、
Linux Mintライブ環境を立ち上げたGPD MicroPC(初代)に、
swayを導入済みのNixOSをインストールできます。

注意点は、スクリプトの実行時に渡す引数です。

~~~bash

bash install.sh micropc mint

~~~

このように、第一引数($1)に``flakes.sh``に定義済みのマシン名(この場合``micropc``)、

第二引数($2)に現在実行中のライブ環境のディストロのデフォルトユーザー名(この場合``mint``)

を入力してください。(Mintを推奨)。

## なぜ公式インストールISOを使わないのか？

テストの際、 **ライブ環境ブート時のGPD MicroPCとの相性を考慮** しました。

NixOS公式ISOを焼いたメディアでのUSBブートの際、UMPC特有のハードウェアの特殊性故か、

起動時に失敗が多発(Windowsがインストール済みの場合の初回起動時は起動成功することが多かった)。

詳しいメカニズムは原因究明出来ていませんが、USBブートが安定しているポピュラーなディストロである、

Ubuntu(Debian)ベースのMintと、Archベースのmanjaroで実行することを念頭に開発しました。

## 気を付けたことは？

- **Nix一時環境構築からシェルの再起動を挟まずにどうワンストップで実行するか？**

に加え、

- **機器固有の``hardware-configuration.nix``の扱いをどうするか？**

- **flakes特有の仕様である、``git add``していないファイルは構築対象から外されることを忘れない為の仕組み化**

です。

### Nix一時環境からのワンストップでのインストール実行

Nixパッケージマネージャーを一時環境に展開しますが、

この際``yes``コマンドをパイプで渡してユーザーの介入を不要にしています。

また、``source``(コード内では``.``)コマンドでNix固有のスクリプトを叩き、

現在のシェル内で読み込み直すことで、シェルを一旦閉じてまた開いて...という作業を不要にしています。

``NIX_PATH``等の環境変数も適宜明示的に指定して実行エラーを防いでいます。

### 自動生成された``hardware-configuration.nix``の扱い

#### 問題点

``nixos-generate-config``コマンドで実行中のマシンの設定が``/mnt/etc/nixos``ディレクトリ

に生成されますが、これを``flakes``に組み込む際のフローをどうするか？が問題となりました。

#### そもそもなぜ本ファイルが必要か？

その答えは実際の``hardware-configuration.nix``をリネームして配置された``micropc.nix``にあります。

実際に見てみます。

~~~bash

cat /mnt/etc/nixos/hardware-configuration.nix

~~~

~~~

{
...(中略)...
boot.initrd.availableKernelModules = [ "ahci" "xhci_pci" "usb_storage" "usbhid" "sd_mod" "sdhci_pci" ]
boot.initrd.kernelModules = [ ];
boot.kernelModules = [ "kvm-intel" ];
boot.extraModulePackages = [ ];

...(中略)...

hardware.cpu.intel.updateMicrocode = lib.mkDefault　config.hardware.enableRedistributableFirmware;
}

~~~

示したコードの上の固まりにカーネルモジュール関連の指定(仮想環境構築に関連する``kvm-intel``含む)、

下の固まりにCPUマイクロコードの指定があります。

上記では``boot.initrd.availableKernelModules``のみが明示的に指定され、実際に組み込まれるように指定されているものはありません(``boot.initrd.kernelModules = [ ];``)。

しかし、セキュリティ的な観点からはCPUマイクロコードの適用は有用であり、外すべきでなく、

また、CPUマイクロコードの指定はマシンのCPUメーカーによって変わる(といってもx86-64ならintelかAMDの2択ではありますが)ため、

これからAMDチップ搭載PC(GPD Win Miniなど)の設定を追加して``core.nix``を使い回すことを前提にすると、

変動しうる本設定を共通設定``core.nix``に書き込むのは適切ではないはずです。

そのため、自動判定されて生成された``hardware-configuration.nix``をflakesに取り込む必要があると判断しました。

#### パーティション・ファイルシステム設定の矛盾の解消

しかしながら、ここで同時に、同じく自動生成で書き込まれる一節、ファイルシステムの設定と、スクリプトで設定した``parted``との自動化コマンドとの競合(不整合)が発生します。

この部分です。

~~~bash

cat /mnt/etc/nixos/hardware-configuration.nix

~~~

~~~

{

...

fileSystems."/" =
    { device = "/dev/disk/by-uuid/34565fa4-04a5-4629-a5bd-1f7c10bac374";
      fsType = "ext4";
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/B289-1484";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };

...

}

~~~

起動ドライブのパスが同ファイルに記述されますが、その定義方法は``by-uuid``となっています。

これはインストールごとに変動する値のため、パーティション設定の宣言との整合性が問題となります。

この点、メインの設定である``core.nix``内に、``lib.mkForce``として``by-partlabel``指定を記述、これを優先させ、元の``by-uuid``設定を強制的に無効化することで対応しました。

このようにすることで、スクリプト内にあるpartedの設定と整合し、起動することが出来ます。

この``hardware-configuration.nix``の設定をそのまま使えないのか？という検討も行いました。

この点、スクリプト内の``parted``の設定を、``if``文などで、確実に一致させるために生成結果を呼んで書き換えるのは、代入ミスなどの危険もあり、生成結果の安定性の観点からは、推奨はされないのではないか、と考えます。

また、デバイス名(``/dev/sda1``など)での指定は、インストール後、ドライブの追加等をした場合、起動時のデバイス名の割り当てタイミングによりずれる可能性があるので、再現性の面からもあまり望ましくない、とも思えます。

そのため、``by-partlabel``で固定する方法を選択しました。

#### 初回実行時の「ファイル不在」どうする？

``flakes.nix``への初回定義時には、同ファイルに各``hoge.nix``ファイルをどう構成するか？を記述する必要がありますが、

その時点ではインストール対象のマシン上で実行されていないため、flakesリポジトリ内に``hardware-configuration.nix``は理論上存在し得ません。

そのため、実行時に生成されたものをマシン名にリネームし、差し込む、という方法にしてみました。

### flakes特有の仕様(``git add``し忘れるとシステム構築に反映されない)への対処

前述した通り、gitリポジトリとして管理されているflakesにおいて、仕様として``git add``しておかないとビルドから変更が無視されます。

したがって、何かしら設定のカスタマイズを行ったあとは、flakes.nixがあるカレントディレクトリにおいてこのようにコマンドを実行しています:

~~~bash

git add .

~~~

これが何回も設定を調整していると忘れがちで、軽いハマリポイントとなっていました。

そこで、スクリプト内で``nixos-rebuild``コマンド実行前に``git add``を仕込んでおくことで、

実行忘れを防ぐことにしました。

## インストール後のデフォルト環境はどうなっている？

- ウインドウマネージャー: Sway(Wayland) + i3status

すべてのSway,i3status設定は``home.nix``に記載されています。

- ネットワーク管理: systemd-networkd + iwd

Wi-Fi接続はこのようにします:

デフォルトのキーバインドであればWin(Super)+Enterでlxterminalを起動して、

~~~bash

iwctl station wlan0 connect <YOUR_SSID>

~~~

- サウンド管理: PulseAudio

ほかシステムアプリは、``core.nix``の通りです。

## 参考文献まとめ

https://wiki.nixos.org/wiki/Nixos-generate-config

https://qiita.com/Taira0222/items/90a6b00225d5f6ecffb1

https://qiita.com/ko1nksm/items/19d300c4cb812b0fde1e

