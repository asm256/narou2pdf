# -*- encoding: utf-8 -*-
#必要なもの
# -ruby2.0.0以上(2.1.2推奨)
# -uplatex
# --furikana.sty

#依存するGem
#Mechanize
##image_size 廃止
#pdf-reader
#diff-lcs
#Bundler
#
#使い方
#>ruby narou2pdf.rb
#  目次ページのURLの入力をすることでその小説をダウンロード・PDF化
#>ruby narou2pdf.rb 目次ページURL
#  これでも可能
#>ruby narou2pdf.rb --pdf 作成したPDF
#  PDFからURLを取得してアップデートを試みる
#  現在、偶に失敗する(多分空白文字のせい)
#
#https://github.com/whiteleaf7/narou との比較
#+-変換先がPDF
#- ダイジェスト化時の処理が未対応
#- なろう以外への対応がされていない
#- ノクタも正式には対応してない
#- 一部横書き化に対応がされていない
#- 小説ごとの細かい調整ができない
#現在の問題点
#改行・段落を私が好き勝手に弄ってるのでレイアウト重視の場面で崩れる
#横書きの時は気にならないが縦書になると改行の多さが目立つ
# => これはもう仕様としかいいようがない
# 気が向いたらオプションとかで設定
# というかオプション予定がハードコーディングされてごっちゃごちゃ
# なにをオプションにするか纏めるべき
#紙面サイズがA5で固定 端末によっては小さいほうがいいかも？
# => オプションで設定できるといいかも？
#将来
#キャッシュファイル(.txt)はzlibとかzip使って圧縮したいかも
#ダウンロード時にIf-Modified-Sinceつけるといいかもしれない
#urlっぽい文字列を見つけたら\hrefでリンクしたい

require 'scanf'
require 'fileutils'
require 'nkf'
require 'date'
require 'time'
require 'yaml'

require 'bundler/setup'
Bundler.require

require_relative 'lib/cache'
require_relative 'lib/n2tex'
require_relative 'lib/build'
require_relative 'lib/diff'


def n_to_code(ncode)
  code = ncode.scan(/[nN](\d{4})(.*)/)[0]
  n = code[0].to_i
  k = 1
  code[1].reverse.each_char{|s|
    n += (s.to_i(36) - 10)*9999*k
    k *= 26
  }
  #p n
  n
end


