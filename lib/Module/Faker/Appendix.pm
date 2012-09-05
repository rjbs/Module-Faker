package Module::Faker::Appendix;
use Moose::Role;
# ABSTRACT: a thing that appends

has append => (
  is => 'ro',
  isa => 'ArrayRef',
  default => sub {[]},
);

around as_string => sub {
  my ($orig, $self) = (shift, shift);
  my $string = $self->$orig(@_);
  $string .= join("\n", @{$self->append});
};

1;
