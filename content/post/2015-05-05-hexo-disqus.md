---
title: "hexo に DISQUS を追加"
date: 2015-05-05T17:22:31+09:00
tags:
  - hexo
slug: 2015/05/05/hexo-disqus
---

DISQUS はコメント機能を提供するサービスで、hexo では簡単に導入できる。

DISQUS の管理ページにある Shortname を設定するだけ。ただ、自分が使っているテーマ light ではうまく表示されなかったので、テーマの設定にある `comment_provider` に facebook 以外の文字列を設定して対処。

```sh
hexo config disqus_shortname harasougithubio
hexo --config themes/light/_config.yml config comment_provider disqus
```
