#!/usr/bin/perl -w

use strict;

use Test::More tests => 72;

BEGIN
{
  require 't/test-lib.pl';
  use_ok('Rose::DB::Object');
  use_ok('Rose::DB::Object::MakeMethods::Generic');
  use_ok('Rose::DB::Object::MakeMethods::Pg');
}

use Rose::DB::Object::Constants qw(STATE_SAVING);

my $p = Person->new() || ok(0);
ok(ref $p && $p->isa('Person'), 'Construct object (no init)');

#
# boolean
#

$p = Person->new(sql_is_happy => 1);
ok(ref $p && $p->isa('Person'), 'boolean 1');

is($p->sql_is_happy, 1, 'boolean 2');

foreach my $val (qw(t true True TRUE T y Y yes Yes YES 1 1.0 1.00))
{
  eval { $p->sql_is_happy($val) };
  ok(!$@ && $p->sql_is_happy, "boolean true '$val'");
}

foreach my $val (qw(f false False FALSE F n N no No NO 0 0.0 0.00))
{
  eval { $p->sql_is_happy($val) };
  ok(!$@ && !$p->sql_is_happy, "boolean false '$val'");
}

#
# These tests require Rose::DB
#

our $db_type;

eval
{
  require Rose::DB;

  foreach my $type (qw(pg mysql))
  {  
    Rose::DB->default_type($type);
    my $db = Rose::DB->new();

    $db->raise_error(0);
    $db->print_error(0);

    if($db->connect)
    {
      $db_type = $type;
      last;
    }
  }

  die unless(defined $db_type);
};

SKIP:
{
  skip("Can't connect to db", 36)  if($@);

  #
  # date
  #

  $p = Person->new(sql_date_birthday => '12/24/1980 1:00');
  ok(ref $p && $p->isa('Person'), 'date 1');

  is($p->sql_date_birthday->ymd, '1980-12-24', 'date 2');

  is($p->sql_date_birthday(truncate => 'month'), '1980-12-01', 'date truncate');
  is($p->sql_date_birthday(format => '%B'), 'December', 'date format');

  $p->sql_date_birthday('12/24/1980 1:00:01');

  is($p->sql_date_birthday->ymd, '1980-12-24', 'date 4');

  is($p->sql_date_birthday_def->ymd, '2002-01-01', 'date 5');

  $p->sql_date_birthday('now');

  if($db_type eq 'pg')
  {
    is($p->sql_date_birthday, 'now', 'date now');
  }
  else
  {
    ok($p->sql_date_birthday =~ /^2/, 'date now');
  }

  $p->sql_date_birthday('infinity');
  is($p->sql_date_birthday(format => ''), 'infinity', 'date infinity');

  $p->sql_date_birthday('-infinity');
  is($p->sql_date_birthday(format => ''), '-infinity', 'date -infinity');

  eval { $p->sql_date_birthday('asdf') };
  ok($@, 'Invalid date');

  #
  # datetime
  #

  $p = Person->new(sql_datetime_birthday => '12/24/1980 1:00');
  ok(ref $p && $p->isa('Person'), 'datetime 1');

  is($p->sql_datetime_birthday->strftime('%Y-%m-%d %H:%M:%S'), 
     '1980-12-24 01:00:00', 'datetime 2');

  is($p->sql_datetime_birthday(truncate => 'month')->strftime('%Y-%m-%d %H:%M:%S'),
     '1980-12-01 00:00:00', 'datetime truncate');

  $p->sql_datetime_birthday('12/24/1980 1:00:01');

  is($p->sql_datetime_birthday->strftime('%Y-%m-%d %H:%M:%S'), 
     '1980-12-24 01:00:01', 'datetime 4');

  is($p->sql_datetime_birthday_def->strftime('%Y-%m-%d %H:%M:%S'),
     '2002-01-02 00:00:00', 'datetime 5');

  eval { $p->sql_datetime_birthday('asdf') };
  ok($@, 'Invalid datetime');

  #
  # timestamp
  #

  $p = Person->new(sql_timestamp_birthday => '12/24/1980 1:00');
  ok(ref $p && $p->isa('Person'), 'timestamp 1');

  is($p->sql_timestamp_birthday->strftime('%Y-%m-%d %H:%M:%S'), 
     '1980-12-24 01:00:00', 'timestamp 2');

  is($p->sql_timestamp_birthday(truncate => 'month')->strftime('%Y-%m-%d %H:%M:%S'),
     '1980-12-01 00:00:00', 'timestamp truncate');

  $p->sql_timestamp_birthday('12/24/1980 1:00:01');

  is($p->sql_timestamp_birthday->strftime('%Y-%m-%d %H:%M:%S'), 
     '1980-12-24 01:00:01', 'timestamp 4');

  is($p->sql_timestamp_birthday_def->strftime('%Y-%m-%d %H:%M:%S'),
     '2002-01-03 00:00:00', 'timestamp 5');

  eval { $p->sql_timestamp_birthday('asdf') };
  ok($@, 'Invalid timestamp');

  #
  # bitfield
  #

  if($p->db->driver eq 'Pg')
  {
    $p->sql_bits(2);
    is($p->sql_bits()->to_Bin, '00000000000000000000000000000010', 'bitfield() 2');
    $p->sql_bits(1010);
    is($p->sql_bits()->to_Bin, '00000000000000000000000000001010', 'bitfield() 1010');
    $p->sql_bits(5.0);
    is($p->sql_bits()->to_Bin, '00000000000000000000000000000101', 'bitfield() 5.0');

    ok($p->sql_bits_intersects('100'), 'bitfield() intsersects 1');
    ok(!$p->sql_bits_intersects('1000'), 'bitfield() intsersects 2');

    $p->sql_8bits(2);
    is($p->sql_8bits()->to_Bin, '00000010', 'bitfield(8) 2');
    $p->sql_8bits(1010);
    is($p->sql_8bits()->to_Bin,  '00001010', 'bitfield(8) 1010');
    $p->sql_8bits(5.0);
    is($p->sql_8bits()->to_Bin, '00000101', 'bitfield(8) 5.0');

    is($p->sql_5bits3()->to_Bin, '00011', 'bitfield(5) default');
    $p->sql_5bits3(2);
    is($p->sql_5bits3()->to_Bin, '00010', 'bitfield(5) 2');
    $p->sql_5bits3(1010);
    is($p->sql_5bits3()->to_Bin, '01010', 'bitfield(5) 1010');
    $p->sql_5bits3(5.0);
    is($p->sql_5bits3()->to_Bin, '00101', 'bitfield(5) 5.0');
  }
  else
  {
    SKIP:
    {
      skip("Not connected to PostgreSQL", 12);
    }
  }

  #
  # array
  #

  if($p->db->driver eq 'Pg')
  {
    local $p->{STATE_SAVING()} = 1;
    $p->sql_array(-1, 2.5, 3);
    is($p->sql_array, '{-1,2.5,3}', 'array 1');

    $p->sql_array([ 'a' .. 'c' ]);
    is($p->sql_array, '{"a","b","c"}', 'array 2');
  }
  else
  {
    SKIP:
    {
      skip("Not connected to PostgreSQL", 2);
    }
  }
}

