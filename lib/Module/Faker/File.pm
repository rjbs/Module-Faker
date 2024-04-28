package Module::Faker::File;
# ABSTRACT: a fake file in a fake dist

use v5.20.0;
use Moose;
with 'Module::Faker::Appendix';

has filename => (is => 'ro', isa => 'Str', required => 1);
has content  => (is => 'ro', isa => 'Str', required => 1);

sub as_string { shift->content }

no Moose;
1;
