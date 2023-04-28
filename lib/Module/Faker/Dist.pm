package Module::Faker::Dist;
# ABSTRACT: a fake CPAN distribution

use Moose;

use Module::Faker::File;
use Module::Faker::Heavy;
use Module::Faker::Package;
use Module::Faker::Module;

use Archive::Any::Create;
use CPAN::DistnameInfo;
use CPAN::Meta 2.130880; # github issue #9
use CPAN::Meta::Converter;
use CPAN::Meta::Merge;
use CPAN::Meta::Requirements;
use Data::OptList ();
use Encode qw( encode_utf8 );
use File::Temp ();
use File::Path ();
use Parse::CPAN::Meta 1.4401;
use Path::Class;
use Storable qw(dclone);

=head1 SYNOPSIS

Building one dist at a time makes plenty of sense, so Module::Faker::Dist makes
it easy.  Building dists from definitions in files is also useful for doing
things in bulk (see L<CPAN::Faker>), so there are a bunch of ways to build
dists from a definition in a file.

    # Build from a META.yml or META.json file, or the delightful
    # AUTHOR_Foo-Bar-1.234.tar.gz.dist file, which can be zero bytes and gets
    # all the relevant data from the filename.
    my $dist = Module::Faker::Dist->from_file($filename);

META files can contain a key called X_Module_Faker that contains attributes to
use in constructing the dist.  C<dist> files can contain anything you want, but
the contents won't do a thing.

You can use the C<new> method on Module::Faker::Dist, of course, but it's a bit
of a pain.  You might, instead, want to use C<from_struct>, which is very close
to C<new>, but with more sugar.

=cut

=attr name

This is the name of the dist.  It will usually look like C<Foo-Bar>.

=attr version

This is the version of the dist, usually some kind of versiony string like
C<1.234> or maybe C<1.2.3>.

=attr abstract

The abstract!  This is a short, pithy description of the distribution, usually
less than a sentence.

=attr release_status

This is the dist's release status.  (See L<CPAN::Meta::Spec>.)  It defaults to
C<stable> but C<unstable> and C<testing> are valid values.

=cut

my $DEFAULT_VERSION;

# required by CPAN::Meta::Spec
has name           => (is => 'ro', isa => 'Str', required => $DEFAULT_VERSION);
has version        => (is => 'ro', isa => 'Maybe[Str]', default => '0.01');
has abstract       => (is => 'ro', isa => 'Str', default => 'a great new dist');
has release_status => (is => 'ro', isa => 'Str', default => 'stable');

=attr cpan_author

This is the PAUSE id of the author, like C<RJBS>.

=attr archive_ext

This is the extension of the archive to build, when you build an archive.  This
defaults to C<tar.gz>.  C<zip> should work, but right now it doesn't.  So
probably stuck to C<tar.gz>.  It would be cool to support more attributes in
the future.

=attr append

This is an arrayref of hashrefs, each of which looks like:

  { file => $filename, content => $character_string }

The content will be UTF-8 encoded and put into a file with the given name.

This feature is a bit weird.  Maybe it will go away eventually.

=attr mtime

If given, this is the epoch seconds to which to set the mtime of the generated
file.  This is useful in rare occasions.

=cut

# Module::Faker options
has cpan_author  => (is => 'ro', isa => 'Maybe[Str]', default => 'LOCAL');
has archive_ext  => (is => 'ro', isa => 'Str', default => 'tar.gz');
has append       => (is => 'ro', isa => 'ArrayRef[HashRef]', default => sub {[]});
has mtime        => (is => 'ro', isa => 'Int', predicate => 'has_mtime');

=attr x_authority

This is the C<X_Authority> header that gets put into the META files.

=cut

has x_authority => (is => 'ro', isa => 'Str');

=attr license

This is the meta spec license string for the distribution.  It defaults to
C<perl_5>.

=cut

has license => (
  is      => 'ro',
  isa     => 'ArrayRef[Str]',
  default => sub { [ 'perl_5' ] },
);

=attr authors

This is an array of strings who are used as the authors in the dist metadata.
The default is:

  [ "AUTHOR <AUTHOR@cpan.local>" ]

...where C<AUTHOR> is the C<cpan_author> of the dist.

=cut

has authors => (
  isa  => 'ArrayRef[Str]',
  lazy => 1,
  traits  => [ 'Array' ],
  handles => { authors => 'elements' },
  default => sub {
    my ($self) = @_;
    return [ sprintf '%s <%s@cpan.local>', ($self->cpan_author) x 2 ];
  },
);

=attr include_provides_in_meta

This is a bool.  If true, the produced META files will include a C<provides>
key based on the packages in the dist.  It defaults to false, to match the
most common behavior of dists in the wild.

=cut

has include_provides_in_meta => (
  is  => 'ro',
  isa => 'Bool',
  default => 0,
);

