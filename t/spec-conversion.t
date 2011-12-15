use strict;
use warnings;

use Test::More tests => 1;

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
