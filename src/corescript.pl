BEGIN {xh::defmodule('xh::corescript.pl', <<'_')}
sub parse;
sub evaluate;

sub into_hash {
  my %result;
  for (my $i = 0; $i < @_; $i += 2) {
    my $k = ref($_[$i]) ? $_[$i]->str : $_[$i];
    $result{$k} = $_[$i + 1];
  }
  \%result;
}

sub xh::corescript::literal::new  {my ($c, $x) = @_; bless \$x, $c}
sub xh::corescript::var::new      {my ($c, $x) = @_; bless \$x, $c}
sub xh::corescript::list::new     {bless [@_[1..$#_]], $_[0]}
sub xh::corescript::array::new    {bless [@_[1..$#_]], $_[0]}
sub xh::corescript::hash::new     {bless into_hash(@_[1..$#_]), $_[0]}
sub xh::corescript::bindings::new {bless [$_[1], $_[2]], $_[0]}
sub xh::corescript::fn::new       {bless [$_[1], $_[2]], $_[0]}
sub xh::corescript::native::new   {bless [$_[1], $_[2]], $_[0]}
sub xh::corescript::delay::new    {bless [@_[1..$#_]], $_[0]}

sub xh::corescript::literal::concrete  {1}
sub xh::corescript::var::concrete      {0}
sub xh::corescript::list::concrete     {0}
sub xh::corescript::array::concrete    {1}
sub xh::corescript::hash::concrete     {1}
sub xh::corescript::bindings::concrete {1}
sub xh::corescript::fn::concrete       {1}
sub xh::corescript::native::concrete   {1}
sub xh::corescript::delay::concrete    {0}

sub xh::corescript::literal::true  { length ${$_[0]} && ${$_[0]} ne '0' }
sub xh::corescript::var::true      {1}
sub xh::corescript::list::true     {1}
sub xh::corescript::array::true    {1}
sub xh::corescript::hash::true     {1}
sub xh::corescript::bindings::true {1}
sub xh::corescript::fn::true       {1}
sub xh::corescript::native::true   {1}
sub xh::corescript::delay::true    {1}

sub strhash {
  my $h = 0;
  $h = $h * 33 ^ ord for split //, $_[0];
  $h;
}

sub arrayhash {
  my $h = 0;
  $h = $h * 65 ^ (ref($_) ? $_->hashcode : strhash($_)) for @_;
  $h;
}

sub hashhash {
  my @ks = sort keys %{$_[0]};
  arrayhash(@ks) ^ arrayhash(@{$_[0]}{@ks});
}

sub xh::corescript::literal::hashcode  { strhash ${$_[0]} }
sub xh::corescript::var::hashcode      { ~strhash ${$_[0]} }
sub xh::corescript::list::hashcode     { arrayhash @{$_[0]} }
sub xh::corescript::array::hashcode    { 1 + arrayhash @{$_[0]} }
sub xh::corescript::hash::hashcode     { hashhash $_[0] }

sub xh::corescript::bindings::hashcode {
  (defined ${$_[0]}[0] ? $$_[0]->hashcode : 0) ^ hashhash ${$_[0]}[1];
}

sub xh::corescript::fn::hashcode     { strhash(${$_[0]}[0])
                                     ^ ${$_[0]}[1]->hashcode }
sub xh::corescript::native::hashcode { 65 * strhash(${$_[0]}[0]) }
sub xh::corescript::delay::hashcode  { ${$_[0]}[0]->hashcode
                                     ^ arrayhash @{$_[0]}[1..$#{$_[0]}] }

# shorthands
use constant literal  => 'xh::corescript::literal';
use constant var      => 'xh::corescript::var';
use constant list     => 'xh::corescript::list';
use constant hash     => 'xh::corescript::hash';
use constant array    => 'xh::corescript::array';
use constant bindings => 'xh::corescript::bindings';
use constant fn       => 'xh::corescript::fn';
use constant native   => 'xh::corescript::native';
use constant delay    => 'xh::corescript::delay';

use constant REF_IDS => 0;

our $deadline = 0;
our %globals;
our $global_bindings = bindings->new(undef, \%globals);

our $apply = literal->new('apply');

sub quote_call {
  my ($f, $xs) = @_;
  ref($xs) eq array ? list->new($f, @$xs)
                    : list->new($apply, $f, $xs);
}

sub ref_id {
  return '' unless REF_IDS and time > $deadline;
  ($_[0] =~ s/^.*\(0x..(...).*$/$1/r) . ':';
}

sub xh::corescript::literal::str {
  my $s = ${$_[0]};
  ref_id($_[0]) .
  ($s =~ /['()[]{},\s]|^$/ ? "'" . (${$_[0]} =~ s/'/\\'/gr) . "'"
                           : $s);
}

sub xh::corescript::var::str   { ref_id($_[0]) . "\$${$_[0]}" }
sub xh::corescript::list::str  { ref_id($_[0]) .
                                 '(' . join(' ', map $_->str, @{$_[0]})
                                     . ')' }

sub xh::corescript::array::str { ref_id($_[0]) .
                                 '[' . join(' ', map $_->str, @{$_[0]})
                                     . ']' }

sub xh::corescript::hash::str {
  ref_id($_[0]) .
  '{' . join(', ', map $_ . ' ' . ${$_[0]}{$_}->str, sort keys %{$_[0]})
      . '}';
}

sub xh::corescript::bindings::str {
  my ($self) = @_;
  my ($parent, $h) = @$self;
  ref_id($_[0]) .
  '(bindings ' . ($parent ? $parent->str : "''")
         . ' ' . join(', ', map "$_ " . $$h{$_}->str, sort keys %$h) . ')';
}

sub xh::corescript::fn::str {
  my ($self) = @_;
  my ($formal, $body) = @$self;
  ref_id($_[0]) . "(fn* $formal " . $body->str . ')';
}

sub xh::corescript::native::str {
  my ($self) = @_;
  ref_id($_[0]) . "%$$self[0]";
}

sub xh::corescript::delay::str {
  my ($self) = @_;
  ref_id($_[0]) . '(delay ' . join(' ', map $_->str, @$self) . ')';
}

sub xh::corescript::bindings::get {
  my ($self, $x) = @_;
  my ($parent, $h) = @$self;
  return undef unless ref($x) eq literal or ref($x) eq var;
  my $binding = $$h{$x->name} // ($parent && $parent->get($x));
  ref($binding) ? $binding : undef;
}

sub xh::corescript::bindings::contains {
  my ($self, $x) = @_;
  my ($parent, $h) = @$self;
  exists($$h{$x->name}) || $parent && $parent->contains($x);
}

sub xh::corescript::hash::get {
  my ($self, $x) = @_;
  $$self{$x->str};
}

sub xh::corescript::hash::contains {
  my ($self, $x) = @_;
  exists $$self{$x->str};
}

sub xh::corescript::array::get {
  my ($self, $x) = @_;
  return undef unless ref($x) eq literal;
  my $i = $x->name;
  die "array index must be number (got $i instead)" unless $i eq $i + 0;
  $$self[$i];
}

*xh::corescript::list::get = *xh::corescript::array::get;

sub xh::corescript::literal::get {
  my ($self, $x) = @_;
  return undef unless ref($x) eq literal;
  my $i = $x->name;
  die "literal index must be number (got $i instead)" unless $i eq $i + 0;
  literal->new(ord substr $$self, $i, 1);
}

sub xh::corescript::var::name     { ${$_[0]} }
sub xh::corescript::literal::name { ${$_[0]} }
sub xh::corescript::native::name  { ${$_[0]}[0] }

sub xh::corescript::literal::eval  { $_[0] }
sub xh::corescript::native::eval   { $_[0] }
sub xh::corescript::bindings::eval { $_[0] }

sub xh::corescript::var::eval { my ($self, $bindings) = @_;
                                $bindings->get($self) // $self }

sub xh::corescript::list::eval {
  my ($self, $bindings) = @_;
  my ($f, @xs) = @$self;
  my $r = $f->invoke($bindings, array->new(@xs));
  return $r if defined $r;
  my @e = map $_->eval($bindings), @$self;
  $e[0] = $bindings->get($e[0]) // $e[0]
    if ref($e[0]) eq literal or ref($e[0]) eq var;
  $$self[$_] eq $e[$_] or return list->new(@e) for 0..$#e;
  $self;
}

sub xh::corescript::array::eval {
  my ($self, $bindings) = @_;
  my @e = map $_->eval($bindings), @$self;
  $$self[$_] eq $e[$_] or return array->new(@e) for 0..$#e;
  $self;
}

sub xh::corescript::hash::eval {
  my ($self, $bindings) = @_;
  my %new;
  my $changed = 0;
  for (keys %$self) {
    my $v0 = $$self{$_};
    my $v  = $new{$_} = $v0->eval($bindings);
    last if $changed = $v ne $v0;
  }
  if ($changed) {
    $new{$_} //= $$self{$_}->eval($bindings) for keys %$self;
    hash->new(%new);
  } else {
    $self;
  }
}

sub xh::corescript::fn::eval {
  my ($self, $bindings) = @_;
  my ($formal, $body) = @$self;
  my $newbody = $body->eval(
    bindings->new($bindings, {$formal => 0}));
  $body eq $newbody ? $self
                    : fn->new($formal, $newbody);
}

sub xh::corescript::delay::eval {
  my ($self, $bindings) = @_;
  my ($values, @body) = @$self;
  for my $x (@$values) {
    if (!$x->concrete && $x eq $x->eval($bindings)) {
      my @e = map $_->eval($bindings), @body;
      $body[$_] eq $e[$_] or return delay->new($values, @e) for 0..$#e;
      return $self;
    }
  }
  list->new(@body)->eval($bindings);
}

sub xh::corescript::var::invoke {
  my ($self, $bindings, $args) = @_;
  my $e = $self->eval($bindings);
  return undef if $e eq $self;
  $e->invoke($bindings, $args);
}

sub xh::corescript::literal::invoke {
  my ($self, $bindings, $args) = @_;
  my $f = $bindings->get($self);
  return undef unless defined $f;
  $f->invoke($bindings, $args);
}

sub xh::corescript::list::invoke {
  my ($self, $bindings, $args) = @_;
  die quote_call($self, $args)->str . ': timeout expired'
    if $deadline and time > $deadline;

  my $evaled = $self->eval($bindings);
  return undef if $self eq $evaled;

  my $result = eval {$evaled->invoke($bindings, $args)};
  my $error = $@;
  if ($error) {
    print STDERR quote_call($self, $args)->str, ': ', $error, "\n";
    die $error;
  } else {
    $result;
  }
}

sub xh::corescript::delay::invoke {
  my ($self, $bindings, $args) = @_;
  die quote_call($self, $args)->str . ': timeout expired'
    if $deadline and time > $deadline;

  my $e = $self->eval($bindings);
  return undef if $e eq $self;
  my $result = eval {$e->invoke($bindings, $args)};
  my $error = $@;
  if ($error) {
    print STDERR quote_call($self, $args)->str, ': ', $error, "\n";
    die $error;
  } else {
    $result;
  }
}

sub xh::corescript::fn::invoke {
  my ($self, $bindings, $args) = @_;
  die quote_call($self, $args)->str . ': timeout expired'
    if $deadline and time > $deadline;

  my ($formal, $body) = @$self;
  my $result = eval {
    $body->eval(bindings->new($global_bindings,
                              {$formal => $args->eval($bindings)}));
  };
  my $error = $@;
  if ($error) {
    print STDERR quote_call($self, $args)->str, ': ', $error, "\n";
    die $error;
  } else {
    $result;
  }
}

sub xh::corescript::native::invoke {
  my ($self, $bindings, $args) = @_;
  die quote_call($self, $args)->str . ': timeout expired'
    if $deadline and time > $deadline;

  my (undef, $f) = @$self;
  $args = $args->eval($bindings);
  my $result = eval {$f->($bindings, @$args)};
  my $error  = $@;
  if ($error) {
    print STDERR quote_call($self, $args)->str, ': ', $error, "\n";
    die $error;
  } else {
    $result;
  }
}

our $y     = literal->new('y');
our $nil   = literal->new('');
our $quote = literal->new('quote');
our $fn    = literal->new('fn*');
our $if    = literal->new('if');

sub bool  { $_[0] ? $y : $nil }
sub quote { list->new($quote, $_[0]) }

our %brackets = (')' => list, ']' => array, '}' => hash);

# defines global natives that may or may not force their arguments
sub defglobal {
  my %bindings = @_;
  $globals{$_} = native->new($_, $bindings{$_}) for keys %bindings;
}

defglobal '==', sub {
  return undef unless $_[1]->concrete and $_[2]->concrete;
  bool($_[1]->str eq $_[2]->str);
};

defglobal apply => sub {
  my ($bindings, $f, @args) = @_;
  my $last = pop @args;
  return undef unless ref($last) eq array;
  $f->invoke($bindings, array->new(@args, @$last))
    // list->new($f, @args, @$last);
};

defglobal array => sub { array->new(@_[1..$#_]) };

defglobal assoc => sub {
  my ($bindings, $h, $k, $v) = @_;
  if (ref($h) eq hash) {
    return undef unless $k->concrete;
    my $result = hash->new(%$h);
    $$result{$k->str} = $v;
    $result;
  } elsif (ref($h) eq array) {
    return undef unless ref($k) eq literal;
    my $result = array->new(@$h);
    $$result[$k->name] = $v;
    $result;
  } else {
    return undef;
  }
};

defglobal bindings => sub {
  my ($bindings, $parent, @xs) = @_;
  my %h;
  for (my $i = 0; $i < @xs; $i += 2) {
    $h{$xs[$i]->name} = $xs[$i + 1];
  }
  bindings->new($parent, \%h);
};

defglobal concrete => sub { bool $_[1]->concrete };
defglobal contains => sub { bool $_[1]->contains($_[2]) };
defglobal count    => sub {
  my ($bindings, $x) = @_;
  ref($x) eq array   ? literal->new(scalar @{$_[1]})
: ref($x) eq literal ? literal->new(length $x->name)
                     : undef;
};

defglobal def => sub {
  my ($bindings, $var, $x) = @_;
  return undef unless ref($var) eq literal;
  $globals{$var->name} = $x;
  $var;
};

defglobal defs => sub { $_[0] };

defglobal delay => sub {
  my ($bindings, $exprs, @body) = @_;
  return undef unless ref($exprs) eq array;
  delay->new($exprs, @body);
};

defglobal do => sub {
  my ($bindings, @body) = @_;
  my $result;
  $result = $_->eval($bindings) for @body;
  $result;
};

defglobal empty => sub {
  return undef unless $_[1]->concrete;
  ref($_[1])->new;
};

defglobal 'fn*' => sub {
  my ($bindings, $formal, $body) = @_;
  $formal = $formal->eval($bindings);
  return undef unless ref($formal) eq literal;
  fn->new($formal->name, $body->eval($bindings));
};

defglobal get => sub {
  return undef unless $_[1]->concrete and $_[2]->concrete;
  $_[1]->get($_[2]);
};

defglobal globals => sub { $global_bindings };
defglobal hash    => sub { hash->new(@_[1..$#_]) };
defglobal hashcode => sub {
  my ($bindings, $x) = @_;
  my $chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
            . 'abcdefghijklmnopqrstuvwxyz'
            . '0123456789'
            . '+-*&^%@!~`|=_<>,.:;';
  my $n = length $chars;

  my $h = $x->hashcode;
  my $s = '';
  $s .= substr($chars, $h % $n, 1), $h /= $n while $h = int $h;
  literal->new($s);
};

defglobal if => sub {
  my ($bindings, $cond, $then, $else) = @_;
  $cond = $cond->eval($bindings);
  return undef unless $cond->concrete;
  ($cond->true ? $then : $else)->eval($bindings);
};

defglobal into => sub {
  my ($bindings, $to, $from) = @_;
  return undef unless ref($to)   eq array
                  and ref($from) eq array;
  ref($to)->new(@$to, @$from);
};

defglobal iota => sub {
  my ($bindings, $i) = @_;
  return undef unless ref($i) eq literal;
  array->new(map literal->new($_), 0..$i->name-1);
};

defglobal keys => sub {
  ref($_[1]) eq hash  ? array->new(map parse($_), sort keys %{$_[1]})
: ref($_[1]) eq array ? array->new(map literal->new($_), 0..$#{$_[1]})
                      : undef;
};

defglobal len     => sub { literal->new(length $_[1]->name) };
defglobal list    => sub { list->new(@_[1..$#_]) };
defglobal literal => sub { literal->new($_[1]->name) };

defglobal module => sub {
  return undef unless ref($_[1]) eq literal;
  literal->new($xh::modules{$_[1]->name});
};

defglobal modules => sub {
  array->new(map literal->new($_), @xh::module_ordering);
};

defglobal parse => sub {
  return undef unless ref($_[1]) eq literal;
  array->new(parse $_[1]->name);
};

defglobal quote => sub { $_[1] };

defglobal realtype => sub {
  return undef unless $_[1]->concrete;
  literal->new(ref($_[1]) =~ s/^.*:://r);
};

defglobal reduce => sub {
  my ($bindings, $f, $init, $xs) = @_;
  return undef unless ref($xs) eq array;
  for my $x (@$xs) {
    my $args = array->new($init, $x);
    $init = $f->invoke($bindings, $args) // quote_call($f, $args);
  }
  $init;
};

defglobal scope => sub {
  my ($bindings, $b, $v) = @_;
  return undef unless ref($b) eq hash;
  $v->eval(bindings->new($bindings, $b));
};

defglobal slice => sub {
  my ($bindings, $xs, $lower, $upper) = @_;
  $lower //= literal->new(0);
  $upper //= literal->new(ref($xs) eq array   ? $#$xs
                        : ref($xs) eq literal ? length $xs
                                              : return undef);
  return undef unless ref($lower) eq literal
                  and ref($upper) eq literal;
  ref($xs) eq array   ? array->new(@$xs[$lower->name .. $upper->name])
: ref($xs) eq literal ? literal->new(substr $xs->name, $lower,
                                            $upper - $lower)
                      : undef;
};

defglobal str => sub {
  ref($_) eq literal or return undef for @_[1..$#_];
  literal->new(join '', map $_->name, @_[1..$#_]);
};

defglobal type => sub { literal->new(ref($_[1]) =~ s/^.*:://r) };

defglobal unquote => sub {
  my ($bindings, $x, $b) = @_;
  $x->eval($bindings)->eval($b // $bindings);
};

defglobal vals => sub { array->new(map ${$_[1]}{$_}, sort keys %{$_[1]}) };
defglobal var  => sub {
  return undef unless ref($_[1]) eq literal;
  var->new($_[1]->name);
};

# Primitive arithmetic
BEGIN {
  my @float_binops = qw( + - * / % ** < > <= >= == != );
  my @float_unops  = qw( - );
  my @int_binops   = (@float_binops, qw( << >> >>> & | ^ ));
  my @int_unops    = (@float_unops,  qw( ~ ! ));

  eval qq{
    defglobal 'f$_', sub {
      my (\$bindings, \$x, \$y) = \@_;
      return undef unless ref(\$x) eq literal
                      and ref(\$y) eq literal;
      literal->new(\$x->name $_ \$y->name);
    };
  } for @float_binops;

  eval qq{
    defglobal 'fu$_', sub {
      my (\$bindings, \$x) = \@_;
      return undef unless ref(\$x) eq literal;
      literal->new($_ \$x);
    };
  } for @float_unops;

  eval qq{
    defglobal 'i$_', sub {
      my (\$bindings, \$x, \$y) = \@_;
      return undef unless ref(\$x) eq literal
                      and ref(\$y) eq literal;
      literal->new(int(int(\$x->name) $_ int(\$y->name)));
    };
  } for @int_binops;

  eval qq{
    defglobal 'iu$_', sub {
      my (\$bindings, \$x) = \@_;
      return undef unless ref(\$x) eq literal;
      literal->new(int($_ int(\$x->name)));
    };
  } for @int_unops;
}

our %escapes = (n => "\n", r => "\r", t => "\t");
sub parse {
  my @stack = [];
  local $_;
  while ($_[0] =~ / \G (?: (?<comment> \#.*)
                         | (?<ws>      [\s,]+)
                         | '(?<qstr>   (?:[^\\']|\\.)*)'
                         | (?<str>     [^\$'()\[\]{}\s,]+)
                         | (?<var>     \$[^\$'\s()\[\]{},]+)
                         | (?<opener>  [(\[{])
                         | (?<closer>  [)\]}])) /gx) {
    next if $+{comment} || $+{ws};
    my $s = $+{str};
    if (defined $s)      {push @{$stack[-1]}, literal->new($s)}
    elsif ($s = $+{var}) {push @{$stack[-1]}, var->new(substr $s, 1)}
    elsif ($+{opener})   {push @stack, []}
    elsif ($s = $+{closer}) {
      my $last = pop @stack;
      die "too many closers" unless @stack;
      push @{$stack[-1]}, $brackets{$s}->new(@$last);
    } elsif (defined($s = $+{qstr})) {
      push @{$stack[-1]},
           literal->new($s =~ s|\\(.)|$escapes{$1} // $1|egr);
    } else {
      die "unrecognized token: $_";
    }
  }
  die "unbalanced brackets: " . scalar(@stack) . " != 1"
    unless @stack == 1;
  @{$stack[0]};
}

sub evaluate {
  my ($expr, $bindings, $timeout) = @_;
  local $_;
  $deadline = $timeout ? time + $timeout : 0;
  $expr->eval($bindings // $global_bindings);
}

$::xh::compilers{xh} = sub {
  for my $x (parse $_[1]) {
    print STDERR '> ', $x->str, "\n";
    my $e = evaluate($x, $global_bindings, 2);
    print STDERR '= ', $e->str, "\n";
  }
};
_
