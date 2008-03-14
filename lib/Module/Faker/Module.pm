package Module::Faker::Module;
use Moose;

our $VERSION = '0.003';

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

  for my $pkg ($self->packages) {
    $string .= sprintf "package %s;\n", $pkg->name;
    $string .= sprintf "our \$VERSION = '%s';\n", $pkg->version
      if defined $pkg->version;

    if (defined $pkg->abstract) {
      $string .= sprintf "\n=head1 NAME\n\n%s - %s\n\n=cut\n\n",
        $pkg->name, $pkg->abstract
    }
  }

  $string .= "1\n";
}

no Moose;
1;
