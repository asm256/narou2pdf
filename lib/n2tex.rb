# encoding: utf-8

#小説の情報を構造体にまとめる
#:name 名前
#:url  URL
#:author 作者
#:chapter  章情報を配列でもつ

NovelInfo = Struct.new(:name ,:url, :author,:chapter){
  def make_index
    @flat_index ||= []
    #binding.pry
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
  def initialize(novel_info,novel_cache)
    @SETTING= {}
    @SETTING[:IMGOPT] = ""
    @novel_info = novel_info
    @ncache = novel_cache
  end
  def makeIndex()
    @ncache.open("index.tex","wb"){|f|
#プリアンブル A5サイズに設定
      f.write <<EOS
\\documentclass[11pt,twoside,a5j,openany]{utbook}
\\usepackage{furikana}
\\usepackage[uplatex]{otf}
\\usepackage[dvipdfmx]{hyperref}
\\usepackage[dvipdfmx]{pxjahyper}
\\usepackage[dvipdfmx]{graphicx}
\\hypersetup{
 bookmarksnumbered=true,
 setpagesize=false,
 pdfpagelayout=TwoPageLeft,
 pdftitle={#{simplestr2tex @novel_info[:name]}},
 pdfauthor={#{simplestr2tex @novel_info[:author]}},
 pdfsubject={#{simplestr2tex @novel_info[:url]}},
 pdfkeywords={小説家になろう}}  %そのうち設定予定。。。は未定
\\AtBeginDvi{\\special{pdf:pagesize width 148mm height 210mm}}
\\AtBeginDvi{\\special{pdf:docview <</ViewerPreferences <</Direction /R2L>> >>}}
%上２行で用紙サイズ設定および右綴じを実現
\\addtolength{\\topmargin}{-15truemm}
\\addtolength{\\textwidth}{25truemm}
\\addtolength{\\footskip}{-10truemm}  %余白を少し小さく
\\renewcommand{\\figurename}{挿絵}
\\renewcommand{\\listfigurename}{挿絵 目 次} %今のところ作ってないのでいらない
\\newcommand{\\rensujiZW}[1]{%
\\leavevmode
\\hbox to 1zw{\\hspace{0.070zw}\\rensuji*{#1}}%
}
\\newcommand{\\ExQue}{\\hbox to 1zw{\\ajLig{!?}}}
\\newcommand{\\ExEx}{\\hbox to 1zw{\\ajLig{!!}}}
\\newcommand{\\Z}{\\hspace{1zw}}
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
\\tableofcontents
\\markboth{}{}
EOS
      @novel_info[:chapter].each{|c|
#チャプター毎の目次
        if !c[:chap].nil? then
        ct = simplestr2tex c[:chap]
        f.write <<EOS
\\chapter*{#{ct}}
\\addcontentsline{toc}{chapter}{#{ct}}%
\\markboth{#{ct}}{}
EOS
        end
        c[:index].each{|wa|
#セクション毎の目次
          t = simplestr2tex wa[:title]
          f.write <<EOS
\\section*{#{t}}
\\markright{#{t}}
\\addcontentsline{toc}{section}{#{t}}
\\input{#{wa[:nth]}.tex}
EOS
        }
      }
      f.write "\\end{document}\n"
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
  def tag_narou_image txt
#画像の挿入部実装
    txt.gsub(/\\verb\|<\|[iｉ]([０-９]+?)\|([０-９]+?)\\verb\|>\|/){
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
    txt.gsub(/^((?=[\p{P}\p{Sm}])[^「」|｜\\＆\n])[^\n]+(?:\n|$)
    (?:\1[^\n]*(?:\n|$))*/x){|x|
      xl = x.split("\n") #\n記号がいらないのでlinesではなくsplit
#記号から始まる行は段落にする
      next "\n" + x + "\n" if xl.size == 1 #noindentにするか悩むところ
#複数行の場合は箇条書きにする
      r = "\\begin{itemize}\n"
      xl.each{|s| r += "  \\item[#$1]#{s[1..-1]}\n"}
      next r + "\\end{itemize}\n"
    }
  end

  def tex_rotate txt
  #回転する記号をもどします。
    txt.gsub(/([：⇒])/){
      "\\rotatebox[origin=c]{90}{#{$1}}"
    }.gsub("\\%","\\rotatebox[origin=c]{90}{\\%}")
    .tr('—','―') #emダッシュをU+2015に変換
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
    txt.gsub("\\"){"\\verb|\\|"}.gsub(/[#$%&_{}>]/){|c|"{\\" + c+"}"}
    .gsub(/[<^~]/){|c|  "{\\verb|"+c+"|}"}
    .gsub("|"){"{\\verb+|+}"}
  end

  #あとでここだけでも、ユニットテストしようかな
  #仕様がちと巨大化・複雑化しすぎててエンバグしやすい
  def txt2tex(txt,info)
    txt.force_encoding NKF.guess txt if !txt.valid_encoding?
    simplestr2tex(
#タイトルの除去 htmlエスケープを考慮してないバグがある
      txt.sub(/(?:#{info[:title]}\n)|(\*{10,}\n)#{info[:title]}\n/,"\\1").
     gsub("\r\n","\n").      #改行コードをLFへ
#同じ文字の連続だけの行があったら段落にする
      gsub(/^([^\p{P}\p{Sm}])\1{5,}$/){|s|"\n#{s}\n"}.
      gsub(/^[ 　]*/,"").  #行頭の空白を除去 段落に置換した方が見栄えはいいかも
      tr("a-zA-Z0-9","ａ-ｚＡ-Ｚ０-９") #問題児,半角英数字の全角化
#これより後ろは半角英数字は全角に置換されてます
    ).
#ココで汎用texエスケープをしてますので注意！
    gsub("{\\&}","&").gsub("{\\verb+|+}"){"|"}. #あとで使う特殊文字を元に戻す
#<>&のHTMLエスケープの解除
    gsub("&ｌｔ;","\\verb|<|").gsub("&ｇｔ;","\\verb|>|").
    gsub("&ａｍｐ;"){"\\&"}. gsub("&ｑｕｏｔ;","\"").
#スマートな改段落を目指す
    tap{|s| s.replace tex_vskip s}.
#記号開始行を段落or箇条書きへ
    tap{|s| s.replace tex_itemize s}.
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
 #noindentだけだと謎の合字しないバグに悩まされるので1ptだけずらす
    gsub(/^「/,"\n\\noindent\n\\hskip1pt「").
    gsub(/」$/,"」\n\n").
#画像の挿入
    tap{|x|x.replace tag_narou_image x}.
    gsub("(?<!\\verb)|","{\\verb+|+}").
#記号の回転
    tap{|x|x.replace tex_rotate x}.
#！？の後の全角空白を半角空白に変換
 #本来は全角のほうが正しいんだろうがTeXの中におせっかい焼きがいるようなので対策
    gsub(/([！？!?])　/,"\\1 ").
#数字の連数字化
    gsub(/(?<![０-９])([０-９]{2,3})(?![０-９])/){
      '\\rensujiZW{' + $1.tr("０-９","0-9") +  '}'
    }.gsub(/[!！][?？]/){"{\\ExQue}"}.gsub(/[!！]{2}/){"{\\ExEx}"}.
#L[vV]を熟語として処理
   gsub(/(?<![ａ-ｚＡ-Ｚ])(Ｌ[Ｖｖ])(?![ａ-ｚＡ-Ｚ])/){"\\rensujiZW{#{$1.tr('ＬＶｖ','Lvv')}}"}
   #gsub(/(?<![ａ-ｚＡ-Ｚ])(Ｌ[Ｖｖ])(?![ａ-ｚＡ-Ｚ])/){"\\LigLv{#{$1.tr('ＬＶｖ','LVv')}}"}
  rescue => e
    puts "[ERROR]: #{e.message}"
    p info
    puts info[:nth]
    puts info[:title]
    raise e
  end
end