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

sub quote_as_line {parse_lines(@_) > 1 ? "{$_[0]}" : $_[0]}
sub quote_as_word {parse_words(@_) > 1 ? "{$_[0]}" : $_[0]}
sub quote_as_path {parse_path(@_)  > 1 ? "{$_[0]}" : $_[0]}

sub to_hash {
  my %result;
  for my $line (parse_lines $_[0]) {
    my ($key, @value) = parse_words $line;
    $result{$key} = [@value];
  }
  \%result;
}
_
