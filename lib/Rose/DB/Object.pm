package Rose::DB::Object;

use strict;

use Carp();

use Rose::DB;
use Rose::DB::Object::Metadata;

use Rose::Object;
our @ISA = qw(Rose::Object);

use Rose::DB::Object::Constants qw(:all);
#use Rose::DB::Constants qw(IN_TRANSACTION);

our $VERSION = '0.012';

our $Debug = 0;

#
# Object data
#

use Rose::Object::MakeMethods::Generic
(
  'scalar'  => [ 'error', 'not_found' ],
  'boolean' =>
  [
    FLAG_DB_IS_PRIVATE,
    STATE_IN_DB,
    STATE_LOADING,
    STATE_SAVING,
  ],
);

#
# Class methods
#

sub meta
{  
  if(ref $_[0])
  {
    return $_[0]->{META_ATTR_NAME()} ||= Rose::DB::Object::Metadata->for_class(ref $_[0]);
  }

  return Rose::DB::Object::Metadata->for_class($_[0]);
}

#
# Object methods
#

sub db
{
  my($self) = shift;

  if(@_)
  {
    $self->{FLAG_DB_IS_PRIVATE()} = 0;
    $self->{'db'}  = shift;
    $self->{'dbh'} = undef;
    $self->meta->schema($self->{'db'}->schema);

    return $self->{'db'};
  }

  return $self->{'db'} ||= $self->_init_db;
}

sub init_db { Rose::DB->new() }

sub _init_db
{
  my($self) = shift;

  my $db = $self->init_db;

  if($db->init_db_info)
  {
    $self->{FLAG_DB_IS_PRIVATE()} = 1;
    $self->meta->schema($db->schema);
    return $db;
  }

  $self->error($db->error);

  return undef;
}

sub dbh
{
  my($self) = shift;

  return $self->{'dbh'}  if($self->{'dbh'});

  my $db = $self->db or return 0;

  if(my $dbh = $db->dbh)
  {
    return $self->{'dbh'} = $dbh;
  }
  else
  {
    $self->error($db->error);
    return undef;
  }
}

sub load
{
  my($self) = shift;

  my %args = @_;

  my $db  = $self->db  or return 0;
  my $dbh = $self->dbh or return 0;

  my $meta = $self->meta;

  my @key_columns = $meta->primary_key_columns;
  my @key_methods = map { $meta->column_method($_) } @key_columns;
  my @key_values  = grep { defined } map { $self->$_() } @key_methods;
  my $null_key  = 0;
  my $found_key = 0;

  unless(@key_values == @key_columns)
  {
    foreach my $cols ($meta->unique_keys)
    {
      my $defined = 0;
      @key_columns = @$cols;
      @key_methods = map { $meta->column_method($_) } @key_columns;
      @key_values  = map { $defined++ if(defined $_); $_ } 
                     map { $self->$_() } @key_methods;

      if($defined)
      {
        $found_key = 1;
        $null_key  = 1  unless($defined == @key_columns);
        last;
      }
    }

    unless($found_key)
    {
      @key_columns = $meta->primary_key_columns;

      $self->error("Cannot load " . ref($self) . " without a primary key (" .
                   join(', ', @key_columns) . ') with ' .
                   (@key_columns > 1 ? 'non-null values in all columns' : 
                                       'a non-null value') .
                   ' or another unique key with at least one non-null value.');
      return 0;
    }
  }

  my $rows = 0;

  my $column_names = $meta->column_names;

  eval
  {
    local $self->{STATE_LOADING()} = 1;
    local $dbh->{'RaiseError'} = 1;

    my($sql, $sth);

    if($null_key)
    {
      $sql = $meta->load_sql_with_null_key(\@key_columns, \@key_values);
      $sth = $dbh->prepare($sql);
    }
    else
    {
      $sql = $meta->load_sql(\@key_columns);
      $sth = $dbh->prepare_cached($sql);
    }

    $Debug && warn "$sql - bind params: ", join(', ', grep { defined } @key_values), "\n";
    $sth->execute(grep { defined } @key_values);

    my %row;

    $sth->bind_columns(undef, \@row{@$column_names});

    $sth->fetch;

    $rows = $sth->rows;

    $sth->finish;

    if($rows > 0)
    {
      $self->{'not_found'} = 0;

      if($meta->column_aliases)
      {
        my $methods = $meta->column_methods;

        foreach my $name (@$column_names)
        {
          my $method = $methods->{$name} ||= $name;
          $self->$method($row{$name});
        }
      }
      else
      {
        foreach my $name (@$column_names)
        {
          $self->$name($row{$name});
        }
      }
    }
    else
    {
      no warnings;
      $self->error("No such " . ref($self) . ' where ' . 
                   join(', ', @key_columns) . ' = ' . join(', ', @key_values));
      $self->{'not_found'} = 1;
    }
  };

  if($@)
  {
    $self->error("load() - $@");
    return 0;
  }

  return 0  unless($rows > 0);

  $self->{STATE_IN_DB()} = 1;
  return 1;
}

