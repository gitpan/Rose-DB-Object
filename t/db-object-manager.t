#!/usr/bin/perl -w

use strict;

use Test::More tests => 97;

BEGIN 
{
  require 't/test-lib.pl';
  use_ok('Rose::DB::Object');
  use_ok('Rose::DB::Object::Manager');
}

our($PG_HAS_CHKPASS, $HAVE_PG, $HAVE_MYSQL, $HAVE_INFORMIX);

#
# Postgres
#

SKIP: foreach my $db_type (qw(pg)) #pg_with_schema
{
  skip("Postgres tests", 31)  unless($HAVE_PG);

  Rose::DB->default_type($db_type);

  my $o = MyPgObject->new(id         => 1,
                          name       => 'John',  
                          flag       => 't',
                          flag2      => 'f',
                          fkone      => 2,
                          status     => 'active',
                          bits       => '00001',
                          start      => '2001-01-02',
                          save_col   => 5,     
                          nums       => [ 1, 2, 3 ],
                          last_modified => 'now',
                          date_created  => '2004-03-30 12:34:56');

  ok($o->save, "object save() 1 - $db_type");

  my $objs = 
    Rose::DB::Object::Manager->get_objects(
      object_class => 'MyPgObject',
      share_db     => 1,
      query_is_sql => 1,
      query        =>
      [
        id         => { ge => 1 },
        name       => 'John',  
        flag       => 't',
        flag2      => 'f',
        status     => 'active',
        bits       => '00001',
        or         => [ and => [ '!bits' => '00001', bits => { ne => '11111' } ],
                        and => [ bits => { lt => '10101' }, '!bits' => '10000' ] ],
        start      => '2001-01-02',
        save_col   => [ 1, 5 ],
        nums       => '{1,2,3}',
        fk1        => 2,
        last_modified => { le => 'now' },
        date_created  => '2004-03-30 12:34:56'
      ],
      clauses => [ "LOWER(status) LIKE 'ac%'" ],
      limit   => 5,
      sort_by => 'id');

  is(ref $objs, 'ARRAY', "get_objects() 1 - $db_type");
  $objs ||= [];
  is(scalar @$objs, 1, "get_objects() 2 - $db_type");

  my $o2 = $o->clone;
  $o2->id(2);
  $o2->name('Fred');

  ok($o2->save, "object save() 2 - $db_type");

  my $o3 = $o2->clone;
  $o3->id(3);
  $o3->name('Sue');

  ok($o3->save, "object save() 3 - $db_type");

  my $o4 = $o3->clone;
  $o4->id(4);
  $o4->name('Bob');

  ok($o4->save, "object save() 4 - $db_type");

  $objs = 
    Rose::DB::Object::Manager->get_objects(
      object_class => 'MyPgObject',
      share_db     => 1,
      query_is_sql => 1,
      query        =>
      [
        id         => { ge => 2 },
        name       => { like => '%e%' },
        flag       => 't',
        flag2      => 'f',
        status     => 'active',
        bits       => '00001',
        start      => '2001-01-02',
        save_col   => [ 1, 5 ],
        nums       => '{1,2,3}',
        last_modified => { le => 'now' },
        date_created  => '2004-03-30 12:34:56',
        status        => { like => 'AC%', field => 'UPPER(status)' },
      ],
      clauses => [ "LOWER(status) LIKE 'ac%'" ],
      limit   => 5,
      sort_by => 'name DESC');

  is(ref $objs, 'ARRAY', "get_objects() 3 - $db_type");
  $objs ||= [];
  is(scalar @$objs, 2, "get_objects() 4 - $db_type");
  is($objs->[0]->id, 3, "get_objects() 5 - $db_type");
  is($objs->[1]->id, 2, "get_objects() 6 - $db_type");

  my $count =
    Rose::DB::Object::Manager->get_objects_count(
      object_class => 'MyPgObject',
      share_db     => 1,
      query_is_sql => 1,
      query        =>
      [
        id         => { ge => 2 },
        name       => { like => '%e%' },
        flag       => 't',
        flag2      => 'f',
        status     => 'active',
        bits       => '00001',
        start      => '2001-01-02',
        save_col   => [ 1, 5 ],
        nums       => '{1,2,3}',
        last_modified => { le => 'now' },
        date_created  => '2004-03-30 12:34:56',
        status        => { like => 'AC%', field => 'UPPER(status)' },
      ],
      clauses => [ "LOWER(status) LIKE 'ac%'" ],
      limit   => 5,
      sort_by => 'name DESC');

  is($count, 2, "get_objects_count() 1 - $db_type");

  my $iterator = 
    Rose::DB::Object::Manager->get_objects_iterator(
      object_class => 'MyPgObject',
      share_db     => 1,
      query_is_sql => 1,
      query        =>
      [
        id         => { ge => 2 },
        name       => { like => '%e%' },
        flag       => 't',
        flag2      => 'f',
        status     => 'active',
        bits       => '00001',
        start      => '2001-01-02',
        save_col   => [ 1, 5 ],
        nums       => '{1,2,3}',
        last_modified => { le => 'now' },
        date_created  => '2004-03-30 12:34:56',
        status        => { like => 'AC%', field => 'UPPER(status)' },
      ],
      clauses => [ "LOWER(status) LIKE 'ac%'" ],
      limit   => 5,
      sort_by => 'name');

  is(ref $iterator, 'Rose::DB::Objects::Iterator', "get_objects_iterator() 1 - $db_type");

  $o = $iterator->next;
  is($o->name, 'Fred', "iterator next() 1 - $db_type");
  is($o->id, 2, "iterator next() 2 - $db_type");

  $o = $iterator->next;
  is($o->name, 'Sue', "iterator next() 3 - $db_type");
  is($o->id, 3, "iterator next() 4 - $db_type");

  $o = $iterator->next;
  is($o, 0, "iterator next() 5 - $db_type");
  is($iterator->total, 2, "iterator total() - $db_type");

  my $fo = MyPgOtherObject->new(name => 'Foo 1',
                                k1   => 1,
                                k2   => 2,
                                k3   => 3);

  ok($fo->save, "object save() 5 - $db_type");

  $fo = MyPgOtherObject->new(name => 'Foo 2',
                             k1   => 2,
                             k2   => 3,
                             k3   => 4);

  ok($fo->save, "object save() 6 - $db_type");

  my $o5 = MyPgObject->new(id         => 5,
                           name       => 'Betty',  
                           flag       => 'f',
                           flag2      => 't',
                           status     => 'with',
                           bits       => '10101',
                           start      => '2002-05-20',
                           save_col   => 123,
                           nums       => [ 4, 5, 6 ],
                           fkone      => 1,
                           fk2        => 2,
                           fk3        => 3,
                           last_modified => '2001-01-10 20:34:56',
                           date_created  => '2002-05-10 10:34:56');

  ok($o5->save, "object save() 7 - $db_type");

  my $fo1 = $o5->other_obj;

  ok($fo1 && ref $fo1 && $fo1->k1 == 1 && $fo1->k2 == 2 && $fo1->k3 == 3,
     "foreign object 1 - $db_type");

  $objs = 
    Rose::DB::Object::Manager->get_objects(
      object_class => 'MyPgObject',
      share_db     => 1,
      query_is_sql => 1,
      query        =>
      [
        id         => { ge => 2 },
        't1.name'  => { like => '%tt%' },
      ],
      with_objects => [ 'other_obj' ]);

  ok(ref $objs->[0]->{'other_obj'} eq 'MyPgOtherObject', "foreign object 2 - $db_type");
  is($objs->[0]->other_obj->k2, 2, "foreign object 3 - $db_type");

  $iterator =
    Rose::DB::Object::Manager->get_objects_iterator(
      object_class => 'MyPgObject',
      share_db     => 1,
      query_is_sql => 1,
      query        =>
      [
        id         => { ge => 2 },
        't1.name'  => { like => '%tt%' },
      ],
      with_objects => [ 'other_obj' ]);

  $o = $iterator->next;

  ok(ref $o->{'other_obj'} eq 'MyPgOtherObject', "foreign object 4 - $db_type");
  is($o->other_obj->k2, 2, "foreign object 5 - $db_type");

  $objs = 
    Rose::DB::Object::Manager->get_objects(
      object_class => 'MyPgObject',
      share_db     => 1,
      query        =>
      [
        id         => { ge => 1 },
        name       => 'John',  
        flag       => 1,
        flag2      => 0,
        status     => 'active',
        bits       => '1',
        start      => '1/2/2001',
        '!start'   => { gt => DateTime->new(year  => '2005', 
                                            month => 1,
                                            day   => 1) },
        '!rose_db_object_test.start' => 
        {
          gt => DateTime->new(year  => '2005', 
                              month => 2,
                              day   => 2)
        },

        '!t1.start' => 
        {
          gt => DateTime->new(year  => '2005', 
                              month => 3,
                              day   => 3)
        },

        save_col   => [ 1, 5 ],
        nums       => [ 1, 2, 3 ],
        fk1        => 2,
        last_modified => { le => '6/6/2020' }, # XXX: breaks in 2020!
        date_created  => '3/30/2004 12:34:56 pm'
      ],
      clauses => [ "LOWER(status) LIKE 'ac%'" ],
      limit   => 5,
      sort_by => 'id');

  is(ref $objs, 'ARRAY', "get_objects() 7 - $db_type");
  $objs ||= [];
  is(scalar @$objs, 1, "get_objects() 8 - $db_type");

  $objs = 
    Rose::DB::Object::Manager->get_objects(
      object_class => 'MyPgObject',
      share_db     => 1,
      query        =>
      [
        id         => { ge => 2 },
        k1         => { lt => 900 },
        or         => [ k1 => { ne => 99 }, k1 => 100 ],
        or         => [ and => [ id => { ne => 123 }, id => { lt => 100  } ],
                        and => [ id => { ne => 456 }, id => { lt => 300  } ] ],
        '!k2'      => { gt => 999 },
        '!t2.name' => 'z',
        start      => { lt => DateTime->new(year => '2005', month => 1, day => 1) },
        '!start'   => { gt => DateTime->new(year => '2005', month => 1, day => 1) },
        'rose_db_object_test.name'   => { like => '%tt%' },
        '!rose_db_object_other.name' => 'q',
        '!rose_db_object_other.name' => [ 'x', 'y' ],
      ],
      with_objects => [ 'other_obj' ]);

  ok(ref $objs->[0]->{'other_obj'} eq 'MyPgOtherObject', "foreign object 6 - $db_type");
  is($objs->[0]->other_obj->k2, 2, "foreign object 7 - $db_type");
}