=attr provides

This is a hashref that gets used as the C<provides> in the metadata.

If no provided, it is built from the C<packages> provided in construction.

If no packages were provided, for a dist named Foo-Bar, it defaults to:

  { 'Foo::Bar' => { version => $DIST_VERSION, file => "lib/Foo/Bar.pm" } }

=cut

has provides => (
  is => 'ro',
  isa => 'HashRef',
  lazy_build => 1,
);

sub _build_provides {
  my ($self) = @_;

  if ($self->has_packages) {
    return {
      map {; $_->name => {
        file    => $_->in_file,
        (defined $_->version ? (version => $_->version) : ()),
      } } $self->packages
    }
  }

  my $pkg = __dist_to_pkg($self->name);
  return {
    $pkg => {
      version => $self->version,
      file => __pkg_to_file($pkg),
    }
  };
};

sub __dor { defined $_[0] ? $_[0] : $_[1] }

sub append_for {
  my ($self, $filename) = @_;
  return [
    # YAML and JSON should both be in utf8 (if not plain ascii)
    map  { encode_utf8($_->{content}) }
    grep { $filename eq $_->{file} }
      @{ $self->append }
  ];
}

=attr archive_basename

If written to disk, the archive will be written to...

  $dist->archive_basename . '.' . $dist->archive_ext

