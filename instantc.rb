#!/usr/bin/ruby -Ks
# coding: sjis

require 'tmpdir'

class InstantC
  def self.main(*argv)
    BuildDir.open do |dir|
      new(dir).start
    end
  end

  def initialize(dir)
    @dir = dir
    @cflags = '/nologo /W2 /EHsc /WX /Od'
    @libs = 'user32.lib'
    @prompt = ">> "
    @pch_cflags = ''
    @_ = nil
    @argv = ''
    @headers = %w[
      stdio.h stdlib.h string.h ctype.h math.h time.h
      windows.h
      string vector iterator functional iostream
      list map memory deque algorithm sstream
    ]
    @decls = ["using namespace std;"]
    @cont = nil
  end

  def start
    mode = File.umask(0077)
    compile_pch
    puts '行末にセミコロンをうつと行がつづきます'
    puts 'exitとかquitとかqとかCtrl+CとかCtrl+Zとかで終了します'
    puts 'http://j.mp/instantc'
    
    while true
      line = prompt and run line or break
    end
  ensure
    File.umask mode
  end

  private
  def run(line)
    return true if line.empty?
    
    return false if line[0] == ?\C-d || line =~ /\Aexit|quit|q\z/i

    if line =~ /\A\s*#/
      line = $' if $'.strip!
      decl line
      return true
    elsif line =~ /\A\s*@/
      line = $' if $'.strip!
      run_as_ruby line
      return true
    end

    code = line
    src, exe, obj = make_filename('c', 'exe', 'obj')
    
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
  
  def prompt
    print @cont ? "?#{@prompt[1..-1]}" : @prompt
    begin
      line = STDIN.gets
    rescue Interrupt
    end

    if line
      line.strip!
      
      if line =~ /;\s*\z/ 
        if @cont
          @cont << line
        else
          @cont = line
        end
        line = ""
      elsif @cont
        @cont << line
        line = @cont
        @cont = nil
      end
    end
    
    line
  end
  
  def header
    "int main(int argc, char **argv) {"
  end

  def footer
    "\n;return 0;}"
  end

  def decl(code)
    @decls << code
    compile_pch
  end
  
  def compile_pch
    src, pch = make_filename('h', 'pch')
    open(src, 'w') do |f|
      @headers.each do |h|
        f.puts "#include <#{h}>"
      end
      f.puts @decls
    end
    
    pch_flags = %[/FI"#{src}" /Fp"#{pch}"]
    msg = `2>&1 cl /c #{@cflags} #{pch_flags} /Yc"#{src}" /Fonul /Tpnul`
    puts msg unless $? == 0
    @pch_cflags = %[#{pch_flags} /Yu"#{src}"]
    msg
  end
  
  def make_filename(*ext)
    @dir.make_filename(*ext)
  end
  
  class BuildDir
    def self.open(dir=nil, &blk)
      if dir
        yield new dir
      else
        Dir.mktmpdir('instantc') do |tmpdir|
          yield new tmpdir
        end
      end
    end
  
    attr_reader :dir
    alias to_s dir
    
    def initialize(dir)
      @dir = dir
      @file_count = 0
    end
    
    def make_filename(*exts)
      @file_count += 1
      name = File.join(@dir, @file_count.to_s)
      exts.map {|e| "#{name}.#{e}" }
    end
  end
end

InstantC.main(*ARGV) if $0 == __FILE__
