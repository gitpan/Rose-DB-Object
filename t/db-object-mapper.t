#!/usr/bin/perl -w

use strict;

use Test::More tests => 256;

BEGIN 
{
  require 't/test-lib.pl';
  use_ok('Rose::DB::Object');
}

our($PG_HAS_CHKPASS, $HAVE_PG, $HAVE_MYSQL, $HAVE_INFORMIX);

#
# Postgres
#

SKIP: foreach my $db_type (qw(pg pg_with_schema))
{
  skip("Postgres tests", 128)  unless($HAVE_PG);

  Rose::DB->default_type($db_type);

  TEST_HACK:
  {
    no warnings;
    *MyPgObject::init_db = sub { Rose::DB->new($db_type) };
  }

  my $o = MyPgObject->new(NAME => 'John', 
                          K1   => 1,
                          K2   => undef,
                          K3   => 3);

  ok(ref $o && $o->isa('MyPgObject'), "new() 1 - $db_type");

  $o->FLAG2('TRUE');
  $o->DATE_CREATED('now');
  $o->LAST_MODIFIED($o->DATE_CREATED);
  $o->save_col(7);

  ok($o->save, "save() 1 - $db_type");

  is($o->ID, 1, "auto-generated primary key - $db_type");

  ok($o->load, "load() 1 - $db_type");

  $o->NAME('C' x 50);
  is($o->NAME, 'C' x 32, "varchar truncation - $db_type");

  $o->NAME('John');

  $o->CODE('A');
  is($o->CODE, 'A     ', "character padding - $db_type");

  $o->CODE('C' x 50);
  is($o->CODE, 'C' x 6, "character truncation - $db_type");

  my $ouk = MyPgObject->new(K1 => 1,
                            K2 => undef,
                            K3 => 3);

  ok($ouk->load, "load() uk 1 - $db_type");
  ok(!$ouk->not_found, "not_found() uk 1 - $db_type");

  is($ouk->ID, 1, "load() uk 2 - $db_type");
  is($ouk->NAME, 'John', "load() uk 3 - $db_type");

  ok($ouk->save, "save() uk 1 - $db_type");

  my $o2 = MyPgObject->new(ID => $o->ID);

  ok(ref $o2 && $o2->isa('MyPgObject'), "new() 2 - $db_type");

  is($o2->bits->to_Bin, '00101', "bits() (bitfield default value) - $db_type");

  ok($o2->load, "load() 2 - $db_type");
  ok(!$o2->not_found, "not_found() 1 - $db_type");

  is($o2->NAME, $o->NAME, "load() verify 1 - $db_type");
  is($o2->DATE_CREATED, $o->DATE_CREATED, "load() verify 2 - $db_type");
  is($o2->LAST_MODIFIED, $o->LAST_MODIFIED, "load() verify 3 - $db_type");
  is($o2->STATUS, 'active', "load() verify 4 (default value) - $db_type");
  is($o2->FLAG, 1, "load() verify 5 (default boolean value) - $db_type");
  is($o2->FLAG2, 1, "load() verify 6 (boolean value) - $db_type");
  is($o2->save_col, 7, "load() verify 7 (aliased column) - $db_type");
  is($o2->START->ymd, '1980-12-24', "load() verify 8 (date value) - $db_type");

  is($o2->bits->to_Bin, '00101', "load() verify 9 (bitfield value) - $db_type");

  my $clone = $o2->clone;
  ok($o2->START eq $clone->START, "clone() 1 - $db_type");
  $clone->START->set(year => '1960');
  ok($o2->START ne $clone->START, "clone() 2 - $db_type");

  $o2->NAME('John 2');
  $o2->START('5/24/2001');

  sleep(1); # keep the last modified dates from being the same

  $o2->LAST_MODIFIED('now');
  ok($o2->save, "save() 2 - $db_type");
  ok($o2->load, "load() 3 - $db_type");

  is($o2->DATE_CREATED, $o->DATE_CREATED, "save() verify 1 - $db_type");
  ok($o2->LAST_MODIFIED ne $o->LAST_MODIFIED, "save() verify 2 - $db_type");
  is($o2->START->ymd, '2001-05-24', "save() verify 3 (date value) - $db_type");

  my $o3 = MyPgObject->new();

  my $db = $o3->db or die $o3->error;

  ok(ref $db && $db->isa('Rose::DB'), "db() - $db_type");

  is($db->dbh, $o3->dbh, "dbh() - $db_type");

  my $o4 = MyPgObject->new(ID => 999);
  ok(!$o4->load(speculative => 1), "load() nonexistent - $db_type");
  ok($o4->not_found, "not_found() 2 - $db_type");

  ok($o->load, "load() 4 - $db_type");

  SKIP:
  {
    if($PG_HAS_CHKPASS)
    {
      $o->{'password_encrypted'} = ':8R1Kf2nOS0bRE';

      ok($o->password_is('xyzzy'), "chkpass() 1 - $db_type");
      is($o->password, 'xyzzy', "chkpass() 2 - $db_type");

      $o->password('foobar');

      ok($o->password_is('foobar'), "chkpass() 3 - $db_type");
      is($o->password, 'foobar', "chkpass() 4 - $db_type");

      ok($o->save, "save() 3 - $db_type");
    }
    else
    {
      skip("chkpass tests", 5);
    }
  }

  my $o5 = MyPgObject->new(ID => $o->ID);

  ok($o5->load, "load() 5 - $db_type");

  SKIP:
  {
    if($PG_HAS_CHKPASS)
    {
      ok($o5->password_is('foobar'), "chkpass() 5 - $db_type");
      is($o5->password, 'foobar', "chkpass() 6 - $db_type"); 
    }
    else
    {
      skip("chkpass tests", 2);
    }
  }

  $o5->NUMS([ 4, 5, 6 ]);
  ok($o5->save, "save() 4 - $db_type");
  ok($o->load, "load() 6 - $db_type");

  is($o5->NUMS->[0], 4, "load() verify 10 (array value) - $db_type");
  is($o5->NUMS->[1], 5, "load() verify 11 (array value) - $db_type");
  is($o5->NUMS->[2], 6, "load() verify 12 (array value) - $db_type");

  my @a = $o5->NUMS;

  is($a[0], 4, "load() verify 13 (array value) - $db_type");
  is($a[1], 5, "load() verify 14 (array value) - $db_type");
  is($a[2], 6, "load() verify 15 (array value) - $db_type");
  is(@a, 3, "load() verify 16 (array value) - $db_type");

  ok($o->delete, "delete() - $db_type");

  $o = MyPgObject->new(NAME => 'John', ID => 9);
  $o->save_col(22);
  ok($o->save, "save() 4 - $db_type");
  $o->save_col(50);
  ok($o->save, "save() 5 - $db_type");

  $ouk = MyPgObject->new(save_col => 50);
  ok($ouk->load, "load() aliased unique key - $db_type");

  eval { $o->meta->alias_column(nonesuch => 'foo') };
  ok($@, "alias_column() nonesuch - $db_type");

  # This is okay now
  #eval { $o->meta->alias_column(ID => 'foo') };
  #ok($@, "alias_column() primary key - $db_type");

  $o = MyPgObject->new(ID => 777);

  $o->meta->error_mode('fatal');

  $o->dbh->{'PrintError'} = 0;

  eval { $o->load };
  ok($@ && $o->not_found, "load() not found fatal - $db_type");

  $o->ID('abc');

  eval { $o->load };
  ok($@ && !$o->not_found, "load() fatal - $db_type");

  eval { $o->save };
  ok($@, "save() fatal - $db_type");

  $o->meta->error_mode('return');
}

