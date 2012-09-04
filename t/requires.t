use strict;
use warnings;

use Test::More tests => 1;

use Module::Faker::Dist;

my $dist = Module::Faker::Dist->from_file('./eg/Simple-Prereq.yml');
my $dir = $dist->make_dist_dir;
open my $fh, '<', "$dir/Makefile.PL" or die "Can't open $dir/Makefile.PL: $!";
my $data = do { local $/; <$fh> };

($data) = $data =~ /^  PREREQ_PM => \{(.+?)\n  \}/ms;
my %p = eval $data;
die $@ if $@;
is_deeply(
  \%p,
  {
    'Mostly::Auto' => '1.00',
    'Provides::Inner' => '0',
  },
  'PREREQ_PM extracted',
);
