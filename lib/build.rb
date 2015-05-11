# -*- encoding: utf-8 -*-
=begin
`kpsewhich -var-value TEXMFLOCAL`
`kpsewhich furikana.sty`
を使えば自動でfurikana.styをインストールできる
=end
#設定 紙幅とかそのうち
@SETTING = {}
@SETTING[:uplatex_opt] = "-sjis-terminal"
@SETTING[:dvipdfmx_opt] = ""
#@SETTING[:dvipdfmx_opt] = "-f uptex-kozuka-pr6n.map"
#texlive/tex-local/fonts/opentype/以下に
#KozGoPr6n-MEDIUM.otf
#KozMinPr6n-Regular.otf
#が必要なので割とめんどくさい

def build(ncache , ninfo)
  ncode = ninfo[:url].scan( /\.com\/(n\d{4}.*)\//)[0][0]
  x     = (ninfo[:url].match(/^http:\/\/novel18/).nil?) ? "N" : "X"
  outtitle = ninfo[:name].tr("?\"/\<>*|:","？”／￥＜＞＊｜：")+"(#{ncode}_#{x})"
  ["#{outtitle}.pdf",ncache.path('index.pdf')].each{|pdf|
    begin
      FileUtils.rm(pdf,:verbose=>true)
    rescue Errno::EACCES=>e
      puts "PDFが開かれてる事を検知"
      e.to_s.scan(/Permission denied @ unlink_internal - (.*pdf)$/){|s|
        `pdfclose --file "#{s[0]}"`
      }
    rescue Errno::ENOENT
    end
  }
ncache.cd{
  File.open("build.bat","w:cp932"){|f|
    f.write <<EOS
uplatex  #{@SETTING[:uplatex_opt]} index.tex
uplatex  #{@SETTING[:uplatex_opt]} index.tex
@rem 3回めは…いらないか
@rem #{@SETTING[:uplatex_opt]} uplatex  index.tex
dvipdfmx #{@SETTING[:dvipdfmx_opt]} index.dvi
EOS
  }
  File.open("update.bat","w:cp932"){|f|
  f.write <<EOS
@cd /d %~dp0
@cd ..\\..
ruby narou2pdf.rb #{ninfo[:url]}
EOS
  }
  #system("build.bat")
  build2
  FileUtils.rm(["index.toc","index.dvi","index.aux","index.out"],
  {:verbose => true})
}
  FileUtils.mv(ncache.path('index.pdf'),"#{outtitle}.pdf")
  #print("表示しますか？表示しないときはnを入力\n")
  #return if gets.strip() =~ /^[nN]/
  puts 'open pdf'
  `pdfopen --r15 --file "#{outtitle}.pdf"`
  FileUtils.rm(ncache.path('index.log'))
end

def build2
  #uplatexの出力がうるさいので追い出す
  print "uplatex ..."
  `start /wait uplatex #{@SETTING[:uplatex_opt]} index.tex`
  puts $?
  print "uplatex ..."
  `start /wait uplatex #{@SETTING[:uplatex_opt]} index.tex`
  puts $?
  print "dvipdfmx ..."
  `start /wait dvipdfmx #{@SETTING[:dvipdfmx_opt]} index.dvi`
  puts $?
end
