package Module::Faker;
use 5.008;
use Moose;

=head1 NAME

Module::Faker - build fake dists for testing CPAN tools

=head1 VERSION

version 0.005

=cut

our $VERSION = '0.005';

use Module::Faker::Dist;

use File::Next ();

=head1 SYNOPSIS

  Module::Faker->make_fakes({
    source => './dir-of-specs',
    dest   => './will-contain-tarballs',
  });

=head2 DESCRIPTION

Module::Faker is a tool for building fake CPAN modules and, perhaps more
importantly, fake CPAN distributions.  These are useful for running tools that
operate against CPAN distributions without having to use real CPAN
distributions.  This is much more useful when testing an entire CPAN instance,
rather than a single distribution, for which see L<CPAN::Faker|CPAN::Faker>.

=head1 METHODS

=head2 make_fakes

  Module::Faker->make_fakes(\%arg);

This method creates a new Module::Faker and builds archives in its destination
directory for every dist-describing file in its source directory.  See the
L</new> method below.

=head2 new

  my $faker = Module::Faker->new(\%arg);

This create the new Module::Faker.  All arguments may be accessed later by
methods of the same name.  Valid arguments are:

  source - the directory in which to find source files
  dest   - the directory in which to construct dist archives

  dist_class - the class used to fake dists; default: Module::Faker::Dist

=cut

has source => (is => 'ro', required => 1);
has dest   => (is => 'ro', required => 1);

has dist_class => (
  is  => 'ro',
  isa => 'Str',
  required => 1,
  default  => sub { 'Module::Faker::Dist' },
);

sub BUILD {
  my ($self) = @_;

  for (qw(source dest)) {
    my $dir = $self->$_;
    Carp::croak "$_ directory does not exist"     unless -e $dir;
    Carp::croak "$_ directory is not a directory" unless -d $dir;
    Carp::croak "$_ directory is not readable"    unless -r $dir;
  }

  Carp::croak "$_ directory is not writeable" unless -w $self->dest;
}

sub make_fakes {
  my ($class, $arg) = @_;

  my $self = ref $class ? $class : $class->new($arg);

  my $iter = File::Next::files($self->source);

  while (my $file = $iter->()) {
    my $dist = $self->dist_class->from_file($file);
    $dist->make_archive({ dir => $self->dest });
  }
}

=head1 COPYRIGHT AND AUTHOR

This distribution was written by Ricardo Signes, E<lt>rjbs@cpan.orgE<gt>.

Copyright 2008.  This is free software, released under the same terms as perl
itself.

=cut

no Moose;
1;
