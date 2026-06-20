#!/usr/bin/env bash

## 最低限のエラーハンドリング
set -e

## 実行時の引数による設定を行う(-以下はデフォルト値)
## $1 には設定するホスト名を引数として渡す
# $2 にはライブ環境のユーザー名(mint, manjaroを想定）を引数として渡す
# 実行例：bash install.sh micropc mint

HOST_NAME="${1:-micropc}"
LIVE_ENV="${2:-mint}"

## 新システムのユーザー名を指定
## 変更する場合はcore.nix及びhome.nixの編集も必要
TARGET_USER="nixuser"
USER_HOME="/mnt/home/${TARGET_USER}"

## 念のためスクリーンセーバーをオフにしておく
## Linux Mintやmanjaroのライブ環境を想定
## Xorgが前提
xset s off -dpms

## インターネット接続を確認
## 一時Nix環境、本システムのビルドに必須
if ping -c 1 google.com; then
    echo ":: Internet connection: OK."
    sleep 5
else
    echo ":: Failed to connect internet. Try again."
    read -r -p ":: Press Enter to exit."
    exit 1
fi

## カレントディレクトリをチェックする。
## flakesがなければ終了。
if [ -f ./my-flakes/flake.nix ]; then
    echo ":: flake.nix exists. Proceeding..."
    sleep 5
else
    echo ":: flake.nix not found in current directory."
    read -r -p ":: Press enter to exit."
    exit 1
fi

## 引数が正常に渡されて本スクリプトが実行されているかチェック
## 引数がない場合や、有効な引数でない場合は終了
if [ -z "$1" ]; then
    echo ":: Arg1 is missing. Please try again and then enter targeted machine name as arguments."
    read -r -p ":: Press enter to exit."
    exit 1
elif [ "$1" == "micropc" ]; then
    echo ":: micropc is selected. Proceeding..."
    sleep 5
else
    echo ":: Invaild machine name."
    read -r -p ":: Press enter to exit."
    exit 1
fi

## インストール先のシステムドライブを特定
## 優先度は: nvme0n1 > nvme1n1 > mmcblk0 > mmcblk1 > sda
if [ "$(lsblk | grep -E "8:0|179:0|259:0" | grep -o "nvme0n1")" = "nvme0n1" ]; then
    DISK=nvme0n1
elif [ "$(lsblk | grep -E "8:0|179:0|259:0" | grep -o "nvme1n1")" = "nvme1n1" ]; then
    DISK=nvme1n1
elif [ "$(lsblk | grep -E "8:0|179:0|259:0" | grep -o "mmcblk0")" = "mmcblk0" ]; then
    DISK=mmcblk0
elif [ "$(lsblk | grep -E "8:0|179:0|259:0" | grep -o "mmcblk1")" = "mmcblk1" ]; then
    DISK=mmcblk1
else
    DISK=sda
fi

## パーティション名を特定する
## eMMCの場合: mmcblk{0,1}{p1,p2}
## nvmeの場合: nvme{0,1}n1{p1,p2}
## SATAの場合: sda{1,2}
if [ "$DISK" == "mmcblk0" ] || [ "$DISK" == "mmcblk1" ]; then
    DISK1=${DISK}p1
    DISK2=${DISK}p2
elif [ "$DISK" == "nvme0n1" ] || [ "$DISK" == "nvme1n1" ]; then
    DISK1=${DISK}p1
    DISK2=${DISK}p2
else
    DISK1=${DISK}1
    DISK2=${DISK}2
fi
echo ":: Target Diskname is ${DISK}. Target Partition name is ${DISK1} and ${DISK2}."
sleep 5

## 現在のパーティションを全消去
PARTNUM=$(lsblk | grep ${DISK} | grep -c part)
if [ "${PARTNUM}" -ge 1 ]; then
    i=1
    while [ $i -le "${PARTNUM}" ]; do
        sudo parted -s /dev/${DISK} rm ${i}
        ((i++))
    done
else
    :
fi

## パーティションを新規作成
## 一つ目のパーティション: FAT32, 512MB
## 二つ目のパーティション: ext4, 残り全部
sudo parted -s /dev/${DISK} mklabel gpt
sudo parted -s /dev/${DISK} mkpart "esp" fat32 1MiB 513MB
sudo parted -s /dev/${DISK} set 1 esp on
sudo parted -s /dev/${DISK} mkpart "root" ext4 513MB 100%
echo ":: Partitioning of ${DISK} completed."
sleep 5

## パーティションのフォーマット
## ファイルシステムは前述(FAT32,ext4)
yes | sudo mkfs.vfat -F32 /dev/${DISK1}
sudo mkfs.ext4 -F /dev/${DISK2}
sudo tune2fs -O ^orphan_file /dev/${DISK2}
sudo e2fsck -f -y /dev/${DISK2}

echo ":: Formatting of ${DISK} completed."
sleep 5

# パーティション構成の読み込み完了を待つ
sudo udevadm settle

## パーティションのマウント
sudo mount /dev/${DISK2} /mnt
sudo mkdir /mnt/boot
sudo mount /dev/${DISK1} /mnt/boot

## Gitの一時環境へのインストール
## Mintかmanjaroを想定し、aptかpacmanかで分岐
if apt --version &>/dev/null; then 
    sudo apt -y install git
elif pacman --version &>/dev/null; then
    sudo pacman -S --noconfirm git
else
    echo ":: Temp git setup failed. Exiting..."
    read -r -p ":: Press enter to exit."
    exit 1
fi

sleep 5

## ここからNixOS構築

## 一時Nix環境のインストール（すでに完了している場合はスキップ）
if ! command -v nix &> /dev/null; then
    yes | sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install) --daemon

    ## デーモン版Nixの環境変数を現在のシェルに反映
    ## このsourceの実行がなければ、現在のシェルでnixコマンドが動作しないので必須
    . "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
fi

## NixOSのインストール自体に必要なツールをインストール
nix-env -f '<nixpkgs>' -iA nixos-install-tools

## rootユーザー環境へNixのパスを引き継ぐためのラッパーを作成
## ライブ環境のPATHにインストールされた nixos-install を root でも使えるようにする
export NIX_PATH=$HOME/.nix-defexpr/channels

## hardware-configuration.nixを自動生成するために実行
## ${HOST_NAME}.nixとしてリネームしてflakes(./specific/)に追加
sudo env PATH="$PATH" NIX_PATH="$NIX_PATH" nixos-generate-config --root /mnt
sudo rm -rf /mnt/etc/nixos/configuration.nix
sudo cp /mnt/etc/nixos/hardware-configuration.nix ~/"${HOST_NAME}.nix"
sudo chown "${LIVE_ENV}": ~/"${HOST_NAME}.nix"
cp ~/"${HOST_NAME}.nix" ./my-flakes/specific/

## Gitリポジトリならすべて追跡対象にする（Nixへのファイル認識漏れ対策）
if git rev-parse --is-inside-work-tree &>/dev/null; then
    git add -A
fi

## Flakeの更新 一般ユーザーで実行可能
nix --experimental-features 'nix-command flakes' flake update

## NixOSのインストール（環境変数を引き継いでルート権限で実行。which不要）
sudo env PATH="$PATH" NIX_PATH="$NIX_PATH" \
  nixos-install \
  --root /mnt \
  --no-root-password \
  --flake .#"${HOST_NAME}"

## flakesを新システムにコピーしてライブ環境から救出
echo ":: Copying flakes to the new NixOS environments"

## 強制的に新システムのホームディレクトリ（となる場所）を作成
sudo mkdir -p "${USER_HOME}/nixos-config"

## 現在ライブ環境（Mint）で使っているFlake一式（カレントディレクトリ "."）を丸ごとコピー
## .git フォルダも含めてコピー
sudo cp -r . "${USER_HOME}/nixos-config/"

## このままだと所有者が root になるので、新システムのユーザー（UID 1000）に変更する
## NixOSの最初の一般ユーザーは必ず UID:1000 / GID:100
sudo chown -R 1000:100 "${USER_HOME}"

echo ":: Running install.sh is finished."
read -rp ":: Press enter to exit."
exit 0