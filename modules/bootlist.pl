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

  my @words = xh::v::parse_words $subscript;
  return [map expand_subscript($_, $n), @words] if @words > 1;

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
  return join ' ',
         map xh::v::quote_as_word(dereference_one $_, $boxed_list),
             @$subscript if ref $subscript eq 'ARRAY';

  # Normal numeric lookup, with empty string for out-of-bounds
  return ''                             if $subscript =~ /^-/;
  return $$boxed_list[$subscript] // '' if $subscript =~ /^\d+/;

  # Hashtable lookup maybe?
  if ($subscript =~ s/^@//) {
    # In this case the boxed list should contain at least words, and
    # probably whole lines. We word-parse each entry looking for the
    # first subscript hit.
    $subscript = xh::v::unbox $subscript;
    for my $x (@$boxed_list) {
      my @words = xh::v::parse_words $x;
      return xh::v::quote_as_word $x if $words[0] eq $subscript;
    }
    return '';
  } else {
    die "unrecognized subscript form: $subscript";
  }
}

sub dereference {
  my ($subscript, $boxed_list) = @_;
  dereference_one expand_subscript($subscript, scalar(@$boxed_list)),
                  $boxed_list;
}

sub index_lines {dereference $_[1], [xh::v::parse_lines $_[2]]}
sub index_words {dereference $_[1], [xh::v::parse_words $_[2]]}
sub index_path  {dereference $_[1], [xh::v::parse_path  $_[2]]}
sub index_bytes {dereference $_[1], [map ord, split //, $_[2]]}

xh::globals::defglobals "'"  => \&index_lines,
                        "@"  => \&index_words,
                        ":"  => \&index_path,
                        "\"" => \&index_bytes;
_