#
# MySQL
#

SKIP: foreach my $db_type ('mysql')
{
  skip("MySQL tests", 62)  unless($HAVE_MYSQL);

  Rose::DB->default_type($db_type);

  my $o = MyMySQLObject->new(NAME => 'John',
                             K1   => 1,
                             K2   => undef,
                             K3   => 3);

  ok(ref $o && $o->isa('MyMySQLObject'), "new() 1 - $db_type");

  $o->FLAG2('true');
  $o->DATE_CREATED('now');
  $o->LAST_MODIFIED($o->DATE_CREATED);
  $o->save_col(22);
  $o->READ(55);

  ok($o->save, "save() 1 - $db_type");
  ok($o->load, "load() 1 - $db_type");

  $o->NAME('C' x 50);
  is($o->NAME, 'C' x 32, "varchar truncation - $db_type");

  $o->NAME('John');

  $o->CODE('A');
  is($o->CODE, 'A     ', "character padding - $db_type");

  $o->CODE('C' x 50);
  is($o->CODE, 'C' x 6, "character truncation - $db_type");

  my $ouk = MyMySQLObject->new(K1 => 1,
                               K2 => undef,
                               K3 => 3);

  ok($ouk->load, "load() uk 1 - $db_type");
  ok(!$ouk->not_found, "not_found() uk 1 - $db_type");

  is($ouk->ID, 1, "load() uk 2 - $db_type");
  is($ouk->NAME, 'John', "load() uk 3 - $db_type");

  ok($ouk->save, "save() uk 1 - $db_type");

  my $o2 = MyMySQLObject->new(ID => $o->ID);

  ok(ref $o2 && $o2->isa('MyMySQLObject'), "new() 2 - $db_type");

  is($o2->bits->to_Bin, '00101', "bits() (bitfield default value) - $db_type");

  ok($o2->load, "load() 2 - $db_type");
  ok(!$o2->not_found, "not_found() 1 - $db_type");

  is($o2->NAME, $o->NAME, "load() verify 1 - $db_type");
  is($o2->DATE_CREATED, $o->DATE_CREATED, "load() verify 2 - $db_type");
  is($o2->LAST_MODIFIED, $o->LAST_MODIFIED, "load() verify 3 - $db_type");
  is($o2->STATUS, 'active', "load() verify 4 (default value) - $db_type");
  is($o2->FLAG, 1, "load() verify 5 (default boolean value) - $db_type");
  is($o2->FLAG2, 1, "load() verify 6 (boolean value) - $db_type");
  is($o2->save_col, 22, "load() verify 7 (aliased column) - $db_type");
  is($o2->START->ymd, '1980-12-24', "load() verify 8 (date value) - $db_type");

  is($o2->bits->to_Bin, '00101', "load() verify 9 (bitfield value) - $db_type");

  my $clone = $o2->clone;
  ok($o2->START eq $clone->START, "clone() 1 - $db_type");
  $clone->START->set(year => '1960');
  ok($o2->START ne $clone->START, "clone() 2 - $db_type");

  $o2->NAME('John 2');
  $o2->START('5/24/2001');
  $o2->READ(99);

  sleep(1); # keep the last modified dates from being the same

  $o2->LAST_MODIFIED('now');
  ok($o2->save, "save() 2 - $db_type");
  ok($o2->load, "load() 3 - $db_type");

  is($o2->DATE_CREATED, $o->DATE_CREATED, "save() verify 1 - $db_type");
  ok($o2->LAST_MODIFIED ne $o->LAST_MODIFIED, "save() verify 2 - $db_type");
  is($o2->START->ymd, '2001-05-24', "save() verify 3 (date value) - $db_type");

  my $o3 = MyMySQLObject->new();

  my $db = $o3->db or die $o3->error;

  ok(ref $db && $db->isa('Rose::DB'), "db() - $db_type");

  is($db->dbh, $o3->dbh, "dbh() - $db_type");

  my $o4 = MyMySQLObject->new(ID => 999);
  ok(!$o4->load(speculative => 1), "load() nonexistent - $db_type");
  ok($o4->not_found, "not_found() 2 - $db_type");

  $o->NUMS([ 4, 5, 6 ]);
  ok($o->save, "save() 3 - $db_type");
  ok($o->load, "load() 4 - $db_type");

  is($o->NUMS->[0], 4, "load() verify 10 (array value) - $db_type");
  is($o->NUMS->[1], 5, "load() verify 11 (array value) - $db_type");
  is($o->NUMS->[2], 6, "load() verify 12 (array value) - $db_type");

  my @a = $o->NUMS;

  is($a[0], 4, "load() verify 13 (array value) - $db_type");
  is($a[1], 5, "load() verify 14 (array value) - $db_type");
  is($a[2], 6, "load() verify 15 (array value) - $db_type");
  is(@a, 3, "load() verify 16 (array value) - $db_type");

  ok($o->delete, "delete() - $db_type");

  $o = MyMySQLObject->new(NAME => 'John', ID => 9);
  $o->save_col(22);
  ok($o->save, "save() 4 - $db_type");
  $o->save_col(50);
  ok($o->save, "save() 5 - $db_type");

  $ouk = MyMySQLObject->new(save_col => 50);
  ok($ouk->load, "load() aliased unique key - $db_type");

  eval { $o->meta->alias_column(nonesuch => 'foo') };
  ok($@, "alias_column() nonesuch - $db_type");

  # This is okay now
  #eval { $o->meta->alias_column(ID => 'foo') };
  #ok($@, "alias_column() primary key - $db_type");

  $o = MyMySQLObject->new(ID => 777);

  $o->meta->error_mode('fatal');

  $o->dbh->{'PrintError'} = 0;

  eval { $o->load };
  ok($@ && $o->not_found, "load() not found fatal - $db_type");

  my $old_table = $o->meta->table;
  $o->meta->table('nonesuch');

  eval { $o->load };
  ok($@ && !$o->not_found, "load() fatal - $db_type");

  eval { $o->save };
  ok($@, "save() fatal - $db_type");

  $o->meta->table($old_table);  
  $o->meta->error_mode('return');

  $o = MyMPKMySQLObject->new(NAME => 'John');

  ok($o->save, "save() 1 multi-value primary key with generated values - $db_type");

  is($o->K1, 1, "save() verify 1 multi-value primary key with generated values - $db_type");
  is($o->K2, 2, "save() verify 2 multi-value primary key with generated values - $db_type");

  $o = MyMPKMySQLObject->new(NAME => 'Alex');

  ok($o->save, "save() 2 multi-value primary key with generated values - $db_type");

  is($o->K1, 3, "save() verify 3 multi-value primary key with generated values - $db_type");
  is($o->K2, 4, "save() verify 4 multi-value primary key with generated values - $db_type");
}