#
# chkpass
#

$p->{'password_encrypted'} = ':8R1Kf2nOS0bRE';

ok($p->password_is('xyzzy'), 'chkpass() 1');
is($p->password, 'xyzzy', 'chkpass() 2');

$p->password('foobar');

ok($p->password_is('foobar'), 'chkpass() 3');
is($p->password, 'foobar', 'chkpass() 4');

BEGIN
{
  Rose::DB->default_type('mysql');

  package Person;

  use strict;

  @Person::ISA = qw(Rose::DB::Object);

  Person->meta->columns
  (
    sql_date_birthday          => { type => 'date' },
    sql_date_birthday_def      => { type => 'date' },
    sql_datetime_birthday      => { type => 'datetime' },
    sql_datetime_birthday_def  => { type => 'datetime' },
    sql_timestamp_birthday     => { type => 'timestamp' },
    sql_timestamp_birthday_def => { type => 'timestamp' },

    sql_is_happy  => { type => 'boolean' },
    sql_bool      => { type => 'boolean' },
    sql_bool_def1 => { type => 'boolean' },

    sql_bits   => { type => 'bitfield' },
    sql_8bits  => { type => 'bitfield', bits => 8 },
    sql_5bits3 => { type => 'bitfield', bits => 5 },

    sql_array  => { type => 'array' },
  );

  my $meta = Person->meta;

  Rose::DB::Object::MakeMethods::Date->make_methods
  (
    { target_class => 'Person' },
    date        => [ 'sql_date_birthday' => { column => $meta->column('sql_date_birthday') } ],
    date        => [ 'sql_date_birthday_def' => { default => '1/1/2002', 
                      column => $meta->column('sql_date_birthday_def') } ],
    datetime    => [ 'sql_datetime_birthday' => { column => $meta->column('sql_datetime_birthday') } ],
    datetime    => [ 'sql_datetime_birthday_def' => { default => '1/2/2002',
                      column => $meta->column('sql_datetime_birthday_def') } ],
    timestamp   => [ 'sql_timestamp_birthday' => { column => $meta->column('sql_timestamp_birthday') } ],
    timestamp   => [ 'sql_timestamp_birthday_def' => { default => '1/3/2002',
                     column => $meta->column('sql_timestamp_birthday_def') } ],
  );

  Rose::DB::Object::MakeMethods::Generic->make_methods
  (
    { target_class => 'Person' },
    boolean => [ 'sql_is_happy' => { column => $meta->column('sql_is_happy') } ],

    boolean =>
    [
      sql_bool      => { column => $meta->column('sql_bool') },
      sql_bool_def1 => { default => 1, column => $meta->column('sql_bool_def1') },
    ],

    bitfield => 
    [
      'sql_bits' => { with_intersects => 1, column => $meta->column('sql_bits') },
    ],

    bitfield =>
    [
      sql_8bits  => { bits => 8, column => $meta->column('sql_8bits') },
      sql_5bits3 => { bits => 5, default => '00011', column => $meta->column('sql_5bits3') },
    ],

    array => [ 'sql_array' => { column => $meta->column('sql_array') } ],
  );

  use Rose::DB::Object::MakeMethods::Pg
  (
    chkpass => 'password',
  );

  sub db
  {
    my $self = shift;
    return $self->{'db'}  if($self->{'db'});
    $self->{'db'} = Rose::DB->new();
    $self->{'db'}->connect or die $self->{'db'}->error;
    return $self->{'db'};
  }

  sub _loading { 0 }
}
