---
title: "関西Ruby会議06 に登壇させてもらった"
date: 2015-07-15T01:45:57+09:00
tags:
  - mruby
slug:           2015/07/15/kansai-ruby-kaigi
thumbnailImage: 2015/07/15/kansai-ruby-kaigi/rubykaigi.png
---

2015/07/11(土)に行われた「[関西Ruby会議06][0]」に登壇させてもらい、mruby の利用事例について紹介してきた。
インフラしか知らないエンジニアが、matz さんを前に mruby の説明なんて、かなり場違いで恐縮な状況でした。

[0]: http://regional.rubykaigi.org/kansai06/

[![](knsrb.png)](http://regional.rubykaigi.org/kansai06/)


<!--more-->

発表内容
----------------------------------------------------------------------
ホスティングを運用していく上で問題となる「DDoS」「高負荷のプロセス」への対応として、Apache のモジュールである mod_mruby を利用した対応方法を紹介。

そこで利用する３つの mrbgems (CRuby でいうところの gem) の実装例（コード）などの紹介も行いました。

- [http-dos-detector][1]
- [http-access-limitter][2]
- [mruby-cgroup][3]

[1]: http://hb.matsumoto-r.jp/entry/2015/06/08/224827
[2]: http://hb.matsumoto-r.jp/entry/2015/07/09/001623
[3]: https://github.com/matsumoto-r/mruby-cgroup

<div style="width: 65%">
<script async class="speakerdeck-embed" data-slide="1" data-id="0238b7f2c8a44f92a189f2fa62958f2e" data-ratio="1.33333333333333" src="//speakerdeck.com/assets/embed.js"></script>
</div>

感想
----------------------------------------------------------------------
自分の発表については、準備不足でひたすら反省しているので割愛。

登壇者用の控え室で、生の matz さんを初めて見て萎縮してしまいました。matsumotory さんが言うには、全然怖い人ではないそうですが。

インフラの人間としては、RSpec だ Minitest だと言われてもちょっとついていけなかったが、笹田さんのキーワードパラメータの話はおもしろかった。最新の CRuby の話が聞けたし、仕様を決める感じがオープソースなんだなぁって感じで。
