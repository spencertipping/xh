BEGIN {xh::defmodule('xh::globals.pl', <<'_')}
sub def {
  my ($binding_stack, $n, %args) = @_;
  $$binding_stack[-$n]{$_} = $args{$_} for keys %args;
  join ' ', keys %args;
}

sub local_def {def $_[0], 1, @_[1..$#_]}

sub echo {
  my ($binding_stack, @args) = @_;
  join ' ', @args;
}

sub comment       {''}
sub print_from_xh {print STDERR join(' ', @_[1 .. $#_]), "\n"; ''}

sub perl_eval {
  my $result = eval $_[1];
  die "$@ while evaluating $_[1]" if $@;
  $result;
}

sub assert_eq_macro {
  my ($binding_stack, $lhs, $rhs) = @_;

  # We should get the same result by evaluating the LHS and RHS; otherwise
  # expand into a print statement describing the error.
  my $expanded_lhs = xh::e::interpolate $binding_stack, $lhs;
  my $expanded_rhs = xh::e::interpolate $binding_stack, $rhs;

  $expanded_lhs eq $expanded_rhs
    ? ''
    : 'print ' . xh::v::quote_default("$lhs (-> $expanded_lhs)")
               . ' != '
               . xh::v::quote_default("$rhs (-> $expanded_rhs)");
}

sub xh_if {
  my ($binding_stack, $cond, $then, $else) = @_;
  xh::e::evaluate $binding_stack, length $cond ? $then : $else;
}

sub xh_while {
  my ($binding_stack, $cond, $body) = @_;
  my $result;
  $result = xh::e::evaluate $binding_stack, $body
    while length xh::e::evaluate $binding_stack, $cond;
  $result;
}

sub xh_not {
  my ($binding_stack, $v) = @_;
  length $v ? '' : '{}';
}

sub xh_eq {
  my ($binding_stack, $x, $y) = @_;
  $x eq $y ? "{" . xh::v::quote_as_word($x) . "}" : '';
}

sub xh_matches {
  # NOTE: leaky abstraction (real xh regexps won't support all of the perl
  # extensions)
  my ($binding_stack, $pattern, $s) = @_;
  $s =~ /$pattern/ ? "{" . xh::v::quote_as_word($s) . "}" : '';
}

sub escalate {
  my ($binding_stack, $levels, $body) = @_;
  xh::e::evaluate xh::e::truncated_stack($binding_stack, -($levels + 1)),
                  $body;
}

# Create an interpreter instance that lets us interpret modules written in
# XH-script.
our $globals = [{def    => \&local_def,
                 '^def' => \&def,
                 '^'    => \&escalate,
                 echo   => \&echo,
                 print  => \&print_from_xh,
                 perl   => \&perl_eval,
                 if     => \&xh_if,
                 while  => \&xh_while,
                 not    => \&xh_not,
                 '=='   => \&xh_eq,
                 '=~'   => \&xh_matches,
                 '#'    => \&comment,
                 '#=='  => \&assert_eq_macro}];

sub defglobals {
  my %vals = @_;
  $$globals[0]{$_} = $vals{$_} for keys %vals;
}

$xh::compilers{xh} = sub {
  my ($module_name, $code) = @_;
  eval {xh::e::evaluate $globals, $code};
  die "error running $module_name: $@" if $@;
}
_
