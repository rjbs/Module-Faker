use strict;
use warnings;

use Test::More tests => 2;

use Module::Faker;
use File::Temp ();

my $MF = 'Module::Faker';

my $tmpdir = File::Temp::tempdir(CLEANUP => 1);

$MF->make_fakes({
  source => './eg',
  dest   => $tmpdir,
});

ok(
  -e "$tmpdir/Mostly-Auto-0.01.tar.gz",
  "we got the mostly-auto dist",
);

my $dist = Module::Faker::Dist->from_file('./eg/RJBS-Dist.yaml');
is($dist->cpan_author, 'RJBS', "get cpan author from Faker section");
