package Meta;
use v5.36.0;

use Data::Fake qw( Core Dates );
use List::Util qw(uniq);
use Sub::Exporter -setup => [ qw(
  fake_cpan_author
  fake_license
  fake_package_names
  fake_version
) ];

use Vocab qw(noun adj);

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

my sub make_identifier ($str) {
  my @bits = split /[^A-Za-z0-9_]/, $str;
  join q{}, map {; ucfirst } @bits;
}

sub fake_package_names ($n) {
  return unless $n >= 1;

  my @base = map { make_identifier( noun() ) } (1 .. fake_int(1,2)->());

  my @names = join q{::}, @base;

  my @adjs = uniq map {; make_identifier( adj() ) } (1 .. $n-1);
  push @names, map {; join q{::}, $names[0], $_ } @adjs;

  return @names;
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

my @v_generators = (
  sub {
    # n.nnn
    my $ver_x = int rand 10;
    my $ver_y = int rand 1000;

    return sprintf '%d.%03d', $ver_x, $ver_y;
  },
  sub {
    # YYYYMMDD.nnn
    my $date = fake_past_datetime('%Y%m%d')->();
    return sprintf '%d.%03d', $date, int rand 1000;
  },
  sub {
    # x.y.z
    return join q{.}, map {; int rand 20 } (1..3);
  },
);

sub fake_version {
  fake_pick(@v_generators);
}

1;
