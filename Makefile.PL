
use strict;
use warnings;

use inc::Module::Install;

name          ('Module-Faker');
author        ('Ricardo Signes <rjbs@cpan.org>');
license       ('perl');
all_from      ('lib/Module/Faker.pm');

requires('Archive::Any::Create'      => 0.000); # minimum unknown
requires('File::Next'                => 0.000); # minimum unknown
requires('File::Path'                => 0.000); # minimum unknown
requires('File::Spec'                => 0.000); # minimum unknown
requires('File::Temp'                => 0.000); # minimum unknown
requires('Moose',                    => 0.000); # minimum unknown
requires('Text::Template'            => 0.000); # minimum unknown
requires('YAML::Syck'                => 0.000); # minimum unknown

author_tests('xt');

WriteAll();