#
# MySQL
#

SKIP: foreach my $db_type ('mysql')
{
  skip("MySQL tests", 31)  unless($HAVE_MYSQL);

  Rose::DB->default_type($db_type);

  my $o = MyMySQLObject->new(id         => 1,
                             name       => 'John',  
                             flag       => 1,
                             flag2      => 0,
                             fkone      => 2,
                             status     => 'active',
                             bits       => '00001',
                             start      => '2001-01-02',
                             save_col   => 5,
                             nums       => [ 1, 2, 3 ],
                             last_modified => 'now',
                             date_created  => '2004-03-30 12:34:56');

  ok($o->save, "object save() 1 - $db_type");

  my $objs = 
    Rose::DB::Object::Manager->get_objects(
      object_class => 'MyMySQLObject',
      share_db     => 1,
      query        =>
      [
        id         => { ge => 1 },
        name       => 'John',  
        flag       => 1,
        flag2      => 0,
        status     => 'active',
        bits       => '00001',
        or         => [ and => [ '!bits' => '00001', bits => { ne => '11111' } ],
                        and => [ bits => { lt => '10101' }, '!bits' => '10000' ] ],
        start      => '2001-01-02',
        save_col   => [ 1, 5 ],
        last_modified => { le => 'now' },
        date_created  => '2004-03-30 12:34:56'
      ],
      clauses => [ "LOWER(status) LIKE 'ac%'" ],
      limit   => 5,
      sort_by => 'id');

  is(ref $objs, 'ARRAY', "get_objects() 1 - $db_type");
  $objs ||= [];
  is(scalar @$objs, 1, "get_objects() 2 - $db_type");

  my $o2 = $o->clone;
  $o2->id(2);
  $o2->name('Fred');

  ok($o2->save, "object save() 2 - $db_type");

  my $o3 = $o2->clone;
  $o3->id(3);
  $o3->name('Sue');

  ok($o3->save, "object save() 3 - $db_type");

  my $o4 = $o3->clone;
  $o4->id(4);
  $o4->name('Bob');

  ok($o4->save, "object save() 4 - $db_type");

  $objs = 
    Rose::DB::Object::Manager->get_objects(
      object_class => 'MyMySQLObject',
      share_db     => 1,
      query        =>
      [
        id         => { ge => 2 },
        name       => { like => '%e%' },
        flag       => 1,
        flag2      => 0,
        status     => 'active',
        bits       => '00001',
        start      => '2001-01-02',
        save_col   => [ 1, 5 ],
        last_modified => { le => 'now' },
        date_created  => '2004-03-30 12:34:56',
        status        => { like => 'AC%', field => 'UPPER(status)' },
      ],
      clauses => [ "LOWER(status) LIKE 'ac%'" ],
      limit   => 5,
      sort_by => 'name DESC');

  is(ref $objs, 'ARRAY', "get_objects() 3 - $db_type");
  $objs ||= [];
  is(scalar @$objs, 2, "get_objects() 4 - $db_type");
  is($objs->[0]->id, 3, "get_objects() 5 - $db_type");
  is($objs->[1]->id, 2, "get_objects() 6 - $db_type");

  my $count =
    Rose::DB::Object::Manager->get_objects_count(
      object_class => 'MyMySQLObject',
      share_db     => 1,
      query        =>
      [
        id         => { ge => 2 },
        name       => { like => '%e%' },
        flag       => 1,
        flag2      => 0,
        status     => 'active',
        bits       => '00001',
        start      => '2001-01-02',
        save_col   => [ 1, 5 ],
        last_modified => { le => 'now' },
        date_created  => '2004-03-30 12:34:56',
        status        => { like => 'AC%', field => 'UPPER(status)' },
      ],
      clauses => [ "LOWER(status) LIKE 'ac%'" ],
      limit   => 5,
      sort_by => 'name DESC');

  is($count, 2, "get_objects_count() 1 - $db_type");

  my $iterator = 
    Rose::DB::Object::Manager->get_objects_iterator(
      object_class => 'MyMySQLObject',
      share_db     => 1,
      query        =>
      [
        id         => { ge => 2 },
        name       => { like => '%e%' },
        flag       => 1,
        flag2      => 0,
        status     => 'active',
        bits       => '00001',
        start      => '2001-01-02',
        save_col   => [ 1, 5 ],
        last_modified => { le => 'now' },
        date_created  => '2004-03-30 12:34:56',
        status        => { like => 'AC%', field => 'UPPER(status)' },
      ],
      clauses => [ "LOWER(status) LIKE 'ac%'" ],
      limit   => 5,
      sort_by => 'name');

  is(ref $iterator, 'Rose::DB::Objects::Iterator', "get_objects_iterator() 1 - $db_type");

  $o = $iterator->next;
  is($o->name, 'Fred', "iterator next() 1 - $db_type");
  is($o->id, 2, "iterator next() 2 - $db_type");

  $o = $iterator->next;
  is($o->name, 'Sue', "iterator next() 3 - $db_type");
  is($o->id, 3, "iterator next() 4 - $db_type");

  $o = $iterator->next;
  is($o, 0, "iterator next() 5 - $db_type");
  is($iterator->total, 2, "iterator total() - $db_type");

  my $fo = MyMySQLOtherObject->new(name => 'Foo 1',
                                   k1   => 1,
                                   k2   => 2,
                                   k3   => 3);

  ok($fo->save, "object save() 5 - $db_type");

  $fo = MyMySQLOtherObject->new(name => 'Foo 2',
                                k1   => 2,
                                k2   => 3,
                                k3   => 4);

  ok($fo->save, "object save() 6 - $db_type");

  my $o5 = MyMySQLObject->new(id         => 5,
                              name       => 'Betty',  
                              flag       => 'f',
                              flag2      => 't',
                              status     => 'with',
                              bits       => '10101',
                              start      => '2002-05-20',
                              save_col   => 123,
                              nums       => [ 4, 5, 6 ],
                              fkone      => 1,
                              fk2        => 2,
                              fk3        => 3,
                              last_modified => '2001-01-10 20:34:56',
                              date_created  => '2002-05-10 10:34:56');

  ok($o5->save, "object save() 7 - $db_type");

  my $fo1 = $o5->other_obj;

  ok($fo1 && ref $fo1 && $fo1->k1 == 1 && $fo1->k2 == 2 && $fo1->k3 == 3,
     "foreign object 1 - $db_type");

  $objs = 
    Rose::DB::Object::Manager->get_objects(
      object_class => 'MyMySQLObject',
      share_db     => 1,
      query        =>
      [
        id         => { ge => 2 },
        't1.name'  => { like => '%tt%' },
      ],
      with_objects => [ 'other_obj' ]);

  ok(ref $objs->[0]->{'other_obj'} eq 'MyMySQLOtherObject', "foreign object 2 - $db_type");
  is($objs->[0]->other_obj->k2, 2, "foreign object 3 - $db_type");

  $iterator =
    Rose::DB::Object::Manager->get_objects_iterator(
      object_class => 'MyMySQLObject',
      share_db     => 1,
      query        =>
      [
        id         => { ge => 2 },
        't1.name'  => { like => '%tt%' },
      ],
      with_objects => [ 'other_obj' ]);

  $o = $iterator->next;

  ok(ref $o->{'other_obj'} eq 'MyMySQLOtherObject', "foreign object 4 - $db_type");
  is($o->other_obj->k2, 2, "foreign object 5 - $db_type");

  $objs = 
    Rose::DB::Object::Manager->get_objects(
      object_class => 'MyMySQLObject',
      share_db     => 1,
      query        =>
      [
        id         => { ge => 1 },
        name       => 'John',  
        flag       => 1,
        flag2      => 0,
        status     => 'active',
        bits       => '1',
        start      => '1/2/2001',
        '!start'   => { gt => DateTime->new(year  => '2005', 
                                            month => 1,
                                            day   => 1) },
        '!rose_db_object_test.start' => 
        {
          gt => DateTime->new(year  => '2005', 
                              month => 2,
                              day   => 2)
        },

        '!t1.start' => 
        {
          gt => DateTime->new(year  => '2005', 
                              month => 3,
                              day   => 3)
        },

        save_col   => [ 1, 5 ],
        nums       => [ 1, 2, 3 ],
        fk1        => 2,
        last_modified => { le => '6/6/2020' }, # XXX: breaks in 2020!
        date_created  => '3/30/2004 12:34:56 pm'
      ],
      clauses => [ "LOWER(status) LIKE 'ac%'" ],
      limit   => 5,
      sort_by => 'id');

  is(ref $objs, 'ARRAY', "get_objects() 7 - $db_type");
  $objs ||= [];
  is(scalar @$objs, 1, "get_objects() 8 - $db_type");

  $objs = 
    Rose::DB::Object::Manager->get_objects(
      object_class => 'MyMySQLObject',
      share_db     => 1,
      query        =>
      [
        id         => { ge => 2 },
        k1         => { lt => 900 },
        or         => [ k1 => { ne => 99 }, k1 => 100 ],
        or         => [ and => [ id => { ne => 123 }, id => { lt => 100  } ],
                        and => [ id => { ne => 456 }, id => { lt => 300  } ] ],
        '!k2'      => { gt => 999 },
        '!t2.name' => 'z',
        start      => { lt => DateTime->new(year => '2005', month => 1, day => 1) },
        '!start'   => { gt => DateTime->new(year => '2005', month => 1, day => 1) },
        'rose_db_object_test.name'   => { like => '%tt%' },
        '!rose_db_object_other.name' => 'q',
        '!rose_db_object_other.name' => [ 'x', 'y' ],
      ],
      with_objects => [ 'other_obj' ]);

  ok(ref $objs->[0]->{'other_obj'} eq 'MyMySQLOtherObject', "foreign object 6 - $db_type");
  is($objs->[0]->other_obj->k2, 2, "foreign object 7 - $db_type");
}

