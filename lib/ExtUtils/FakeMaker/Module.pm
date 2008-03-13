package ExtUtils::FakeMaker::Module;
use Moose;

use ExtUtils::FakeMaker::Package;

has filename => (
  is  => 'ro',
  isa => 'Str',
  required => 1,
);

has packages => (
  is         => 'ro',
  isa        => 'ArrayRef[ExtUtils::FakeMaker::Package]',
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
