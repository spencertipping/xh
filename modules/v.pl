BEGIN {xh::defmodule('xh::v.pl', <<'_')}
sub parse_with_brackets {
  my ($regexp, $filler, $x) = @_;
  $regexp = qr/$regexp/;
  my @initial_split = split /$regexp/, $x;

  @initial_split = grep length, @initial_split if $regexp =~ /\(/;
  my $item;
  my @result;
  my $bracket_count = 0;

  for my $data (@initial_split) {
    $bracket_count += length($data =~ s/\\.|[^\[({]//gr);
    $bracket_count -= length($data =~ s/\\.|[^\])}]//gr);
    $item = length($item) ? "$item$filler$data" : $data;
    unless ($bracket_count) {
      push @result, $item;
      $item = '';
    }
  }

  push @result, $item if $item;
  @result;
}

sub parse_lines {parse_with_brackets '\v',                 "\n", @_}
sub parse_words {parse_with_brackets '\s',                 " ",  @_}
sub parse_path  {parse_with_brackets '(/[^\[\](){}\s/]*)', "",   @_}
_