The default is:

  $dist->name . '.' . ($dist->version // 'undef')

=cut

has archive_basename => (
  is   => 'ro',
  isa  => 'Str',
  lazy => 1,
  default => sub {
    my ($self) = @_;
    return sprintf '%s-%s', $self->name, __dor($self->version, 'undef');
  },
);

=attr omitted_files

If given, this is an arrayref of filenames that shouldn't be automatically
generated and included.

=cut

has omitted_files => (
  isa  => 'ArrayRef[Str]',
  traits  => [ 'Array' ],
  handles => { omitted_files => 'elements' },
  lazy    => 1,
  default => sub { [] },
);

sub __dist_to_pkg { my $str = shift; $str =~ s/-/::/g; return $str; }
sub __pkg_to_file { my $str = shift; $str =~ s{::}{/}g; return "lib/$str.pm"; }

# This is stupid, but copes with MakeMaker wanting to have a module name as its
# NAME parameter.  Ugh! -- rjbs, 2008-03-13
sub _pkgy_name {
  my $name = shift->name;
  $name =~ s/-/::/g;

  return $name;
}

=attr packages

This is an array of L<Module::Faker::Package> objects.  It's built by
C<provides> if needed, but you might want to look at using the
C<L</from_struct>> method to set it up.

=cut

has packages => (
  isa     => 'Module::Faker::Type::Packages',
  lazy    => 1,
  builder => '_build_packages',
  traits  => [ 'Array' ],
  handles => { packages => 'elements' },
  predicate => 'has_packages',
);

sub _build_packages {
  my ($self) = @_;

  my $provides = $self->provides;

  # do this dance so we don't autovivify X_Module_Faker in provides
  my %package_order = map {;
    $_ => (exists $provides->{$_}{X_Module_Faker} ? $provides->{$_}{X_Module_Faker}{order} : 0 )
  } keys %$provides;

  my @pkg_names = do {
    no warnings 'uninitialized';
    sort { $package_order{$a} <=> $package_order{$b} } keys %package_order;
  };

  my @packages;
  for my $name (@pkg_names) {
    push @packages, Module::Faker::Package->new({
      name    => $name,
      version => $provides->{$name}{version},
      in_file => $provides->{$name}{file},
      ($provides->{$name}{style} ? (style => $provides->{$name}{style}) : ()),
    });
  }

  return \@packages;
}

=method modules

This produces and returns a list of L<Module::Faker::Module> objects,
representing modules.  Modules, if you're not as steeped in CPAN toolchain
nonsense, are the C<.pm> files in which packages are defined.

These are produced by combining the packages from C<L</packages>> into files
based on their C<in_file> attributes.

=cut

sub modules {
  my ($self) = @_;

  my %module;
  for my $pkg ($self->packages) {
    my $filename = $pkg->in_file;

    push @{ $module{ $filename } ||= [] }, $pkg;
  }

  my @modules = map {
    Module::Faker::Module->new({
      packages => $module{$_},
      filename => $_,
      append   => $self->append_for($_)
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

=method C<make_dist_dir>

  my $directory_name = $dist->make_dist_dir(\%arg);

This returns the name of a directory into which the dist's contents have been
written.  If a C<dir> argument is provided, the dist will be written to a
directory beneath that dir.  Otherwise, it will be written below a temporary
directory.

=cut

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

=method make_archive

  my $archive_filename = $dist->make_archive(\%arg);

This writes the dist archive file, like a tarball or zip file.  If a C<dir>
argument is given, it will be written in that directory.  Otherwise, it will be
written to a temporary directory.  If the C<author_prefix> argument is given
and true, it will be written under a hashed author dir, like:

  U/US/USERID/Foo-Bar-1.23.tar.gz

=cut

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
  utime time, $self->mtime, $archive_filename if $self->has_mtime;
  return $archive_filename;
}

sub files {
  my ($self) = @_;
  my @files = ($self->modules, $self->_extras, $self->_manifest_file);
  for my $file (@{$self->append}) {
    next if grep { $_->filename eq $file->{file} } @files;
    push(@files,
      $self->_file_class->new(
        filename => $file->{file},
        content  => '',
        append   => $self->append_for($file->{file}),
      ) );
  }
  return @files;
}

sub _file_class { 'Module::Faker::File' }

around BUILDARGS => sub {
  my ($orig, $self, @rest) = @_;
  my $arg = $self->$orig(@rest);

  confess "can't supply both requires and prereqs"
    if $arg->{prereqs} && $arg->{requires};

  if ($arg->{requires}) {
    $arg->{prereqs} = {
      runtime => { requires => delete $arg->{requires} }
    };
  }

  return $arg;
};

sub BUILD {
  my ($self) = @_;
  my $provides = $self->provides;

  $provides->{$_}{file} //= __pkg_to_file($_) for keys %$provides;
}

has prereqs => (
  is   => 'ro',
  isa  => 'HashRef',
  default => sub {  {}  },
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

=attr more_metadata

This can be given as a hashref of data to merge into the CPAN::Meta files.

=cut

has more_metadata => (
  is    => 'ro',
  isa   => 'HashRef',
  predicate => 'has_more_metadata',
);

=attr meta_munger

If given, this is a coderef that's called just before the CPAN::Meta data for
the dist is written to disk, an can be used to change things, especially into
invalid data.  It is expected to return the new content to serialize.

It's called like this:

  $coderef->($struct, { format => $format, version => $version });

...where C<$struct> is the result of C<< $cpan_meta->as_struct >>.
C<$version> is the version number of the target metafile.  Normally, both
version 1.4 and 2 are requested.  C<$format> is either C<yaml> or C<json>.

If the munger returns a string instead of a structure, it will be used as the
content of the file being written.  This lets you put all kinds of nonsense in
those meta files.  Have fun, go nuts!

=cut

has meta_munger => (
  isa => 'CodeRef',
  predicate => 'has_meta_munger',
  traits    => [ 'Code' ],
  handles   => { munge_meta => 'execute' },
);

has _cpan_meta => (
  is => 'ro',
  isa => 'CPAN::Meta',
  lazy_build => 1,
);

sub _build__cpan_meta {
  my ($self) = @_;
  my $meta = {
    'meta-spec' => { version => '2' },
    dynamic_config => 0,
    author => [ $self->authors ], # plural attribute that derefs
  };
  # required fields
  for my $key ( qw/abstract license name release_status version/ ) {
    $meta->{$key} = $self->$key;
  }
  # optional fields
  for my $key ( qw/prereqs x_authority/ ) {
    my $value = $self->$key;
    $meta->{$key} = $value if $value;
  }

  if ($self->provides && $self->include_provides_in_meta) {
    $meta->{provides} = $self->provides;
  }

  my $cpanmeta = CPAN::Meta->new( $meta, {lazy_validation => 1} );
  return $cpanmeta unless $self->has_more_metadata;

  return CPAN::Meta->new(
    CPAN::Meta::Merge->new(default_version => 2)->merge(
      $cpanmeta,
      $self->more_metadata,
    ),
    { lazy_validation => 1 }
  );
}

has _extras => (
  isa  => 'ArrayRef[Module::Faker::File]',
  lazy => 1,
  traits    => [ 'Array' ],
  handles   => { _extras => 'elements' },
  default   => sub {
    my ($self) = @_;
    my @files;

    for my $filename (qw(Makefile.PL t/00-nop.t)) {
      next if grep { $_ eq $filename } $self->omitted_files;
      push @files, $self->_file_class->new({
        filename => $filename,
        content  => Module::Faker::Heavy->_render(
          $filename,
          { dist => $self },
        ),
      });
    }

    unless ( grep { $_ eq 'META.json' } $self->omitted_files ) {
      push @files, $self->_file_class->new({
        filename => 'META.json',
        content  => $self->_meta_file_content(json => 2),
      });
    }

    unless ( grep { $_ eq 'META.yml' } $self->omitted_files ) {
      push @files, $self->_file_class->new({
        filename => 'META.yml',
        content  => $self->_meta_file_content(yaml => 1.4),
      });
    }

    return \@files;
  },
);

# This code is based on the code in CPAN::Meta v2.150010
# -- rjbs, 2019-04-28
sub _meta_file_content {
  my ($self, $format, $version) = @_;

  my $meta = $self->_cpan_meta;

  my $struct;
  if ($meta->meta_spec_version ne $version) {
    $struct = CPAN::Meta::Converter->new($meta->as_struct)
                                   ->convert(version => $version);
  } else {
    $struct = $meta->as_struct;
  }

  if ($self->has_meta_munger) {
    # Is that dclone() paranoia?  Maybe. -- rjbs, 2019-04-28
    $struct = $self->munge_meta(
      dclone($struct),
      {
        format  => $format,
        version => $version
      },
    );

    return $struct unless ref $struct;
  }

  my ($data, $backend);
  if ($format eq 'json') {
    $backend = Parse::CPAN::Meta->json_backend();
    local $struct->{x_serialization_backend} = sprintf '%s version %s',
      $backend, $backend->VERSION;
    $data = $backend->new->pretty->canonical->encode($struct);
  } elsif ($format eq 'yaml') {
    $backend = Parse::CPAN::Meta->yaml_backend();
    local $struct->{x_serialization_backend} = sprintf '%s version %s',
      $backend, $backend->VERSION;
    $data = eval { no strict 'refs'; &{"$backend\::Dump"}($struct) };
    if ( $@ ) {
      croak($backend->can('errstr') ? $backend->errstr : $@);
    }
  } else {
    confess "unknown meta format: $format"
  }

  return $data;
}

=method from_file

  my $dist = Module::Faker::Dist->from_file($filename);

Given a filename with dist configuration, this builds the dist described by the
file.

Given a file ending in C<yaml> or C<yml> or C<json>, it's treated as a
CPAN::Meta file and interpreted as such.  The key C<X_Module_Faker> can be
present to provide attributes that don't match data found in a meta file.

Given a file ending in C<dist>, all the configuration comes from the filename,
which should look like this:

  AUTHOR_Dist-Name-1.234.tar.gz.dist

=cut

# TODO: make this a registry -- rjbs, 2008-03-12
my %HANDLER_FOR = (
  yaml => '_from_meta_file',
  yml  => '_from_meta_file',
  json => '_from_meta_file',
  dist => '_from_distnameinfo'
);

sub from_file {
  my ($self, $filename) = @_;

  my ($ext) = $filename =~ /.*\.(.+?)\z/;

  Carp::croak "don't know how to handle file $filename"
    unless $ext and my $method = $HANDLER_FOR{$ext};

  $self->$method($filename);
}

sub _from_distnameinfo {
  my ($self, $filename) = @_;
  $filename = file($filename)->basename;
  $filename =~ s/\.dist$//;

  my ($author, $path) = split /_/, $filename, 2;

  my $dni = CPAN::DistnameInfo->new($path);

  return $self->new({
    name     => $dni->dist,
    version  => $dni->version,
    abstract => sprintf('the %s dist', $dni->dist),
    archive_ext => $dni->extension,
    cpan_author => $author,
  });
}

sub _from_meta_file {
  my ($self, $filename) = @_;

  my $data = Parse::CPAN::Meta->load_file($filename);
  my $extra = (delete $data->{X_Module_Faker}) || {};
  my $dist = $self->new({ %$data, %$extra });
}

sub _flat_prereqs {
  my ($self) = @_;
  my $prereqs = $self->_cpan_meta->effective_prereqs;
  my $req = CPAN::Meta::Requirements->new;
  for my $phase ( qw/runtime build test/ ) {
    $req->add_requirements( $prereqs->requirements_for( $phase, 'requires' ) );
  }
  return %{ $req->as_string_hash };
}

=method from_struct

  my $dist = Module::Faker::Dist->from_struct(\%arg);

This is sugar over C<new>, working like this:

=for :list
* packages version defaults to the dist version unless specified
* packages for dist Foo-Bar defaults to Foo::Bar unless specified
* if specified, packages is an L<optlist|Data::OptList>

=cut

sub from_struct {
  my ($self, $arg) = @_;

  my $version = exists $arg->{version} ? $arg->{version} : $DEFAULT_VERSION;

  my $specs = Data::OptList::mkopt(
      ! exists $arg->{packages} ? [ __dist_to_pkg($arg->{name}) ]
    : ref $arg->{packages}      ? $arg->{packages}
    : defined $arg->{packages}  ? [ $arg->{packages} ]
    :                             ()
  );

  my @packages;
  for my $spec (@$specs) {
    my %spec = $spec->[1] ? %{ $spec->[1] } : ();

    push @packages, Module::Faker::Package->new({
      name => $spec->[0],
      in_file => __pkg_to_file($spec->[0]), # to be overridden below if needed
      %spec,
      version => (exists $spec{version} ? $spec{version} : $version),
    });
  }

  return $self->new({
    %$arg,
    version   => $version,
    packages  => \@packages,
  });
}

1;

# vim: ts=2 sts=2 sw=2 et:
