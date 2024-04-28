package Data::Fake::CPAN;
use v5.36.0;

use Data::Fake qw( Core Dates );
use List::Util qw(uniq);

use Sub::Exporter -setup => {
  groups  => { default => [ '-all' ] },
  exports => [ qw(
    fake_cpan_author
    fake_cpan_distribution
    fake_license
    fake_package_names
    fake_prereqs
    fake_version
  ) ],
};

sub fake_cpan_author {
  sub { Module::Faker::Blaster::Author->new }
}

my sub _package ($name) {
  state $config = {
    layout => {
      pkgword => fake_weighted(
        [ package => 4 ],
        [ class   => 1 ],
        [ role    => 1 ],
      )->(),
      style   => fake_pick(qw( statement block ))->(),
      version => fake_pick(qw( our our-literal inline ))->(),
    },
  };

  return $name => $config;
}

sub fake_cpan_distribution {
  sub {
    my @package_names = fake_package_names(fake_int(1,6)->())->();

    my $author  = fake_cpan_author()->();

    my $ext = fake_weighted(
      [ 'tar.gz' => 4 ],
      [ zip      => 1 ],
    )->();

    my $dist = Module::Faker::Dist->from_struct({
      name    => ($package_names[0] =~ s/::/-/gr),
      version => fake_version()->(),
      authors     => [ $author->name_and_email ],
      cpan_author => $author->pauseid,
      license     => [ fake_license()->() ],
      archive_ext => $ext,
      packages    => [ map {; _package($_) } sort @package_names ],
      prereqs     => fake_prereqs()->(),
    });
  }
}

sub fake_license {
  state @specific = qw(
    agpl_3 apache_1_1 apache_2_0 artistic_1 artistic_2 bsd freebsd gfdl_1_2
    gfdl_1_3 gpl_1 gpl_2 gpl_3 lgpl_2_1 lgpl_3_0 mit mozilla_1_0 mozilla_1_1
    openssl perl_5 qpl_1_0 ssleay sun zlib
  );

  state @general = qw( open_source restricted unrestricted unknown );

  fake_pick(@specific, @general);
}

my sub make_identifier ($str) {
  my @bits = split /[^A-Za-z0-9_]/, $str;
  join q{}, map {; ucfirst } @bits;
}

sub fake_package_names ($n) {
  return unless $n >= 1;

  sub {
    my @base = map { make_identifier( _noun() ) } (1 .. fake_int(1,2)->());
    my @names = join q{::}, @base;

    my @adjs = uniq map {; make_identifier( _adj() ) } (1 .. $n-1);
    push @names, map {; join q{::}, $names[0], $_ } @adjs;

    return @names;
  }
}

sub fake_prereqs {
  sub {
    my %prereqs;

    my $mk_phase = fake_weighted(
      [ configure =>  1 ],
      [ runtime   => 10 ],
      [ build     =>  2 ],
      [ test      =>  3 ],
      [ develop   =>  2 ],
    );

    my $mk_type = fake_weighted(
      [ conflicts   =>  1 ],
      [ recommends  =>  3 ],
      [ requires    => 15 ],
      [ suggests    =>  1 ],
    );

    for (1 .. fake_int(0, 20)->()) {
      my $phase = $mk_phase->();
      my $type  = $mk_type->();

      my ($package) = fake_package_names(1)->();
      $prereqs{$phase}{$type}{$package} = fake_version()->();
    }

    return \%prereqs;
  }
}

package Module::Faker::Blaster::Author {
  use Moose;
  use v5.36.0;

  has given_name => (
    is      => 'ro',
    default => sub { Data::Fake::Names::fake_first_name()->() },
  );

  has surname => (
    is      => 'ro',
    default => sub { Data::Fake::Names::fake_surname()->() },
  );

  sub full_name ($self) {
    join q{ }, $self->given_name, $self->surname;
  }

  has pauseid => (
    is    => 'ro',
    lazy  => 1,
    default => sub ($self) {
      uc( substr($self->given_name, 0, 1) . substr($self->surname, 0, 7));
    },
  );

  has email_address => (
    is => 'ro',
    lazy => 1,
    default => sub ($self) {
      lc $self->pauseid . '@fakecpan.org';
    },
  );

  sub name_and_email ($self) {
    sprintf "%s <%s>", $self->full_name, $self->email_address;
  }

  no Moose;
}