#
# Informix
#

SKIP: foreach my $db_type (qw(informix))
{
  skip("Informix tests", 33)  unless($HAVE_INFORMIX);

  Rose::DB->default_type($db_type);

  my $o = MyInformixObject->new(id         => 1,
                                name       => 'John',  
                                flag       => 't',
                                flag2      => 'f',
                                fkone      => 2,
                                status     => 'active',
                                bits       => '00001',
                                start      => '2001-01-02',
                                save_col   => 5,     
                                nums       => [ 1, 2, 3 ],
                                last_modified => 'now',
                                date_created  => '2004-03-30 12:34:56');

  ok($o->save, "object save() 1 - $db_type");

  my $objs = 
    Rose::DB::Object::Manager->get_objects(
      object_class => 'MyInformixObject',
      share_db     => 1,
      query        =>
      [
        id         => { ge => 1 },
        name       => 'John',  
        flag       => 't',
        flag2      => 'f',
        status     => 'active',
        bits       => '00001',
        or         => [ and => [ '!bits' => '00001', bits => { ne => '11111' } ],
                        and => [ bits => { lt => '10101' }, '!bits' => '10000' ] ],
        start      => '01/02/2001',
        save_col   => [ 1, 5 ],
        nums       => 'SET{1,2,3}',
        fk1        => 2,
        last_modified => { le => $o->db->format_timestamp($o->db->parse_timestamp('now')) },
        date_created  => '2004-03-30 12:34:56'
      ],
      clauses => [ "LOWER(status) LIKE 'ac%'" ],
      limit   => 5,
      sort_by => 'id');

  is(ref $objs, 'ARRAY', "get_objects() 1 - $db_type");
  $objs ||= [];
  is(scalar @$objs, 1, "get_objects() 2 - $db_type");

  my $o2 = $o->clone;
  $o2->id(2);
  $o2->name('Fred');

  ok($o2->save, "object save() 2 - $db_type");

  my $o3 = $o2->clone;
  $o3->id(3);
  $o3->name('Sue');

  ok($o3->save, "object save() 3 - $db_type");

  my $o4 = $o3->clone;
  $o4->id(4);
  $o4->name('Bob');

  ok($o4->save, "object save() 4 - $db_type");

  $objs = 
    Rose::DB::Object::Manager->get_objects(
      object_class => 'MyInformixObject',
      share_db     => 1,
      query        =>
      [
        id         => { ge => 2 },
        name       => { like => '%e%' },
        flag       => 't',
        flag2      => 'f',
        status     => 'active',
        bits       => '00001',
        start      => '01/02/2001',
        save_col   => [ 1, 5 ],
        nums       => 'SET{1,2,3}',
        last_modified => { le => $o->db->format_timestamp($o->db->parse_timestamp('now')) },
        date_created  => '2004-03-30 12:34:56',
        status        => { like => 'AC%', field => 'UPPER(status)' },
      ],
      clauses => [ "LOWER(status) LIKE 'ac%'" ],
      limit   => 5,
      sort_by => 'name DESC');

  is(ref $objs, 'ARRAY', "get_objects() 3 - $db_type");
  $objs ||= [];
  is(scalar @$objs, 2, "get_objects() 4 - $db_type");
  is($objs->[0]->id, 3, "get_objects() 5 - $db_type");
  is($objs->[1]->id, 2, "get_objects() 6 - $db_type");

  my $count =
    Rose::DB::Object::Manager->get_objects_count(
      object_class => 'MyInformixObject',
      share_db     => 1,
      query        =>
      [
        id         => { ge => 2 },
        name       => { like => '%e%' },
        flag       => 't',
        flag2      => 'f',
        status     => 'active',
        bits       => '00001',
        start      => '01/02/2001',
        save_col   => [ 1, 5 ],
        nums       => 'SET{1,2,3}',
        last_modified => { le => $o->db->format_timestamp($o->db->parse_timestamp('now')) },
        date_created  => '2004-03-30 12:34:56',
        status        => { like => 'AC%', field => 'UPPER(status)' },
      ],
      clauses => [ "LOWER(status) LIKE 'ac%'" ],
      limit   => 5,
      sort_by => 'name DESC');

  is($count, 2, "get_objects_count() 1 - $db_type");

  my $iterator = 
    Rose::DB::Object::Manager->get_objects_iterator(
      object_class => 'MyInformixObject',
      share_db     => 1,
      query        =>
      [
        id         => { ge => 2 },
        name       => { like => '%e%' },
        flag       => 't',
        flag2      => 'f',
        status     => 'active',
        bits       => '00001',
        start      => '01/02/2001',
        save_col   => [ 1, 5 ],
        nums       => 'SET{1,2,3}',
        last_modified => { le => $o->db->format_timestamp($o->db->parse_timestamp('now')) },
        date_created  => '2004-03-30 12:34:56',
        status        => { like => 'AC%', field => 'UPPER(status)' },
      ],
      clauses => [ "LOWER(status) LIKE 'ac%'" ],
      limit   => 5,
      sort_by => 'name');

  is(ref $iterator, 'Rose::DB::Objects::Iterator', "get_objects_iterator() 1 - $db_type");

  $o = $iterator->next;
  is($o->name, 'Fred', "iterator next() 1 - $db_type");
  is($o->id, 2, "iterator next() 2 - $db_type");

  $o = $iterator->next;
  is($o->name, 'Sue', "iterator next() 3 - $db_type");
  is($o->id, 3, "iterator next() 4 - $db_type");

  $o = $iterator->next;
  is($o, 0, "iterator next() 5 - $db_type");
  is($iterator->total, 2, "iterator total() - $db_type");

  my $fo = MyInformixOtherObject->new(name => 'Foo 1',
                                      k1   => 1,
                                      k2   => 2,
                                      k3   => 3);

  ok($fo->save, "object save() 5 - $db_type");

  $fo = MyInformixOtherObject->new(name => 'Foo 2',
                                   k1   => 2,
                                   k2   => 3,
                                   k3   => 4);

  ok($fo->save, "object save() 6 - $db_type");

  my $o5 = MyInformixObject->new(id         => 5,
                                 name       => 'Betty',  
                                 flag       => 'f',
                                 flag2      => 't',
                                 status     => 'with',
                                 bits       => '10101',
                                 start      => '2002-05-20',
                                 save_col   => 123,
                                 nums       => [ 4, 5, 6 ],
                                 fkone      => 1,
                                 fk2        => 2,
                                 fk3        => 3,
                                 last_modified => '2001-01-10 20:34:56',
                                 date_created  => '2002-05-10 10:34:56');

  ok($o5->save, "object save() 7 - $db_type");

  my $fo1 = $o5->other_obj;

  ok($fo1 && ref $fo1 && $fo1->k1 == 1 && $fo1->k2 == 2 && $fo1->k3 == 3,
     "foreign object 1 - $db_type");

  $objs = 
    Rose::DB::Object::Manager->get_objects(
      object_class => 'MyInformixObject',
      share_db     => 1,
      query        =>
      [
        id         => { ge => 2 },
        't1.name'  => { like => '%tt%' },
      ],
      with_objects => [ 'other_obj' ]);

  ok(ref $objs->[0]->{'other_obj'} eq 'MyInformixOtherObject', "foreign object 2 - $db_type");
  is($objs->[0]->other_obj->k2, 2, "foreign object 3 - $db_type");

  $iterator =
    Rose::DB::Object::Manager->get_objects_iterator(
      object_class => 'MyInformixObject',
      share_db     => 1,
      query        =>
      [
        id         => { ge => 2 },
        't1.name'  => { like => '%tt%' },
      ],
      with_objects => [ 'other_obj' ]);

  $o = $iterator->next;

  ok(ref $o->{'other_obj'} eq 'MyInformixOtherObject', "foreign object 4 - $db_type");
  is($o->other_obj->k2, 2, "foreign object 5 - $db_type");

  $objs = 
    Rose::DB::Object::Manager->get_objects(
      object_class => 'MyInformixObject',
      share_db     => 1,
      query        =>
      [
        id         => { ge => 1 },
        name       => 'John',  
        flag       => 1,
        flag2      => 0,
        status     => 'active',
        bits       => '1',
        start      => '1/2/2001',
        '!start'   => { gt => DateTime->new(year  => '2005', 
                                            month => 1,
                                            day   => 1) },
        '!rose_db_object_test.start' => 
        {
          gt => DateTime->new(year  => '2005', 
                              month => 2,
                              day   => 2)
        },

        '!t1.start' => 
        {
          gt => DateTime->new(year  => '2005', 
                              month => 3,
                              day   => 3)
        },

        save_col   => [ 1, 5 ],
        nums       => [ 1, 2, 3 ],
        fk1        => 2,
        fk1        => { lt => 99 },
        fk1        => { lt => 100 },
        or         => [ nums => { in_set => [ 2, 22, 222 ] }, 
                        fk1 => { lt => 777 },
                        last_modified => '6/6/2020' ],
        nums       => { any_in_set => [ 1, 99, 100 ] },
        nums       => { in_set => [ 2, 22, 222 ] },
        nums       => { in_set => 2 },
        nums       => { all_in_set => [ 1, 2, 3 ] },
        last_modified => { le => '6/6/2020' }, # XXX: test breaks in 2020!
        date_created  => '3/30/2004 12:34:56 pm'
      ],
      clauses => [ "LOWER(status) LIKE 'ac%'" ],
      limit   => 5,
      sort_by => 'id');

  is(ref $objs, 'ARRAY', "get_objects() 7 - $db_type");
  $objs ||= [];
  is(scalar @$objs, 1, "get_objects() 8 - $db_type");

  $objs = 
    Rose::DB::Object::Manager->get_objects(
      object_class => 'MyInformixObject',
      share_db     => 1,
      query        =>
      [
        id         => { ge => 2 },
        k1         => { lt => 900 },
        or         => [ k1 => { ne => 99 }, k1 => 100 ],
        or         => [ and => [ id => { ne => 123 }, id => { lt => 100  } ],
                        and => [ id => { ne => 456 }, id => { lt => 300  } ] ],
        '!k2'      => { gt => 999 },
        '!t2.name' => 'z',
        start      => { lt => DateTime->new(year => '2005', month => 1, day => 1) },
        '!start'   => { gt => DateTime->new(year => '2005', month => 1, day => 1) },
        'rose_db_object_test.name'   => { like => '%tt%' },
        '!rose_db_object_other.name' => 'q',
        '!rose_db_object_other.name' => [ 'x', 'y' ],
      ],
      with_objects => [ 'other_obj' ]);

  ok(ref $objs->[0]->{'other_obj'} eq 'MyInformixOtherObject', "foreign object 6 - $db_type");
  is($objs->[0]->other_obj->k2, 2, "foreign object 7 - $db_type");

  #local $Rose::DB::Object::Manager::Debug = 1;

  $objs = 
    Rose::DB::Object::Manager->get_objects(
      object_class => 'MyInformixObject',
      share_db     => 1,
      queryis_sql  => 1,
      query        =>
      [
        id         => { ge => 1 },
        name       => 'John',  
        nums       => { any_in_set => [ 1, 99, 100 ] },
        nums       => { in_set => [ 2, 22, 222 ] },
        nums       => { in_set => 2 },
        nums       => { all_in_set => [ 1, 2, 3 ] },
      ],
      limit   => 5,
      sort_by => 'id');

  is(ref $objs, 'ARRAY', "get_objects() 9 - $db_type");
  $objs ||= [];
  is(scalar @$objs, 1, "get_objects() 10 - $db_type");
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
      $dbh->do('DROP TABLE rose_db_object_other');
    }

    eval
    {
      local $dbh->{'RaiseError'} = 1;
      local $dbh->{'PrintError'} = 0;
      $dbh->do('CREATE TABLE rose_db_object_chkpass_test (pass CHKPASS)');
      $dbh->do('DROP TABLE rose_db_object_chkpass_test;');
    };

    our $PG_HAS_CHKPASS = 1  unless($@);

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_other
(
  k1    INT NOT NULL,
  k2    INT NOT NULL,
  k3    INT NOT NULL,
  name  VARCHAR(32),

  UNIQUE(k1, k2, k3)
)
EOF

    # Create test foreign subclass

    package MyPgOtherObject;

    our @ISA = qw(Rose::DB::Object);

    MyPgOtherObject->meta->table('rose_db_object_other');

    MyPgOtherObject->meta->columns
    (
      name => { type => 'varchar'},
      k1   => { type => 'int' },
      k2   => { type => 'int' },
      k3   => { type => 'int' },
    );

    MyPgOtherObject->meta->primary_key_columns(qw(k1 k2 k3));

    MyPgOtherObject->meta->initialize;

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_test
(
  id             INT NOT NULL PRIMARY KEY,
  @{[ $PG_HAS_CHKPASS ? 'password CHKPASS,' : '' ]}
  name           VARCHAR(32) NOT NULL,
  flag           BOOLEAN NOT NULL,
  flag2          BOOLEAN,
  status         VARCHAR(32) DEFAULT 'active',
  bits           BIT(5) NOT NULL DEFAULT B'00101',
  start          DATE,
  save           INT,
  nums           INT[],
  fk1            INT,
  fk2            INT,
  fk3            INT,
  last_modified  TIMESTAMP,
  date_created   TIMESTAMP,

  FOREIGN KEY (fk1, fk2, fk3) REFERENCES rose_db_object_other (k1, k2, k3)
)
EOF

    $dbh->disconnect;

    # Create test subclass

    package MyPgObject;

    our @ISA = qw(Rose::DB::Object);

    MyPgObject->meta->table('rose_db_object_test');

    MyPgObject->meta->columns
    (
      'name',
      id       => { primary_key => 1 },
      ($PG_HAS_CHKPASS ? (password => { type => 'chkpass' }) : ()),
      flag     => { type => 'boolean', default => 1 },
      flag2    => { type => 'boolean' },
      status   => { default => 'active' },
      start    => { type => 'date', default => '12/24/1980' },
      save     => { type => 'scalar' },
      nums     => { type => 'array' },
      bits     => { type => 'bitfield', bits => 5, default => 101 },
      fk1      => { type => 'int' },
      fk2      => { type => 'int' },
      fk3      => { type => 'int' },
      last_modified => { type => 'timestamp' },
      date_created  => { type => 'timestamp' },
    );

    MyPgObject->meta->foreign_keys
    (
      other_obj =>
      {
        class => 'MyPgOtherObject',
        key_columns =>
        {
          fk1 => 'k1',
          fk2 => 'k2',
          fk3 => 'k3',
        }
      },
    );

    MyPgObject->meta->alias_column(fk1 => 'fkone');

    eval { MyPgObject->meta->initialize };
    Test::More::ok($@, 'meta->initialize() reserved method');

    MyPgObject->meta->alias_column(save => 'save_col');
    MyPgObject->meta->initialize(preserve_existing_methods => 1);
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
      $dbh->do('DROP TABLE rose_db_object_other');
    }

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_other
(
  k1    INT NOT NULL,
  k2    INT NOT NULL,
  k3    INT NOT NULL,
  name  VARCHAR(32),

  KEY(k1, k2, k3)
)
EOF

    # Create test foreign subclass

    package MyMySQLOtherObject;

    our @ISA = qw(Rose::DB::Object);

    MyMySQLOtherObject->meta->table('rose_db_object_other');

    MyMySQLOtherObject->meta->columns
    (
      name => { type => 'varchar'},
      k1   => { type => 'int' },
      k2   => { type => 'int' },
      k3   => { type => 'int' },
    );

    MyMySQLOtherObject->meta->primary_key_columns([ qw(k1 k2 k3) ]);

    MyMySQLOtherObject->meta->initialize;

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_test
(
  id             INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name           VARCHAR(32) NOT NULL,
  flag           BOOLEAN NOT NULL,
  flag2          BOOLEAN,
  status         VARCHAR(32) DEFAULT 'active',
  bits           VARCHAR(5) NOT NULL DEFAULT '00101',
  nums           VARCHAR(255),
  start          DATE,
  save           INT,
  fk1            INT,
  fk2            INT,
  fk3            INT,
  last_modified  TIMESTAMP,
  date_created   TIMESTAMP
)
EOF

    $dbh->disconnect;

    # Create test subclass

    package MyMySQLObject;

    our @ISA = qw(Rose::DB::Object);

    MyMySQLObject->meta->table('rose_db_object_test');

    MyMySQLObject->meta->columns
    (
      'name',
      id       => { primary_key => 1 },
      flag     => { type => 'boolean', default => 1 },
      flag2    => { type => 'boolean' },
      status   => { default => 'active' },
      start    => { type => 'date', default => '12/24/1980' },
      save     => { type => 'scalar' },
      bits     => { type => 'bitfield', bits => 5, default => 101 },
      nums     => { type => 'array' },
      fk1      => { type => 'int' },
      fk2      => { type => 'int' },
      fk3      => { type => 'int' },
      last_modified => { type => 'datetime' },
      date_created  => { type => 'datetime' },
    );

    MyMySQLObject->meta->foreign_keys
    (
      other_obj =>
      {
        class => 'MyMySQLOtherObject',
        key_columns =>
        {
          fk1 => 'k1',
          fk2 => 'k2',
          fk3 => 'k3',
        }
      },
    );

    MyMySQLObject->meta->alias_column(fk1 => 'fkone');

    eval { MyMySQLObject->meta->initialize };
    Test::More::ok($@, 'meta->initialize() reserved method');

    MyMySQLObject->meta->alias_column(save => 'save_col');
    MyMySQLObject->meta->initialize(preserve_existing_methods => 1);
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
      $dbh->do('DROP TABLE rose_db_object_other');
    }

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_other
(
  k1    INT NOT NULL,
  k2    INT NOT NULL,
  k3    INT NOT NULL,
  name  VARCHAR(32),

  UNIQUE(k1, k2, k3)
)
EOF

    # Create test foreign subclass

    package MyInformixOtherObject;

    our @ISA = qw(Rose::DB::Object);

    MyInformixOtherObject->meta->table('rose_db_object_other');

    MyInformixOtherObject->meta->columns
    (
      name => { type => 'varchar'},
      k1   => { type => 'int' },
      k2   => { type => 'int' },
      k3   => { type => 'int' },
    );

    MyInformixOtherObject->meta->primary_key_columns([ qw(k1 k2 k3) ]);

    MyInformixOtherObject->meta->initialize;

    $dbh->do(<<"EOF");
