package ExtUtils::MockMaker::Dist;
use Moose;

use ExtUtils::MockMaker::Package;
use ExtUtils::MockMaker::Module;

has name         => (is => 'ro', isa => 'Str', required => 1);
has version      => (is => 'ro', isa => 'Maybe[Str]', default => '0.01');
has archive_type => (is => 'ro', isa => 'Str', default => 'tar.gz');

has archive_filename => (
  is   => 'ro',
  isa  => 'Str',
  lazy => 1,
  default => sub {
    my ($self) = @_;
    return sprintf '%s-%s.%s',
      $self->name, $self->version // 'undef', $self->archive_type;
  },
);

sub __dist_to_pkg { my $str = shift; $str =~ s/-/::/g; return $str; }
sub __pkg_to_file { my $str = shift; $str =~ s{::}{/}g; return "lib/$str.pm"; }

has provides => (
  is     => 'ro',
  isa    => 'ExtUtils::MockMaker::Type::Packages',
  lazy   => 1,
  coerce => 1,
  required   => 1,
  default    => sub {
    my ($self) = @_;
    my $pkg = __dist_to_pkg($self->name);
    return [
      ExtUtils::MockMaker::Package->new({
        name    => $pkg,
        version => $self->version,
        in_file => __pkg_to_file($pkg),
      })
    ]
  },
  auto_deref => 1,
);

sub modules {
  my ($self) = @_;

  my %module;
  for my $pkg ($self->provides) {
    my $filename = $pkg->in_file;

    push @{ $module{ $filename } ||= [] }, $pkg;
  }

  my @modules = map {
    ExtUtils::MockMaker::Module->new({
      packages => $module{$_},
      filename => $_,
    });
  } keys %module;

  return @modules;
}

1;