my @v_generators = (
  sub {
    # n.nnn
    my $ver_x = int rand 10;
    my $ver_y = int rand 1000;

    return sprintf '%d.%03d', $ver_x, $ver_y;
  },
  sub {
    # YYYYMMDD.nnn
    my $date = fake_past_datetime('%Y%m%d')->();
    return sprintf '%d.%03d', $date, int rand 1000;
  },
  sub {
    # x.y.z
    return join q{.}, map {; int rand 20 } (1..3);
  },
);

sub fake_version {
  fake_pick(@v_generators);
}

my @ADJECTIVES = qw(
  abandoned able absolute adorable adventurous academic acceptable acclaimed
  accomplished accurate aching acidic acrobatic active actual adept admirable
  admired adolescent adorable adored advanced afraid affectionate aged
  aggravating aggressive agile agitated agonizing agreeable ajar alarmed
  alarming alert alienated alive all altruistic amazing ambitious ample amused
  amusing anchored ancient angelic angry anguished animated annual another
  antique anxious any apprehensive appropriate apt arctic arid aromatic
  artistic ashamed assured astonishing athletic attached attentive attractive
  austere authentic authorized automatic avaricious average aware awesome
  awful awkward babyish bad back baggy bare barren basic beautiful belated
  beloved beneficial better best bewitched big big-hearted biodegradable
  bite-sized bitter black black-and-white bland blank blaring bleak blind
  blissful blond blue blushing bogus boiling bold bony boring bossy both
  bouncy bountiful bowed brave breakable brief bright brilliant brisk broken
  bronze brown bruised bubbly bulky bumpy buoyant burdensome burly bustling
  busy buttery buzzing calculating calm candid canine capital carefree careful
  careless caring cautious cavernous celebrated charming cheap cheerful cheery
  chief chilly chubby circular classic clean clear clear-cut clever close
  closed cloudy clueless clumsy cluttered coarse cold colorful colorless
  colossal comfortable common compassionate competent complete complex
  complicated composed concerned concrete confused conscious considerate
  constant content conventional cooked cool cooperative coordinated corny
  corrupt costly courageous courteous crafty crazy creamy creative creepy
  criminal crisp critical crooked crowded cruel crushing cuddly cultivated
  cultured cumbersome curly curvy cute cylindrical damaged damp dangerous
  dapper daring darling dark dazzling dead deadly deafening dear dearest
  decent decimal decisive deep defenseless defensive defiant deficient
  definite definitive delayed delectable delicious delightful delirious
  demanding dense dental dependable dependent descriptive deserted detailed
  determined devoted different difficult digital diligent dim dimpled
  dimwitted direct disastrous discrete disfigured disgusting disloyal dismal
  distant downright dreary dirty disguised dishonest dismal distant distinct
  distorted dizzy dopey doting double downright drab drafty dramatic dreary
  droopy dry dual dull dutiful each eager earnest early easy easy-going
  ecstatic edible educated elaborate elastic elated elderly electric elegant
  elementary elliptical embarrassed embellished eminent emotional empty
  enchanted enchanting energetic enlightened enormous enraged entire envious
  equal equatorial essential esteemed ethical euphoric even evergreen
  everlasting every evil exalted excellent exemplary exhausted excitable
  excited exciting exotic expensive experienced expert extraneous extroverted
  extra-large extra-small fabulous failing faint fair faithful fake false
  familiar famous fancy fantastic far faraway far-flung far-off fast fat fatal
  fatherly favorable favorite fearful fearless feisty feline female feminine
  few fickle filthy fine finished firm first firsthand fitting fixed flaky
  flamboyant flashy flat flawed flawless flickering flimsy flippant flowery
  fluffy fluid flustered focused fond foolhardy foolish forceful forked formal
  forsaken forthright fortunate fragrant frail frank frayed free French fresh
  frequent friendly frightened frightening frigid frilly frizzy frivolous
  front frosty frozen frugal fruitful full fumbling functional funny fussy
  fuzzy gargantuan gaseous general generous gentle genuine giant giddy
  gigantic gifted giving glamorous glaring glass gleaming gleeful glistening
  glittering gloomy glorious glossy glum golden good good-natured gorgeous
  graceful gracious grand grandiose granular grateful grave gray great greedy
  green gregarious grim grimy gripping grizzled gross grotesque grouchy
  grounded growing growling grown grubby gruesome grumpy guilty gullible gummy
  hairy half handmade handsome handy happy happy-go-lucky hard hard-to-find
  harmful harmless harmonious harsh hasty hateful haunting healthy heartfelt
  hearty heavenly heavy hefty helpful helpless hidden hideous high high-level
  hilarious hoarse hollow homely honest honorable honored hopeful horrible
  hospitable hot huge humble humiliating humming humongous hungry hurtful
  husky icky icy ideal idealistic identical idle idiotic idolized ignorant ill
  illegal ill-fated ill-informed illiterate illustrious imaginary imaginative
  immaculate immaterial immediate immense impassioned impeccable impartial
  imperfect imperturbable impish impolite important impossible impractical
  impressionable impressive improbable impure inborn incomparable incompatible
  incomplete inconsequential incredible indelible inexperienced indolent
  infamous infantile infatuated inferior infinite informal innocent insecure
  insidious insignificant insistent instructive insubstantial intelligent
  intent intentional interesting internal international intrepid ironclad
  irresponsible irritating itchy jaded jagged jam-packed jaunty jealous
  jittery joint jolly jovial joyful joyous jubilant judicious juicy jumbo
  junior jumpy juvenile kaleidoscopic keen key kind kindhearted kindly klutzy
  knobby knotty knowledgeable knowing known kooky kosher lame lanky large last
  lasting late lavish lawful lazy leading lean leafy left legal legitimate
  light lighthearted likable likely limited limp limping linear lined liquid
  little live lively livid loathsome lone lonely long long-term loose lopsided
  lost loud lovable lovely loving low loyal lucky lumbering luminous lumpy
  lustrous luxurious mad made-up magnificent majestic major male mammoth
  married marvelous masculine massive mature meager mealy mean measly meaty
  medical mediocre medium meek mellow melodic memorable menacing merry messy
  metallic mild milky mindless miniature minor minty miserable miserly
  misguided misty mixed modern modest moist monstrous monthly monumental moral
  mortified motherly motionless mountainous muddy muffled multicolored mundane
  murky mushy musty muted mysterious naive narrow nasty natural naughty
  nautical near neat necessary needy negative neglected negligible neighboring
  nervous new next nice nifty nimble nippy nocturnal noisy nonstop normal
  notable noted noteworthy novel noxious numb nutritious nutty obedient obese
  oblong oily oblong obvious occasional odd oddball offbeat offensive official
  old old-fashioned only open optimal optimistic opulent orange orderly
  organic ornate ornery ordinary original other our outlying outgoing
  outlandish outrageous outstanding oval overcooked overdue overjoyed
  overlooked palatable pale paltry parallel parched partial passionate past
  pastel peaceful peppery perfect perfumed periodic perky personal pertinent
  pesky pessimistic petty phony physical piercing pink pitiful plain plaintive
  plastic playful pleasant pleased pleasing plump plush polished polite
  political pointed pointless poised poor popular portly posh positive
  possible potable powerful powerless practical precious present prestigious
  pretty precious previous pricey prickly primary prime pristine private prize
  probable productive profitable profuse proper proud prudent punctual pungent
  puny pure purple pushy putrid puzzled puzzling quaint qualified quarrelsome
  quarterly queasy querulous questionable quick quick-witted quiet
  quintessential quirky quixotic quizzical radiant ragged rapid rare rash raw
  recent reckless rectangular ready real realistic reasonable red reflecting
  regal regular reliable relieved remarkable remorseful remote repentant
  required respectful responsible repulsive revolving rewarding rich rigid
  right ringed ripe roasted robust rosy rotating rotten rough round rowdy
  royal rubbery rundown ruddy rude runny rural rusty sad safe salty same sandy
  sane sarcastic sardonic satisfied scaly scarce scared scary scented
  scholarly scientific scornful scratchy scrawny second secondary second-hand
  secret self-assured self-reliant selfish sentimental separate serene serious
  serpentine several severe shabby shadowy shady shallow shameful shameless
  sharp shimmering shiny shocked shocking shoddy short short-term showy shrill
  shy sick silent silky silly silver similar simple simplistic sinful single
  sizzling skeletal skinny sleepy slight slim slimy slippery slow slushy small
  smart smoggy smooth smug snappy snarling sneaky sniveling snoopy sociable
  soft soggy solid somber some spherical sophisticated sore sorrowful soulful
  soupy sour Spanish sparkling sparse specific spectacular speedy spicy spiffy
  spirited spiteful splendid spotless spotted spry square squeaky squiggly
  stable staid stained stale standard starchy stark starry steep sticky stiff
  stimulating stingy stormy straight strange steel strict strident striking
  striped strong studious stunning stupendous stupid sturdy stylish subdued
  submissive substantial subtle suburban sudden sugary sunny super superb
  superficial superior supportive sure-footed surprised suspicious svelte
  sweaty sweet sweltering swift sympathetic tall talkative tame tan tangible
  tart tasty tattered taut tedious teeming tempting tender tense tepid
  terrible terrific testy thankful that these thick thin third thirsty this
  thorough thorny those thoughtful threadbare thrifty thunderous tidy tight
  timely tinted tiny tired torn total tough traumatic treasured tremendous
  tragic trained tremendous triangular tricky trifling trim trivial troubled
  true trusting trustworthy trusty truthful tubby turbulent twin ugly ultimate
  unacceptable unaware uncomfortable uncommon unconscious understated
  unequaled uneven unfinished unfit unfolded unfortunate unhappy unhealthy
  uniform unimportant unique united unkempt unknown unlawful unlined unlucky
  unnatural unpleasant unrealistic unripe unruly unselfish unsightly unsteady
  unsung untidy untimely untried untrue unused unusual unwelcome unwieldy
  unwilling unwitting unwritten upbeat upright upset urban usable used useful
  useless utilized utter vacant vague vain valid valuable vapid variable vast
  velvety venerated vengeful verifiable vibrant vicious victorious vigilant
  vigorous villainous violet violent virtual virtuous visible vital vivacious
  vivid voluminous wan warlike warm warmhearted warped wary wasteful watchful
  waterlogged watery wavy wealthy weak weary webbed wee weekly weepy weighty
  weird welcome well-documented well-groomed well-informed well-lit well-made
  well-off well-to-do well-worn wet which whimsical whirlwind whispered white
  whole whopping wicked wide wide-eyed wiggly wild willing wilted winding
  windy winged wiry wise witty wobbly woeful wonderful wooden woozy wordy
  worldly worn worried worrisome worse worst worthless worthwhile worthy
  wrathful wretched writhing wrong wry yawning yearly yellow yellowish young
  youthful yummy zany zealous zesty
);

