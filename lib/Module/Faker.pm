package Module::Faker;
# ABSTRACT: build fake dists for testing CPAN tools

use 5.008;
use Moose 0.33;

use Module::Faker::Dist;

use File::Next ();

=head1 SYNOPSIS

  Module::Faker->make_fakes({
    source => './dir-of-specs', # ...or a single file
    dest   => './will-contain-tarballs',
  });

=head2 DESCRIPTION

Module::Faker is a tool for building fake CPAN modules and, perhaps more
importantly, fake CPAN distributions.  These are useful for running tools that
operate against CPAN distributions without having to use real CPAN
distributions.  This is much more useful when testing an entire CPAN instance,
rather than a single distribution, for which see L<CPAN::Faker|CPAN::Faker>.

=method make_fakes

  Module::Faker->make_fakes(\%arg);

This method creates a new Module::Faker and builds archives in its destination
directory for every dist-describing file in its source directory.  See the
L</new> method below.

=method new

  my $faker = Module::Faker->new(\%arg);

This create the new Module::Faker.  All arguments may be accessed later by
methods of the same name.  Valid arguments are:

  source - the directory in which to find source files
  dest   - the directory in which to construct dist archives

  dist_class - the class used to fake dists; default: Module::Faker::Dist

The source files are essentially a subset of CPAN::Meta files with some
optional extra features.  All you really require are the name and
abstract.  Other bits like requirements can be specified and will be passed
through.  Out of the box the module will create the main module file based
on the module name and a single test file.  You can either use the provides
section of the CPAN::META file or to specify their contents use the
X_Module_Faker append section.

The X_Module_Faker also allows you to alter the cpan_author from the
default 'LOCAL <LOCAL@cpan.local>' which overrides whatever is in the
usual CPAN::Meta file.

Here is an example yaml specification from the tests,

    name: Append
    abstract: nothing to see here
    provides:
      Provides::Inner:
        file: lib/Provides/Inner.pm
        version: 0.001
      Provides::Inner::Util:
        file: lib/Provides/Inner.pm
    X_Module_Faker:
      cpan_author: SOMEONE
      append:
        - file: lib/Provides/Inner.pm
          content: "\n=head1 NAME\n\nAppend - here I am"
        - file: t/foo.t
          content: |
            use Test::More;
        - file: t/foo.t
          content: "ok(1);"

If you need to sort the packages within a file you
can use an X_Module_Faker:order parameter on the
provides class.

    provides:
      Provides::Inner::Sorted::Charlie:
        file: lib/Provides/Inner/Sorted.pm
        version: 0.008
        X_Module_Faker:
          order: 2
      Provides::Inner::Sorted::Alfa:
        file: lib/Provides/Inner/Sorted.pm
        version: 0.001
        X_Module_Faker:
          order: 1

The supported keys from CPAN::Meta are,

=over

=item *  abstract

=item *  license

=item *  name

=item *  release_status

=item *  version

=item *  provides

=item *  prereqs

=item *  x_authority

=back

=cut

has source => (is => 'ro', required => 1);
has dest   => (is => 'ro', required => 1);
has author_prefix => (is => 'ro', default => 0);

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
    $dist->make_archive({
      dir => $self->dest,
      author_prefix => $self->author_prefix,
    });
  }
}

no Moose;
1;
