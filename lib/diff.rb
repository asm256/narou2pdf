require 'diff/lcs/hunk'

#diff-lcsのldiffから抜粋
#diff-lcs
# Copyright 2004-2013 Austin Ziegler
# MIT License
#https://github.com/halostatue/diff-lcs/blob/master/License.rdoc
def str_diff(org,dst)
  file_length_difference = 0
  oldhunk = hunk = nil
  lines = 0
  output = ""
  data_olds = org.lines.map{|x| x.chomp}
  data_news = dst.lines.map{|x| x.chomp}
  diffs = Diff::LCS.diff(data_olds, data_news)
  output = ""

  diffs.each do |piece|
    begin
      hunk = Diff::LCS::Hunk.new(data_olds, data_news, piece, lines,
      file_length_difference)
      file_length_difference = hunk.file_length_difference

      next unless oldhunk
      next if (lines > 0) and hunk.merge(oldhunk)
      output << oldhunk.diff(:unified) + "\n"
    ensure
        oldhunk = hunk
    end
  end
  output << oldhunk.diff(:unified) << "\n" if oldhunk

 return output if output.size > 0
 nil
end