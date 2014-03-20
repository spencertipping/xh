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

our $whitespace = qr/\s+/;
our $newlines   = qr/\n(?:\s*\n)*/;
our %closers    = ('(' => ')', '[' => ']', '{' => '}');

sub element_regions {
  # Returns integer-encoded regions describing the positions of list
  # elements. The list passed into this function should be unwrapped; that
  # is, it should have no braces.
  my ($is_vertical, $xs) = @_;
  my $split_on           = $is_vertical ? $newlines : $whitespace;
  my $offset             = 0;
  my @pieces             = split / ( "(?:\\.|[^"])*"
                                   | '(?:\\.|[^'])*'
                                   | \\.
                                   | [({\[\]})]
                                   | $split_on ) /xs, $_[0];
  my @paren_offsets;
  my @parens;
  my @result;
  my $item_start = -1;

  for (@pieces) {
    unless (@paren_offsets) {
      if (/$split_on/ || /^[)\]}]/) {
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
        pop @paren_offsets;
        pop @parens;
      } else {
        die 'illegal closing brace: ... '
          . substr($xs, max(0, $offset - 10), 20)
          . ' ...'
          . "\n(whole string is $xs)";
      }
    } elsif (/^[(\[{]/) {
      push @paren_offsets, $offset;
      push @parens, $_;
    }

    $offset += length;
  }

  push @result, $item_start << 32 | $offset if $item_start >= 0;
  @result;
}

memoize 'element_regions';

sub xh_list_box {
  $_[0] !~ /^[({\[]/ && element_regions(0, $_[0]) > 1
    ? "[$_[0]]"
    : $_[0];
}

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

sub parse_block {
  my $unboxed = xh_list_unbox $_[0];
  map xh_list_box(substr $unboxed, $_ >> 32, $_ & 0xffffffff),
      element_regions 1, $unboxed;
}

sub into_list  {'(' . join(' ',  map xh_list_box($_), @_) . ')'}
sub into_vec   {'[' . join(' ',  map xh_list_box($_), @_) . ']'}
sub into_block {'{' . join("\n",                      @_) . '}'}

sub xh_vecp   {$_[0] =~ /^\[.*\]$/}
sub xh_listp  {$_[0] =~ /^\(.*\)$/}
sub xh_blockp {$_[0] =~ /^\{.*\}$/}
sub xh_varp   {$_[0] =~ /^\$/}

sub xh_count {
  scalar element_regions 0, xh_list_unbox $_[0];
}

sub xh_nth {(parse_list $_[0])[$_[1]]}

sub xh_nth_eq {
  # FIXME
  my ($copy, $i, $v) = @_;
  my @regions        = element_regions 0, $copy;
  my $r              = $regions[$i];
  substr($copy, $r >> 32, $r & 0xffffffff) = $v;
  $copy;
}

sub xh_vcount {
  scalar element_regions 1, xh_list_unbox $_[0];
}

sub xh_vnth {
  my @regions = element_regions 1, $_[0];
  my $r       = $regions[$_[1]];
  xh_list_box substr $_[0], $r >> 32, $r & 0xffffffff;
}

sub xh_vnth_eq {
  my ($copy, $i, $v) = @_;
  my @regions        = element_regions 1, $copy;
  my $r              = $regions[$i];
  substr($copy, $r >> 32, $r & 0xffffffff) = $v;
  $copy;
}

sub destructuring_bind;
sub destructuring_bind {
  # Both $pattern and $v should be quoted; that is, the string character [
  # should be encoded as \[.
  my ($pattern, $v) = @_;
  my @pattern_elements = element_regions 0, $pattern;
  my @v_elements       = element_regions 0, $v;
  my %bindings;

  # NOTE: no $@ matching
  return undef unless @v_elements == @pattern_elements;

  # NOTE: no foo$bar matching (partial constants)
  for (my $i = 0; $i < @pattern_elements; ++$i) {
    my $pi = xh_nth $pattern, $i;
    my $vi = xh_nth $v,       $i;

    return undef if $pi !~ /^\$/ && $pi ne $vi;

    my @pattern_regions = element_regions 0, $pi;
    my @v_regions       = element_regions 0, $vi;
    return undef unless @pattern_regions == 1 && $pi =~ /^\$/
                     || @pattern_regions == @v_regions;

    if (xh_vecp $pi) {
      my $sub_bind = destructuring_bind $pi, $vi;
      return undef unless ref $sub_bind;
      my %sub_bindings = %$sub_bind;
      for (keys %sub_bindings) {
        return undef if exists $bindings{$_}
                     && $bindings{$_} ne $sub_bindings{$_};
        $bindings{$_} = $sub_bindings{$_};
      }
    } elsif (xh_listp $pi) {
      die "TODO: implement list binding for $pi";
    } elsif ($pi =~ /^\$\{?(\w+)\}?$/) {
      return undef if exists $bindings{$1} && $bindings{$1} ne $vi;
      $bindings{$1} = $vi;
    } elsif ($pi =~ /^\$/) {
      die "illegal binding form: $pi";
    } else {
      return undef unless $pi eq $vi;
    }
  }

  {%bindings};
}

sub invoke;
sub interpolate;
sub interpolate {
  # Takes a string and a compiled binding hash and interpolates all
  # applicable substrings outside-in. This process may involve full
  # evaluation if () subexpressions are present, and is in general
  # quadratic or worse in the length of the string.
  my $bindings              = $_[0];
  my @interpolation_regions = active_regions $_[1];
  my @result_pieces;

  for (@interpolation_regions) {
    my $slice = substr $_[0], $_ >> 32, $_ & 0xffffffff;

    # NOTE: no support for complex ${} expressions
    if ($slice =~ /^\$(@?!?)\{?(\w+)\}?$/) {
      # Expand a named variable that may or may not be defined yet.
      push @result_pieces,
           exists ${$bindings}{$2} ?
               $1 eq ''  ? xh_listquote(xh_deactivate $bindings->{$2})
             : $1 eq '@' ? xh_deactivate($bindings->{$2})
             : $1 eq '!' ? xh_listquote($bindings->{$2})
             :             $bindings->{$2}
           : "\$$slice";
    } elsif ($slice =~ /^\((.*)\)$/s) {
      push @result_pieces, invoke $bindings, parse_list interpolate $1;
    } else {
      push @result_pieces, $slice;
    }
  }

  join '', @result_pieces;
}

sub xh_function_cases {
  my @result;
  my @so_far;
  for (parse_vlist $_[0]) {
    my ($command, @args) = parse_list $_;
    if (xh_vecp $command) {
      push @result, into_block @so_far if @so_far;
      @so_far = ($command, into_list @args);
    }
  }
  push @result, into_block @so_far if @so_far;
  @result;
}

sub evaluate;
sub invoke {
  # NOTE: no support for (foo bar $x)-style conditional destructuring;
  # these are all rewritten into lambda forms
  my ($bindings, $f, @args) = @_;
  my $args = into_vec @args;

  # Resolve f into a lambda form if it's still in word form.
  $f = $bindings->{$f} if exists $bindings->{$f};

  # Escape into perl
  return $f->($bindings, @args) if ref $f eq 'CODE';

  my %nested_bindings = %$bindings;
  for (xh_function_cases $f) {
    my ($formals, @body) = parse_block $_;
    if (my $maybe_bindings = destructuring_bind $formals, $args) {
      $nested_bindings{$_} = $$maybe_bindings{$_}
      for keys %$maybe_bindings;
      return evaluate {%nested_bindings}, into_block @body;
    }
  }

  return into_list $f, @args;
}

sub evaluate {
  my ($bindings, $block) = @_;
  my @statements         = parse_block $block;
  my $result;

  # NOTE: this function updates $bindings in place.
  for (@statements) {
    # Each statement is an invocation, which for now we assume all to be
    # functions.
    #
    # NOTE: this is semantically incomplete as we don't consider
    # macro-bindings.
    $result = invoke $bindings, parse_list interpolate $bindings, $_;
  }
  $result;
}
_
