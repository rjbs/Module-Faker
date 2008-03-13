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

ok(1, 'this test intentionally left passing');
