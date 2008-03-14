package Module::Faker;
use 5.008;
use Moose;

=head1 NAME

Module::Faker - build fake dists for testing CPAN tools

=head1 VERSION

version 0.003

=cut

our $VERSION = '0.003';

use Module::Faker::Dist;

use File::Next ();

=head1 SYNOPSIS

  Module::Faker->make_fakes({
    source => './dir-of-specs',
    dest   => './will-contain-tarballs',
  });

=cut

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

sub make_fakes {
  my ($class, $arg) = @_;

  my $self = ref $class ? $class : $class->new($arg);

  my $iter = File::Next::files($self->source);

  while (my $file = $iter->()) {
    my $dist = $self->dist_class->from_file($file);
    $dist->make_archive({ dir => $self->dest });
  }
}

sub dist_class { 'Module::Faker::Dist' }

=head1 COPYRIGHT AND AUTHOR

This distribution was written by Ricardo Signes, E<lt>rjbs@cpan.orgE<gt>.

Copyright 2008.  This is free software, released under the same terms as perl
itself.

=cut

no Moose;
1;
