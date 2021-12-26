---
title: "Apache のハンドラを差し替えるモジュールを作った"
date: 2021-12-19T01:16:30+09:00
tags:
  - apache
slug:           2021/12/19/mod-replace-handler
thumbnailImage: 2021/12/19/mod-replace-handler/feather.png
---

個人で必要となるケースは、まずないと思うが、.htaccess などで設定されているハンドラを
システム側で強制的に変更するような Apache のモジュールを作った。

<!--more-->

mod_replace_handler
-----------------------------------------------------------------------------------

https://github.com/harasou/mod_replace_handler

動作仕様
-----------------------------------------------------------------------------------

例えば以下の .htaccess ように、拡張子が html のファイルに、PHP 5.2 が動作するような
ハンドラを割り当てていた場合、

.htaccess
```
AddHandler php5.2-script .html
```

以下のような設定を追加すると、

```
LoadModule replace_handler_module modules/mod_replace_handler.so

<Ifmodule mod_replace_handler.c>
ReplaceHandler php5.2-script php5.3-script
</Ifmodule>
```

拡張子 html のファイルは、PHP 5.2 ではなく、5.3 で動作するようになる。

利用シーン
-----------------------------------------------------------------------------------

想定としては、複数のPHPバージョンを提供しているサーバなどで、古いPHP の提供をシステム側で止めたい場合。

単純に古いPHPを削除すると、該当ハンドラーに対するアクションが存在しなくなるため、
中身がPHPのままダウンロードされてしまう（DBへの接続情報が書かれたファイルなどへ
アクセスされるとインシデントだし...）。

htaccess を書き換えてもらうのが正当だが、そうも言ってられない場合が多いので。

（なんか、他に使い道あるかなぁ）


<!--links-->
