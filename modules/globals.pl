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

sub default_binding_stack {[{def => \&def, echo => \&echo}]}
_
