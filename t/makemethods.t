#!/usr/bin/perl -w

use strict;

use Test::More tests => 71;

BEGIN
{
  require 't/test-lib.pl';
  use_ok('Rose::DB::Object::MakeMethods::Generic');
  use_ok('Rose::DB::Object::MakeMethods::Pg');
}

use Rose::DB::Object::Constants qw(PRIVATE_PREFIX);

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

eval
{
  require Rose::DB;
  Rose::DB->default_type('pg');
  my $db = Rose::DB->new();
  $db->connect or die $db->error;
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

  ok($p->sql_date_birthday->ymd, 'date now');

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
  
  #
  # array
  #

  if($p->db->driver eq 'Pg')
  {
    local $p->{PRIVATE_PREFIX . '_saving'} = 1;
    $p->sql_array(-1, 2.5, 3);
    is($p->sql_array, '{-1,2.5,3}', 'array 1');

    $p->sql_array([ 'a' .. 'c' ]);
    is($p->sql_array, '{"a","b","c"}', 'array 2');
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
  Rose::DB->default_type('pg');

  package Person;

  use strict;

  @Person::ISA = qw(Rose::Object);

  use Rose::DB::Object::MakeMethods::Date
  (
    date        => 'sql_date_birthday',
    date        => [ 'sql_date_birthday_def' => { default => '1/1/2002' } ],
    datetime    => 'sql_datetime_birthday',
    datetime    => [ 'sql_datetime_birthday_def' => { default => '1/2/2002' } ],
    timestamp   => 'sql_timestamp_birthday',
    timestamp   => [ 'sql_timestamp_birthday_def' => { default => '1/3/2002' } ],
  );

  use Rose::DB::Object::MakeMethods::Generic
  (
    boolean => 'sql_is_happy',

    boolean =>
    [
      sql_bool      => { },
      sql_bool_def1 => { default => 1 },
    ],

    bitfield => 
    [
      'sql_bits' => { with_intersects => 1 },
    ],

    bitfield =>
    [
      sql_8bits  => { bits => 8 },
      sql_5bits3 => { bits => 5, default => '00011' },
    ],
    
    array => 'sql_array',
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
