@start ruby -x "%~f0" %* & exit /b
#!/usr/bin/ruby -Ks
# coding: sjis

require 'tmpdir'

class InstantC
  def self.main(*argv)
    if argv.include?("-h")
      puts 'Instant C, Interactive C or Read-Compile-Execute-Loop'
      puts 'http://j.mp/instantc'
      puts '行末に演算子をうったり、字下げすると行がつづきます'
      puts '関数や変数は # int hoge() { puts("fuga"); } みたいな感じで宣言できます'
      puts "-p オプションをつけると起動時にプリコンパイルします"
      puts "-x オプションをつけるとC++のvectorとかが使えるようになります (-pと併用はおすすめ)"
    end
    BuildDir.open do |dir|
      new(Compiler.guess(dir)).start
    end
  end

  def initialize(compiler)
    @compiler = compiler
    @prompt = ">> "
    @_ = nil
    @argv = ''
    @precompiled_decls = []
    
    headers = %w[cstdio cstdlib cstring cctype cmath ctime]
    
    if ARGV.include?("-x")
      headers.concat %w[
        string vector iterator functional iostream
        list map memory deque algorithm sstream
      ]
    end
    @decls = headers.map {|h| "#include <#{h}>" }
    @decls << "using namespace std;"
    @cont = nil
  end

  def start
    mode = File.umask(0077)
    puts 'instantc cel http://j.mp/instantc'
    puts '行末に演算子をうったり、字下げすると行がつづきます'
    puts '関数の定義とかのしかたは-hオプションで見れます'
    puts 'exitとかquitとかqとかCtrl+CとかCtrl+Zとかで終了します'
    
    precompile if ARGV.include?("-p")
    
    while true
      line = prompt and run line or break
    end
  ensure
    File.umask mode
  end

  private
  def run(line)
    case line
    when /\A(?:\C-d|exit|quit|q)\s*\z/i
      return false
    when /\A\s*\z/
      return true
    when /\A\s*#/
      rest = $'
      line = rest if rest.lstrip!
      declare line
      return true
    when /\A\s*@/
      rest = $'
      line = rest if rest.lstrip!
      run_as_ruby line
      return true
    end

    if exe = @compiler.compile([header, line, footer])
      if system %["#{exe}" #{@argv}]
        puts
      else
        puts "エラー終了しました コード: #{$? >> 8}"
      end
    end
    
    true
  end
  
  def run_as_ruby(line)
    return if line.empty?
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
      if @interrupted
        return nil
      else
        @interrupted = true
        puts
        return ""
      end
    end

    return nil unless line
    
    if line =~ /[-;{\\+*\/%^,.(&|<=>]\s*\z/ || line =~ /\A\s/
      if @cont
        @cont << line
      else
        @cont = line
      end
      line = ""
      @interrupted = false
    elsif @cont && !line.empty?
      @cont << line
      line = @cont
      @cont = nil
      @interrupted = false
    end
    
    line
  end
  
  def header
    @decls.reject {|x| x.frozen? }.join("\n") +
    "\n;\nint main(int argc, char **argv) {"
  end

  def footer
    "\n;return 0;}"
  end

  def declare(code)
    @decls << code
  end
  
  def precompile
    hmm = @precompiled_decls + @decls
    begin
      puts 'プリコンパイル中.. (Ctrl+Cや-fスイッチでスキップできます)'
      @compiler.precompile(hmm)
    rescue Interrupt
      puts "中断しました"
      return
    end
    @precompiled_decls = hmm
    @decls.clear
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
  
  class Compiler
    attr_accessor :cflags
    
    def self.guess(workdir)
      if RUBY_PLATFORM.include?("mswin") && MSVC.try_setup_env!
        MSVC.new workdir
      else
        raise "couldn't find any compiler"
      end
    end
    
    def initialize(workdir)
      @dir = workdir
    end
    
    private
    def make_filename(*args)
      @dir.make_filename(*args)
    end
    
    class MSVC < Compiler
      def self.try_setup_env!
        return true if system("cl >nul 2>nul")
      
        unless bat = find_vsvars32
          warn "couldn't find any vsvars32.bat" if $DEBUG
          return false
        end
        
        variables_to_import = %w[INCLUDE LIB LIBPATH PATH]
        values = exec_and_get_env(bat, variables_to_import)
        
        unless values.all? {|v| v }
          warn "failed to import variables" if $DEBUG
          return false
        end
        
        variables_to_import.zip(values) {|var, value| ENV[var] = value }
        
        true
      end
      
      class << self
        private
        def find_vsvars32
          11.downto(5) do |n|
            dir = ENV["VS#{n}0COMNTOOLS"] or next
            bat = File.join(dir, 'vsvars32.bat')
            return bat if File.exist?(bat)
          end
          nil
        end
        
        def exec_and_get_env(cmd, vars)
          queries = vars.map {|v| "set #{v}" }.join(" & ")
          result = `"#{cmd}" >nul 2>nul & #{queries}`
          vars.map {|var| result =~ /^#{var}=(.*)/i; $1.strip }
        end
      end
    
      def initialize(workdir)
        super
        @pch_cflags = nil
        @cflags = '/nologo /W2 /EHsc /Od /D_CRT_SECURE_NO_DEPRECATE'
      end
      
      def precompile(code)
        src, pch = make_filename('h', 'pch')
        open(src, 'w') {|f| f.puts code }
        pch_flags = %[/FI"#{src}" /Fp"#{pch}"]
        msg = `2>&1 cl /c #{@cflags} #{pch_flags} /Yc"#{src}" /Fonul /Tpnul`
        puts msg unless $? == 0
        @pch_cflags = %[#{pch_flags} /Yu"#{src}"]
        msg
      end
      
      def compile(code)
        src, exe, obj = make_filename('c', 'exe', 'obj')
        
        open(src, 'w') do |f|
          f.puts code
        end

        compile_begin = Time.now if $DEBUG
        msg = `2>&1 cl #{@cflags} #{@pch_cflags} /Fe"#{exe}" /Fo"#{obj}" /Tp"#{src}"`
        puts "#{Time.now - compile_begin} sec." if $DEBUG
        msg.scan(/(?:error|warning)[^:]+:\s*/) {|s| puts $' }
        
        exe if $? == 0
      end
    end
  end
end

InstantC.main(*ARGV) if $0 == __FILE__