sub save
{
  my($self, %args) = @_;

  if(!$args{'insert'} && ($args{'update'} || $self->{STATE_IN_DB()}))
  {
    return shift->update(@_);
  }

  return shift->insert(@_);
}

sub update
{
  my($self, %args) = @_;

  my $db  = $self->db  or return 0;
  my $dbh = $self->dbh or return 0;

  my $meta = $self->meta;

  my @key_columns = $meta->primary_key_columns;
  my @key_methods = map { $meta->column_method($_) } @key_columns;
  my @key_values  = grep { defined } map { $self->$_() } @key_columns;

  # See comment below
  #my $null_key  = 0;
  #my $found_key = 0;

  unless(@key_values == @key_columns)
  {
    # This is nonsensical right now because the primary key 
    # always has to be non-null, and any update will use the 
    # primary key instead of a unique key.  But I'll leave the
    # code here (commented out) just in case.
    #foreach my $cols ($meta->unique_keys)
    #{
    #  my $defined = 0;
    #  @key_columns = @$cols;
    #  @key_methods = map { $meta->column_method($_) } @key_columns;
    #  @key_values  = map { $defined++ if(defined $_); $_ } 
    #                 map { $self->$_() } @key_methods;
    #
    #  if($defined)
    #  {
    #    $found_key = 1;
    #    $null_key  = 1  unless($defined == @key_columns);
    #    last;
    #  }
    #}
    #
    #unless($found_key)
    #{
    #  @key_columns = $meta->primary_key_columns;
    #
    #  $self->error("Cannot update " . ref($self) . " without a primary key (" .
    #               join(', ', @key_columns) . ') with ' .
    #               (@key_columns > 1 ? 'non-null values in all columns' : 
    #                                   'a non-null value') .
    #               ' or another unique key with at least one non-null value.');
    #  return 0;
    #}

    $self->error("Cannot update " . ref($self) . " without a primary key (" .
                 join(', ', @key_columns) . ') with ' .
                 (@key_columns > 1 ? 'non-null values in all columns' : 
                                     'a non-null value'));
  }

  #my $ret = $db->begin_work;
  #
  #unless($ret)
  #{
  #  $self->error('Could not begin transaction before inserting - ' . $db->error);
  #  return undef;
  #}
  #
  #my $started_new_tx = ($ret == Rose::DB::Constants::IN_TRANSACTION) ? 0 : 1;

  eval
  {
    local $self->{STATE_SAVING()} = 1;
    local $dbh->{'RaiseError'} = 1;

    my $sth;

    if($meta->allow_inline_column_values)
    {
      # This versions of update_sql_with_inlining is not needed (see comments
      # in Rose/DB/Object/Metadata.pm for more information)
      #my($sql, $bind) = 
      #  $meta->update_sql_with_inlining($self, \@key_columns, \@key_values);

      my($sql, $bind) = 
        $meta->update_sql_with_inlining($self, \@key_columns);

      if($Debug)
      {
        no warnings;
        warn "$sql - bind params: ", join(', ', @$bind, @key_values), "\n";
      }

      $sth = $dbh->prepare($sql);
      $sth->execute(@$bind, @key_values);
    }
    else
    {
      my $column_names = $meta->column_names;

      # See comment above regarding primary keys vs. unique keys for updates
      #my($sql, $sth);
      #
      #if($null_key)
      #{
      #  $sql = $meta->update_sql_with_null_key(\@key_columns, \@key_values);
      #  $sth = $dbh->prepare($sql);
      #}
      #else
      #{
      #  $sql = $meta->update_sql(\@key_columns);
      #  $sth = $dbh->prepare_cached($sql);
      #}

      my $sql = $meta->update_sql(\@key_columns);
      my $sth = $dbh->prepare_cached($sql);

      my %key = map { ($_ => 1) } @key_columns;

      if($meta->column_aliases)
      {
        my $methods = $meta->column_methods;

        if($Debug)
        {
          no warnings;
          warn "$sql - bind params: ", 
            join(', ', (map { my $m = $methods->{$_} ||= $_; $self->$m(); } 
                        grep { !$key{$_} } @$column_names), 
                        grep { defined } @key_values), "\n";
        }

        $sth->execute(
          (map { my $m = $methods->{$_} ||= $_; $self->$m(); } 
           grep { !$key{$_} } @$column_names), grep { defined } @key_values);
      }
      else
      {
        if($Debug)
        {
          no warnings;
          warn "$sql - bind params: ", 
            join(', ', (map { $self->$_() } grep { !$key{$_} } @$column_names), 
                        grep { defined } @key_values), "\n";
        }

        $sth->execute((map { $self->$_() } grep { !$key{$_} } @$column_names), 
                       grep { defined } @key_values);
      }
    }
    #if($started_new_tx)
    #{
    #  $db->commit or die $db->error;
    #}
  };

  if($@)
  {
    $self->error("update() - $@");
    #$db->rollback or warn $db->error  if($started_new_tx);
    return 0;
  }

  return 1;
}

