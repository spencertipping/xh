BEGIN {xh::defmodule('xh::math.pl', <<'_')}
sub binary_to_nary {
  my ($f, $zero) = @_;
  sub {
    my ($bindings, $x, @args) = @_;
    return $zero unless defined $x;
    return &$f($zero, $x) unless @args;
    $x = &$f($x, $_) for @args;
    $x;
  };
}

xh::globals::defglobals
  "math$_" => binary_to_nary(eval "sub {\$_[0] $_ \$_[1]}", /^[*\/]$/)
for qw[+ - * / & | ! < > << >>];
_
