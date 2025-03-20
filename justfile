build:
    werk build --jobs=1

example *args="":
    c3c compile-run examples/basic.c3 opter.c3 -o basic-cli -- {{args}}

test:
    c3c compile-test *.c3