sub insert
{
  my($self, %args) = @_;

  my $db  = $self->db  or return 0;
  my $dbh = $self->dbh or return 0;

  my $meta = $self->meta;

  my @pk_columns = map { $meta->column_method($_) } $meta->primary_key_columns;
  my @pk_values  = grep { defined } map { $self->$_() } @pk_columns;

  #my $ret = $db->begin_work;
  #
  #unless($ret)
  #{
  #  $self->error('Could not begin transaction before inserting - ' . $db->error);
  #  return undef;
  #}
  #
  #my $started_new_tx = ($ret > 0) ? 1 : 0;

  my $using_pk_placeholders = 0;

  unless(@pk_values == @pk_columns)
  {
    @pk_values = $meta->generate_primary_key_values($db);

    unless(@pk_values)
    {
      @pk_values = $meta->generate_primary_key_placeholders($db);
      $using_pk_placeholders = 1;
    }

    unless(@pk_values == @pk_columns)
    {
      my $s = (@pk_values == 1 ? '' : 's');
      $self->error("Could not generate primary key$s for column$s " .
                   join(', ', @pk_columns));
      return undef;
    }

    if($meta->column_aliases)
    {
      my $methods = $meta->column_methods;

      foreach my $name (@pk_columns)
      {
        my $method = $methods->{$name} ||= $name;
        $self->$name(shift @pk_values);
      }
    }
    else
    {
      foreach my $name (@pk_columns)
      {
        $self->$name(shift @pk_values);
      }
    }
  }

  eval
  {
    local $self->{STATE_SAVING()} = 1;
    local $dbh->{'RaiseError'} = 1;

    my $sth;

    if($meta->allow_inline_column_values)
    {
      my($sql, $bind) = $meta->insert_sql_with_inlining($self);

      if($Debug)
      {
        no warnings;
        warn "$sql - bind params: ", join(', ', @$bind), "\n";
      }

      $sth = $dbh->prepare($sql);
      $sth->execute(@$bind);
    }
    else
    {
      my $column_names = $meta->column_names;

      $sth = $dbh->prepare_cached($meta->insert_sql);

      if($Debug)
      {
        no warnings;
        warn $meta->insert_sql, " - bind params: ", 
          join(', ', (map { $self->$_() } $meta->column_method_names)), "\n";
      }

      if($meta->column_aliases)
      {
        $sth->execute(map { $self->$_() } $meta->column_method_names);
      }
      else
      {
        $sth->execute(map { $self->$_() } @$column_names);
      }
    }

    if(@pk_columns == 1)
    {
      my $pk = $pk_columns[0];

      if($using_pk_placeholders || !defined $self->$pk())
      {
        $self->$pk($db->last_insertid_from_sth($sth));
        $self->{STATE_IN_DB()} = 1;
      }
      elsif(!$using_pk_placeholders && defined $self->$pk())
      {
        $self->{STATE_IN_DB()} = 1;
      }
    }
    elsif(@pk_values == @pk_columns)
    {
      $self->{STATE_IN_DB()} = 1;
    }
    elsif(!$using_pk_placeholders)
    {
      my $have_pk = 1;

      foreach my $pk (@pk_columns)
      {
        $have_pk = 0  unless(defined $self->$pk());
      }

      $self->{STATE_IN_DB()} = $have_pk;
    }

    #if($started_new_tx)
    #{
    #  $db->commit or die $db->error;
    #}
  };

  if($@)
  {
    $self->error("update() - $@");
    #$db->rollback or warn $db->error  if($started_new_tx);
    return 0;
  }

  return 1;
}

