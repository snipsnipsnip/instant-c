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
    @cflags = '/nologo /W2 /EHsc /WX /Od user32.lib'
    @prompt = ">> "
  end

  def start
    puts 'exit�Ƃ�quit�Ƃ�q�Ƃ�Ctrl+C�Ƃ�Ctrl+Z�Ƃ��ŏI�����܂� http://j.mp/instantc'
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
      puts "������ #{@argv} �ɐݒ肵�܂���"
      return true
    end

    code = line
    src = Tempfile.open("instantc", @workdir)
    src << header << code << footer
    src.close(false)

    exe = "#{src.path}.exe"
    obj = "#{src.path}.obj"
    compile_begin = Time.now
    msg = `2>&1 cl #{@cflags} /Fe"#{exe}" /Fo"#{obj}" /Tp"#{src.path}"`
    puts "#{Time.now - compile_begin} sec."
    msg.scan(/(?:error|warning)[^:]+:\s*(.*)/) {|s| puts s }
    
    if $? == 0
      result = `"#{exe}" #{@argv} 2>&1`
      result.strip!
      puts result unless result.empty?
      puts "�G���[�I�����܂��� �R�[�h: #{$? >> 8}" if $? != 0
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
    @header ||= begin
      %w[stdio stdlib string ctype math time windows].map {|h| "#include <#{h}.h>" } +
      %w[string vector iterator functional iostream
        list map memory deque algorithm sstream].map {|h| "#include <#{h}>" } +
      ["\nint main(int argc, char **argv) {"]
    end.join("\n")
  end

  def footer
    ";return 0;}"
  end
end

InstantC.main(*ARGV) if $0 == __FILE__
