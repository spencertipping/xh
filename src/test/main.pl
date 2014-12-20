BEGIN {xh::defmodule('xh::main.pl', <<'_')}
sub main {
  # TESTCODE (FIXME if in a real image)
  print ::xh::image if grep /^--recompile/, @ARGV;

  if (grep /^--repl/, @ARGV) {
    print STDERR "> ";
    while (<STDIN>) {
      chomp;
      if (length) {
        eval {
          my ($parsed) = xh::corescript::parse $_;
          my $result =
            eval {xh::corescript::evaluate($parsed,
                                           $xh::corescript::global_bindings,
                                           2)};
          print $@ ? "! $@\n"
                   : "= " . $result->str . "\n";
        };
        print "! $@\n" if $@;
      }
      print STDERR "> ";
    }
  }
}
_