sub delete
{
  my($self, %args) = @_;

  my $dbh = $self->dbh or return 0;

  my $meta = $self->meta;

  my @pk_columns = map { $meta->column_method($_) } $meta->primary_key_columns;
  my @pk_values  = grep { defined } map { $self->$_() } @pk_columns;

  unless(@pk_values == @pk_columns)
  {
    $self->error("Cannot delete " . ref($self) . " without a primary key (" .
                 join(', ', @pk_columns) . ')');
    return 0;
  }

  eval
  {
    local $self->{STATE_SAVING()} = 1;
    local $dbh->{'RaiseError'} = 1;

    my $sth = $dbh->prepare_cached($meta->delete_sql);

    $Debug && warn $meta->delete_sql, " - bind params: ", join(', ', @pk_values), "\n";
    $sth->execute(@pk_values);

    unless($sth->rows > 0)
    {
      $self->error("Did not delete " . ref($self) . ' where ' . 
                   join(', ', @pk_columns) . ' = ' . join(', ', @pk_values));
    }
  };

  if($@)
  {
    $self->error("delete() - $@");
    return 0;
  }

  $self->{STATE_IN_DB()} = 0;
  return 1;
}

sub clone
{
  my($self) = shift;
  my $class = ref $self;
  local $self->{STATE_CLONING()} = 1;
  return $class->new(map { $_ => $self->$_() } $self->meta->column_method_names);
}

sub DESTROY
{
  my($self) = shift;

  if($self->{FLAG_DB_IS_PRIVATE()})
  {
    if(my $db = $self->{'db'})
    {
      #$Debug && warn "$self DISCONNECT\n";
      $db->disconnect;
    }
  }
}

1;

__END__

=head1 NAME

Rose::DB::Object - Object representation of a single row in a database table.

