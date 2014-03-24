[part:language-reference]

Introduction
============

[chp:introduction] As a programming language, xh gives you two fairly
uncommon invariants:

1.  Every value is fully expressible as a string, and behaves as such.
    [item:values-are-strings]

2.  Every computation can be expressed as a series of
    string-transformation rules. [item:computation-is-transformation]

xh’s string transformations are all about expansion, which corresponds
roughly to the kind of interpolation found in shell script or TCL.
Unlike those languages, however, xh string interpolation itself has
invariants, some of which you can disable. The semantics of xh are all
defined in terms of the string representations of values, though xh is
at liberty to use any representation that convincingly maintains the
illusion that your values function as strings.

Examples
--------

[sec:examples] In these examples, `$` indicates the bash prompt and the
outermost `()` indicate the xh prompt (neither needs to be typed).

    bash                              xh
    $ echo hi                         (. hi)
    $ foo=bar                         (def foo bar)
    $ echo $foo                       (. @foo)
    $ echo "$foo"                     (. $foo)
    $ echo "$(eval $foo)"             (. !foo)
    $ echo $(eval $foo)               (. @!foo)
    $ find . -name '*.txt'            (find . -name '*.txt')
    $ ls name\ with\ spaces           (ls name\ with\ spaces)
    $ rm x && touch x                 (rm x && touch x)
    $ ls | wc -l                      (ls | wc -l)
    $ cat foo > bar                   (cat foo > bar)

    $ for f in $files; do             (map fn(rm $_ && touch $_) $files)
    >   rm "$f" && touch "$f"
    > done

    $ if [[ -x foo ]]; then           (if (-x foo) (./foo arg1 arg2 @_))
    >   ./foo arg1 arg2 "$@"
    > fi

    $ ls | while read f; do           (ls | =f -S)
    >   [[ -S $f ]] && echo $f
    > done

Some xh features have no analog in bash, for instance data structures:

    clojure                           xh
    (def m {})                        (def m {})
    (assoc m :foo 5)                  {foo 5 @m}
    (assoc m :foo 5)                  (assoc $m foo 5)
    (dissoc m :foo :bar)              (dissoc $m foo bar)
    (:foo m)                          ($m foo)
    (get m :foo 0)                    ($m foo 0)
    (map? m)                          (map? $m)
    (contains? m :foo)                (contains? $m foo)

    (def v [])                        (def v [])
    (conj v 1 2 3)                    [@v 1 2 3]
    (conj v 1 2 3)                    (push $v 1 2 3)

    (def s #{})                       (def s s[])
    (contains? s :foo)                ($s foo)
    (contains? s :foo)                (contains? $s foo)

    (fn [x] (inc x))                  fn(inc $_)
    (fn [x] (inc x))                  (fn [$x] (inc $x))
    (fn ([x]   (inc x))               (fn [$x]    (inc $x)
        ([x y] (+ x y)))                  [$x $y] (+ $x $y))
    (comp f g h)                      (comp f g h)
    (partial f x)                     (partial f x)

[part:self-hosting-implementation]

xh-script parser
================

[chp:xh-script-parser] Defined in terms of structural equivalence
between quoted and unquoted forms by specifying the behavior of the
quote relation. Note the free variable `$ws` whenever we join multiple
words together; this allows whitespace to be stored as a transient
quantity and reused across function inversions.

    (def (quote [@xs])             (str "[" (qw $xs) "]")
         (quote {@xs})             (str "{" (qw $xs) "}")
         (quote "@s")              (str "\\\"" (qw $s) "\\\"")
         (quote (re '^[@!$]$' $x)) (str "\\" $x)
         (quote !x)                (str @(match '^([@!\$]+)(.*)$' $x))
         (quote $x)                $x
         ^where (qw $xs) (join (re '^\s+$' $ws) (map quote $xs)))

    (def (parse (quote $x)) $x) 

[part:bootstrap-implementation]

Self-replication
================

[chp:self-replication] **Note:** This implementation requires Perl 5.14
or later, but the self-compiled xh image will run on anything back to
5.10. For this and other reasons, mostly performance-related, you should
always use the xh-compiled image rather than bootstrapping in
production.

    #!/usr/bin/env perl
    BEGIN {eval(our $xh_bootstrap = q{
    # xh: the X shell | https://github.com/spencertipping/xh
    # Copyright (C) 2014, Spencer Tipping
    # Licensed under the terms of the MIT source code license

    # For the benefit of HTML viewers (long story):
    # <body style='display:none'>
    # <script src='http://spencertipping.com/xh/page.js'></script>
    use 5.014;
    package xh;
    our %modules;
    our @module_ordering;
    our %eval_numbers = (1 => '$xh_bootstrap');

    sub with_eval_rewriting(&) {
      my @result = eval {$_[0]->(@_[1..$#_])};
      $@ =~ s/\(eval (\d+)\)/$eval_numbers{$1}/eg if $@;
      die $@ if $@;
      @result;
    }

    sub named_eval {
      my ($name, $code) = @_;
      $eval_numbers{$1 + 1} = $name if eval('__FILE__') =~ /\(eval (\d+)\)/;
      with_eval_rewriting {eval $code};
    }

    our %compilers = (pl => sub {
      my $package = $_[0] =~ s/\./::/gr;
      named_eval $_[0], "{package ::$package;\n$_[1]\n}";
      die "error compiling module $_[0]: $@" if $@;
    });

    sub defmodule {
      my ($name, $code, @args) = @_;
      chomp($modules{$name} = $code);
      push @module_ordering, $name;
      my ($base, $extension) = split /\.(\w+$)/, $name;
      die "undefined module extension '$extension' for $name"
        unless exists $compilers{$extension};
      $compilers{$extension}->($base, $code, @args);
    }

    chomp($modules{bootstrap} = $::xh_bootstrap);
    undef $::xh_bootstrap; 

At this point we need a way to reproduce the image. Since the bootstrap
code is already stored, we can just wrap it and each defined module into
an appropriate `BEGIN` block.

    sub image {
      my @pieces = "#!/usr/bin/env perl";
      push @pieces, "BEGIN {eval(our \$xh_bootstrap = <<'_')}",
                    $modules{bootstrap},
                    '_';
      push @pieces, "BEGIN {xh::defmodule('$_', <<'_')}",
                    $modules{$_},
                    '_' for @module_ordering;
      push @pieces, "xh::main::main;\n__DATA__";
      join "\n", @pieces;
    }
    })} 
