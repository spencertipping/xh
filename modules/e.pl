BEGIN {xh::defmodule('xh::e.pl', <<'_')}
sub evaluate;
sub interpolate;

sub interpolate_wrap {
  my ($prefix, $unquoted) = @_;
  return xh::v::quote_as_multiple_lines $unquoted if $prefix eq "\$'";
  return xh::v::quote_as_line           $unquoted if $prefix eq "\$@";
  return xh::v::quote_as_word           $unquoted if $prefix eq "\$:";
  return xh::v::quote_as_path           $unquoted if $prefix eq "\$\"";
  xh::v::quote_default $unquoted;
}

sub interpolate_dollar {
  my ($binding_stack, $term) = @_;

  # First things first: strip off any prefix operator, then interpolate the
  # result. We do this because $ is right-associative.
  my ($prefix, $rhs) = $term =~ /^(\$\^*[@"':]?)?(.*)$/g;

  # Do we have a compound form? If so, then we need to treat the whole
  # thing as a unit.
  if ($rhs =~ /^\(/) {
    # RHS is a command, so grab the result of executing the inside.
    return interpolate_wrap
             $prefix,
             evaluate $binding_stack, substr($rhs, 1, -1);
  } elsif ($rhs =~ /^\[/) {
    # TODO: handle this case. Right now we count on the macro preprocessor
    # to do it for us.
    die 'unhandled interpolate case: $[]';
  } elsif ($rhs =~ /^\{/) {
    $rhs = xh::v::unbox $rhs;
  } else {
    # It's either a plain word or another $-term. Either way, go ahead and
    # interpolate it so that it's ready for this operator.
    $rhs = xh::v::unbox interpolate $binding_stack, $rhs;
  }

  # Try to unwrap any layers around the RHS. Any braces at this point mean
  # that it's artificially quoted, or that the RHS is unusable.
  while ($rhs =~ /^\{/) {
    my $new_rhs = xh::v::unbox $rhs;
    die "illegal interpolation: $rhs" if $new_rhs eq $rhs;
    $rhs = $new_rhs;
  }

  # At this point we have a direct form we can use on the right: either a
  # quoted expression (in which case we unbox), or a word, in which case we
  # dereference.
  my $layer = 0;
  $layer = length $1 if $prefix =~ s/^\$(\^*)/\$/;

  my $unquoted = $$binding_stack[-($layer + 1)]{$rhs}       # local scope
              // $$binding_stack[0]{$rhs}                   # global scope
              // die "unbound var: $rhs";

  interpolate_wrap $prefix, $unquoted;
}

sub interpolate {
  my ($binding_stack, $x) = @_;
  join '', map {$_ =~ /^\$/ ? interpolate_dollar $binding_stack, $_
              : $_ =~ /^\\/ ? xh::v::undo_backslash_escape $_
              : $_ } xh::v::split_by_interpolation $x;
}

sub call {
  my ($binding_stack, $f, @args) = @_;
  my $fn = $$binding_stack[-1]{$f}
        // $$binding_stack[0]{$f}
        // die "unbound function: $f";

  # Special case: if it's a builtin Perl sub, then just call that directly.
  return &$fn($binding_stack, @args) if ref $fn eq 'CODE';

  # Otherwise use xh calling convention.
  push @$binding_stack,
       {_ => join ' ', map xh::v::quote_default($_), @args};

  my $result = evaluate $binding_stack, $fn;
  pop @$binding_stack;
  $result;
}

sub macroexpand {
  my ($binding_stack, $macro, @args) = @_;
  call($binding_stack, $macro, @args);
}

sub evaluate {
  my ($binding_stack, $body) = @_;
  my @statements             = xh::v::parse_lines $body;
  my $result                 = '';

  for my $s (@statements) {
    # Step 1: Do we have a macro? If so, macroexpand before calling
    # anything. (NOTE: technically incorrect; macros should receive their
    # arguments with whitespace intact)
    #
    # For now, macros are functions that start with %. I have no
    # particularly good feelings about this; it's just an expedient at this
    # point.
    my @words;
    $s = macroexpand $binding_stack, @words
    while (@words = xh::v::parse_words $s)[0] =~ /^%/;

    # Step 2: Interpolate the whole command once. Note that we can't wrap
    # each word at this point, since that would block interpolation
    # altogether.
    $s = interpolate $binding_stack, $s;

    # Step 3: See if the interpolation produced multiple lines. If so, we
    # need to re-expand. Otherwise we can do a single function call.
    if (xh::v::parse_lines($s) > 1) {
      $result = evaluate $binding_stack, $s;
    } else {
      # Just one line, so continue normally. At this point we look up the
      # function and call it. If it's Perl native, then we're set; we just
      # call that on the newly-parsed arg list. Otherwise delegate to
      # create a new call frame and locals.
      $result = call $binding_stack, xh::v::parse_words $s;
    }
  }
  $result;
}
_
