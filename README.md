narou2pdf
=========

「小説家になろう」をPDFに変換するスクリプト

公式のタテ書き小説ネットでいいじゃない
=========
タテ書きはなんというか台本読んでるみたいで味気ない  
なにより、*挿絵が省かれる*
必要なもの
=========
1. ruby(2.0.0 以上)
Onigmoライブラリ使用してるので2.0以上必須です
2. いくつかのGem
 * Mechanize
 * pdf-reader
 * diff-lcs
 * Bundler
3. upLaTeX
TeXLive 2014なら大丈夫なはず
[TeX Live](https://www.tug.org/texlive/)  

 * furikana.sty

使い方
=========
windows環境用になっているので他環境の場合  
lib/build.rbの書き換えが必要になります

  * 具体的にはstartコマンドはないので、ただのuplatexに
  * bat をsh

一応コレで動くと思うけど試してはないです

* $ ruby narou2pdf  
対話的操作  
目次ページ聞かれるのでコピペで
* $ ruby narou2pdf http://ncode.syosetu.com/n3009bk/  
上のちょっとだけ省略
* $ ruby narou2pdf --pdf できあがった.pdf  
pdfから目次ページを読み取って更新する  
キャッシュの更新日時読み取って更新されたモノだけ更新している  
問題がいくつかある
 * 更新時間まで見てないので本日更新したものは毎回上書き
 * ダイジェスト化等で短くなった場合とりあえず更新を中止します
 * １話より前に設定資料を追加等で番号がズレた場合を考慮してない

つくった人
============
[@asm__](http://twitter.com/@asm__)
謝辞
============
このスクリプト自体のライセンスはまだ決めてないです。ごめんなさい  
lib/diff.rbはMITライセンスのlcs-diffのldiffを含んでます  
lib/n2tex.rbのプリアンブルには[LaTeX 小説同人誌制作術・小説組版術サポートページ](http://p-act.sakura.ne.jp/PARALLEL_ACT/LaTeX-Dojin/)から拾ってきたコードとか入ってます  
