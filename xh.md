[part:introduction]

design constraints {#chp:design-constraints}
==================

xh is designed to be a powerful and ergonomic interface to multiple
systems, many of which are remote. As such, it’s subject to programming
language, shell, and distributed-systems constraints:

1.  [i:real-programming] xh will be used for real programming. (Initial
    assumption)

2.  [i:shell] xh will be used as a shell. (Initial assumption)

3.  [i:distributed-computation] xh will be used to manage any machine on
    which you have a login, which could be hundreds or thousands.
    (Initial assumption)

4.  [i:no-root-access] You will not always have root access to machines
    you want to use, and they may have different architectures. (Initial
    assumption)

5.  [i:ergonomic-limit] xh should approach the limit of ergonomic
    efficiency as it learns more about you. (Initial assumption)

6.  [i:security] xh should never compromise your security, provided you
    understand what it’s doing. (Initial assumption)

7.  [i:quick-webserver] It should be possible to write a “hello world”
    HTTP server on one line. (Initial assumption, [i:real-programming],
    [i:shell])

8.  [i:live-preview] It should be possible to preview the evaluation of
    any well-formed expression without causing side-effects. (Initial
    assumption, [i:shell], [i:ergonomic-limit], [i:trivial-debugging])

9.  [i:not-slow] xh should never cause a dealbreaking performance
    problem. (Initial assumption, [i:real-programming],
    [i:ergonomic-limit])

10. [i:unreliable-connections] Connections between machines may die at
    any time, and remain down for arbitrarily long. xh must never become
    unresponsive when this happens, and any data coming from those
    machines should block until it is available again (i.e. xh’s
    behavior should be invariant with connection failures). (Initial
    assumption, [i:real-programming], [i:shell],
    [i:distributed-computation])

11. [i:trivial-debugging] Debugging should require little or no effort;
    all error cases should be trivially obvious. (Initial assumption,
    [i:real-programming], [i:distributed-computation],
    [i:ergonomic-limit])

12. [i:trivial-database] An xh instance should trivially function as a
    database; there should be no distinction between data in memory and
    data on disk. (Initial assumption, [i:real-programming],
    [i:ergonomic-limit], [i:trivial-debugging], [i:no-oome],
    [i:not-slow])

13. [i:universal-prediction] xh should use every keystroke to
    build/refine a model it uses to predict future keystrokes and
    commands. ([i:ergonomic-limit])

14. [i:forgetful-history] The likelihood that xh forgets anything from
    your command history should be inversely proportional to the amount
    of effort required to retype/recreate it. ([i:ergonomic-limit],
    [i:universal-prediction])

15. [i:locally-anonymous] xh must provide a way to accept input and
    execute commands without updating its prediction model.
    ([i:security])

16. [i:http-client] xh should be able to submit an encrypted version of
    its current state to HTTP services like Github gists or pastebin.
    ([i:ergonomic-limit], [i:security], [i:unreliable-connections],
    [i:transparent-self-install], [i:www-initialization])

17. [i:feel-like-shell] xh-script needs to feel like a regular shell for
    most purposes. ([i:shell])

18. [i:imperative] xh-script should be fundamentally imperative.
    ([i:real-programming], [i:shell], [i:feel-like-shell])

19. [i:no-oome] xh must never run out of memory or swap pages to disk,
    regardless of what you tell it to do. ([i:real-programming],
    [i:shell], [i:not-slow], [i:ergonomic-limit])

20. [i:nonblocking] xh must respond to every keystroke within 20ms;
    therefore, SSH must be used only for nonblocking RPC requests
    (i.e. the shell always runs locally). ([i:shell], [i:not-slow],
    [i:ergonomic-limit])

21. [i:remote-resources] All resources, local and remote, must be
    uniformly accessible; i.e. autocomplete, filename substitution, etc,
    must all just work (up to random access, which is impossible without
    FUSE or similar). ([i:shell], [i:distributed-computation],
    [i:ergonomic-limit])

22. [i:prefix-notation] xh-script uses prefix notation. ([i:shell])

23. [i:quasiquoting] xh-script quasiquotes values by default.
    ([i:shell])

24. [i:unquoting] xh-script defines an unquote operator. ([i:shell],
    [i:quasiquoting])

25. [i:real-data-structures] The xh runtime provides real,
    garbage-collected data structures. ([i:real-programming])

26. [i:data-structures-can-be-quoted] Every xh data structure has a
    quoted form. ([i:real-data-structures], [i:shell],
    [i:trivial-debugging], [i:live-preview])

27. [i:data-structures-can-be-serialized] Every xh data structure can be
    losslessly serialized. ([i:shell], [i:distributed-computation],
    [i:trivial-database], [i:data-structures-can-be-quoted],
    [i:settings-contain-variable-definitions], [i:image-merging])

28. [i:data-structures-are-immutable] Data structures have no identity
    and therefore are immutable. ([i:distributed-computation],
    [i:data-structures-can-be-serialized])

29. [i:opaque-resources] xh-script must have access to machine-specific
    opaque resources like PIDs and file handles. ([i:real-programming],
    [i:shell])

30. [i:mutable-symbol-table] Each xh instance should implement a mutable
    symbol table with weak reference support, subject to
    semi-conservative distributed garbage collection.
    ([i:data-structures-are-immutable], [i:opaque-resources],
    [i:no-oome], [i:xh-heap])

31. [i:state-ownership] Every piece of mutable state, including symbol
    tables, must have at most one authoritative copy (mutable state
    within xh is managed by a CP system). ([i:unreliable-connections],
    [i:opaque-resources], [i:mutable-symbol-table], [i:thread-mobility])

32. [i:checkpointing] An xh instance should be able to save checkpoints
    of itself in case of failure. If you do this, xh becomes an AP
    system. ([i:unreliable-connections], [i:state-ownership])

33. [i:lazy-evaluation] xh’s evaluator must support some kind of
    laziness. ([i:real-programming], [i:no-oome], [i:remote-resources],
    [i:not-slow])

34. [i:laziness-serializable] Lazy values must have well-defined quoted
    forms and be losslessly serializable.
    ([i:data-structures-can-be-quoted],
    [i:data-structures-can-be-serialized], [i:lazy-evaluation],
    [i:thread-mobility], [i:xh-heap])

35. [i:lazy-introspection] All lazy values must be subject to
    introspection to identify why they haven’t been realized.
    ([i:trivial-debugging], [i:not-slow], [i:unreliable-connections],
    [i:nonblocking], [i:lazy-evaluation], [i:priority-scheduler])

36. [i:abstract-evaluation] xh must be able to partially evaluate
    expressions that contain unknown quantities. ([i:live-preview],
    [i:lazy-evaluation], [i:lazy-introspection],
    [i:laziness-serializable])

37. [i:code-as-data] xh-script code should be a reasonable data storage
    format. ([i:shell], [i:abstract-evaluation])

38. [i:parse-self] xh-script must contain a library to parse itself.
    ([i:code-as-data])

39. [i:homoiconic] xh-script must be homoiconic. ([i:code-as-data],
    [i:parse-self], [i:self-hosting-runtime],
    [i:representational-abstraction])

40. [i:compile-to-c] xh should be able to compile any function to C,
    compile it if the host has a C compiler, and transparently migrate
    execution into this process. ([i:real-programming],
    [i:thread-mobility], [i:not-slow])

41. [i:compile-to-perl] xh should be able to compile any function to
    Perl rather than interpreting its execution. ([i:real-programming],
    [i:no-root-access], [i:not-slow])

42. [i:compile-to-js] xh should be able to compile any function to
    Javascript so that browser sessions can transparently become
    computing nodes. ([i:real-programming], [i:distributed-computation],
    [i:not-slow])

43. [i:self-hosting-runtime] xh should follow a bootstrapped
    self-hosting runtime model. ([i:compile-to-c], [i:compile-to-perl],
    [i:compile-to-js] [i:representational-abstraction])

44. [i:tracing-jit] xh-script should be executed by a profiling/tracing
    dynamic compiler that automatically compiles certain pieces of code
    to alternative forms like Perl or C. ([i:not-slow])

45. [i:representational-abstraction] The xh compiler should optimize
    data structure representations for the backend being targeted.
    ([i:not-slow], [i:thread-mobility], [i:tracing-jit])

46. [i:xh-heap] xh needs to implement its own heap and memory manager,
    and swap values to disk without blocking. ([i:real-programming],
    [i:no-oome], [i:trivial-database], [i:written-in-perl])

47. [i:xh-threading] xh should implement its own threading model to
    accommodate blocked IO requests. ([i:shell],
    [i:distributed-computation], [i:quick-webserver],
    [i:lazy-evaluation], [i:xh-heap])

48. [i:priority-scheduler] xh threads should be subject to scheduling
    that reflects the user’s priorities. ([i:shell],
    [i:distributed-computation], [i:lazy-evaluation], [i:xh-threading])

49. [i:thread-mobility] Running threads must be transparently portable
    between machines and compiled backends.
    ([i:distributed-computation], [i:xh-threading], [i:tracing-jit],
    [i:representational-abstraction], [i:priority-scheduler])

50. [i:reference-locality] All machine-specific references must encode
    the machine for which they are defined. ([i:opaque-resources],
    [i:thread-mobility])

51. [i:unique-ids] Every xh instance must have a unique ID, ideally one
    that can be typed easily. ([i:ergonomic-limit],
    [i:reference-locality])

52. [i:transparent-self-install] xh needs to be able to self-install on
    remote machines with no intervention (assuming you have a
    passwordless SSH connection). ([i:distributed-computation],
    [i:no-root-access])

53. [i:www-initialization] You should be able to upload your xh image to
    a website and then install it with a command like
    this: `curl me.com/xh | perl`. ([i:distributed-computation],
    [i:no-root-access])

54. [i:self-modifying-image] Your settings should be present as soon as
    you download your image, so the image must be self-modifying and
    contain your settings. ([i:distributed-computation],
    [i:ergonomic-limit], [i:universal-prediction],
    [i:transparent-self-install], [i:www-initialization])

55. [i:settings-contain-variable-definitions] Your settings should be
    able to contain any value you can create from the REPL (with the
    caveat that some are defined only with respect to a specific
    machine). ([i:real-programming], [i:shell], [i:ergonomic-limit],
    [i:real-data-structures], [i:www-initialization])

56. [i:written-in-perl] xh should probably be written in Perl 5.
    ([i:distributed-computation], [i:no-root-access],
    [i:transparent-self-install], [i:www-initialization],
    [i:self-modifying-image])

57. [i:no-perl-modules] xh can’t have any dependencies on CPAN modules,
    or anything else that isn’t in the core library.
    ([i:distributed-computation], [i:no-root-access],
    [i:transparent-self-install])

58. [i:image-merging] It should be possible to address variables defined
    within xh images (as files or network locations).
    ([i:self-modifying-image],
    [i:settings-contain-variable-definitions])

59. [i:rpc-via-ssh] xh’s RPC protocol must work via stdin/out
    communication over an SSH channel to a remote instance of itself.
    ([i:distributed-computation], [i:security],
    [i:transparent-self-install], [i:nonblocking], [i:remote-resources])

60. [i:rpc-multiplexing] xh’s RPC protocol must support request
    multiplexing. ([i:distributed-computation], [i:not-slow],
    [i:nonblocking], [i:remote-resources], [i:lazy-evaluation],
    [i:rpc-via-ssh])

61. [i:xh-self-connection] Two xh servers on the same host should
    automatically connect to each other. This allows a server-only
    machine to act as a VPN. ([i:distributed-computation],
    [i:no-root-access], [i:rpc-via-ssh], [i:transitive-topology])

62. [i:domain-sockets] xh should create a UNIX domain socket to listen
    for other same-machine instances. ([i:security],
    [i:xh-self-connection])

63. [i:transitive-topology] xh’s network topology should forward
    requests transitively. ([i:distributed-computation],
    [i:no-root-access], [i:rpc-via-ssh])

64. [i:network-routing] xh should implement a network optimizer that
    responds to observations it makes about latency and throughput.
    ([i:not-slow], [i:rpc-via-ssh], [i:transitive-topology])

self-replication {#chp:self-replication}
================

    #!/usr/bin/env perl
    BEGIN {eval(our $xh_bootstrap = q{
    # xh | https://github.com/spencertipping/xh
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

reader {#chp:reader}
======

xh-script has a reader just like Lisp does. This makes it easier to
factor the runtime: the reader is invariant with the semantics of the
language under any given interpreter/compiler. For simplicity, this
reader does not stream its output. Instead, it emits a full quoted data
structure hierarchy in OO format.

    BEGIN {xh::defmodule('xh::v.pl', <<'_')}
    use parent qw/Exporter/;
    our @EXPORT = qw/read/;

    sub new {
      my ($class, $type, $tag, @values) = @_;
      bless [$type, $tag, @values], $class;
    }
    sub parse {
      my @return_values;
      my @context = (\@return_values);

      while ($_[0] =~ /\G (?: \s* | #.*)*
                          (?: (?<tag> [^\s()\[\]{}"']+)?
                              (?: (?<listopen>   \()
                                | (?<vectoropen> \[)
                                | (?<mapopen>    \{)
                                | "(?<dstring>   (?:[^"]*|\\[\s\S]))"
                                | '(?<sstring>   (?:[^']*|\\[\s\S]))')
                            | (?<word>        (?: [^\s()\[\]{}'"] | \\.)+)
                            | (?<listclose>   \))
                            | (?<vectorclose> \])
                            | (?<mapclose>    \}))/xmg) {
        my $opener = $+{listopen} // $+{vectoropen} // $+{mapopen};
        if (defined $+{word}) {
          push @{$context[-1]}, $+{word};
        } elsif (defined $+{dstring}) {
          push @{$context[-1]}, xh::v->new('"', $+{tag}, $+{dstring});
        } elsif (defined $+{sstring}) {
          push @{$context[-1]}, xh::v->new("'", $+{tag}, $+{sstring});
        } elsif (defined $opener) {
          my $new_container = xh::v->new($opener, $+{tag});
          push @{$context[-1]}, $new_container;
          push @context, $new_container;
        } elsif (defined($+{listclose} // $+{vectorclose} // $+{mapclose})) {
          my $popped = pop @context;
          push @{$context[-1]}, $popped;
        }
      }
      @return_values;
    }
    _ 

    use parent qw/Exporter/;
    our @EXPORT = qw/read/;

    sub new {
      my ($class, $type, $tag, @values) = @_;
      bless [$type, $tag, @values], $class;
    } 

    sub parse {
      my @return_values;
      my @context = (\@return_values);

      while ($_[0] =~ /\G (?: \s* | #.*)*
                          (?: (?<tag> [^\s()\[\]{}"']+)?
                              (?: (?<listopen>   \()
                                | (?<vectoropen> \[)
                                | (?<mapopen>    \{)
                                | "(?<dstring>   (?:[^"]*|\\[\s\S]))"
                                | '(?<sstring>   (?:[^']*|\\[\s\S]))')
                            | (?<word>        (?: [^\s()\[\]{}'"] | \\.)+)
                            | (?<listclose>   \))
                            | (?<vectorclose> \])
                            | (?<mapclose>    \}))/xmg) {
        my $opener = $+{listopen} // $+{vectoropen} // $+{mapopen};
        if (defined $+{word}) {
          push @{$context[-1]}, $+{word};
        } elsif (defined $+{dstring}) {
          push @{$context[-1]}, xh::v->new('"', $+{tag}, $+{dstring});
        } elsif (defined $+{sstring}) {
          push @{$context[-1]}, xh::v->new("'", $+{tag}, $+{sstring});
        } elsif (defined $opener) {
          my $new_container = xh::v->new($opener, $+{tag});
          push @{$context[-1]}, $new_container;
          push @context, $new_container;
        } elsif (defined($+{listclose} // $+{vectorclose} // $+{mapclose})) {
          my $popped = pop @context;
          push @{$context[-1]}, $popped;
        }
      }
      @return_values;
    } 
