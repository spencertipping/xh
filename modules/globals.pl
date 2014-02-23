BEGIN {xh::defmodule('xh::globals.pl', <<'_')}
sub def {
  my ($binding_stack, %args) = @_;
  $$binding_stack[-1]{$_} = $args{$_} for keys %args;
  join ' ', keys %args;
}

sub echo {
  my ($binding_stack, @args) = @_;
  join ' ', @args;
}

sub comment       {''}
sub print_from_xh {print STDERR join(' ', @_[1 .. $#_]), "\n"}

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

# Create an interpreter instance that lets us interpret modules written in
# XH-script.
our $globals = [{def   => \&def,
                 echo  => \&echo,
                 print => \&print_from_xh,
                 perl  => \&perl_eval,
                 '#'   => \&comment,
                 '#==' => \&assert_eq_macro}];

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
