package Module::Faker::Dist;
use Moose;

our $VERSION = '0.003';

use Module::Faker::File;
use Module::Faker::Heavy;
use Module::Faker::Package;
use Module::Faker::Module;

use Archive::Any::Create;
use File::Temp ();
use File::Path ();
use YAML::Syck ();

sub __dor { defined $_[0] ? $_[0] : $_[1] }

has name         => (is => 'ro', isa => 'Str', required => 1);
has version      => (is => 'ro', isa => 'Maybe[Str]', default => '0.01');
has abstract     => (is => 'ro', isa => 'Str', default => 'a great new dist');
has cpan_author  => (is => 'ro', isa => 'Maybe[Str]', default => 'LOCAL');
has archive_ext  => (is => 'ro', isa => 'Str', default => 'tar.gz');

has archive_basename => (
  is   => 'ro',
  isa  => 'Str',
  lazy => 1,
  default => sub {
    my ($self) = @_;
    return sprintf '%s-%s', $self->name, __dor($self->version, 'undef');
  },
);

has authors => (
  is  => 'ro',
  isa => 'ArrayRef[Str]',
  auto_deref => 1,
  default    => sub { [ 'Local Author <local@cpan.local>' ] },
);

sub __dist_to_pkg { my $str = shift; $str =~ s/-/::/g; return $str; }
sub __pkg_to_file { my $str = shift; $str =~ s{::}{/}g; return "lib/$str.pm"; }

# This is stupid, but copes with MakeMaker wanting to have a module name as its
# NAME paramter.  Ugh! -- rjbs, 2008-03-13
sub _pkgy_name {
  my $name = shift->name;
  $name =~ s/-/::/;

  return $name;
}

has provides => (
  is     => 'ro',
  isa    => 'Module::Faker::Type::Packages',
  lazy   => 1,
  coerce => 1,
  required   => 1,
  default    => sub {
    my ($self) = @_;
    my $pkg = __dist_to_pkg($self->name);
    return [
      Module::Faker::Package->new({
        name    => $pkg,
        version => $self->version,
        in_file => __pkg_to_file($pkg),
      })
    ]
  },
  auto_deref => 1,
);

sub modules {
  my ($self) = @_;

  my %module;
  for my $pkg ($self->provides) {
    my $filename = $pkg->in_file;

    push @{ $module{ $filename } ||= [] }, $pkg;
  }

  my @modules = map {
    Module::Faker::Module->new({
      packages => $module{$_},
      filename => $_,
    });
  } keys %module;

  return @modules;
}

sub _mk_container_path {
  my ($self, $filename) = @_;

  my (@parts) = File::Spec->splitdir($filename);
  my $leaf_filename = pop @parts;
  File::Path::mkpath(File::Spec->catdir(@parts));
}

sub make_dist_dir {
  my ($self, $arg) = @_;
  $arg ||= {};

  my $dir = $arg->{dir} || File::Temp::tempdir;
  my $dist_dir = File::Spec->catdir($dir, $self->archive_basename);

  for my $file ($self->files) {
    my $fqfn = File::Spec->catfile($dist_dir, $file->filename);
    $self->_mk_container_path($fqfn);

    open my $fh, '>', $fqfn or die "couldn't open $fqfn for writing: $!";
    print $fh $file->as_string;
    close $fh or die "error when closing $fqfn: $!";
  }

  return $dist_dir;
}

sub _author_dir_infix {
  my ($self) = @_;

  Carp::croak "can't put archive in author dir with no author defined"
    unless my $pauseid = $self->cpan_author;
  
  # Sorta like pow- pow- power-wheels! -- rjbs, 2008-03-14
  my ($pa, $p) = $pauseid =~ /^((.).)/;
  return ($p, $pa, $pauseid);
}

sub archive_filename {
  my ($self, $arg) = @_;

  my $base = $self->archive_basename;
  my $ext  = $self->archive_ext;

  return File::Spec->catfile(
    ($arg->{author_prefix} ? $self->_author_dir_infix : ()),
    "$base.$ext",
  );
}

sub make_archive {
  my ($self, $arg) = @_;
  $arg ||= {};

  my $dir = $arg->{dir} || File::Temp::tempdir;

  my $archive   = Archive::Any::Create->new;
  my $container = $self->archive_basename;

  $archive->container($container);

  for my $file ($self->files) {
    $archive->add_file($file->filename, $file->as_string);
  }

  my $archive_filename = File::Spec->catfile(
    $dir,
    $self->archive_filename({ author_prefix => $arg->{author_prefix} })
  );

  $self->_mk_container_path($archive_filename);
  $archive->write_file($archive_filename);

  return $archive_filename;
}

sub files {
  my ($self) = @_;
  return ($self->modules, $self->_extras, $self->_manifest_file);
}

sub _file_class { 'Module::Faker::File' }

has requires => (
  is   => 'ro',
  isa  => 'HashRef',
  lazy => 1,
  default    => sub { {} },
  auto_deref => 1,
);

has _manifest_file => (
  is   => 'ro',
  isa  => 'Module::Faker::File',
  lazy => 1,
  default => sub {
    my ($self) = @_;
    my @files = ($self->modules, $self->_extras);

    return $self->_file_class->new({
      filename => 'MANIFEST',
      content  => join("\n",
        'MANIFEST',
        map { $_->filename } @files
      ),
    });
  },
);
    
has _extras => (
  is   => 'ro',
  isa  => 'ArrayRef[Module::Faker::File]',
  lazy => 1,
  auto_deref => 1,
  default    => sub {
    my ($self) = @_;
    my @files;

    for my $filename (qw(Makefile.PL META.yml t/00-nop.t)) {
      push @files, $self->_file_class->new({
        filename => $filename,
        content  => Module::Faker::Heavy->_render(
          $filename,
          { dist => $self },
        ),
      });
    }

    return \@files;
  },
);

# TODO: make this a registry -- rjbs, 2008-03-12
my %HANDLER_FOR = (
  yaml => '_from_yaml_file',
  yml  => '_from_yaml_file',
);

sub from_file {
  my ($self, $filename) = @_;

  my ($ext) = $filename =~ /\.(.+?)\z/;

  Carp::croak "don't know how to handle file $filename"
    unless $ext and my $method = $HANDLER_FOR{$ext};

  $self->$method($filename);
}

sub _from_yaml_file {
  my ($self, $filename) = @_;

  my $data = YAML::Syck::LoadFile($filename);
  my $dist = $self->new($data);
}

1;
