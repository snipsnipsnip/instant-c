#!/usr/bin/ruby

require 'tmpdir'
require 'tempfile'

class InstantC
  def self.main(*argv)
    Dir.mktmpdir('instantc') do |dir|
      new(dir).start
    end
  end

  def initialize(workdir)
    @workdir = workdir
    @cflags = '/nologo /W2 /EHsc /WX /Od'
    @libs = 'user32.lib'
    @prompt = ">> "
  end

  def start
    init_pch
    puts 'exitとかquitとかqとかCtrl+CとかCtrl+Zとかで終了します http://j.mp/instantc'
    while true
      line = prompt and run line or break
    end
  end

  private
  def run(line)
    return true if line.empty?
    
    return false if line[0] == ?\C-d || line =~ /\Aexit|quit|q\z/i
    
    if line =~ /\A#arg[vs]?\s*=\s*/i
      @argv = $' #'
      puts "引数を #{@argv} に設定しました"
      return true
    end

    code = line
    src = Tempfile.open("instantc", @workdir)
    src << header << code << footer
    src.close

    exe = "#{src.path}.exe"
    obj = "#{src.path}.obj"
    compile_begin = Time.now
    msg = `2>&1 cl #{@cflags} /Fe"#{exe}" /Fo"#{obj}" /Tp"#{src.path}" #{@libs}`
    puts "#{Time.now - compile_begin} sec."
    msg.scan(/(?:error|warning)[^:]+:\s*(.*)/) {|s| puts s }
    
    if $? == 0
      result = `"#{exe}" #{@argv} 2>&1`
      result.strip!
      puts result unless result.empty?
      puts "エラー終了しました コード: #{$? >> 8}" if $? != 0
    end
    
    true
  end
  
  def prompt
    print @prompt
    begin
      line = STDIN.gets
    rescue Interrupt
    end
    line.strip! if line
    line
  end
  
  def header
    "int main(int argc, char **argv) {"
  end

  def footer
    "\n;return 0;}"
  end
  
  def init_pch
    pch_src = Tempfile.open("instantc-pch", @workdir)
    
    %w[stdio stdlib string ctype math time windows].each do |h|
      pch_src.puts "#include <#{h}.h>"
    end
    %w[string vector iterator functional iostream
      list map memory deque algorithm sstream].each do |h|
      pch_src.puts "#include <#{h}>"
    end
    
    pch_src.close
    
    pch_obj = "#{pch_src.path}.obj"
    pch_pch = "#{pch_src.path}.pch"
    
    pch_flags = %[/FI"#{pch_src.path}" /Fp"#{pch_pch}"]
    
    system %[cl /c #{@cflags} #{pch_flags} /Yc"#{pch_src.path}" /Fo"#{pch_obj}" /Tp"#{pch_src.path}" > nul]
    
    @cflags += %[ #{pch_flags} /Yu"#{pch_src.path}"]
  end
end

InstantC.main(*ARGV) if $0 == __FILE__
