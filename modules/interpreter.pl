BEGIN {xh::defmodule('xh::interpreter.pl', <<'_')}
use Memoize qw/memoize/;
use List::Util qw/max/;

sub active_regions {
  # Returns a series of numbers that describes, in pre-order, regions of
  # the given string that should be interpolated. The numeric list has the
  # following format:
  #
  # (offset << 32 | len), (offset << 32 | len) ...

  my @pieces = split /(\\.|\$@?!?\w+|\$@?!?\{[^}]+\}|@?!?\(|[')])/s, $_[0];
  my $offset = 0;
  my @result;
  my @quote_offsets;

  for (@pieces) {
    if (@quote_offsets && substr($_[0], $quote_offsets[-1], 1) eq "'") {
      # We're inside a hard-quote, so ignore everything except for the next
      # hard-quote.
      pop @quote_offsets if /^'/;
    } else {
      if (/^'/ || /^@?!?\(/) {
        push @quote_offsets, $offset;
      } elsif (/^\$/) {
        push @result, $offset << 32 | length;
      } elsif (/^\)/) {
        my $start = pop @quote_offsets;
        push @result, $start << 32 | $offset + 1 - $start;
      }
    }
    $offset += length;
  }

  sort {$a <=> $b} @result;
}

memoize 'active_regions';

our %closers = ('(' => ')', '[' => ']', '{' => '}');
sub element_regions {
  # Returns integer-encoded regions describing the positions of list
  # elements. The list passed into this function should be unwrapped; that
  # is, it should have no braces.
  my ($xs)   = @_;
  my $offset = 0;
  my @pieces = split / ( "(?:\\.|[^"\\])*"
                       | '(?:\\.|[^'\\])*'
                       | \\.
                       | [({\[\]})]
                       | \s+ ) /xs, $_[0];
  my @parens;
  my @result;
  my $item_start = -1;

  for (@pieces) {
    unless (@parens) {
      if (/^\s+/ || /^[)\]}]/) {
        # End any item if we have one.
        push @result, $item_start << 32 | $offset - $item_start
        if $item_start >= 0;
        $item_start = -1;
      } else {
        # Start an item unless we've already done so.
        $item_start = $offset if $item_start < 0;
      }
    }

    # Update bracket tracking.
    if ($_ eq $closers{$parens[-1]}) {
      if (@parens) {
        pop @parens;
      } else {
        die 'illegal closing brace: ... '
          . substr($xs, max(0, $offset - 10), 20)
          . ' ...'
          . "\n(whole string is $xs)";
      }
    } elsif (/^[(\[{]/) {
      push @parens, $_;
    }

    $offset += length;
  }

  push @result, $item_start << 32 | $offset if $item_start >= 0;
  @result;
}

memoize 'element_regions';

sub xh_list_unbox {
  return $1 if $_[0] =~ /^\[(.*)\]$/
            || $_[0] =~ /^\((.*)\)$/
            || $_[0] =~ /^\{(.*)\}$/;
  $_[0];
}

sub parse_list {
  my $unboxed = xh_list_unbox $_[0];
  map xh_list_box(substr $unboxed, $_ >> 32, $_ & 0xffffffff),
      element_regions 0, $unboxed;
}

sub into_list {'(' . join(' ', map xh_list_box($_), @_) . ')'}
sub into_vec  {'[' . join(' ', map xh_list_box($_), @_) . ']'}
sub into_map  {'{' . join(' ', map xh_list_box($_), @_) . '}'}

sub xh_vecp   {$_[0] =~ /^\[.*\]$/}
sub xh_listp  {$_[0] =~ /^\(.*\)$/}
sub xh_blockp {$_[0] =~ /^\{.*\}$/}
sub xh_varp   {$_[0] =~ /^\$/}

sub xh_count {
  scalar element_regions 0, xh_list_unbox $_[0];
}

sub xh_nth {(parse_list $_[0])[$_[1]]}

sub xh_nth_eq {
  my (undef, $i, $v) = @_;
  my $unboxed        = xh_list_unbox $_[0];
  my @regions        = element_regions 0, $unboxed;
  my $r              = $regions[$i];

  substr($_[0], 0, 1 + ($r >> 32)) . $v .
  substr($_[0], 1 + ($r >> 32) + ($r & 0xffffffff));
}
_
