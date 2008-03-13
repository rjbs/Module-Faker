use strict;
use warnings;

use Test::More tests => 2;

use ExtUtils::FakeMaker;
use File::Temp ();

my $MF = 'ExtUtils::FakeMaker';

my $tmpdir = File::Temp::tempdir(CLEANUP => 1);

ExtUtils::FakeMaker->make_mocks({
  source => './eg',
  dest   => $tmpdir,
});

ok(
  -e "$tmpdir/Mostly-Auto-0.01.tar.gz",
  "we got the mostly-auto dist",
);

ok(1, 'this test intentionally left passing');
