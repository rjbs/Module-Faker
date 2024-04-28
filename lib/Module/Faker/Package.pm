package Module::Faker::Package;
# ABSTRACT: a faked package in a faked module

use v5.20.0;
use Moose;

use Moose::Util::TypeConstraints;

has name     => (is => 'ro', isa => 'Str', required => 1);
has version  => (is => 'ro', isa => 'Maybe[Str]');
has abstract => (is => 'ro', isa => 'Maybe[Str]');

has in_file  => (
  is       => 'ro',
  isa      => 'Str',
  lazy     => 1,
  default  => sub {
    my ($self) = @_;
    my $name = $self->name;
    $name =~ s{::}{/}g;
    return "lib/$name";
  },
);

# PKGWORD = package | class | role
# VERSION = our | our-literal | inline
# STYLE   = statement | block
#
#                           STYLE         VERSION
# PW N;  our $V = '...';    statement     our
# PW N;  our $V =  ... ;    statement     our-literal
# PW N V;                   statement     inline
# PW N { our $V = '...' }   block         our
# PW N { our $V =  ...  }   block         our-literal
# PW N V { ... }            block         inline

has layout => (
  reader  => '_layout',
  default => sub {
    return { pkgword => 'package', version => 'our', style => 'statement' };
  },
);

my %STYLE_TEMPLATE = (
  'statement_our'         =>  [ "PKGWORD PKGNAME;\nour \$VERSION = 'VERSIONSTR';",
                                "PKGWORD PKGNAME;",
                              ],
  'statement_our-literal' =>  [ "PKGWORD PKGNAME;\nour \$VERSION = VERSIONSTR;",
                                "PKGWORD PKGNAME;",
                              ],
  'statement_inline'      =>  [ "PKGWORD PKGNAME VERSIONSTR;",
                                "PKGWORD PKGNAME;",
                              ],
  'block_our'             =>  [ "PKGWORD PKGNAME {\n  our \$VERSION = 'VERSIONSTR';\n  # code!\n}",
                                "PKGWORD PKGNAME {\n  #code!\n}",
                              ],
  'block_our-literal'     =>  [ "PKGWORD PKGNAME {\n  our \$VERSION = VERSIONSTR;\n  # code!\n}",
                                "PKGWORD PKGNAME {\n  #code!\n}",
                              ],
  'block_inline'          =>  [ "PKGWORD PKGNAME VERSIONSTR {\n  # code!\n}",
                                "PKGWORD PKGNAME {\n  #code!\n}",
                              ],
);

my %KNOWN_KEY     = map {; $_ => 1 } qw(pkgword version style);
my %KNOWN_PKGWORD = map {; $_ => 1 } qw(package class role);

sub as_string {
  my ($self) = @_;

  my $layout = $self->_layout;

  my (@unknown) = grep {; ! $KNOWN_KEY{$_} } keys %$layout;
  if (@unknown) {
    Carp::confess("Unknown entries in package layout: @unknown");
  }

  my $layout_pkgword = $layout->{pkgword} // 'package';
  my $layout_version = $layout->{version} // 'our';
  my $layout_style   = $layout->{style}   // 'statement';

  unless ($KNOWN_PKGWORD{$layout_pkgword}) {
    Carp::confess("Invalid value for package layout's pkgword");
  }

  my $version = $self->version;
  my $name    = $self->name;

  my $key = join q{_}, $layout_style, $layout_version;

  my $template_pair = $STYLE_TEMPLATE{$key};
  confess("Can't handle style/version combination in package layout")
    unless $template_pair;

  my $template = $template_pair->[ defined $version ? 0 : 1 ];

  my $body = $template  =~ s/PKGWORD/$layout_pkgword/r
                        =~ s/PKGNAME/$name/r
                        =~ s/VERSIONSTR/$version/r;

  return $body;
}

subtype 'Module::Faker::Type::Packages'
  => as 'ArrayRef[Module::Faker::Package]';

no Moose;
1;
