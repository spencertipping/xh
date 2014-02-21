BEGIN {xh::defmodule('xh::compile.pl', <<'_')}
our %shorthands = ("'["  => 'xh::compile::line_index',
                   "'s{" => 'xh::compile::line_transform',
                   "'#"  => 'xh::compile::line_count',
                   '@['  => 'xh::compile::word_index',
                   '@s{' => 'xh::compile::word_transform',
                   '@#'  => 'xh::compile::word_count',
                   ':['  => 'xh::compile::path_index',
                   ':s{' => 'xh::compile::path_transform',
                   ':#'  => 'xh::compile::path_count',
                   '"['  => 'xh::compile::byte_index',
                   '"s{' => 'xh::compile::byte_transform',
                   '"#'  => 'xh::compile::byte_count');

sub compile_statement;
sub compile_expression;
sub expand_shorthands;
sub unquote_list;
sub to_perl_ident;
sub to_perl_string;

sub compile_function {
  join "\n", "(sub {",
             'local $_ = $_[0];',
             (map {compile_statement $_} xh::v::parse_lines(@_)),
             "})";
}

sub compile_statement {
  my ($fn, @args) = xh::v::parse_words $_[0];
  if ($fn =~ /^\[/) {
    join ' . ', compile_expression($fn),
                map compile_expression($_), @args;
  } elsif ($fn eq 'def') {
    my @result;
    for (my $i = 0; $i < @args; $i += 2) {
      # No first-class names here.
      my $safe_name = to_perl_ident      $args[$i];
      my $expr      = compile_expression $args[$i + 1];
      push @result, "my \$$safe_name = $expr;";
    }
    @result;
  } else {
    # Everything else is just a function call.
    my $fn_name       = compile_expression $fn;
    my @compiled_args = map compile_expression($_), @args;
    "\${$fn_name}->(" . join(', ', @compiled_args) . ");";
  }
}

sub compile_expression {
  # Two cases that require interpretation here. One is when the word begins
  # with a $, in which case we expand shorthands into real function calls.
  # The other is when the word is quoted, in which case we unquote it by a
  # layer.
  my ($word) = @_;
  return expand_shorthands substr($word, 1) if $word =~ /^\$/;
  return unquote_list      $word            if $word =~ /^[{(]/;
  return to_perl_string    $word;
}

sub expand_shorthands {
  my ($initial, @operators) = xh::v::parse_path @_;
  my $result;
  if ($initial =~ /^[^\[\](){}]/) {
    # A regular word, so start by referencing a Perl variable.
    $result = "(\$" . to_perl_ident($initial) . ")";
  } elsif ($initial =~ /^\{/) {
    # A quoted constant; unquote by a layer and use a Perl string.
    $result = "(" . to_perl_string(unquote_list($initial)) . ")";
  } elsif ($initial =~ /^\(/) {
    # Substituting in the value from a command.
    $result = "((sub {local \$_ = \$_[0];"
            . compile_statement($initial)
            . "})->())";
  } elsif ($initial =~ /^\[/) {
    # A quoted vector; leave as a vector, parse as words, and evaluate each
    # element (TODO)
    die "need to implement shorthand-from-vector case";
  } else {
    die "expand_shorthands: got $initial";
  }

  # Now compile shorthands into function calls.
  for (my $i = 0; $i < @operators; ++$i) {
    my $op        = $operators[$i];
    my $arg_count = 0;

    die "$op does not begin with a slash" unless $op =~ s/^\///;

    while ($operators[$i + $arg_count + 1] =~ /^([\[({])/) {
      ++$arg_count;
      $op .= $1;
    }
    die "undefined shorthand operator: $op" unless exists $shorthands{$op};
    $result = "$shorthands{$op}("
            . join(",", $result, map compile_expression($_),
                                     @operators[$i + 1 .. $i + $arg_count])
            . ")";
    $i += $arg_count;
  }
  $result;
}

sub unquote_list {
  my ($l) = @_;

  # Simple case: literal expansion of {}
  return to_perl_string substr($l, 1, -1) if $l =~ /^\{/;

  # Any other list is subject to in-place interpolation (TODO: fix this to
  # preserve whitespace).
  my @elements = xh::v::parse_words substr($l, 1, -2);
  my $compiled = 'join(" "'
               . join(', ', map compile_expression($_), @elements)
               . ')';

  $l =~ /^\[/ ? "'[' . $compiled . ']'" : $compiled;
}

sub to_perl_ident {
  # Mangle names by replacing every non-alpha character with its char-code.
  $_[0] =~ s/(\W)/"_x".ord($1)/egr;
}

sub to_perl_string {
  # Quote the value by escaping any single-quotes and backslashes.
  "'" . ($_[0] =~ s/[\\']/\\$1/gr) . "'";
}
_