#
# Informix
#

SKIP: foreach my $db_type ('informix')
{
  skip("Informix tests", 65)  unless($HAVE_INFORMIX);

  Rose::DB->default_type($db_type);

  my $o = MyInformixObject->new(NAME => 'John', 
                                ID   => 1,
                                K1   => 1,
                                K2   => undef,
                                k3   => 3);

  ok(ref $o && $o->isa('MyInformixObject'), "new() 1 - $db_type");

  $o->meta->allow_inline_column_values(1);

  $o->flag2('true');
  $o->date_created('current year to fraction(5)');
  $o->last_modified($o->date_created);
  $o->save_col(22);

  ok($o->save, "save() 1 - $db_type");
  ok($o->load, "load() 1 - $db_type");

  $o->name('C' x 50);
  is($o->name, 'C' x 32, "varchar truncation - $db_type");

  $o->name('John');

  $o->code('A');
  is($o->code, 'A     ', "character padding - $db_type");

  $o->code('C' x 50);
  is($o->code, 'C' x 6, "character truncation - $db_type");

  my $ouk = MyInformixObject->new(k1 => 1,
                                  k2 => undef,
                                  k3 => 3);

  ok($ouk->load, "load() uk 1 - $db_type");
  ok(!$ouk->not_found, "not_found() uk 1 - $db_type");

  is($ouk->id, 1, "load() uk 2 - $db_type");
  is($ouk->name, 'John', "load() uk 3 - $db_type");

  ok($ouk->save, "save() uk 1 - $db_type");

  my $o2 = MyInformixObject->new(id => $o->id);

  ok(ref $o2 && $o2->isa('MyInformixObject'), "new() 2 - $db_type");

  is($o2->bits->to_Bin, '00101', "bits() (bitfield default value) - $db_type");

  ok($o2->load, "load() 2 - $db_type");
  ok(!$o2->not_found, "not_found() 1 - $db_type");

  is($o2->name, $o->name, "load() verify 1 - $db_type");
  is($o2->date_created, $o->date_created, "load() verify 2 - $db_type");
  is($o2->last_modified, $o->last_modified, "load() verify 3 - $db_type");
  is($o2->status, 'active', "load() verify 4 (default value) - $db_type");
  is($o2->flag, 1, "load() verify 5 (default boolean value) - $db_type");
  is($o2->flag2, 1, "load() verify 6 (boolean value) - $db_type");
  is($o2->save_col, 22, "load() verify 7 (aliased column) - $db_type");
  is($o2->start->ymd, '1980-12-24', "load() verify 8 (date value) - $db_type");

  is($o2->bits->to_Bin, '00101', "load() verify 9 (bitfield value) - $db_type");

  my $clone = $o2->clone;
  ok($o2->start eq $clone->start, "clone() 1 - $db_type");
  $clone->start->set(year => '1960');
  ok($o2->start ne $clone->start, "clone() 2 - $db_type");

  $o2->name('John 2');
  $o2->start('5/24/2001');

  sleep(1); # keep the last modified dates from being the same

  $o2->last_modified('current year to second');
  ok($o2->save, "save() 2 - $db_type");
  ok($o2->load, "load() 3 - $db_type");

  is($o2->date_created, $o->date_created, "save() verify 1 - $db_type");
  ok($o2->last_modified ne $o->last_modified, "save() verify 2 - $db_type");
  is($o2->start->ymd, '2001-05-24', "save() verify 3 (date value) - $db_type");

  my $o3 = MyInformixObject->new();

  my $db = $o3->db or die $o3->error;

  ok(ref $db && $db->isa('Rose::DB'), "db() - $db_type");

  is($db->dbh, $o3->dbh, "dbh() - $db_type");

  my $o4 = MyInformixObject->new(id => 999);
  ok(!$o4->load(speculative => 1), "load() nonexistent - $db_type");
  ok($o4->not_found, "not_found() 2 - $db_type");

  $o->nums([ 4, 5, 6 ]);
  $o->names([ qw(a b 3.1) ]);

  ok($o->save, "save() 3 - $db_type");
  ok($o->load, "load() 4 - $db_type");

  is($o->nums->[0], 4, "load() verify 10 (array value) - $db_type");
  is($o->nums->[1], 5, "load() verify 11 (array value) - $db_type");
  is($o->nums->[2], 6, "load() verify 12 (array value) - $db_type");

  $o->nums(7, 8, 9);

  my @a = $o->nums;

  is($a[0], 7, "load() verify 13 (array value) - $db_type");
  is($a[1], 8, "load() verify 14 (array value) - $db_type");
  is($a[2], 9, "load() verify 15 (array value) - $db_type");
  is(@a, 3, "load() verify 16 (array value) - $db_type");

  is($o->names->[0], 'a', "load() verify 10 (set value) - $db_type");
  is($o->names->[1], 'b', "load() verify 11 (set value) - $db_type");
  is($o->names->[2], '3.1', "load() verify 12 (set value) - $db_type");

  $o->names('c', 'd', '4.2');

  @a = $o->names;

  is($a[0], 'c', "load() verify 13 (set value) - $db_type");
  is($a[1], 'd', "load() verify 14 (set value) - $db_type");
  is($a[2], '4.2', "load() verify 15 (set value) - $db_type");
  is(@a, 3, "load() verify 16 (set value) - $db_type");

  ok($o->delete, "delete() - $db_type");

  $o = MyInformixObject->new(name => 'John', id => 9);

  $o->flag2('true');
  $o->date_created('current year to fraction(5)');
  $o->last_modified($o->date_created);
  $o->save_col(22);

  ok($o->save, "save() 4 - $db_type");
  $o->save_col(50);

  ok($o->save, "save() 5 - $db_type");

  $ouk = MyInformixObject->new(save_col => 50);
  ok($ouk->load, "load() aliased unique key - $db_type");

  eval { $o->meta->alias_column(nonesuch => 'foo') };
  ok($@, "alias_column() nonesuch - $db_type");

  # This is okay now
  #eval { $o->meta->alias_column(id => 'foo') };
  #ok($@, "alias_column() primary key - $db_type");

  $o = MyInformixObject->new(id => 777);

  $o->meta->error_mode('fatal');

  $o->dbh->{'PrintError'} = 0;

  eval { $o->load };
  ok($@ && $o->not_found, "load() not found fatal - $db_type");

  $o->id('abc');

  eval { $o->load };
  ok($@ && !$o->not_found, "load() fatal - $db_type");

  eval { $o->save };
  ok($@, "save() fatal - $db_type");

  $o->meta->error_mode('return');
}

