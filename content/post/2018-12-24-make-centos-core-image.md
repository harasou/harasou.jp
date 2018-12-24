---
title: 古い CentOS の Docker イメージを作成する
date: 2018-12-24T14:42:00+09:00
tags:
  - docker
  - yum
url:            2018/12/24/make-centos-core-image
thumbnailImage: 2018/12/24/make-centos-core-image/vertical.png
---

仕事で CentOS6.4 の Docker イメージが欲しかったのだが、Officialには 6.6 までしかなかった。
せっかくなので、ISOイメージから core グループのみインストールしたイメージを作成してみた。

<!--more-->


Official のイメージ
-----------------------------------------------------------------------------------

[Official] の場合、CentOS 6.10 だと以下のような [Dockerfile] になっていて、ADD している
`centos-6-docker.tar.xz` は、 [kickstart] で構築した VM から作成している模様。

```
FROM scratch
ADD centos-6-docker.tar.xz /

LABEL org.label-schema.schema-version="1.0" \
    org.label-schema.name="CentOS Base Image" \
    org.label-schema.vendor="CentOS" \
    org.label-schema.license="GPLv2" \
    org.label-schema.build-date="20180804"

CMD ["/bin/bash"]
```

kickstart を見ると、coreグループや baseブループもいれずに、必要なパッケージだけ指定している。
さらに依存？で入った不要なパッケージを削除し、不要なディレクトリを消す処理もあった。


yum \--installroot
-----------------------------------------------------------------------------------
packer とかで Official の kickstart をベースに作ることも可能そうだが、検証用に欲しいので
そこまで削られてなくていい。ググったら、yum の installroot オプションを使用すれば作れそうなので、
やってみた。

作業は macOS で上で行い、yum とかは docker の centos を利用。大まか流れは以下の通り。

![](dockerbuild.png)

手順：

1. macOS 上で CentOS の ISOイメージをダウンロード
1. mount した ISOイメージを参照する yum のリポジトリファイルを作成
1. 上記 ISOイメージと yum のリポジトリファイルを volume に指定して centos のコンテナを起動
1. コンテナ内で、ISOイメージをマウントし、`yum --instaroot` を実行
1. インストールされたディレクトリを tar.gz で固めて、volume 配下に設置
1. macOS 上で、上記 tar.gz を ADD する Dockerfile を書いて、docker build

んー、書き出してみると結構長い。


CentOS6.4 の Dockerイメージ作成
-----------------------------------------------------------------------------------
Docker Desktop がはいった macOS で実施。

1. macOS 上で CentOS の ISOイメージをダウンロード

    ```
    curl -O http://ftp.jaist.ac.jp/pub/Linux/CentOS-vault/6.4/isos/x86_64/CentOS-6.4-x86_64-minimal.iso
    mkdir root && mv *.iso root/
    ```

1. mount した ISOイメージを参照する yum のリポジトリファイルを作成

    ```
    mkdir yum.repos.d
    cat<<EOD>yum.repos.d/CentOS-ISO.repo
    [iso]
    name=CentOS-6 - ISO
    baseurl=file:///mnt
    enabled=1
    gpgcheck=1
    gpgkey=file:///mnt/RPM-GPG-KEY-CentOS-6
    EOD
    ```

1. 上記 ISOイメージと yum のリポジトリファイルを volume に指定して centos のコンテナを起動

    ```
    docker container run --privileged -it --rm -v $PWD/yum.repos.d:/etc/yum.repos.d -v $PWD/root:/root centos
    ```
    - ISO をマウントする必要があるの`--privileged` を付与
    - CentOS7 の ISO は、macOS 上で簡単にマウントできなかったので、やむなくコンテナ上でマウント

1. コンテナ内で、ISOイメージをマウントし、`yum --instaroot` を実行

    ```
    mount -o loop /root/CentOS-6.4-x86_64-minimal.iso /mnt
    yum --installroot=/tmp/root --skip-broken '--exclude=*-firmware' groupinstall Core -y
    chroot /tmp/root rpm --rebuilddb
    ```
    - 結構容量があるが不要な`*-firmware`パッケージは除外
    - 依存で kernel や fuse がエラーになるので、無視するため `--skip-broken` を追加
    - centos7 のコンテナを使用しているせいか、作成したイメージで起動した際、rpm がエラーを出すので、
      ここで修復しておく


1. インストールされたディレクトリを tar.gz で固めて、volume 配下に設置

    ```
    tar zcvf /root/centos-core-6.tar.gz -C /tmp/root .
    exit
    ```

1. macOS 上で、上記 tar.gz を ADD する Dockerfile を書いて、docker build

    ```
    cat<<EOD>Dockerfile
    FROM scratch
    ADD root/centos-core-6.tar.gz /
    
    CMD ["/bin/bash"]
    EOD
    docker build -t centos-core:6.4 .
    ```

1. 動作確認

    ```
    docker container run -it --rm centos-core:6.4
    ```

おまけ
-----------------------------------------------------------------------------------
ビルドしたイメージは [dockerhub] にもあげて、簡単に使えるようにした。

```
docker container run -it --rm harasou/centos-core:6.4
```

加えて、上記手順を[スクリプト化][buildcentcore]。

```
curl -o buildcentcore https://gist.githubusercontent.com/harasou/460efe82c0e3a0e57eb9e28080ece471/raw
bash buildcentcore 6.4
```

便利。

ただ、自分がやりたかったことは docker より LXC の方が向いてる気がする:-(

<!--links-->
[Official]: https://hub.docker.com/_/centos/
[Dockerfile]: https://github.com/CentOS/sig-cloud-instance-images/blob/CentOS-6.10/docker/Dockerfile 
[kickstart]: https://github.com/CentOS/sig-cloud-instance-build/blob/master/docker/centos-6.ks#L35-L71
[dockerhub]: https://hub.docker.com/r/harasou/centos-core
[buildcentcore]: https://gist.github.com/harasou/460efe82c0e3a0e57eb9e28080ece471
