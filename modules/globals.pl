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

sub comment {''}

sub print_from_xh {print STDERR join(' ', @_[1 .. $#_]), "\n"}

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

sub default_binding_stack {[{def         => \&def,
                             echo        => \&echo,
                             '#'         => \&comment,
                             print       => \&print_from_xh,
                             '%assert==' => \&assert_eq_macro}]}

# Create an interpreter instance that lets us interpret modules written in
# XH-script.
our $globals = default_binding_stack;
$xh::compilers{xh} = sub {
  my ($module_name, $code) = @_;
  eval {xh::e::evaluate $globals, $code};
  die "error running $module_name: $@" if $@;
}
_
