use strict;
use warnings;

use Test::More tests => 1;

use ExtUtils::MockMaker;
use File::Temp ();

my $MM = 'ExtUtils::MockMaker';

# # XXX: Obviously we will clean this up in the future -- rjbs, 2008-03-12
# my $tmpdir = File::Temp::tempdir(CLEANUP => 0);
# 
# ExtUtils::MockMaker->make_mocks({
#   source => './eg',
#   dest   => $tmpdir,
# });

for my $file ('eg/MetaVersion.yaml', 'eg/ProvidesInner.yaml') {
  my $dist = $MM->dist_from_file($file);

  for my $file ($dist->files) {
    diag "=== " . $file->filename . " ===\n";
    diag $file->as_string;
  }

  # diag $dist->make_dist;
}

ok(1, 'this test intentionally left passing');