=head1 SYNOPSIS

  package Category;

  use Rose::DB::Object;
  our @ISA = qw(Rose::DB::Object);

  __PACKAGE__->meta->table('categories');

  __PACKAGE__->meta->columns
  (
    id          => { type => 'int', primary_key => 1 },
    name        => { type => 'varchar', length => 255 },
    description => { type => 'text' },
  );

  __PACKAGE__->meta->add_unique_key('name');

  __PACKAGE__->meta->initialize;

  ...

  package Product;

  use Rose::DB::Object;
  our @ISA = qw(Rose::DB::Object);

  __PACKAGE__->meta->table('products');

  __PACKAGE__->meta->columns
  (
    id          => { type => 'int', primary_key => 1 },
    name        => { type => 'varchar', length => 255 },
    description => { type => 'text' },
    category_id => { type => 'int' },

    status => 
    {
      type      => 'varchar', 
      check_in  => [ 'active', 'inactive' ],
      default   => 'inactive',
    },

    start_date  => { type => 'datetime' },
    end_date    => { type => 'datetime' },

    date_created     => { type => 'timestamp', default => 'now' },  
    last_modified    => { type => 'timestamp', default => 'now' },
  );

  __PACKAGE__->meta->add_unique_key('name');

  __PACKAGE__->meta->foreign_keys
  (
    category =>
    {
      class       => 'Category',
      key_columns =>
      {
        category_id => 'id',
      }
    },
  );

  __PACKAGE__->meta->initialize;

  ...

  $product = Product->new(id          => 123,
                          name        => 'GameCube',
                          status      => 'active',
                          start_date  => '11/5/2001',
                          end_date    => '12/1/2007',
                          category_id => 5);

  $product->save or die $product->error;

  ...

  $product = Product->new(id => 123);
  $product->load or die $product->error;

  print $product->category->name;

  $product->end_date->add(days => 45);

  $product->save or die $product->error;

  ...

=head1 DESCRIPTION

C<Rose::DB::Object> is a base class for objects that encapsulate a single row in a database table.  C<Rose::DB::Object>-derived objects are sometimes simply called "C<Rose::DB::Object> objects" in this documentation for the sake of brevity, but be assured that derivation is the only reasonable way to use this class.

C<Rose::DB::Object> objects can represent rows in almost any database table, subject to the following constraints.

=over 4

=item * The database server must be supported by C<Rose::DB>.

=item * The database table must have a primary key, and that key must not allow null values in any of its columns.

=back

Although the list above contains the only hard and fast rules, there may be other realities that you'll need to work around.

The most common example is the existence of a column name in the database table that conflicts with the name of a method in the C<Rose::DB::Object> API.  The work-around is to alias the column.  See the C<alias_column()> method in the C<Rose::DB::Object::Metadata> documentation for more details.

There are also varying degrees of support for data types in each database server supported by C<Rose::DB>.  If you have a table that uses a data type not supported by an existing C<Rose::DB::Object::Metadata::Column>-derived class, you will have to write your own column class and then map it to a type name using C<Rose::DB::Object::Metadata>'s C<column_type_class()> method, yada yada.  

The entire framework is meant to be extensible.  I have created simple implementations of the most common column types, but there's certainly mor ethat could be done.  Submissions are welcome.

C<Rose::DB::Object> provides the following functions:

=over 4

=item * Create a row in the database by saving a newly constructed object.

=item * Initialize an object by loading a row from the database.

=item * Update a row by saving a modified object back to the database.

=item * Delete a row from the database.

=back

Objects can be loaded based on either a primary key or a unique key.  Since all tables fronted by C<Rose::DB::Object>s must have non-null primary keys, insert, update, and delete operations are done based on the primary key.

This is all very straightforward, but the really handy part is C<Rose::DB::Object>'s ability to parse, coerce, "inflate", and "deflate" column values on your behalf, providing the most convenient possible data representations on the Perl side of the fence, while allowing the programmer to largely forget about the ugly details of the data formats required by the database.

