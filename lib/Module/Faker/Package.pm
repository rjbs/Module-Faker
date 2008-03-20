package Module::Faker::Package;
use Moose;

our $VERSION = '0.005';

use Moose::Util::TypeConstraints;

has name     => (is => 'ro', isa => 'Str', required => 1);
has version  => (is => 'ro', isa => 'Maybe[Str]');
has abstract => (is => 'ro', isa => 'Maybe[Str]');

has in_file  => (
  is       => 'ro',
  isa      => 'Str',
  lazy     => 1,
  default  => sub {
    my ($self) = @_;
    my $name = $self->name;
    $name =~ s{::}{/}g;
    return "lib/$name";
  },
);

subtype 'Module::Faker::Type::Packages'
  => as 'ArrayRef[Module::Faker::Package]';

coerce 'Module::Faker::Type::Packages'
  => from 'HashRef'
  => via  {
    my ($href) = @_;
    my @packages;

    my @pkg_names = do {
      no warnings 'uninitialized';
      sort { $href->{$a}{Faker}{order} <=> $href->{$b}{Faker}{order} } keys %$href;
    };

    for my $name (@pkg_names) {
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
