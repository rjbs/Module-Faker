package Module::Faker::File;
use Moose;
with 'Module::Faker::Appendix';

has filename => (is => 'ro', isa => 'Str', required => 1);
has content  => (is => 'ro', isa => 'Str', required => 1);

sub as_string { shift->content }

no Moose;
1;
