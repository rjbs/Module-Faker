use strict;
use warnings;

use Test::More;

use Module::Faker::Dist;
use File::Temp ();

my @expected = qw(
    Makefile.PL
    META.yml
    META.json
);

plan tests => 1 + @expected;

my $MFD = 'Module::Faker::Dist';

my $tmpdir = File::Temp::tempdir(CLEANUP => 1);

my $dist = $MFD->from_file('./eg/Mostly-Auto.yml');

isa_ok($dist, $MFD);

my $dir = $dist->make_dist_dir({ dir => $tmpdir });

for my $f ( @expected ) {
    ok(
    -e "$dir/$f",
    "there's a $f",
    );
}

