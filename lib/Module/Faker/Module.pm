package Module::Faker::Module;
# ABSTRACT: a faked module

use Moose;
with 'Module::Faker::Appendix';

use Module::Faker::Package;

has filename => (
  is  => 'ro',
  isa => 'Str',
  required => 1,
);

has packages => (
  is         => 'ro',
  isa        => 'ArrayRef[Module::Faker::Package]',
  required   => 1,
  auto_deref => 1,
);

sub as_string {
  my ($self) = @_;

  my $string = '';

  my @packages = $self->packages;

  for ($packages[0]) {
    $string .= sprintf "\n=head1 NAME\n\n%s - %s\n\n=cut\n\n",
      $_->name, $_->abstract // 'a cool package';
  }

  for my $pkg ($self->packages) {
    $string .= $pkg->as_string . "\n";
  }

  $string .= "1\n";
}

no Moose;
1;
