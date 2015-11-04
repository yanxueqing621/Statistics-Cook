package Statistics::Cook;
use Modern::Perl;
use Data::Dumper;
use List::Util qw/sum/;
use Carp;
use Moo;
use Types::Standard qw/Str Num Int ArrayRef/;

# VERSION
# ABSTRACT: Statistics::Cook

=head1 SYNOPSIS

  use Statistics::Cook;
  ...

=head1 DESCRIPTION

Blablabla

=cut

has x => (
  is => 'rw',
  isa => ArrayRef,
  lazy => 1,
  default => sub { [] },
  trigger => 1,
);

has y => (
  is => 'rw',
  isa => ArrayRef,
  default => sub { [] },
  lazy => 1,
  trigger => 1,
);

has weight => (
  is => 'rw',
  isa => ArrayRef
);

has slope => (
  is => 'rw',
  isa => Num,
);

has intercept=> (
  is => 'rw',
  isa => Num,
);

has regress_done => (
  is => 'rw',
  isa => Int,
  default => 0,
  lazy => 1,
);

sub _trigger_x {
  shift->regress_done(0);
}
sub _trigger_y {
  shift->regress_done(0);
}

sub regress {
  my $self = shift;
  my ($x, $y) = ($self->x, $self->y);
  confess "have not got data or x y length is not same" unless(@$x and @$y and @$x == @$y);
  my $sums = $self->computeSums;
  say Dumper $sums;
  say "xx:".$sums->{xx} ."\t" . $sums->{x} ** 2 / scalar(@$x) . "\n";
  my $sqdevx = $sums->{xx} - $sums->{x} ** 2 / scalar(@$x);
  if ($sqdevx != 0) {
    my $sqdevy = $sums->{yy} - $sums->{y} ** 2 / scalar(@$y);
    my $sqdevxy = $sums->{xy} - $sums->{x} * $sums->{y} / scalar(@$x);
    my $slope = $sqdevxy / $sqdevx;
    my $intercept = ($sums->{y} - $slope * $sums->{x}) / @$x;
    $self->slope($slope);
    $self->intercept( $intercept);
    $self->regress_done(1);
    return ($intercept, $slope);
  } else {
    confess "Can't fit line when x values are all equal";
  }
}

sub computeSums {
  my $self = shift;
  my @x = @{$self->x};
  my @y = @{$self->y};
  my ($sums, @weights);
  if (defined (my $weight = $self->weight)) {
    confess "weights does not have same length with x" unless (@$weight == @x);
    @weights = @$weight;
  } else {
    @weights = (1) x scalar(@x);
  }
  for my $i (0..$#x) {
    my $w = $weights[$i];
    $sums->{x} += $w * $x[$i];
    $sums->{y} += $w * $y[$i];
    $sums->{xx} += $w * $x[$i] ** 2;
    $sums->{yy} += $w * $y[$i] ** 2;
    $sums->{xy} += $w * $x[$i] * $y[$i];
  }
  say Dumper $sums;
  return $sums;
}

sub coefficients {
  my $self = shift;
  if ($self->regress_done) {
    return ($self->intercept, $self->slope);
  } else {
    return $self->regress;
  }
}

sub fitted {
  my $self = shift;
  if ($self->regress_done) {
    return map {$self->intercept + $self->slope * $_ } @{$self->x};
  } else {
    my ($a, $b) = $self->regress;
    return map {$a + $b * $_} @{$self->x};
  }
}
sub residuals {
  my $self = shift;
  my @y = @{$self->y};
  my @yf = $self->fitted;
  return map { $y[$_] - $yf[$_] } 0..$#y;
}

sub cooks_distance {
  my ($self, @cooks) = shift;
  my @yr = $self->residuals;
  my @y = @{$self->y};
  my @x = @{$self->x};
  my $statis = Statistics::Cook->new();
  for my $i (0..$#y) {
    my @xi = @x;
    my @yi = @y;
    splice(@xi, $i, 1);
    splice(@yi, $i, 1);
    say "x:";
    say Dumper \@xi;
    say "y:";
    say Dumper \@yi;
    $statis->x(\@xi);
    $statis->y(\@yi);
    my ($a, $b) = $statis->coefficients;
    my @yf_new = map {$a + $b * $_ } @x;
    my @yf = $self->fitted;
    my ($sum1, $sum2) = (0, 0);
    for my $j (0..$#yf) {
      $sum1 += ($yf[$j] - $yf_new[$j]) ** 2;
      $sum2 += $yr[$j] ** 2;
    }
    my $cook = $sum1 * (@y - 2) / $sum2 / 2;
    push @cooks, $cook;
  }
  return @cooks;
}

sub N {
  my ($self, $num) = @_;
  my $n = shift || 50;
  my @nums = sort { $a <=> $b } @$num;
  my $sum = sum(@nums);
  my $tmp = 0;
  for my $i (0..$#nums) {
    $tmp += $nums[$i];
    return ($nums[$i], $i+1) if ($tmp > $sum * $n / 100);
  }
}

1;
