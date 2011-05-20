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
  end

  def start
    puts 'exitとかquitとかqとかCtrl+CとかCtrl+Zとかで終了します http://j.mp/instantc'
    while true
      print ">> "
      begin
        line = STDIN.gets or break
      rescue Interrupt
        break
      end
      line.strip!
      break if line[0] == ?\C-d || line =~ /\Aexit|quit|q\z/i
      next if line.empty?
      
      if line =~ /\A#arg[vs]?\s*=\s*/i
        @argv = $' #'
        puts "引数を #{@argv} に設定しました"
        next
      end

      code = line
      Tempfile.open("instantc", @workdir) do |f|
        f << header << code << footer
        f.close

        exe = "#{f.path}.exe"
        compile_begin = Time.now
        msg = `cl /W2 /EHsc /WX /Od /nologo /Fe"#{exe}" /Fo"#{f.path}.obj" /Tp"#{f.path}" 2>&1`
        puts "#{Time.now - compile_begin} sec."
        msg.scan(/(?:error|warning)[^:]+:\s*(.*)/) {|s| puts s }
        if $? == 0 && File.exist?(exe)
          result = `"#{exe} #{@argv}" 2>&1`
          result.strip!
          puts result unless result.empty?
          puts "エラー終了しました コード: #{$? >> 8}" if $? != 0
        end
      end
    end
  end

  private
  def header
    @header ||= begin
      %w[stdio stdlib string ctype math time windows].map {|h| "#include <#{h}.h>" }.join("\n") +
      %w[string vector iterator functional iostream
        list map memory deque algorithm sstream].map {|h| "#include <#{h}>" }.join("\n") +
      "\nint main(int argc, char **argv) {"
    end
  end

  def footer
    ";return 0;}"
  end
end

InstantC.main(*ARGV) if $0 == __FILE__
