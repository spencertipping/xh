BEGIN {xh::defmodule('xh::bootlist.pl', <<'_')}
sub wrap_negative {
  my ($i, $n) = @_;
  return undef unless length $i;
  return $n + $i if $i < 0;
  $i;
}

sub flexible_range {
  my ($lower, $upper) = @_;
  return reverse $upper .. $lower if $upper < $lower;
  $lower .. $upper;
}

sub expand_subscript;
sub expand_subscript {
  my ($subscript, $n) = @_;

  return [map expand_subscript($_, $n),
              xh::v::split_words xh::v::unbox $subscript]
  if $subscript =~ /^\{/;

  return [flexible_range wrap_negative($1, $n) // 0,
                         wrap_negative($2, $n) // $n - 1]
  if $subscript =~ /^(-?\d*):(-?\d*)$/;

  return wrap_negative $subscript, $n if $subscript =~ /^-/;
  $subscript;
}

sub dereference_one;
sub dereference_one {
  my ($subscript, $boxed_list) = @_;

  # List homomorphism of subscripts
  return xh::v::quote_default
         join ' ', map dereference_one($_, $boxed_list),
                       @$subscript if ref $subscript eq 'ARRAY';

  # Normal numeric lookup, with empty string for out-of-bounds
  return xh::v::quote_as_word '' if $subscript =~ /^-/;
  return $$boxed_list[$1] // ''  if $subscript =~ /^(\d+)!$/;

  return xh::v::quote_as_word $$boxed_list[$subscript] // ''
  if $subscript =~ /^\d+$/;

  if ($subscript =~ s/^\^//) {
    # In this case the boxed list should contain at least words, and
    # probably whole lines. We word-parse each entry looking for the
    # first subscript hit.
    $subscript = xh::v::unbox $subscript;
    for my $x (@$boxed_list) {
      my @words = xh::v::parse_words $x;
      return xh::v::quote_as_word $x if $words[0] eq $subscript;
    }
    '';
  } elsif ($subscript eq '#') {
    scalar @$boxed_list;
  } else {
    die "unrecognized subscript form: $subscript";
  }
}

sub dereference;
sub dereference {
  my ($subscript, $boxed_list) = @_;
  $subscript = xh::v::quote_as_word $subscript;
  dereference_one expand_subscript($subscript, scalar(@$boxed_list)),
                  $boxed_list;
}

sub index_lines {dereference $_[1], [xh::v::parse_lines $_[2]]}
sub index_words {dereference $_[1], [xh::v::parse_words $_[2]]}
sub index_path  {dereference $_[1], [xh::v::parse_path  $_[2]]}
sub index_bytes {dereference $_[1], [map ord, split //, $_[2]]}

sub outer_lines {dereference $_[1], [xh::v::split_lines $_[2]]}
sub outer_words {dereference $_[1], [xh::v::split_words $_[2]]}
sub outer_path  {dereference $_[1], [xh::v::split_path  $_[2]]}

sub update {
  my ($subscript, $replacement, $join, $quote, $boxed_list) = @_;
  my $expanded = expand_subscript $subscript, scalar @$boxed_list;

  die "can't use list subscript for update: $subscript"
  if ref $expanded eq 'ARRAY';

  my $associative = $expanded =~ s/^\^//;

  my @result;
  for (my $i = 0; $i < @$boxed_list; ++$i) {
    my ($k) = xh::v::parse_words $$boxed_list[$i];
    push @result, ($associative ? $expanded eq $k : $expanded eq $i)
                  ? $replacement
                  : $$boxed_list[$i];
  }

  if ($expanded =~ /^\d+$/ and $expanded > @$boxed_list) {
    # It could be that we need to add something to the end.
    for (my $i = @$boxed_list; $i < $expanded; ++$i) {
      push @result, '';
    }
    push @result, $replacement;
  }

  xh::v::quote_as_word join $join, map &$quote($_), @result;
}

sub update_lines {update @_[1, 2], "\n", \&xh::v::quote_as_line,
                         [xh::v::parse_lines $_[3]]}

sub update_words {update @_[1, 2], ' ',  \&xh::v::quote_as_word,
                         [xh::v::parse_words $_[3]]}

sub update_path  {update @_[1, 2], '',   \&xh::v::quote_as_path,
                         [xh::v::parse_path  $_[3]]}

sub update_byte  {update @_[1, 2], '',   sub {$_[0]},
                         [map ord, split //, $_[3]]}

xh::globals::defglobals "'"  => \&index_lines,  "'="  => \&update_lines,
                        "@"  => \&index_words,  "@="  => \&update_words,
                        ":"  => \&index_path,   ":="  => \&update_path,
                        "\"" => \&index_bytes,  "\"=" => \&update_byte,

                        "'%" => \&outer_lines,
                        "@%" => \&outer_words,
                        ":%" => \&outer_path;

# Conversions between list types.
sub list_to_list_fn {
  my ($join, $quote, $parse) = @_;
  sub {xh::v::quote_as_word
       join $join, map &$quote($_), map &$parse($_), @_[1 .. $#_]};
}

my %joins   = ("'" => "\n", "@" => ' ', ":" => '/', "\"" => '');
my %quotes  = ("'"  => \&xh::v::quote_as_line,
               "@"  => \&xh::v::quote_as_word,
               ":"  => \&xh::v::quote_as_path,
               "\"" => sub {chr $_[0]});

my %parsers = ("'"  => \&xh::v::parse_lines,
               "@"  => \&xh::v::parse_words,
               ":"  => \&xh::v::parse_path,
               "\"" => sub {map ord, split //, $_[0]});

for my $k1 (keys %parsers) {
  for my $k2 (keys %parsers) {
    next if $k1 eq $k2;
    my $fn = list_to_list_fn($joins{$k2}, $quotes{$k2}, $parsers{$k1});
    xh::globals::defglobals "$k1$k2" => $fn;
  }
}

sub explode {xh::v::unbox $_[1]}
xh::globals::defglobals '!' => \&explode;
_
