#!/usr/bin/ruby

require 'tmpdir'

class InstantC
  def self.main(*argv)
    mode = File.umask(0077)
    Dir.mktmpdir('instantc') do |dir|
      new(dir).start
    end
  ensure
    File.umask mode
  end

  def initialize(workdir)
    @workdir = workdir
    @cflags = '/nologo /W2 /EHsc /WX /Od'
    @libs = 'user32.lib'
    @prompt = ">> "
    @count = 0
    @pch_cflags = ''
    @_ = nil
    @argv = ''
    @headers = %w[
      stdio.h stdlib.h string.h ctype.h math.h time.h
      windows.h
      string vector iterator functional iostream
      list map memory deque algorithm sstream
    ]
    @preface = "using namespace std;"
  end

  def start
    compile_pch
    puts 'exitとかquitとかqとかCtrl+CとかCtrl+Zとかで終了します http://j.mp/instantc'
    while true
      line = prompt and run line or break
    end
  end

  private
  def run(line)
    return true if line.empty?
    
    return false if line[0] == ?\C-d || line =~ /\Aexit|quit|q\z/i
    
    if line =~ /\A\s*@/i
      if $'.strip!
        run_as_ruby $'
      else
        run_as_ruby line
      end
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

    compile_begin = Time.now if $DEBUG
    msg = `2>&1 cl #{@cflags} #{@pch_cflags} /Fe"#{exe}" /Fo"#{obj}" /Tp"#{src}" #{@libs}`
    puts "#{Time.now - compile_begin} sec." if $DEBUG
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
  
  def run_as_ruby(line)
    result = eval(line)
    print "=> "
    p result
    @_ = result
  rescue Exception => e
    puts e
    e.backtrace.each {|b| puts "  from #{b}" }
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
  
  def compile_pch
    src = "#{gen_filename}.h"
    open(src, "w") do |f|
      @headers.each do |h|
        f.puts "#include <#{h}>"
      end
      f.puts @preface
    end
    
    pch = "#{src}.pch"
    pch_flags = %[/FI"#{src}" /Fp"#{pch}"]
    msg = `2>&1 cl /c #{@cflags} #{pch_flags} /Yc"#{src}" /Fonul /Tpnul`
    puts msg unless $? == 0
    @pch_cflags = %[#{pch_flags} /Yu"#{src}"]
    msg
  end
end

InstantC.main(*ARGV) if $0 == __FILE__
