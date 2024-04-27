package Meta;
use v5.36.0;

use Data::Fake qw( Core );
use Sub::Exporter -setup => [ qw( fake_cpan_author fake_license ) ];

sub fake_cpan_author {
  sub { Module::Faker::Blaster::Author->new }
}

sub fake_license {
  state @specific = qw(
    agpl_3 apache_1_1 apache_2_0 artistic_1 artistic_2 bsd freebsd gfdl_1_2
    gfdl_1_3 gpl_1 gpl_2 gpl_3 lgpl_2_1 lgpl_3_0 mit mozilla_1_0 mozilla_1_1
    openssl perl_5 qpl_1_0 ssleay sun zlib
  );

  state @general = qw( open_source restricted unrestricted unknown );

  fake_pick(@specific, @general);
}

package Module::Faker::Blaster::Author {
  use Moose;
  use v5.36.0;

  has given_name => (
    is      => 'ro',
    default => sub { Data::Fake::Names::fake_first_name()->() },
  );

  has surname => (
    is      => 'ro',
    default => sub { Data::Fake::Names::fake_surname()->() },
  );

  sub full_name ($self) {
    join q{ }, $self->given_name, $self->surname;
  }

  has pauseid => (
    is    => 'ro',
    lazy  => 1,
    default => sub ($self) {
      uc( substr($self->given_name, 0, 1) . substr($self->surname, 0, 7));
    },
  );

  has email_address => (
    is => 'ro',
    lazy => 1,
    default => sub ($self) {
      lc $self->pauseid . '@fakecpan.org';
    },
  );

  sub name_and_email ($self) {
    sprintf "%s <%s>", $self->full_name, $self->email_address;
  }

  no Moose;
}

1;
