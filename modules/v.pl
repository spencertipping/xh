BEGIN {xh::defmodule('xh::v.pl', <<'_')}
sub unbox;

sub parse_with_quoted {
  my ($events_to_split, $split_sublists, $s) = @_;
  my @result;
  my $current_item  = '';
  my $sublist_depth = 0;

  for my $piece (split /(\v+|\s+|\/|\\.|[\[\](){}])/, $s) {
    next unless length $piece;
    my $depth_before_piece = $sublist_depth;
    $sublist_depth += $piece =~ /^[\[({]$/;
    $sublist_depth -= $piece =~ /^[\])}]$/;

    if ($split_sublists && !$sublist_depth != !$depth_before_piece) {
      # Two possibilities. One is that we just closed an item, in which
      # case we take the piece, concatenate it to the item, and continue.
      # The other is that we just opened one, in which case we emit what we
      # have and start a new item with the piece.
      if ($sublist_depth) {
        # Just opened one; kick out current item and start a new one.
        push @result, unbox $current_item if length $current_item;
        $current_item = $piece;
      } else {
        # Just closed a list; concat and kick out the full item.
        push @result, unbox "$current_item$piece";
        $current_item = '';
      }
    } elsif (!$sublist_depth && $piece =~ /$events_to_split/) {
      # If the match produces a group, then treat it as a part of the next
      # item. Otherwise throw it away.
      push @result, unbox $current_item if length $current_item;
      $current_item = $1;
    } else {
      $current_item .= $piece;
    }
  }

  push @result, unbox $current_item if length $current_item;
  @result;
}

sub parse_lines {parse_with_quoted '\v+', 0, @_}
sub parse_words {parse_with_quoted '\s+', 0, @_}
sub parse_path  {parse_with_quoted '(/)', 1, @_}

sub brace_balance {my $without_escapes = $_[0] =~ s/\\.//gr;
                   length($without_escapes =~ s/[^\[({]//gr) -
                   length($without_escapes =~ s/[^\])}]//gr)}

sub escape_braces_in {$_[0] =~ s/([\\\[\](){}])/\\$1/gr}

sub quote_as_multiple_lines {
  return escape_braces_in $_[0] if brace_balance $_[0];
  $_[0];
}

sub brace_wrap {"{" . quote_as_multiple_lines($_[0]) . "}"}

sub quote_as_line {parse_lines(@_) > 1 ? brace_wrap $_[0] : $_[0]}
sub quote_as_word {parse_words(@_) > 1 ? brace_wrap $_[0] : $_[0]}
sub quote_as_path {parse_path(@_)  > 1 ? brace_wrap $_[0] : $_[0]}

sub quote_default {brace_wrap $_[0]}

sub split_by_interpolation {
  # Splits a value into constant and interpolated pieces, where
  # interpolated pieces always begin with $. Adjacent constant pieces may
  # be split across items. Any active backslash-escapes will be placed on
  # their own.

  my @result;
  my $current_item        = '';
  my $sublist_depth       = 0;
  my $blocker_count       = 0;      # number of open-braces
  my $interpolating       = 0;
  my $interpolating_depth = 0;

  my $closed_something    = 0;
  my $opened_something    = 0;

  for my $piece (split /([\[\](){}]|\\.|\/|\$|\s+)/, $_[0]) {
    $sublist_depth += $opened_something = $piece =~ /^[\[({]$/;
    $sublist_depth -= $closed_something = $piece =~ /^[\])}]$/;
    $blocker_count += $piece eq '{';
    $blocker_count -= $piece eq '}';

    if (!$interpolating) {
      # Not yet interpolating, but see if we can find a reason to change
      # that.
      if (!$blocker_count && $piece eq '$') {
        # Emit current item and start interpolating.
        push @result, $current_item if length $current_item;
        $current_item = $piece;
        $interpolating = 1;
        $interpolating_depth = $sublist_depth;
      } elsif (!$blocker_count && $piece =~ /^\\/) {
        # The backslash should be interpreted, so emit it as its own piece.
        push @result, $current_item if length $current_item;
        push @result, $piece;
        $current_item = '';
      } else {
        # Collect the piece and continue.
        $current_item .= $piece;
      }
    } else {
      # Grab everything until:
      #
      # 1. We close the list in which the interpolation occurred.
      # 2. We close a list to get back out to the interpolation depth.
      # 3. We observe whitespace.
      # 4. We observe a path separator.

      if ($sublist_depth < $interpolating_depth
          or $sublist_depth == $interpolating_depth
             and $closed_something || $piece eq '/' || $piece =~ /^\s/) {
        # No longer interpolating because of what we just saw, so emit
        # current item and start a new constant piece.
        push @result, $current_item if length $current_item;
        $current_item = $piece;
        $interpolating = 0;
      } else {
        # Still interpolating, so collect the piece.
        $current_item .= $piece;
      }
    }
  }

  push @result, $current_item if length $current_item;
  @result;
}

sub undo_backslash_escape {
  return "\n" if $_[0] eq '\n';
  return "\t" if $_[0] eq '\t';
  return "\\" if $_[0] eq '\\\\';
  substr $_[0], 1;
}

sub unbox {
  my ($s) = @_;
  my $depth  = 0;
  for my $piece (split /(\\.|[\[\](){}])/, $s) {
    $depth += $piece =~ /^[\[({]/;
    $depth -= $piece =~ /^[\])}]/;
    return $s if $depth <= 0;
  }
  substr $s, 1, -1;
}
_