BEGIN
{
  #
  # Postgres
  #

  my $dbh;

  eval 
  {
    $dbh = Rose::DB->new('pg_admin')->retain_dbh()
      or die Rose::DB->error;
  };

  if(!$@ && $dbh)
  {
    our $HAVE_PG = 1;

    # Drop existing table and create schema, ignoring errors
    {
      local $dbh->{'RaiseError'} = 0;
      local $dbh->{'PrintError'} = 0;
      $dbh->do('DROP TABLE rose_db_object_test');
      $dbh->do('DROP TABLE rose_db_object_private.rose_db_object_test');
      $dbh->do('DROP TABLE rose_db_object_chkpass_test');
      $dbh->do('CREATE SCHEMA rose_db_object_private');
    }

    eval
    {
      local $dbh->{'RaiseError'} = 1;
      local $dbh->{'PrintError'} = 0;
      $dbh->do('CREATE TABLE rose_db_object_chkpass_test (pass CHKPASS)');
      $dbh->do('DROP TABLE rose_db_object_chkpass_test');
    };

    our $PG_HAS_CHKPASS = 1  unless($@);

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_test
(
  id             SERIAL NOT NULL PRIMARY KEY,
  k1             INT,
  k2             INT,
  k3             INT,
  @{[ $PG_HAS_CHKPASS ? 'passwd CHKPASS,' : '' ]}
  name           VARCHAR(32) NOT NULL,
  code           CHAR(6),
  flag           BOOLEAN NOT NULL,
  flag2          BOOLEAN,
  status         VARCHAR(32) DEFAULT 'active',
  bitz           BIT(5) NOT NULL DEFAULT B'00101',
  start          DATE,
  save           INT,
  nums           INT[],
  last_modified  TIMESTAMP,
  date_created   TIMESTAMP,

  UNIQUE(k1, k2, k3)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_private.rose_db_object_test
(
  id             SERIAL NOT NULL PRIMARY KEY,
  k1             INT,
  k2             INT,
  k3             INT,
  @{[ $PG_HAS_CHKPASS ? 'passwd CHKPASS,' : '' ]}
  name           VARCHAR(32) NOT NULL,
  code           CHAR(6),
  flag           BOOLEAN NOT NULL,
  flag2          BOOLEAN,
  status         VARCHAR(32) DEFAULT 'active',
  bitz           BIT(5) NOT NULL DEFAULT B'00101',
  start          DATE,
  save           INT,
  nums           INT[],
  last_modified  TIMESTAMP,
  date_created   TIMESTAMP,

  UNIQUE(k1, k2, k3)
)
EOF

    $dbh->disconnect;

    # Create test subclass

    package MyPgObject;

    our @ISA = qw(Rose::DB::Object);

    sub init_db { Rose::DB->new('pg') }

    MyPgObject->meta->table('rose_db_object_test');

    MyPgObject->meta->columns
    (
      name     => { type => 'varchar', length => 32 },
      code     => { type => 'char', length => 6 },
      id       => { primary_key => 1, not_null => 1 },
      k1       => { type => 'int' },
      k2       => { type => 'int' },
      k3       => { type => 'int' },
      ($PG_HAS_CHKPASS ? (passwd => { type => 'chkpass', alias => 'password' }) : ()),
      flag     => { type => 'boolean', default => 1 },
      flag2    => { type => 'boolean' },
      status   => { default => 'active' },
      start    => { type => 'date', default => '12/24/1980' },
      save     => { type => 'scalar' },
      nums     => { type => 'array' },
      bitz     => { type => 'bitfield', bits => 5, default => 101, alias => 'bits' },
      #last_modified => { type => 'timestamp' },
      date_created  => { type => 'timestamp' },
    );

    MyPgObject->meta->add_unique_key('save');

    MyPgObject->meta->add_unique_key([ qw(k1 k2 k3) ]);

    MyPgObject->meta->add_columns(
      Rose::DB::Object::Metadata::Column::Timestamp->new(
        name => 'last_modified'));

    MyPgObject->meta->column_name_to_method_name_mapper(sub 
    {
      my($meta, $name) = @_;
      return uc $name;
    });

    MyPgObject->meta->alias_column(save => 'save_col');

    MyPgObject->meta->initialize;

    Test::More::is(MyPgObject->meta->column('id')->is_primary_key_member, 1, 'is_primary_key_member - pg');
    Test::More::is(MyPgObject->meta->column('id')->primary_key_position, 1, 'primary_key_position 1 - pg');
    Test::More::ok(!defined MyPgObject->meta->column('k1')->primary_key_position, 'primary_key_position 2 - pg');
    MyPgObject->meta->column('k1')->primary_key_position(7);
    Test::More::ok(!defined MyPgObject->meta->column('k1')->primary_key_position, 'primary_key_position 3 - pg');
  }

  #
  # MySQL
  #

  eval 
  {
    $dbh = Rose::DB->new('mysql_admin')->retain_dbh()
      or die Rose::DB->error;
  };

  if(!$@ && $dbh)
  {
    our $HAVE_MYSQL = 1;

    # Drop existing table and create schema, ignoring errors
    {
      local $dbh->{'RaiseError'} = 0;
      local $dbh->{'PrintError'} = 0;
      $dbh->do('DROP TABLE rose_db_object_test');
      $dbh->do('DROP TABLE rose_db_object_test2');
    }

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_test
(
  id             INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  k1             INT,
  k2             INT,
  k3             INT,
  name           VARCHAR(32) NOT NULL,
  code           CHAR(6),
  flag           TINYINT(1) NOT NULL,
  flag2          TINYINT(1),
  status         VARCHAR(32) DEFAULT 'active',
  bitz           BIT(5) NOT NULL DEFAULT '00101',
  nums           VARCHAR(255),
  start          DATE,
  save           INT,
  `read`         INT,
  last_modified  TIMESTAMP,
  date_created   TIMESTAMP,

  UNIQUE(k1, k2, k3)
)
EOF

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_test2
(
  k1             INT NOT NULL,
  k2             INT NOT NULL,
  name           VARCHAR(32),

  UNIQUE(k1, k2)
)
EOF

    $dbh->disconnect;

    # Create test subclass

    package MyMySQLObject;

    our @ISA = qw(Rose::DB::Object);

    sub init_db { Rose::DB->new('mysql') }

    MyMySQLObject->meta->table('rose_db_object_test');

    MyMySQLObject->meta->columns
    (
      name     => { type => 'varchar', length => 32 },
      code     => { type => 'char', length => 6 },
      id       => { primary_key => 1, not_null => 1 },
      k1       => { type => 'int' },
      k2       => { type => 'int' },
      k3       => { type => 'int' },
      flag     => { type => 'boolean', default => 1 },
      flag2    => { type => 'boolean' },
      status   => { default => 'active' },
      start    => { type => 'date', default => '12/24/1980' },
      save     => { type => 'scalar' },
      read     => { type => 'int' },
      nums     => { type => 'array' },
      bitz     => { type => 'bitfield', bits => 5, default => 101, alias => 'bits' },
      last_modified => { type => 'timestamp' },
      date_created  => { type => 'timestamp' },
    );

    MyMySQLObject->meta->column_name_to_method_name_mapper(sub 
    {
      my($meta, $name) = @_;
      return uc $name;
    });

    MyMySQLObject->meta->alias_column(save => 'save_col');

    MyMySQLObject->meta->add_unique_key('save');
    MyMySQLObject->meta->add_unique_key([ qw(k1 k2 k3) ]);

    MyMySQLObject->meta->initialize(preserve_existing => 1);

    Test::More::is(MyMySQLObject->meta->column('id')->is_primary_key_member, 1, 'is_primary_key_member - mysql');
    Test::More::is(MyMySQLObject->meta->column('id')->primary_key_position, 1, 'primary_key_position 1 - mysql');
    Test::More::ok(!defined MyMySQLObject->meta->column('k1')->primary_key_position, 'primary_key_position 2 - mysql');
    MyMySQLObject->meta->column('k1')->primary_key_position(7);
    Test::More::ok(!defined MyMySQLObject->meta->column('k1')->primary_key_position, 'primary_key_position 3 - mysql');

    package MyMPKMySQLObject;

    use Rose::DB::Object;

    our @ISA = qw(Rose::DB::Object);

    sub init_db { Rose::DB->new('mysql') }

    MyMPKMySQLObject->meta->table('rose_db_object_test2');

    MyMPKMySQLObject->meta->columns
    (
      k1          => { type => 'int', not_null => 1 },
      k2          => { type => 'int', not_null => 1 },
      name        => { type => 'varchar', length => 32 },
    );

    MyMPKMySQLObject->meta->primary_key_columns('k1', 'k2');

    MyMPKMySQLObject->meta->column_name_to_method_name_mapper(sub 
    {
      my($meta, $name) = @_;
      return uc $name;
    });

    MyMPKMySQLObject->meta->initialize;

    my $i = 1;

    MyMPKMySQLObject->meta->primary_key_generator(sub
    {
      my($meta, $db) = @_;

      my $k1 = $i++;
      my $k2 = $i++;

      return $k1, $k2;
    });
  }

  #
  # Informix
  #

  eval
  {
    $dbh = Rose::DB->new('informix_admin')->retain_dbh()
      or die Rose::DB->error;
  };

  if(!$@ && $dbh)
  {
    our $HAVE_INFORMIX = 1;

    # Drop existing table and create schema, ignoring errors
    {
      local $dbh->{'RaiseError'} = 0;
      local $dbh->{'PrintError'} = 0;
      $dbh->do('DROP TABLE rose_db_object_test');
    }

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_test
(
  id             SERIAL NOT NULL PRIMARY KEY,
  k1             INT,
  k2             INT,
  k3             INT,
  name           VARCHAR(32) NOT NULL,
  code           CHAR(6),
  flag           BOOLEAN NOT NULL,
  flag2          BOOLEAN,
  status         VARCHAR(32) DEFAULT 'active',
  bitz           VARCHAR(5) DEFAULT '00101' NOT NULL,
  nums           VARCHAR(255),
  start          DATE,
  save           INT,
  names          SET(VARCHAR(64) NOT NULL),
  last_modified  DATETIME YEAR TO FRACTION(5),
  date_created   DATETIME YEAR TO FRACTION(5)
)
EOF

    $dbh->disconnect;

    # Create test subclass

    package MyInformixObject;

    our @ISA = qw(Rose::DB::Object);

    sub init_db { Rose::DB->new('informix') }

    MyInformixObject->meta->table('rose_db_object_test');

    MyInformixObject->meta->columns
    (
      name     => { type => 'varchar', length => 32 },
      code     => { type => 'char', length => 6 },
      id       => { type => 'serial', primary_key => 1, not_null => 1 },
      k1       => { type => 'int' },
      k2       => { type => 'int' },
      k3       => { type => 'int' },
      flag     => { type => 'boolean', default => 1 },
      flag2    => { type => 'boolean' },
      status   => { default => 'active' },
      start    => { type => 'date', default => '12/24/1980' },
      save     => { type => 'scalar' },
      nums     => { type => 'array' },
      bitz     => { type => 'bitfield', bits => 5, default => 101, alias => 'bits' },
      names    => { type => 'set' },
      last_modified => { type => 'timestamp' },
      date_created  => { type => 'datetime year to fraction(5)' },
    );

    MyInformixObject->meta->column_name_to_method_name_mapper(sub 
    {
      my($meta, $name) = @_;
      return uc $name;
    });

    eval { MyInformixObject->meta->initialize };
    Test::More::ok($@, 'meta->initialize() reserved method');

    MyInformixObject->meta->prepare_options({ix_CursorWithHold => 1});    

    MyInformixObject->meta->alias_column(save => 'save_col');

    eval { MyInformixObject->meta->initialize };
    Test::More::ok($@, 'meta->initialize() no override');

    MyInformixObject->meta->add_unique_key('save');
    MyInformixObject->meta->add_unique_key([ qw(k1 k2 k3) ]);

    MyInformixObject->meta->initialize(preserve_existing => 1);

    Test::More::is(MyInformixObject->meta->column('id')->is_primary_key_member, 1, 'is_primary_key_member - informix');
    Test::More::is(MyInformixObject->meta->column('id')->primary_key_position, 1, 'primary_key_position 1 - informix');
    Test::More::ok(!defined MyInformixObject->meta->column('k1')->primary_key_position, 'primary_key_position 2 - informix');
    MyInformixObject->meta->column('k1')->primary_key_position(7);
    Test::More::ok(!defined MyInformixObject->meta->column('k1')->primary_key_position, 'primary_key_position 3 - informix');
  }
}

END
{
  # Delete test table

  if($HAVE_PG)
  {
    # Postgres
    my $dbh = Rose::DB->new('pg_admin')->retain_dbh()
      or die Rose::DB->error;

    $dbh->do('DROP TABLE rose_db_object_test');
    $dbh->do('DROP TABLE rose_db_object_private.rose_db_object_test');
    $dbh->do('DROP SCHEMA rose_db_object_private CASCADE');

    $dbh->disconnect;
  }

  if($HAVE_MYSQL)
  {
    # MySQL
    my $dbh = Rose::DB->new('mysql_admin')->retain_dbh()
      or die Rose::DB->error;

    $dbh->do('DROP TABLE rose_db_object_test');
    $dbh->do('DROP TABLE rose_db_object_test2');

    $dbh->disconnect;
  }

  if($HAVE_INFORMIX)
  {
    # MySQL
    my $dbh = Rose::DB->new('informix_admin')->retain_dbh()
      or die Rose::DB->error;

    $dbh->do('DROP TABLE rose_db_object_test');

    $dbh->disconnect;
  }
}
