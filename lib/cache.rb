class CacheUtil
  def initialize(ncode)
    @dir = FileUtils.mkdir_p(".narou/#{ncode}")
  end
  def exist? name
    File.exist?(path name)
  end
  def mtime(name)
    return nil unless exist? name
    return File::stat(path name).mtime
  end
  def path(name)
    File.join(@dir,name)
  end
  def open(name,opt,&block)
    if block_given?
      return File.open(path(name),opt,&block)
    else
      return File.open(path(name),opt)
    end
  end
  def read(name)
    s = open(name,'rb:utf-8'){|f| f.read}
    s.force_encoding NKF.guess s unless s.valid_encoding?
    s
  end
  def write(name,str)
    open(name,"wb"){|f| f.write str}
  end
  def cd(&block)
    FileUtils.cd(File.join(@dir),&block)
  end
end