CREATE TABLE rose_db_object_test
(
  id             INT NOT NULL PRIMARY KEY,
  name           VARCHAR(32) NOT NULL,
  flag           BOOLEAN NOT NULL,
  flag2          BOOLEAN,
  status         VARCHAR(32) DEFAULT 'active',
  bits           VARCHAR(5) DEFAULT '00101' NOT NULL,
  start          DATE,
  save           INT,
  nums           SET(INT NOT NULL),
  fk1            INT,
  fk2            INT,
  fk3            INT,
  last_modified  DATETIME YEAR TO FRACTION(5),
  date_created   DATETIME YEAR TO FRACTION(5),
  
  FOREIGN KEY (fk1, fk2, fk3) REFERENCES rose_db_object_other (k1, k2, k3)
)
EOF

    $dbh->disconnect;

    # Create test subclass

    package MyInformixObject;

    our @ISA = qw(Rose::DB::Object);

    MyInformixObject->meta->table('rose_db_object_test');

    MyInformixObject->meta->columns
    (
      'name',
      id       => { primary_key => 1 },
      flag     => { type => 'boolean', default => 1 },
      flag2    => { type => 'boolean' },
      status   => { default => 'active' },
      start    => { type => 'date', default => '12/24/1980' },
      save     => { type => 'scalar' },
      nums     => { type => 'set' },
      bits     => { type => 'bitfield', bits => 5, default => 101 },
      fk1      => { type => 'int' },
      fk2      => { type => 'int' },
      fk3      => { type => 'int' },
      last_modified => { type => 'timestamp' },
      date_created  => { type => 'timestamp' },
    );

    MyInformixObject->meta->foreign_keys
    (
      other_obj =>
      {
        class => 'MyInformixOtherObject',
        key_columns =>
        {
          fk1 => 'k1',
          fk2 => 'k2',
          fk3 => 'k3',
        }
      },
    );

    MyInformixObject->meta->alias_column(fk1 => 'fkone');

    eval { MyInformixObject->meta->initialize };
    Test::More::ok($@, 'meta->initialize() reserved method');

    MyInformixObject->meta->alias_column(save => 'save_col');
    MyInformixObject->meta->initialize(preserve_existing_methods => 1);
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
    $dbh->do('DROP TABLE rose_db_object_other');

    $dbh->disconnect;
  }

  if($HAVE_MYSQL)
  {
    # MySQL
    my $dbh = Rose::DB->new('mysql_admin')->retain_dbh()
      or die Rose::DB->error;

    $dbh->do('DROP TABLE rose_db_object_test');
    $dbh->do('DROP TABLE rose_db_object_other');

    $dbh->disconnect;
  }

  if($HAVE_INFORMIX)
  {
    # Informix
    my $dbh = Rose::DB->new('informix_admin')->retain_dbh()
      or die Rose::DB->error;
  
    $dbh->do('DROP TABLE rose_db_object_test');
    $dbh->do('DROP TABLE rose_db_object_other');
  
    $dbh->disconnect;
  }
}

