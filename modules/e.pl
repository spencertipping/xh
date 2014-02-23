BEGIN {xh::defmodule('xh::e.pl', <<'_')}
sub evaluate;
sub interpolate;

sub interpolate_dollar {
  my ($binding_stack, $term) = @_;

  # First things first: strip off any prefix operator, then interpolate the
  # result. We do this because $ is right-associative.
  my ($prefix, $rhs) = $term =~ /^(\$\^*[@"':]?)?(.*)/g;

  # Do we have a compound form? If so, then we need to treat the whole
  # thing as a unit.
  if ($rhs =~ /^\(/) {
    # RHS is a command, so grab the result of executing the inside.
    return evaluate $binding_stack, substr($rhs, 1, -1);
  } elsif ($rhs =~ /^\[/) {
    # TODO: handle this case. Right now we count on the macro preprocessor
    # to do it for us.
    die 'unhandled interpolate case: $[]';
  } elsif ($rhs =~ /^\{/) {
    $rhs = xh::v::unbox $rhs;
  } else {
    # It's either a plain word or another $-term. Either way, go ahead and
    # interpolate it so that it's ready for this operator.
    $rhs = interpolate $binding_stack, $rhs;
  }

  # At this point we have a direct form we can use on the right: either a
  # quoted expression (in which case we unbox), or a word, in which case we
  # dereference.
  my $layer = length $rhs =~ /^\$(\^*)/ || 0;
  my $unquoted =
    $rhs =~ /^\{/ ? xh::v::unbox $rhs
                  : $$binding_stack[-($layer + 1)]{$rhs}    # local scope
                    // $$binding_stack[0]{$rhs}             # global scope
                    // die "unbound var: $rhs";

  # Now select how to quote the result based on the prefix.
  return xh::v::quote_as_multiple_lines $unquoted if $prefix eq "\$'";
  return xh::v::quote_as_line           $unquoted if $prefix eq "\$@";
  return xh::v::quote_as_word           $unquoted if $prefix eq "\$:";
  return xh::v::quote_as_path           $unquoted if $prefix eq "\$\"";
  xh::v::quote_default $unquoted;
}

sub interpolate {
  my ($binding_stack, $x) = @_;
  join '', map {$_ =~ /^\$/ ? interpolate_dollar $binding_stack, $_
              : $_ =~ /^\\/ ? xh::v::undo_backslash_escape $_
              : $_ } xh::split_by_interpolation $x;
}

sub call {
  my ($binding_stack, $fn, @args) = @_;
  push @$binding_stack,
       {_ => join ' ', map xh::v::quote_default($_), @args};
  my $result = evaluate $binding_stack, $fn;
  pop @$binding_stack;
  $result;
}

sub evaluate {
  my ($binding_stack, $body) = @_;
  my @statements = xh::v::parse_lines $body;
  my $result;

  for my $s (@statements) {
    my @words = xh::v::parse_words $s;

    # Step 1: Do we have a macro? If so, macroexpand before calling
    # anything. (NOTE: technically incorrect; macros should receive their
    # arguments with whitespace intact)
    @words = macroexpand $binding_stack, @words
    while is_a_macro $binding_stack, $words[0];

    # Step 2: Interpolate the whole command once.
    $s = interpolate $binding_stack,
                     join ' ', map xh::v::quote_default($_), @words;

    # Step 3: Look up the function and call it. If it's Perl native, then
    # we're set; we just call that on the newly-parsed arg list. Otherwise
    # do the call frame stuff.
    my ($f, @args) = xh::v::parse_words $s;
    my $fn = $$binding_stack[-1]{$f}
          // $$binding_stack[0]{$f}
          // die "unbound function: $f";

    $result = ref $fn eq 'CODE' ? $fn->(@args)
                                : call($binding_stack, $fn, @args);
  }
  $result;
}
_
