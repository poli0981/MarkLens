# Code blocks

Fenced with a language:

```dart
void main() {
  final greeting = 'Xin chào';
  print(greeting);
}
```

Fenced without a language:

```
plain preformatted text
  indentation preserved
```

Language the highlighter will not know:

```zzunknownlang
this should render unstyled, never as an error
```

A very long line that must scroll horizontally rather than wrap:

```text
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
```

Tilde fences:

~~~python
def hello():
    return "world"
~~~

A fence containing what looks like another fence:

````markdown
```dart
void nested() {}
```
````

Indented code block (four spaces):

    indented code
    second line

Math, which the charter says is shown as a code block, not rendered:

```math
E = mc^2
```

Mermaid, likewise:

```mermaid
graph TD;
  A-->B;
```

Inline code with backticks inside: `` a ` b `` and ``` `` ```.

A fence that is never closed:

```dart
void unterminated() {
