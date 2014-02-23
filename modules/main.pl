BEGIN {xh::defmodule('xh::main.pl', <<'_')}
sub main {
  # This keeps xh from blocking on stdin when we ask it to compile itself.
  /^--recompile$/ and return 0 for @ARGV;

  my $list_depth    = 0;
  my $expression    = '';
  my $binding_stack = $xh::globals::globals;

  print "xh\$ ";
  while (my $line = <STDIN>) {
    if (!($list_depth += xh::v::brace_balance $line)) {
      # Collect the line and evaluate everything we have.
      $expression .= $line;

      my $result = eval {xh::e::evaluate $binding_stack, $expression};
      print "error: $@\n" if length $@;
      print "$result\n"   if length $result;

      $expression = '';
      print "xh\$ ";
    } else {
      $expression .= $line;
      print '>   ' . '  ' x $list_depth;
    }
  }
}
_