my @NOUNS = qw(
  ability accident activity actor ad addition administration advertising
  advice agency agreement airport alcohol analysis anxiety apartment
  appearance application appointment area argument army arrival art article
  aspect assistance association assumption atmosphere attention attitude
  audience awareness baseball basis basket bath bird blood bonus boyfriend
  bread breath buyer cabinet camera cancer candidate category cell chapter
  charity chemistry chest child childhood chocolate church cigarette city
  classroom climate clothes coffee collection college combination committee
  communication community comparison competition complaint computer concept
  conclusion confusion connection construction context contract contribution
  control conversation cookie country county courage cousin criticism currency
  customer dad data database dealer death debt decision definition delivery
  department depression depth description desk development device difference
  difficulty dinner direction director disaster discussion disease disk
  distribution drama drawer drawing driver economics editor education
  efficiency effort election elevator emotion emphasis employee employer
  employment energy engine engineering entertainment enthusiasm entry
  environment equipment error establishment estate event exam examination
  excitement explanation expression extent fact failure family farmer feedback
  finding fishing flight food football foundation freedom garbage gate girl
  goal government grandmother grocery growth guest guidance guitar hair hall
  health hearing heart height highway historian history homework honey
  hospital hotel housing idea imagination importance impression improvement
  income independence industry inflation information initiative injury insect
  inspection inspector instance instruction insurance interaction internet
  introduction investment judgment king knowledge lab ladder lake language law
  leader leadership length library literature location loss love magazine
  maintenance mall management manager manufacturer map marketing marriage math
  meal meaning measurement meat media medicine member membership memory menu
  message method mixture mode mom moment month mood movie mud music nation
  nature news newspaper night office operation opinion opportunity orange
  organization outcome oven owner painting paper passion patience payment
  penalty people percentage perception performance permission person
  personality perspective philosophy phone photo physics piano pie player poem
  poetry police policy politics population possession possibility potato power
  preference preparation presence presentation president priority problem
  procedure product profession professor promotion property proposal
  protection psychology quality quantity queen ratio reaction reading reality
  reception recipe recommendation recording reflection refrigerator region
  relation relationship replacement republic requirement resolution resource
  response responsibility restaurant revenue revolution river road role safety
  salad sample satisfaction scene science secretary sector security selection
  series session setting shopping signature significance singer sister
  situation skill society software solution son song soup speech statement
  steak storage story strategy student studio success suggestion supermarket
  system tea teacher teaching technology television temperature tennis tension
  thanks theory thing thought tongue tooth topic town tradition transportation
  truth two understanding union unit university user variation variety vehicle
  version video village virus volume warning way weakness wealth wedding week
  wife winner woman wood worker world writer writing year
);

sub _noun { return $NOUNS[ rand @NOUNS ] }
sub _adj  { return $ADJECTIVES[ rand @ADJECTIVES ] }

1;
