---
title: "Raspberry PiでおうちKubernetesクラスタ"
date: 2021-12-31T00:14:00+09:00
tags:
  - raspberrypi
  - kubernetes
  - ubuntu
slug:           2021/12/31/raspi-cluster
thumbnailImage: 2021/12/31/raspi-cluster/k8s.png
---

今年の3月頃、ラズパイで k8sクラスタを組んだ。既に半年以上経っているが、せっかくなので今年のうちに、さわりだけでもまとめておく。

<!--more-->

Hardware
-----------------------------------------------------------------------------------

予算 5万円として揃えてみた。
しかし現在は、ケーブルの取り回しや、MicroSD の遅さに辟易して追加で購入したものもある... 。ケースもふつうでつまらないので、現在、物色中。k8s の勉強用というより、ガジェット感が強い 😓

{{< image classes="fancybox fig-50 clear" src="rasphberrypi-cluster-01.JPG" thumbnail="rasphberrypi-cluster-01.png" group="group:raspi" >}}
{{< image classes="fancybox fig-20" src="rasphberrypi-cluster-02.JPG" thumbnail="rasphberrypi-cluster-02.png" group="group:raspi" >}}
{{< image classes="fancybox fig-20" src="rasphberrypi-cluster-03.JPG" thumbnail="rasphberrypi-cluster-03.png" group="group:raspi" >}}
{{< image classes="fancybox fig-20" src="rasphberrypi-cluster-04.JPG" thumbnail="rasphberrypi-cluster-04.png" group="group:raspi" >}}
{{< image classes="fancybox fig-20" src="rasphberrypi-cluster-05.JPG" thumbnail="rasphberrypi-cluster-05.png" group="group:raspi" >}}
{{< image classes="fancybox fig-20" src="rasphberrypi-cluster-06.JPG" thumbnail="rasphberrypi-cluster-06.png" group="group:raspi" >}}


|買ったもの（2021年3月）                                 |単価    |個数|
|:-------------------------------------------------------|-------:|---:|
|Raspberry Pi 4 8GB                                      | 9,000円| 4個|
|GeeekPi Raspberry Pi4クラスターケース                   | 2,499円| 1個|
|RAVPower USB充電器 (60W 6ポート) RP-PC028               | 2,699円| 1個|
|iFory USBケーブル (TypeC-TypeA) 0.3m 2パック            |   959円| 1個|
|エレコム スイッチングハブ ギガビット 5ポートEHC-G05PA-SB| 2,955円| 1個|
|エレコム LANケーブル 0.15m×2本                          |   822円| 2個|
|東芝 MicroSD 32G TOTF32G-M203BULK-2SET                  | 1,198円| 2個|


|追加分                                                  |単価    |個数|
|:-------------------------------------------------------|-------:|---:|
|サンワサプライ 電源コード(2P・L型コネクタ) 1m           |   471円| 1本|
|Samsung Fit Plus 128GB 400MB/S USB3.1 MUF-128AB/EC      | 3,313円| 4個|

Network
-----------------------------------------------------------------------------------
1台をmaster node にして、残り3台を worker node に。

![](network.png)


とりあえず、有線も無線（WiFi）を設定している。

有線は固定IP、WiFi は DHCP で。普段の操作は、WiFi 経由で行なっている。
スイッチのポートが1つ空いてるので、作業用の端末を有線LAN で繋いだり、シリアルコンソールを
繋いだりすることもある。

OS（Ubuntu ARM 64bit版）
-----------------------------------------------------------------------------------

OS は現在、arm64版 Ubuntu 21.04 を USBブートで使用中。ヘッドレスインストールしている。

インストール手順としては、vfat と ext4 が読める OSを準備
（初回はVolumioが入っているラズパイを使った。2回目位以降は、4台中のどれかで実施）。 

そのOS上で、

1. Ubuntu のイメージをダウンロード
1. ダウンロードしたイメージを、USBメモリに ddで書き込み
1. USBメモリに書き込まれた 2つパーティションをマウント
1. マウントポイント配下のディレクトリに、cloud-init と netplan の設定ファイルを設置

なお、設定ファイルの設置は何度もやっているので、簡単なスクリプトにしている。

```sh
# イメージダウンロードして USBメモリ（/dev/sdb）に書き込み
curl -O https://cdimage.ubuntu.com/releases/21.04/release/ubuntu-21.04-preinstalled-server-arm64+raspi.img.xz
xzcat ubuntu-21.04-preinstalled-server-arm64+raspi.img.xz | sudo dd of=/dev/sdb bs=1M

# 自動でマウントされなければ、マウントポイント準備してマウント
mount -t vfat,ext4
sudo mkdir -p /media/{system-boot,writable}
sudo mount /dev/sdb1 /media/system-boot
sudo mount /dev/sdb2 /media/writable

# セットアップ用のスクリプト「setup」を準備して、cloud-init と netplan の設定ファイルを設置
bash setup master
# bash setup worker1
# bash setup worker2
# bash setup worker3

# umount
sudo umount /media/{system-boot,writable}
```

セットアップ用スクリプト「setup」

```
#!/bin/bash

function user-data(){
cat<<EOD
#cloud-config

hostname: $1

timezone: Asia/Tokyo
locale: ja_JP.UTF-8

ntp:
  servers: [ntp.nict.jp]

#package_update: true
#package_upgrade: true

ssh_pwauth: false
runcmd:
  - ufw limit ssh
  - ufw enable
  - reboot

users:
  - name: harasou
    groups: [adm, audio, cdrom, dialout, dip, floppy, lxd, netdev, plugdev, sudo, video]
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAAgQCU6IyyiClAZrIx0hr0Xoh1cUe099BzRE6WexxsbeyrUHN9uKkQN7lK1A73zHEsr1xt+xiCTu6FwnXrlCGplyIm8EKgArB1BeuCK/5ItBrE+ulGOi0TpXWuGLeL50FOyKPiXnNp/PhlFXqKs/feS9sF74a8u2KzDKMq6YCb6Nc5yw==
EOD
}

function netplan() {
cat<<EOD
network:
    ethernets:
        eth0:
            addresses:
                - $1/24
            dhcp4: false
    version: 2
    wifis:
        wlan0:
            access-points:
                <SSID>:
                    password: "<PASSWORD>"
            dhcp4: true
            optional: true
EOD
}

case $1 in
 master) ipaddress="192.168.2.1";   hostname="k8s-master" ;;
worker1) ipaddress="192.168.2.101"; hostname="k8s-worker1" ;;
worker2) ipaddress="192.168.2.102"; hostname="k8s-worker2" ;;
worker3) ipaddress="192.168.2.103"; hostname="k8s-worker3" ;;
      *) exit 1
esac

user-data $hostname | sudo cp -v /dev/stdin /media/system-boot/user-data
netplan $ipaddress | sudo cp -v /dev/stdin /media/writable/etc/netplan/99-static-config.yaml
```

Kubernetes
-----------------------------------------------------------------------------------

肝心の k8s の環境については、いろいろ試していて固定していないので、ある程度まとまったら書く。

Ubuntu も 20.04LTS 使ったり、kubeadm や k0s 使ったり。LXDクラスタや ESXi も試したりして、
かなり遊び場と化して、k8s の運用の知見は全く溜まってない。。。


<!--links-->

