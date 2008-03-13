package ExtUtils::MockMaker::Module;
use Moose;

use ExtUtils::MockMaker::Package;

has filename => (
  is  => 'ro',
  isa => 'Str',
  required => 1,
);

has packages => (
  is         => 'ro',
  isa        => 'ArrayRef[ExtUtils::MockMaker::Package]',
  required   => 1,
  auto_deref => 1,
);

sub as_string {
  my ($self) = @_;

  my $string = '';

  for my $package ($self->packages) {
    $string .= sprintf "package %s;\n", $package->name;

    $string .= sprintf "our \$VERSION = '%s';\n", $package->version
      if defined $package->version;
  }

  $string .= "1\n";
}

no Moose;
1;
