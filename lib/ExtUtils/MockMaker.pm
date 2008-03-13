package ExtUtils::MockMaker;
use Moose;

our $VERSION = '0.001';

use ExtUtils::MockMaker::Dist;

use File::Next ();
use YAML::Syck ();

has source => (is => 'ro', required => 1);
has dest   => (is => 'ro', required => 1);

# TODO: make this a registry -- rjbs, 2008-03-12
my %HANDLER_FOR = (
  yaml => '_from_yaml_file',
  yml  => '_from_yaml_file',
);

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

  my $iter = File::Next::files($arg->{source});

  while (my $file = $iter->()) {
    my $dist = $self->dist_from_file($file);
  }
}

sub dist_class { 'ExtUtils::MockMaker::Dist' }

sub dist_from_file {
  my ($self, $filename) = @_;

  my ($ext) = $filename =~ /\.(.+?)\z/;

  Carp::croak "don't know how to handle file $filename"
    unless $ext and my $method = $HANDLER_FOR{$ext};

  $self->$method($filename);
}

sub _from_yaml_file {
  my ($self, $filename) = @_;

  my $data = YAML::Syck::LoadFile($filename);
  my $dist = $self->dist_class->new($data);
}

no Moose;
1;