#情報取得 txt取得 tex化 が癒着してるので複雑かつ巨大になってる
#分離を考える
def downloadall(url)
  ua = Mechanize.new
  ua.user_agent =
    'Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; Trident/5.0)'
  ua.max_history = 1
  
  config = YAML.load File.open("global.config","rb")
  if u = url.scan(/(ncode\.syosetu\.com)\/([nN]\d{4}[a-zA-Z]*)/).first then
    url = "http://#{u[0]}/#{u[1].downcase}/"
    url_txtdown = "http://ncode.syosetu.com/txtdownload/"
  elsif u = url.scan(/(novel18\.syosetu\.com)\/([nN]\d{4}[a-zA-Z]*)/).first then
    url = "http://#{u[0]}/#{u[1].downcase}/"
    url_txtdown = "http://novel18.syosetu.com/txtdownload/"
  end
  ncode = url.scan( /\.com\/([nN]\d{4}.*)\//)[0][0]
  indpage = ua.get url
  ##作者ページ公開してる場合
  #author = indpage.link_with(:href =>/http:\/\/x?mypage\./)
  author = indpage.at(".novel_writername").text.scan(/：(.*)$/).first
#取得できなかったら例外飛ばすので後で考える
  raise "Failed read Author Name" if author == nil
  author = author.first.strip
  chapters =[]
  indpage.search(".index_box > *").each{|node|
    if "chapter_title" == node.get_attribute("class") then
      #章情報の取得はココで
      chapters.push(:chap => node.text ,:index => [])
    elsif "novel_sublist2" == node.get_attribute("class") then
      chapters.push(:chap => nil ,:index => []) if chapters[-1].nil?
      #各話情報を取得するならココで
      anode =node.search("a")[0]
      kaiko = node.search("span")
      #各話最終更新時刻の取得
      if ! kaiko[0].nil? then
        ud = Date.strptime(kaiko[0]["title"] , "%Y年 %m月 %d日 改稿")
      else
        syoko = node.search("dt")[0].text
        ud = Date.strptime(syoko.strip , "%Y年 %m月 %d日")
      end
      chapters[-1][:index].push(:title => anode.text,
                   :nth => anode["href"].scan(/\/n\d{4}.*\/(\d+)\//)[0][0],
                   :update => ud
      )
    end
  }
  novel_info = NovelInfo.new(indpage.title ,url ,author ,chapters)
  novel_info.make_index
  page =ua.get(url_txtdown+
               "top/ncode/#{n_to_code ncode}/"
              )
  #dir = FileUtils.mkdir_p(".narou/#{ncode}")

  novel_cache=CacheUtil.new ncode
  nconv = N2Tex.new( novel_info ,novel_cache,config)
  nconv.makeIndex
  novel_info_flat = novel_info.flat_index
#ここらへんまでが小説情報の取得
  dlkaisuu = 0
  page.forms[0].field_with(:name => "kaigyo")
    .option_with(:value => "LF").select
  if novel_cache.exist? "#{novel_info_flat.size+1}.tex" then
#削除検知
    puts "話が短くなっています。#{ncode}のバックアップをオススメします"
    raise "part delete"
  end
  outputs = ""
  if page.forms[0].field_with(:name => "no") == nil then
    c_index = 0
    begin
      txt = page.forms[0].submit.body
    rescue Mechanize::ResponseCodeError => ex
      case ex.response_code
      when '404' then
        p "E404"
        return
      when '503' then
        print '503Errorの為5秒間休みます\n'
        p(ex.page.uri)
        sleep 5
        retry
      else
        warn ex.message
      end
    end
    novel_cache.write "0.txt",txt
    novel_cache.write "0.tex" , nconv.txt2tex(txt,novel_info_flat[c_index])
    return build(novel_cache,novel_info)
  end
  page.forms[0].field_with(:name => "no").options.each{|o|
    o.select
    c_index = o.to_s.to_i-1#インデックスのカウンタ
    #改稿のないファイルは更新をすっとばす
    olds = nil
    if novel_cache.exist? o.to_s + ".txt" then
      olds = novel_cache.read "#{o.to_s}.txt"
      if novel_info_flat[c_index][:update] < novel_cache.mtime("#{o.to_s}.txt").to_date then
        novel_cache.write("#{o.to_s}.tex",nconv.txt2tex(olds,novel_info_flat[c_index]))
        next
      end
      puts(""+novel_info_flat[c_index][:nth]+":"+
      novel_info_flat[c_index][:title]+"に更新の疑惑")
    else
      puts("[新規]" + novel_info_flat[c_index][:title])
    end
    begin
      txt = page.forms[0].submit.body
    rescue Mechanize::ResponseCodeError => ex
      case ex.response_code
      when '404' then
        p "E404"
        return
      when '503' then
        print '503Errorの為5秒間休みます\n'
        p(ex.page.uri)
        sleep 5
        retry
      else
        warn ex.message
      end
    end
    dlkaisuu += 1
    if (dlkaisuu % 10) == 9 then
      print "503回避のため、10秒スリープします\n"
      sleep 10
    end
    sleep 0.1
    txt.force_encoding("utf-8")
    if olds then #更新時
      output = str_diff(olds , txt)
#diffのヘッダが適当なのでそのうち直そう
 #--- b.txt 2013-08-27 11:00:37.000000000 +0900
 #+++ a.txt 2014-08-27 10:47:26.000000000 +0900
      outputs << "+-@ #{novel_info_flat[c_index][:title]}\n#{output}" if output && output.size > 0
    end
    novel_cache.write "#{o.to_s}.txt",txt
    novel_cache.write "#{o.to_s}.tex" , nconv.txt2tex(txt,novel_info_flat[c_index])
  }
#diffをひとまとめに
  if outputs.size > 0 then
    File.open('diff.txt','w:utf-8').write outputs
    puts '更新がありました'
  end
  #ビルド
  build(novel_cache,novel_info)
end

  #コマンドライン解析
if  __FILE__ == $0 then
require 'optparse'
opt = OptionParser.new
opt.on('--pdf FILENAME'){|v|
  require "pdf-reader"
  puts v
  PDF::Reader.open(v){|p|
    downloadall p.info[:Subject]
    exit
  }
}
  #p ARGV
cline = opt.permute(ARGV)
if cline.size == 0 then
  print "なろう小説の目次ページのURLを入力してください\n"
  print "例:http://ncode.syosetu.com/n9999xx/\n=>\n"
  downloadall gets.chomp
elsif cline.first.scan URI.regexp('http')
  downloadall cline.first
end
end