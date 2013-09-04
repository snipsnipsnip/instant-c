ic
==

Instant C, Interactive C or Dump-Compile-Execute-Loop (heavily relying on MSVC)

概要
----
C言語をちょっと試したい時に便利なツールです

昔のBASIC風味のラインエディットをしながら繰り返しいじる機能もあります

いまのところVisual C++にしか対応していません

`printf("hoge") `など、Cコードの断片を書いてリターンを押すと、以下のようなテンプレにあてはめてコンパイルし、その場で実行します

テンプレはある程度コマンドで編集できます

```c
#include <stdio.h>

int main(int argc, char **argv) {
   /* 入力した内容 */
   ;
   return 0;
}
```

基本的な使い方
---
行が変わると別のソースファイルなので、変数は持ち越されません

毎度定義する必要があります

```c
>> printf("hoge")
hoge
>> int hoge; printf("hoge? "); scanf("%d", &hoge); printf("%d", hoge * 2)
hoge? 21
42
>> printf("%d", hoge * 2)
'hoge' : 定義されていない識別子です。
>> vector<int> v(5, 10); copy(v.begin(), v.end(), ostream_iterator<int>(cout, "\n"))
10
10
10
10
10

>> char buf[80]; printf("%s", fgets(buf, 80, fopen("instantc.rb", "r")))
#!/usr/bin/ruby
```
複数行入力
----
行末に開き括弧や演算子があると行の受け付けがつづきます

```c
>> printf(
?> "%d", 1 +
?> 2 *
?> 3);
7
```
字下げしても続きます

コピペに便利です

関数を定義する場合は、最初の` # `も字下げする必要があるので注意してください

```c
>>   printf("hoge");
?> printf("moga")
hogemoga
>>   int hoge;
?>   printf("hoge? ");
?>   scanf("%d", &hoge);
?>   printf("%d", hoge * 2)
?> ;
hoge? 21
42
>>  #
?>   int fibo(int n) {
?>      if (n < 2) {
?>         return 1;
?>      }
?>      return fibo(n - 1) + fibo(n - 2);
?>   }
?> ;
>> printf("%d", fibo(5))
8
>> printf("%d", fibo(10))
89
```
argc, argvと@argv
-----
ruby変数の`@argv`で実行時の引数を設定できます

```c
>> @argv
=> ""
>> printf("%d", argc)
1
>> @argv = "hoge fuga moga"
=> "hoge fuga moga"
>> printf("%d", argc)
4
>> for (int i = 0; i < argc; i++) { printf("%s\n", argv[i]); }
f:/temp/instantc20111102-1908-799euj/4.exe
hoge
fuga
moga
```
関数や定数の定義
----
変数、関数、定数などの宣言は#で始めます

`#define`や`#include`以外にも使えます

その場合は `#` のあとにスペースをあけて定義を書いてください

いままでの定義は `#` だけ打つと見ることができます

`##` と打つとプリコンパイル済みの定義も含めて表示します
 
`#delete [数字]`でその番号の定義を削除します

`#delete` のみだと最後の定義を削除します

```c
>> printf("%d", hoge * 2)
'hoge' : 定義されていない識別子です。
>> #define HOGE 10
>> printf("hoge: %d", HOGE)
hoge: 10
>> # int fuga = 10;
>> # int calc(int a, int b) { return 42; }
>> #
=>
  07: #define HOGE 10
  08: int calc(int a, int b) { return 42; }
>> printf("hoge: %d", calc(HOGE, fuga))
hoge: 42
>> #delete 8
=> "int calc(int a, int b) { return 42; }"
>> printf("hoge: %d", calc(HOGE, fuga))
'calc': 識別子が見つかりませんでした
>> #
=>
  07: #define HOGE 10
```
テンプレの中身はこうなっています

```ruby
<<EOS
#{@decls.join("\n")}
int main(int argc, char **argv) {
#{input}
; return 0; }
EOS
```
rubyのeval
----

`@`で始まる入力はrubyコードとして扱われます

`@`の後スペースがあれば最初の@は取り除いて実行されます

`@_`には直前に実行したrubyコードの値が入っています

```ruby
>> @ 1 + 1
=> 2
>> @ 3.times { puts 'hello?' }
hello?
hello?
hello?
=> 3
>> @_
=> 3
>> @ run %[printf("f#{'o' * 50}")]
foooooooooooooooooooooooooooooooooooooooooooooooooo
=> true
```
プリコンパイル
-----
C++のヘッダを使う場合、snipsnipsnipの持つ程度のマシンだとコンパイルに時間がかかります

そのため、`-x`オプションをつけると`-p`オプションが有効になるようにしてあります

次のコマンドでプリコンパイルヘッダを手動で更新できます

```ruby
@ precompile 
```
