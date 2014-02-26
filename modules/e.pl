BEGIN {xh::defmodule('xh::e.pl', <<'_')}
sub evaluate;
sub interpolate;
sub call;

sub interpolate_wrap {
  my ($prefix, $unquoted) = @_;
  return xh::v::quote_as_multiple_lines $unquoted if $prefix =~ /'$/;
  return xh::v::quote_as_line           $unquoted if $prefix =~ /\@$/;
  return xh::v::quote_as_path           $unquoted if $prefix =~ /:$/;
  return xh::v::quote_default           $unquoted if $prefix =~ /"$/;
  xh::v::quote_as_word $unquoted;
}

sub scope_index_for {
  my ($carets) = $_[0] =~ /^\$(\^*)/g;
  -(1 + length $carets);
}

sub truncated_stack {
  my ($stack, $index) = @_;
  return $stack if $index == -1;
  [@$stack[0 .. @$stack + $index]];
}

sub interpolate_dollar {
  my ($binding_stack, $term) = @_;

  # First things first: strip off any prefix operator, then interpolate the
  # result. We do this because $ is right-associative.
  my ($prefix, $rhs) = $term =~ /^(\$\^*[@"':]?)(.*)$/sg;

  # Do we have a compound form? If so, then we need to treat the whole
  # thing as a unit.
  if ($rhs =~ /^\(/) {
    # The exact semantics here are a little subtle. Because the RHS is just
    # ()-boxed, it should be expanded within the current scope. The actual
    # evaluation, however, might be happening within a parent scope; we'll
    # know by looking at the $prefix to check for ^s.

    my $interpolated_rhs = interpolate $binding_stack, xh::v::unbox $rhs;
    my $index            = scope_index_for $prefix;
    my $new_stack        = truncated_stack $binding_stack, $index;

    return interpolate_wrap $prefix,
                            evaluate $new_stack, $interpolated_rhs;
  } elsif ($rhs =~ /^\[/) {
    # $[] is a way to call a series of functions on a value, just like
    # Clojure's (-> x y z). Like $(), we always interpolate the terms of
    # the [] list in the current environment; but any ^s you use (e.g.
    # $^[]) cause the inner functions to be called from a parent scope.
    # This can be relevant in certain pathological cases that you should
    # probably never use.

    my ($initial, @fns) = map {interpolate $binding_stack, $_}
                              xh::v::parse_words xh::v::unbox $rhs;
    my $index           = scope_index_for $prefix;
    my $calling_stack   = truncated_stack $binding_stack, $index;

    # You can use paths as a curried notation within $[] interpolation. For
    # example:
    #
    # > echo $[foo echo/hi]
    # hi foo
    #
    # Lists also work, but there is no difference between () and [], which
    # is a horrible oversight that should probably be addressed at some
    # point.
    $initial = xh::v::quote_as_word $initial;
    $initial = call $calling_stack,
                    (map {s/^\///r} xh::v::parse_path($_)),
                    xh::v::parse_words $initial
    for @fns;

    return interpolate_wrap $prefix, $initial;
  } elsif ($rhs =~ /^\{/) {
    # Interpolated quotation, possibly under a different scope index.
    my $index         = scope_index_for $prefix;
    my $calling_stack = truncated_stack($binding_stack, $index);

    return interpolate_wrap $prefix,
      interpolate $calling_stack, xh::v::unbox $rhs;
  } else {
    # It's either a plain word or another $-term. Either way, go ahead and
    # interpolate it so that it's ready for this operator.
    $rhs = xh::v::unbox interpolate $binding_stack, $rhs;

    my $index = scope_index_for $prefix;
    interpolate_wrap $prefix,
      $$binding_stack[$index]{$rhs}
      // $$binding_stack[0]{$rhs}
      // die "unbound var: $rhs (bound vars are ["
             . join(' ', sort keys %{$$binding_stack[$index]})
             . "] locally, ["
             . join(' ', sort keys %{$$binding_stack[$index - 1]})
             . " ] in parent stack, ["
             . join(' ', sort keys %{$$binding_stack[0]})
             . "] globally)";
  }
}

sub interpolate {
  my ($binding_stack, $x) = @_;
  join '', map {$_ =~ /^\$/ ? interpolate_dollar $binding_stack, $_
              : $_ =~ /^\\/ ? xh::v::undo_backslash_escape $_
              : $_ } xh::v::split_by_interpolation $x;
}

sub call {
  my ($binding_stack, $f, @args) = @_;
  my $fn = xh::v::quote_as_word($f) =~ /^\{/ ? $f
         : $$binding_stack[-1]{$f}
        // $$binding_stack[0]{$f}
        // die "unbound function: $f";

  # Special case: if it's a builtin Perl sub, then just call that directly.
  return &$fn($binding_stack, @args) if ref $fn eq 'CODE';

  # Otherwise use xh calling convention.
  push @$binding_stack,
       {_ => join ' ', map xh::v::quote_as_word($_), @args};

  my $result = eval {evaluate $binding_stack, $fn};
  my $error  = "$@ in $f "
             . join(' ', map xh::v::quote_as_word($_), @args)
             . ' at calling stack depth ' . @$binding_stack
             . " with locals:\n"
             . join("\n", map "  $_ -> $$binding_stack[-1]{$_}",
                              sort keys %{$$binding_stack[-1]}) if $@;
  pop @$binding_stack;
  die $error if $error;
  $result;
}

sub evaluate {
  my ($binding_stack, $body) = @_;
  my @statements             = xh::v::parse_lines $body;
  my $result                 = '';

  for my $s (@statements) {
    my $original = $s;

    # Step 1: Do we have a macro? If so, macroexpand before calling
    # anything. (NOTE: technically incorrect; macros should receive their
    # arguments with whitespace intact)
    my @words;
    while ((@words = xh::v::parse_words $s)[0] =~ /^#/) {
      $s = eval {call $binding_stack, @words};
      die "$@ in @words (while macroexpanding $original)" if $@;
    }

    # Step 2: Interpolate the whole command once. Note that we can't wrap
    # each word at this point, since that would block interpolation
    # altogether.
    my $new_s = eval {interpolate $binding_stack, $s};
    die "$@ in $s (while interpolating from $original)" if $@;
    $s = $new_s;

    # If that killed our value, then we have nothing to do.
    next unless @words = xh::v::parse_words $s;

    # Step 3: See if the interpolation produced multiple lines. If so, we
    # need to re-expand. Otherwise we can do a single function call.
    if (xh::v::parse_lines($s) > 1) {
      $result = evaluate $binding_stack, $s;
    } else {
      # Just one line, so continue normally. At this point we look up the
      # function and call it. If it's Perl native, then we're set; we just
      # call that on the newly-parsed arg list. Otherwise delegate to
      # create a new call frame and locals.
      $result = eval {call $binding_stack, @words};
      die "$@ in $s (while evaluating $original)" if $@;
    }
  }
  $result;
}
_
