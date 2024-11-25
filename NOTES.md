I'm writing a cli arg parser, and would like to iterate over parsed arguments in a while loop. `next()` may return an EOF or an error, so I'm wondering what the best API is. In rust I'd use `fn next(&self) -> Result<Option<Arg>, ParseError>`. But it's not clear to me I can have a `fn Arg!! next(&self)`, and I don't particularly want to nest types.

Some examples:

```
fn Arg! Parser.next(&self);
Parser p;
p.init(input);
while (try arg = p.next()) {
    io::printn(arg.value);
}
if (p.has_error) {
    p.error()!;
}
```
```
fn Arg! Parser.next(&self);
Parser p;
p.init(input);
while (1) {
    Arg! arg = p.next();
    if (catch err = arg) {
        if (err == ParseState.EOF) {
            break;
        } else {
            return err?;
        }
    }
    io::printn(arg.value);
}
```
```
fn bool! Parser.next(&self, Arg* arg);
Parser p;
p.init(input);
Arg arg;
while (p.next(&arg)!) {
    io::printn(arg.value);
}
