package Module::Faker::File;
use Moose;

our $VERSION = '0.004';

has filename => (is => 'ro', isa => 'Str', required => 1);
has content  => (is => 'ro', isa => 'Str', required => 1);

sub as_string { shift->content }

no Moose;
1;
