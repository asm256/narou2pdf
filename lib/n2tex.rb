# encoding: utf-8

#参考資料 JIS X 4051
#日本語組版処理の要件
#http://www.w3.org/TR/jlreq/ja/
#LaTeX 小説同人誌制作術
#http://p-act.sakura.ne.jp/PARALLEL_ACT/LaTeX-Dojin/

#小説の情報を構造体にまとめる
#:name 名前
#:url  URL
#:author 作者
#:chapter  章情報を配列でもつ

NovelInfo = Struct.new(:name ,:url, :author,:chapter){
  def make_index
    @flat_index ||= []
    chapter.each{|n|
    @flat_index.concat n[:index]}
  end
  def flat_index
    @flat_index
  end
}
class N2Tex
#@SETTINGをそのうち外部から取り込む
  #横書きの時はangleを0に
  def initialize(novel_info,novel_cache,config)
    @ncache = novel_cache
    @SETTING= config
    @SETTING.merge! YAML.load @ncache.read "local.config" if @ncache.exist? "local.config"
    #@SETTING[:IMGOPT] = ""
    @novel_info = novel_info
  end
  def makeIndex()
    @ncache.open("index.tex","wb"){|f|
#プリアンブル A5サイズに設定
      f.write <<EOS
\\documentclass[#{@SETTING[:paper][:fontsize]},twoside,#{@SETTING[:paper][:size]},openany]{utbook}
\\usepackage{furikana}
\\usepackage[uplatex,expert,deluxe,burasage]{otf}
\\usepackage[dvipdfmx]{hyperref}
\\usepackage[dvipdfmx]{pxjahyper}
\\usepackage[dvipdfmx]{graphicx}
\\hypersetup{
 bookmarksnumbered=true,
 setpagesize=false,
 pdfpagelayout=TwoPageLeft,
 pdfdirection={R2L},
 pdftitle={#{simplestr2tex @novel_info[:name]}},
 pdfauthor={#{simplestr2tex @novel_info[:author]}},
 pdfsubject={#{simplestr2tex @novel_info[:url]}},
 pdfkeywords={小説家になろう}}  %そのうち設定予定。。。は未定
\\AtBeginDvi{\\special{pdf:pagesize #{@SETTING[:paper][:pdfpagesize]}}}
EOS
      f.puts @SETTING[:add_header]
      f.write <<EOS
\\renewcommand{\\figurename}{挿絵}
\\renewcommand{\\listfigurename}{挿絵 目 次} %今のところ作ってないのでいらない
\\newcommand{\\rensujiZW}[1]{%
%\\leavevmode
%\\hbox to 1zw{\\hspace{0.070zw}\\rensuji*{\\ajTsumesuji*{#1}}}%
\\rensuji*{\\ajTsumesuji*{#1}}%
}
\\newcommand{\\ExQue}{\\ajLig{!?}}
\\newcommand{\\ExEx}{\\ajLig{!!}}
\\makeatletter
%\\noindent\\null の後で、行頭括弧が揃うようにする
\\let\\orig@null=\\null
\\def\\null{\\orig@null\\futurelet\\@let@token\\@@tondgnewline}

%\\noindent の後で、行頭括弧が揃うようにする
\\let\\orig@noindent=\\noindent
\\def\\noindent{\\orig@noindent\\futurelet\\@let@token\\@@tondgnewline}

%改行の後で、行頭括弧が揃うようにする
\\def\\@tondgnewline{%
  \\futurelet\\@let@token\\@@tondgnewline}
\\def\\@@tondgnewline{%
  \\ifx\\@let@token「
    \\hskip.5zw\\<%
  \\else
    \\ifx\\@let@token（
      \\hskip.5zw\\<%
    \\else
      \\ifx\\@let@token『
        \\hskip.5zw\\<%
      \\else
        \\ifx\\@let@token［
          \\hskip.5zw\\<%
        \\else
          \\ifx\\@let@token“
            \\hskip.5zw\\<%
          \\else
            \\ifx\\@let@token‘
              \\hskip.5zw\\<%
            \\else
              \\ifx\\@let@token〈
                \\hskip.5zw\\<%
              \\else
                \\ifx\\@let@token《
                  \\hskip.5zw\\<%
                \\else
                  \\ifx\\@let@token【
                    \\hskip.5zw\\<%
                  \\else
                    \\ifx\\@let@token〔
                      \\hskip.5zw\\<%
                    \\fi
                  \\fi
                \\fi
              \\fi
            \\fi
          \\fi
        \\fi
      \\fi
    \\fi
  \\fi}
\\def\\@gnewline #1{%
  \\ifvmode
    \\@nolnerr
  \\else
     \\unskip \\reserved@e {\\reserved@f#1}\\nobreak \\hfil \\break \\null
    \\ignorespaces
  \\fi
  \\@tondgnewline}
\\makeatother
\\begin{document}
\\begin{titlepage}
\\Large \\begin{flushleft}#{@novel_info[:name]}
\\end{flushleft}
\\begin{flushright}
作者\\rotatebox[origin=c]{90}{：}#{simplestr2tex @novel_info[:author]}
\\end{flushright}
\\begin{flushright}
\\end{flushright}
\\end{titlepage}
EOS
      f.write <<EOS if @novel_info[:chapter].size > 0
\\tableofcontents
\\markboth{}{}
EOS
      f.write "\\input{0.tex}\n" if @novel_info[:chapter].size == 0
      @novel_info[:chapter].each{|c|
#チャプター毎の目次
        if !c[:chap].nil? then
        ct = tex_titlize c[:chap]
        f.write <<EOS
\\chapter*{#{tex_rotate ct}}
\\addcontentsline{toc}{chapter}{#{ct}}%
\\markboth{#{ct}}{}
EOS
        end
        c[:index].each{|wa|
#セクション毎の目次
          t = tex_titlize wa[:title]
          f.write <<EOS
\\section*{#{tex_rotate t}}
\\markright{#{t}}
\\addcontentsline{toc}{section}{#{t}}
\\input{#{wa[:nth]}.tex}
EOS
        }
      }
      f.write "\\end{document}\n"
    }
  end

#実験的フォーマット
#数字で開始されてる行の後は改行を入れる
  def txt_numberstart txt
    txt.gsub(/^([０-９]+[^\n]*)\n(?!\n)/){"\n#{$1}\n\n"}
  end
#行末が約物でない場合レイアウト重視場面と判断し段落に変える
  def txt_smartend txt
  txt.gsub(/^([^\n]+?[^\na-zA-Z0-9。、」』‥…～♪.．？?！!])$/){
    "\n#{$1}\n"
  }
  end
  def bouten? oya , ko
    oya.size == ko.size
  end
  def bouten_v? oya,ko
    return false unless bouten?(oya,ko)
    #wikipediaの圏点からリスト取得＋全半角の・
    return ko.match /^[●○▲△◎◉・･.﹅﹆]+$/
  end
  def bouten oya, ko
    out = ""
    oya.size.times{|x|
      out << "\\kana{#{oya[x]}}{#{ko[x]}}"
    }
    out
  end

#先頭および末尾の空白を除去
def txt_trim txt
  txt.gsub(/^[ 　 ]+/,'').gsub(/[ 　  ]+$/,'')
end

#引用符を日本版引用符に変更
def txt_quotation txt
  txt.gsub(/(?:"(?:[^\n"]*\n?){,3}")|(?:[“”](?:[^\n“”]*\n?){,3}[“”])/){|s|
    "〝#{s[1..-2]}〟"
  }
end

#なろう専用タグの処理
  def tag_narou txt
    txt.gsub('【改ページ】' ,'{\bigskip}')
       .gsub('<KBR>','')
       .gsub('<PBR>','')
  end

  def tag_narou_image txt
#画像の挿入部実装
    txt.gsub(/<[iｉ]([０-９]+?)\|([０-９]+?)>/){
      agent = Mechanize.new
      agent.user_agent =
        'Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; Trident/5.0)'
      d1 = $1.tr("０-９","0-9")
      d2 = $2.tr("０-９","0-9")
      puts "[画像] http://#{d2}.mitemin.net/i#{d1}/"
      page = agent.get("http://#{d2}.mitemin.net/i#{d1}/")
      pic_link = page.link_with(:text=>'最大化')
      fnpic = pic_link.uri.path.split("/")[-1]
      if !@ncache.exist? fnpic then #画像はまだダウンロードされていない
        pic = pic_link.click
        @ncache.write(fnpic,pic.body)
      end
      `extractbb #{@ncache.path(fnpic)}` unless @ncache.exist? fnpic.gsub(/\..+$/){|x| ".xbb"}
      img_opt = 'angle=90,width=\textwidth,height=\textheight,keepaspectratio'
      next <<EOS
\n 挿絵\\ref{fig:#{d1}:#{d2}}
\\begin{figure}
    \\centering
    \\includegraphics[#{img_opt}]{#{fnpic.split("/")[-1]}}
    \\caption{\\href{http://#{d2}.mitemin.net/i#{d1}/}{http://#{d2}.mitemin.net/i#{d1}/}}
    \\label{fig:#{d1}:#{d2}}
\\end{figure}
EOS
    }
  end


  def tex_itemize txt
    txt.gsub(/^((?=[\p{P}\p{Sm}])[^「」|｜\\＆><\n])[^\n]+(?:\n|$)
    (?:\1[^\n]*(?:\n|$))*/x){|x|
      xl = x.split("\n") #\n記号がいらないのでlinesではなくsplit
#記号から始まる行は段落にする
      next "\n" + x + "\n" if xl.size == 1 #noindentにするか悩むところ
#複数行の場合は箇条書きにする
      r = "\\begin{itemize}\n"
      xl.each{|s| r += "  \\item[#$1]#{s[1..-1]}\n"}
      next r + "\\end{itemize}\n"
    }.
#<>で始まる行をitemizeする方法わからんので段落へ
    gsub(/^([<>])([^\n]*)/,"\n\\1\\2\n")
  end

  def tex_rotate txt
  #回転する記号をもどします。
   #U+21D1が表示されない問題orz
    txt.gsub(/([：⇐⇒＞＜∈∋≪≫])/){
      "\\rotatebox[origin=c]{270}{#{$1}}"
    }.gsub("\\%","\\rotatebox[origin=c]{270}{\\%}")
    .gsub(/[—－]/,'―')  #emダッシュ/全角ハイフンをU+2015に変換
    .gsub(/\\(?:href|label|ref){(.*?)}$/){|x|
      x.gsub(/\\rotatebox\[origin=c\]\{270\}\{([^}]+)\}/,'\1')
    }
  end

#ちょっと行間を空けて改段落
  def tex_vskip txt
    txt.gsub(/\n{9,}/){"\n\\clearpage\n\n"}.
        gsub(/\n{6,}/){"\n\\bigskip\n\n"}.
        gsub(/\n{5,}/){"\n\\medskip\n\n"}.
        gsub(/\n{4}/ ){"\n\\smallskip\n\n"}
  end

  #単純にtxtで指示された文章をエスケープ
  def simplestr2tex txt
    txt.gsub("\\"){"\\verb+\\+"}.gsub(/[#$%&_{}]/){|c|"{\\" + c+"}"}
    .gsub(/[<>^~|]/){|c|  "{\\verb+"+c+"+}"}
  end

  #チャプタ文字列化
  def tex_titlize txt
    #手抜き
    txt.tr("\\<>#$%&_{}" , "\\＜＞＃＄％＆＿｛｝")
  end

  #あとでここだけでも、ユニットテストしようかな
  #仕様がちと巨大化・複雑化しすぎててエンバグしやすい
  def txt2tex(txt,info)
    txt.force_encoding NKF.guess txt if !txt.valid_encoding?
    txt.force_encoding NKF.guess txt if txt.encoding == Encoding::ASCII_8BIT
#タイトルの除去 htmlエスケープを考慮してないバグがある
    txt = txt.sub(/(?:#{info[:title]}\n)|(\*{10,}\n)#{info[:title]}\n/,"\\1") if info
    simplestr2tex(txt.
      gsub("\r\n","\n").      #改行コードをLFへ
      tap{|s| @SETTING[:replace_pre].reduce(s){|memo,item| memo.gsub!(item[0],item[1]);memo }}.
#同じ文字の連続だけの行があったら段落にする
      gsub(/^([^\p{P}\p{Sm}])\1{5,}$/){|s|"\n#{s}\n"}.
#行頭・末尾の空白を除去 行頭空白は段落に置換した方が元のデザイン的には正しいが
  #縦組で読む場合段落多すぎて不快に感じるので
      tap{|s|s.replace txt_trim s}.
      tr("a-zA-Z0-9/","ａ-ｚＡ-Ｚ０-９／") #問題児,半角英数字の全角化
      #半角スラッシュはむしろ半角バックスラッシュに変換した方が見栄えがいいんだが
      #コピペした時の利便性を考えて全角化に留める
#これより後ろは半角英数字は全角に置換されてます
    ).
#http://[a-zA-Z./0-9]+をリンクに置き換える
    gsub(/(ｈｔｔｐｓ?)[:：]／／([ａ-ｚＡ-Ｚ０-９.／]+)/){|s|
      scm = $1.tr("ａ-ｚＡ-Ｚ０-９／","a-zA-Z0-9/")
      uri = $2.tr("ａ-ｚＡ-Ｚ０-９／","a-zA-Z0-9/")
      "\\url{#{scm}://#{uri}}"
    }.
#ココで汎用texエスケープをしてますので注意！
    gsub("{\\&}","&").gsub("{\\verb+|+}"){"|"}. #あとで使う特殊文字を元に戻す
#<>&のHTMLエスケープの解除
    gsub("&ｌｔ;","<").gsub("&ｇｔ;",">").
    gsub("&ａｍｐ;"){"\\&"}. gsub("&ｑｕｏｔ;","\"").
    #引用符を日本語用に
    tap{|s|s.replace txt_quotation s}.
#スマートな改段落を目指す
    tap{|s| s.replace tex_vskip s}.
    tap{|s| s.replace txt_smartend s}.
#記号開始行を段落or箇条書きへ
    tap{|s| s.replace tex_itemize s}.
#実験機能 数字開始行を強制改行(掲示板方式を読みやすくする狙い)
    tap{|s| s.replace txt_numberstart s}.
#ルビその１
    gsub( /[｜|]([^\n]*?)(《[^》\n]*》|（[^）\n]*）|\([^\)\n]*\))/){
      next bouten($1,$2[1..-2]) if bouten?($1 ,$2[1..-2])
      next $2 if ($1.eql? "") || $1[-1] == "|" || $1[-1] == "｜"
      next "\\kana{#{$1}}{#{$2[1..-2]}}"
    }.
#ルビその2 これは作者ミスパターンも多いので()を残す
    gsub(/(\p{Han}+)(《[\p{Katakana}\p{Hiragana}ーｰﾞﾟ・･]+》
    |\([\p{Katakana}\p{Hiragana}ーｰﾞﾟ・･]+\)
    |（[\p{Katakana}\p{Hiragana}ーｰﾞﾟ・･]+）)/x){
     next bouten($1,$2[1..-2]) if bouten_v?($1 ,$2[1..-2])
     "\\kana{#{$1}}{#{$2}}"
    }.
#セリフは段落を変える
 #ただし、字下げはしない
    gsub(/^[「｢]/,"\n\\noindent\n「").
    gsub(/[」｣]$/,"」\n").
#なろう専用タグ
    tap{|x|x.replace tag_narou x}.
#画像の挿入
    tap{|x|x.replace tag_narou_image x}.
    gsub("(?<!\\verb)|","{\\verb+|+}").
#記号の回転
    tap{|x|x.replace tex_rotate x}.
#！？の後の全角/半角空白を削除
 #本来は全角のほうが正しいんだろうがTeXの中におせっかい焼きがいるようなので対策
    gsub(/([！？!?])[　 ]/,"\\1").
 #なんかしらんが)を終わり括弧と認識してないくさいのでグルー消し
    gsub(/([！？!?])([)])/,'\1\<\2').
#数字の連数字化
 #カンマ付き数字に対応できないorz
    gsub(/(?<![０-９,])([０-９]{2,4})(?![０-９])/){
      '\rensujiZW{' + $1.tr("０-９","0-9") +  '}'
    }.gsub(/[!！][?？]/){"{\\ExQue}"}.gsub(/[!！]{2}/){"{\\ExEx}"}.
#L[vV]を熟語として処理
   gsub(/(?<![ａ-ｚＡ-Ｚ])(Ｌ[Ｖｖ][.．]?)(?![ａ-ｚＡ-Ｚ])/){"\\rensuji*{#{$1.tr('ＬＶｖ．','Lvv.')}}"}.
   gsub(/(?<![ａ-ｚＡ-Ｚ])([Ｏｏ][ｒＴ][ｚＺ])(?![ａ-ｚＡ-Ｚ])/){"\\rensuji*{#{$1.tr('ＯｏｒＴｚＺ','OorTzZ')}}"}.
   gsub(/(?<![ａ-ｚＡ-Ｚ])ｋ㎡(?![ａ-ｚＡ-Ｚ])/,'\ajLig{km2}').
#<>をtexエスケープ
   gsub(/(?<!(?:\\item\[)|\\)([<>])/ , '\verb|\1|').
   tap{|s| @SETTING[:replace_post].reduce(s){|memo,item| memo.gsub!(item[0],item[1]);memo}}
  rescue => e
    puts "[ERROR]: #{e.message}"
    if p then
    p info
      puts info[:nth]
      puts info[:title]
    end
    raise e
  end
end