---
title: "実行ファイル一つだけの Docker イメージを作る"
date: 2018-02-10T11:36:50+09:00
tags:
  - docker
  - golang
slug:           2018/02/10/one-execusion-file-in-docker-image
thumbnailImage: 2018/02/10/one-execusion-file-in-docker-image/vertical.png
---

「Go で書かれた実行ファイルを一つだけいれた Dockerイメージを作る」って話が [こちらのサイト][1]
に載っていて、なるほどなぁと思ったので試して見た。

<!--more-->

> [まっさらな状態から Docker イメージを作る][1]
>
> つまり、究極的にはプロセスの動作に必要なファイル一式がシングルバイナリにまとめられて
> いれば、そのファイルだけあれば良いことになる。

スタティックリンクされたバイナリであれば、ルートファイルシステムって、いらんのか...。

Dcckerイメージの作り方
-----------------------------------------------------------------------------------
![](horizontal.png)

Dockerfile は、ベースとして利用するイメージを `FROM` で指定するが、`FROM scratch` と
指定すると何もない状態をベースにできる。あとは、実行ファイルをひとつだけ `ADD` して
あげれば「実行ファイル一つだけの Docker イメージ」ができあがり。

Dockerfile
```
FROM scratch
ADD http-fileserver /

CMD ["/http-fileserver"]
```

`http-fileserver` が、今回用意した「Go で書かれた実行ファイル」で、public ディレクトリ配下を
HTTP で公開するだけのシンプルなやつ。


http-fileserver.go
```
package main

import (
	"log"
	"net/http"
)

func main() {
	log.Fatal(http.ListenAndServe(":8080", http.FileServer(http.Dir("public"))))
}
```

### Build & Run

まずは Go のプログラムをビルド。Docker は Linux なので、Linux 用にビルドする必要がある。
Go はクロスコンパイルが簡単すぎる。

```
GOOS=linux go build http-fileserver.go
```
    
次に、Docker イメージの作成。


```
docker build -t harasou/http-fileserver:latest .
```

そして実行。

```
docker run -it -p 8080:8080 -v $PWD:/public -t harasou/http-fileserver
```

カレントディレクトリのファイルが、ブラウザ http://localhost:8080/ から参照でき、確かに
ちゃんと動いている :-)

![](browser.png)

## 本当にバイナリ一つしかないのか？

最初、http-fileserver.go の `http.Dir("public")` を `http.Dir(".")` のように書いていたら、
以下のように見えていた。

![](browser2.png)

- `http-fileserver` Dockerfile で ADD したファイル
- `public/` docker run 時に指定したボリューム

指定したもの以外にも、いくつかファイルが見える。docker コマンドで、実行中のコンテナ内の
ファイルを確認してみると、

```
$ docker ps
CONTAINER ID        IMAGE                     COMMAND              CREATED             STATUS              PORTS                    NAMES
2de9fb95f020        harasou/http-fileserver   "/http-fileserver"   12 seconds ago      Up 15 seconds       0.0.0.0:8080->8080/tcp   focused_hodgkin
```
```
$ docker export 2de9fb95f020 | tar tv
-rwxr-xr-x  0 0      0           0  2  9 23:48 .dockerenv
drwxr-xr-x  0 0      0           0  2  9 23:48 dev/
-rwxr-xr-x  0 0      0           0  2  9 23:48 dev/console
drwxr-xr-x  0 0      0           0  2  9 23:48 dev/pts/
drwxr-xr-x  0 0      0           0  2  9 23:48 dev/shm/
drwxr-xr-x  0 0      0           0  2  9 23:48 etc/
-rwxr-xr-x  0 0      0           0  2  9 23:48 etc/hostname
-rwxr-xr-x  0 0      0           0  2  9 23:48 etc/hosts
lrwxrwxrwx  0 0      0           0  2  9 23:48 etc/mtab -> /proc/mounts
-rwxr-xr-x  0 0      0           0  2  9 23:48 etc/resolv.conf
-rwxr-xr-x  0 0      0     6188001  2  9 21:28 http-fileserver
drwxr-xr-x  0 0      0           0  2  9 23:48 proc/
drwxr-xr-x  0 0      0           0  2  9 23:48 public/
drwxr-xr-x  0 0      0           0  2  9 23:48 sys/
```

確かにコンテナ内には、http-fileserver 以外のファイルもある。では、イメージの中身は？

```
$ docker image ls
REPOSITORY                TAG                 IMAGE ID            CREATED             SIZE
harasou/http-fileserver   latest              f9c1a31a943c        About an hour ago   6.19MB
```
```
$ docker save f9c1a31a943c | tar tv
drwxr-xr-x  0 0      0           0  2  9 22:41 5947e13bfcf28a2aaed85e364f76a031510cc9a8365d545ec9365995dfb2edb4/
-rw-r--r--  0 0      0           3  2  9 22:41 5947e13bfcf28a2aaed85e364f76a031510cc9a8365d545ec9365995dfb2edb4/VERSION
-rw-r--r--  0 0      0        1202  2  9 22:41 5947e13bfcf28a2aaed85e364f76a031510cc9a8365d545ec9365995dfb2edb4/json
-rw-r--r--  0 0      0     6189568  2  9 22:41 5947e13bfcf28a2aaed85e364f76a031510cc9a8365d545ec9365995dfb2edb4/layer.tar
-rw-r--r--  0 0      0        1539  2  9 22:41 f9c1a31a943c130a319b67a7704272f01d19153db1181127c231009898616742.json
-rw-r--r--  0 0      0         189  1  1  1970 manifest.json
$
```

layer.tar は一つしかないので、階層的には一つみたい。

```
$ docker save f9c1a31a943c | tar xv
x 5947e13bfcf28a2aaed85e364f76a031510cc9a8365d545ec9365995dfb2edb4/
x 5947e13bfcf28a2aaed85e364f76a031510cc9a8365d545ec9365995dfb2edb4/VERSION
x 5947e13bfcf28a2aaed85e364f76a031510cc9a8365d545ec9365995dfb2edb4/json
x 5947e13bfcf28a2aaed85e364f76a031510cc9a8365d545ec9365995dfb2edb4/layer.tar
x f9c1a31a943c130a319b67a7704272f01d19153db1181127c231009898616742.json
x manifest.json
```
```
$ tar tvf 5947e13bfcf28a2aaed85e364f76a031510cc9a8365d545ec9365995dfb2edb4/layer.tar
-rwxr-xr-x  0 0      0     6188001  2  9 21:28 http-fileserver
```

中身をみると、確かに http-fileserver しかないので、やはり、イメージ自体には、
実行ファイル一つしかないようだ :-)

<!--links-->
[1]: http://blog.amedama.jp/entry/2018/02/04/034707