To define your own C<Rose::DB::Object>-derived class, you must first describe the table that contains the rows you plan to represent.    This is done through the C<Rose::DB::Object::Metadata> object associated with each C<Rose::DB::Object>-dervied class.  (You can see a simple example of this in the L<synopsis|"SYNOPSIS">.)  The metadata object is accessible via C<Rose::DB::Object>'s C<meta()> method.  See the C<Rose::DB::Object::Metadata> documentation for more information.

This class inherits from, and follows the conventions of, C<Rose::Object>.
See the C<Rose::Object> documentation for more information.

=head1 CONSTRUCTOR

=over 4

=item B<new PARAMS>

Returns a new C<Rose::DB::Object> constructed according to PARAMS, where PARAMS are name/value pairs.  Any object method is a valid parameter name.

=back

=head1 CLASS METHODS

=over 4

Returns the C<Rose::DB::Object::Metadata> object associated with this class.  This object describes the database table whose rows are fronted by this class: the name of the table, its columns, unique keys, foreign keys, etc.

See the C<Rose::DB::Object::Metadata> documentation for more information.

=back

=head1 OBJECT METHODS

=over 4

=item B<db [DB]>

Get or set the C<Rose::DB> object used to access the database that contains the table whose rows are fronted by the C<Rose::DB::Object>-derived class.

If it does not already exist, this object is created with a simple, argumentless call to C<Rose::DB-E<gt>new()>.  To override this default in a subclass, override the C<init_db> method and return the C<Rose::DB> to be used as the new default.

=item B<dbh>

Returns the C<DBI> database handle contained in C<db>.

=item B<delete>

Delete the row represented by the current object.  The object must have been previously loaded from the database (or must otherwise have a defined primary key value) in order to be deleted.  Returns true if the row was deleted or did not exist, false otherwise.

=item B<error>

Returns the text message associated with the last error that occurred.

=item B<load>

Load a row from the database table, initializing the object with the values from that row.  An object can be loaded based on either a primary key or a unique key.

Returns true if the row was loaded successfully, false if the row could not be loaded or did not exist.

=item B<not_found>

Returns true if the previous call to C<load()> failed because a row in the database table with the specified primary or unique key did not exist, false otherwise.

=item B<meta>

Returns the C<Rose::DB::Object::Metadata> object associated with this class.  This object describes the database table whose rows are fronted by this class: the name of the table, its columns, unique keys, foreign keys, etc.

See the C<Rose::DB::Object::Metadata> documentation for more information.

=item B<save [PARAMS]>

Save the current object to the database table.  In the absence of PARAMS, if the object was previously C<load()>ed from the database, the row will be updated.  Otherwise, a new row will be created.

PARAMS are name/value pairs.  Valid parameters are:

=over 4

=item * C<insert>

If set to a true value, then an insert is attempted, regardless of whether or not the object was previously C<load()>ed from the database.

=item * C<update>

If set to a true value, then an update is attempted, regardless of whether or not the object was previously C<load()>ed from the database.

=back

It is an error to pass both the C<insert> and C<update> parameters in a single call.

Returns true if the row was inserted or updated successfully, false otherwise.

=back

=head1 RESERVED METHODS

As described in the C<Rose::DB::Object::Metadata> documentation, each column in the database table has an associated get/set accessor method in the C<Rose::DB::Object>.  Since the C<Rose::DB::Object> API already defines many methods (C<load()>, C<save()>, C<meta()>, etc.), accessor methods for columns that share the name of an existing method pose a problem.  The solution is to alias such columns using C<Rose::DB::Object::Metadata>'s  C<alias_column()> method. 

Here is a list of method names reserved by the C<Rose::DB::Object> API.  If you have a column with one of these names, you must alias it.

    db
    dbh
    delete
    DESTROY
    error
    init_db
    _init_db
    insert
    load
    meta
    not_found
    save
    update

Note that not all of these methods are public.  These methods do not suddently become public just because you now know their names!  Remember the stated policy of the C<Rose> web application framework: if a method is not documented, it does not exist.  (And no, the above list of method names does not constitute "documentation")

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2005 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
