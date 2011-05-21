#!/usr/bin/ruby

require 'tmpdir'

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
    @count = 0
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
    name = gen_filename
    src = "#{name}.c"
    exe = "#{name}.exe"
    obj = "#{name}.obj"
    
    open(src, 'w') do |f|
      f << header << code << footer
    end

    compile_begin = Time.now
    msg = `2>&1 cl #{@cflags} /Fe"#{exe}" /Fo"#{obj}" /Tp"#{src}" #{@libs}`
    puts "#{Time.now - compile_begin} sec."
    msg.scan(/(?:error|warning)[^:]+:\s*(.*)/) {|s| puts s }

    if $? == 0
      system %["#{exe}" #{@argv}]
      if $? == 0
        puts
      else
        puts "エラー終了しました コード: #{$? >> 8}"
      end
    end
    
    true
  end
  
  def gen_filename
    @count += 1
    File.join(@workdir, @count.to_s)
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
    src = "#{gen_filename}.h"
    open(src, "w") do |f|
      %w[stdio stdlib string ctype math time windows].each do |h|
        f.puts "#include <#{h}.h>"
      end
      %w[string vector iterator functional iostream
        list map memory deque algorithm sstream].each do |h|
        f.puts "#include <#{h}>"
      end
      f.puts "using namespace std;"
    end
    
    pch = "#{src}.pch"
    pch_flags = %[/FI"#{src}" /Fp"#{pch}"]
    system %[cl /c #{@cflags} #{pch_flags} /Yc"#{src}" /Fonul /Tpnul > nul]
    @cflags += %[ #{pch_flags} /Yu"#{src}"]
  end
end

InstantC.main(*ARGV) if $0 == __FILE__
