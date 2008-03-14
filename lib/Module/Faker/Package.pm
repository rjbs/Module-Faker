package Module::Faker::Package;
use Moose;

our $VERSION = '0.003';

use Moose::Util::TypeConstraints;

has name     => (is => 'ro', isa => 'Str', required => 1);
has version  => (is => 'ro', isa => 'Maybe[Str]');
has abstract => (is => 'ro', isa => 'Maybe[Str]');

# TODO: default this in from name -- rjbs, 2008-03-12
has in_file => (is => 'ro', isa => 'Str', required => 1);

subtype 'Module::Faker::Type::Packages'
  => as 'ArrayRef[Module::Faker::Package]';

coerce 'Module::Faker::Type::Packages'
  => from 'HashRef'
  => via  {
    my ($href) = @_;
    my @packages;
    for my $name (keys %$href) {
      push @packages, __PACKAGE__->new({
        name    => $name,
        version => $href->{$name}{version},
        in_file => $href->{$name}{file},
      });
    }
    return \@packages;
  };

no Moose;
1;
