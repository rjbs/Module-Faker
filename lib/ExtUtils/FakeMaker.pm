package ExtUtils::FakeMaker;
use Moose;

our $VERSION = '0.001';

use ExtUtils::FakeMaker::Dist;

use File::Next ();

has source => (is => 'ro', required => 1);
has dest   => (is => 'ro', required => 1);

sub BUILD {
  my ($self) = @_;

  for (qw(source dest)) {
    my $dir = $self->$_;
    Carp::croak "$_ directory does not exist"     unless -e $dir;
    Carp::croak "$_ directory is not a directory" unless -d $dir;
    Carp::croak "$_ directory is not writeable"   unless -w $dir;
  }
}

sub make_mocks {
  my ($class, $arg) = @_;

  my $self = ref $class ? $class : $class->new($arg);

  my $iter = File::Next::files($self->source);

  while (my $file = $iter->()) {
    my $dist = $self->dist_class->from_file($file);
    $dist->make_archive({ dir => $self->dest });
  }
}

sub dist_class { 'ExtUtils::FakeMaker::Dist' }

no Moose;
1;
