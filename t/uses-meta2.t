use strict;
use warnings;

use Test::More 0.88;

use File::Temp ();
use Parse::CPAN::Meta ();
use Module::Faker::Dist;

my $dist = Module::Faker::Dist->from_file('./eg/Uses-Meta2.json');
my $dir = $dist->make_dist_dir({dir => File::Temp::tempdir(CLEANUP => 1)});

my $meta = Parse::CPAN::Meta->load_file("$dir/META.yml");

is_deeply(
  # 'requires' hash is at the root of the document
  $meta->{requires},
  {
    Foo => 1
  },
  'meta downgraded from spec v2',
);

my $metajson = Parse::CPAN::Meta->load_file("$dir/META.json");

is_deeply
  $metajson->{prereqs},
  {
    runtime => {
      requires => {
        Foo => 1
      },
    },
    configure => {
      requires => {
        Bar => 2.1
      }
    },
  },
  'meta v2 prereqs preserved';

is_deeply
  $metajson->{no_index},
  {
    package => [ 'Uses::Meta2::Secret' ],
  },
  'meta no_index preserved';

done_testing;
