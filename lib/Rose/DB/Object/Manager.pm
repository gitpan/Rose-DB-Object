package Rose::DB::Object::Manager;

use strict;

use Carp();

use Rose::DB::Objects::Iterator;
use Rose::DB::Object::QueryBuilder qw(build_select);

our $VERSION = '0.02';

our $Debug = 0;

#
# Class data
#

use Rose::Class::MakeMethods::Generic
(
  inheritable_scalar => [ 'error', 'total' ],
);

sub get_objects_count
{
  my($class) = shift;
  $class->get_objects(@_, count_only => 1);
}

sub get_objects_iterator { shift->get_objects(@_, return_iterator => 1) }
sub get_objects_sql      { shift->get_objects(@_, return_sql => 1) }

sub get_objects
{
  my($class, %args) = @_;

  $class->error(undef);

  my $return_sql      = delete $args{'return_sql'};
  my $return_iterator = delete $args{'return_iterator'};
  my $object_class    = delete $args{'object_class'} or Carp::croak "Missing object class argument";
  my $with_objects    = delete $args{'with_objects'};

  my $count_only = delete $args{'count_only'};

  my $db  = delete $args{'db'} || $object_class->init_db;
  my $dbh = delete $args{'dbh'};
  my $dbh_retained = 0;

  unless($dbh)
  {
    unless($dbh = $db->retain_dbh)
    {
      $class->error($db->error);
      return undef;
    }

    $dbh_retained = 1;
  }

  my %object_args = (ref $args{'object_args'} eq 'HASH') ? %{$args{'object_args'}} : ();
  my %subobject_args;

  $args{'share_db'} = 1  unless(exists $args{'share_db'});

  if(delete $args{'share_db'})
  {
    $object_args{'db'}    = $db;
    $subobject_args{'db'} = $db;
  }

  my $meta = $object_class->meta;

  my($fields, $fields_string, $table);

  my @tables  = ($meta->fq_table_sql);
  my %columns = ($tables[0] => scalar $meta->columns);#_names);
  my %classes = ($tables[0] => $object_class);
  my %methods = ($tables[0] => scalar $meta->column_mutator_method_names);
  my @classes = ($object_class);
  my %meta    = ($object_class => $meta);
  my %table_aliases = ($tables[0] => 't1', $meta->table => 't1');
  my %alias_tables  = (t1 => $tables[0]);

  if($with_objects)
  {
    my $clauses = $args{'clauses'} ||= [];

    my $i = 1;

    $with_objects = [ $with_objects ]  unless(ref $with_objects);

    foreach my $name (@$with_objects)
    {
      my $key = $meta->foreign_key($name) or 
        Carp::confess "$class - no information found for foreign key '$name'";

      my $fk_class = $key->class or 
        Carp::confess "$class - Missing foreign object class for '$name'";

      my $fk_columns = $key->key_columns or 
        Carp::confess "$class - Missing key columns for '$name'";

      my $fk_meta = $fk_class->meta; 

      $meta{$fk_class} = $fk_meta;

      push(@tables, $fk_meta->fq_table_sql);
      push(@classes, $fk_class);
      $i++;

      $table_aliases{$tables[-1]} = "t$i";
      $table_aliases{$fk_meta->table} = "t$i";
      $alias_tables{"t$i"} = $tables[-1];

      $columns{$tables[-1]} = $fk_meta->columns;#_names;
      $classes{$tables[-1]} = $fk_class;
      $methods{$tables[-1]} = $fk_meta->column_mutator_method_names;

      # Add join condition(s)
      while(my($local_column, $foreign_column) = each(%$fk_columns))
      {
        # Aliased table names
        push(@$clauses, "t1.$local_column = t$i.$foreign_column");

        # Fully-qualified table names
        #push(@$clauses, "$tables[0].$local_column = $tables[-1].$foreign_column");
      }
    }
  }

  if($count_only)
  {
    delete $args{'limit'};
    delete $args{'sort_by'};

    my($sql, $bind) =
      build_select(dbh     => $dbh,
                   select  => 'COUNT(*)',
                   tables  => \@tables,
                   columns => \%columns,
                   classes => \%classes,
                   meta    => \%meta,
                   db      => $db,
                   pretty  => $Debug,
                   %args);

    if($return_sql)
    {
      $db->release_dbh  if($dbh_retained);
      return wantarray ? ($sql, $bind) : $sql;
    }

    my $count = 0;

    eval
    {
      local $dbh->{'RaiseError'} = 1;
      $Debug && warn "$sql\n";
      my $sth = $dbh->prepare($sql) or die $dbh->errstr;
      $sth->execute(@$bind);
      $count = $sth->fetchrow_array;
      $sth->finish;
    };

    if($@)
    {
      $class->total(undef);
      $class->error("get_objects() - $@");
      return undef;
    }

    $class->total($count);
    return $count;
  }

  my($count, @objects, $iterator);

  my($sql, $bind) =
    build_select(dbh     => $dbh,
                 tables  => \@tables,
                 columns => \%columns,
                 classes => \%classes,
                 meta    => \%meta,
                 db      => $db,
                 pretty  => $Debug,
                 %args);

  if($return_sql)
  {
    $db->release_dbh  if($dbh_retained);
    return wantarray ? ($sql, $bind) : $sql;
  }

  eval
  {
    local $dbh->{'RaiseError'} = 1;

    $Debug && warn "$sql (", join(', ', @$bind), ")\n";
    my $sth = $dbh->prepare($sql) or die $dbh->errstr;

    $sth->{'RaiseError'} = 1;

    $sth->execute(@$bind);

    my %row;

    my $i = 1;

    foreach my $table (@tables)
    {
      my $class = $classes{$table};

      foreach my $column (@{$methods{$table}})
      {
        $sth->bind_col($i++, \$row{$class}{$column});
      }
    }

    if($return_iterator)
    {
      $iterator = Rose::DB::Objects::Iterator->new(active => 1);

      my $num_subtables = $with_objects ? @$with_objects : 0;

      $iterator->_next_code(sub
      {
        my($self) = shift;

        my $object = 0;

        eval
        {
          unless($sth->fetch)
          {
            $self->total($self->{'_count'});
            return 0;
          }

          $object = $object_class->new(%{$row{$object_class}}, %object_args);

          if($with_objects)
          {
            foreach my $i (1 .. $num_subtables)
            {
              my $method = $with_objects->[$i - 1];
              my $class  = $classes[$i];

              $object->$method($class->new(%{$row{$class}}, %subobject_args));
            }
          }

          $self->{'_count'}++;
        };

        if($@)
        {
          $self->error("next() - $@");
          return undef;
        }

        return $object;
      });

      $iterator->_finish_code(sub
      {
        $sth->finish;
        $db->release_dbh  if($dbh_retained);
      });

      return $iterator;
    }

    if($with_objects)
    {
      my $num_subtables = @$with_objects;

      while($sth->fetch)
      {
        my $object = $object_class->new(%{$row{$object_class}}, %object_args);

        foreach my $i (1 .. $num_subtables)
        {
          my $method = $with_objects->[$i - 1];
          my $class  = $classes[$i];

          $object->$method($class->new(%{$row{$class}}, %subobject_args));
        }

        push(@objects, $object);
      }
    }
    else
    {
      while($sth->fetch)
      {
        push(@objects, $object_class->new(%{$row{$object_class}}, %object_args));
      }
    }

    $sth->finish;
  };

  return $iterator  if($iterator);

  $db->release_dbh  if($dbh_retained);

  if($@)
  {
    $class->error("get_objects() - $@");
    return undef;
  }

  return \@objects;
}

sub _map_action
{
  my($class, $action, @objects) = @_;

  $class->error(undef);

  foreach my $object (@objects)
  {
    unless($object->$action())
    {
      $class->error($object->error);
      return;
    }
  }

  return 1;
}

sub save_objects   { shift->_map_action('save', @_)   }
sub delete_objects { shift->_map_action('delete', @_) }

1;

__END__

=head1 NAME

Rose::DB::Object::Manager - Fetch multiple Rose::DB::Object-derived objects from the database.

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

  package Product::Manager;

  use Rose::DB::Object::Manager;
  our @ISA = qw(Rose::DB::Object::Manager);

  sub get_products
  {
    my $class = shift;

    Rose::DB::Object::Manager->get_objects(
      object_class => 'Product', @_)
  }

  sub get_products_iterator
  {
    my $class = shift;

    Rose::DB::Object::Manager->get_objects_iterator(
      object_class => 'Product', @_)
  }

  sub get_products_count
  {
    my $class = shift;

    Rose::DB::Object::Manager->get_objects_count(
      object_class => 'Product', @_)
  }

  ...

  #
  # Get a reference to an array of objects
  #

  $products = 
    Product::Manager->get_products
    (
      query =>
      [
        category_id => [ 5, 7, 22 ],
        status      => 'active',
        start_date  => { lt => '15/12/2005 6:30 p.m.' },
        name        => { like => [ '%foo%', '%bar%' ] },
      ],
      sort_by => 'category_id, start_date DESC',
      limit   => 100
    ) 
    or die Product::Manager->error;

  foreach my $product (@$products)
  {
    print $product->id, ' ', $product->name, "\n";
  }

  #
  # Get objects iterator
  #

  $iterator = 
    Product::Manager->get_products_iterator
    (
      query =>
      [
        category_id => [ 5, 7, 22 ],
        status      => 'active',
        start_date  => { lt => '15/12/2005 6:30 p.m.' },
        name        => { like => [ '%foo%', '%bar%' ] },
      ],
      sort_by => 'category_id, start_date DESC',
      limit   => 100
    )
    or die Product::Manager->error;

  while($product = $iterator->next)
  {
    print $product->id, ' ', $product->name, "\n";
  }

  print $iterator->total;

  #
  # Get objects count
  #

  $count =
    Product::Manager->get_products_count
    (
      query =>
      [
        category_id => [ 5, 7, 22 ],
        status      => 'active',
        start_date  => { lt => '15/12/2005 6:30 p.m.' },
        name        => { like => [ '%foo%', '%bar%' ] },
      ],
      limit   => 100
    ); 

   die Product::Manager->error  unless(defined $count);

  print $count; # or Product::Manager->total()

  #
  # Get objects and sub-objects in a single query
  #

  $products = 
    Product::Manager->get_products
    (
      with_objects => [ 'category' ],
      query =>
      [
        category_id => [ 5, 7, 22 ],
        status      => 'active',
        start_date  => { lt => '15/12/2005 6:30 p.m.' },
        name        => { like => [ '%foo%', '%bar%' ] },
      ],
      sort_by => 'category_id, start_date DESC',
      limit   => 100
    )
    or die Product::Manager->error;

  foreach my $product (@$products)
  {
    print $product->name, ': ', $product->category->name, "\n";
  }

=head1 DESCRIPTION

C<Rose::DB::Object::Manager> is a base class for classes that select rows from tables fronted by C<Rose::DB::Object>-derived classes.  Each row in the table(s) queried is converted into the equivalent C<Rose::DB::Object>-derived object.

Class methods are provided for fetching objects all at once, one at a time through the use of an iterator, or just getting the object count.  Subclasses are expected to create syntactically pleasing wrappers for C<Rose::DB::Object::Manager> class methods.  A very minimal example is shown in the L<synopsis|SYNOPSIS> above.

=head1 CLASS METHODS

=over 4

=item B<error>

Returns the text message associated with the last error, or false if there was no error.

=item B<get_objects [PARAMS]>

Get C<Rose::DB::Object>-derived objects based on PARAMS, where PARAMS are name/value pairs.  Returns a  reference to a (possibly empty) array in scalar context, a list of objects in list context, or undef if there was an error.  

Note that naively calling this method in list context may result in a list containing a single undef element if there was an error.  Example:

    # If there is an error, you'll get: @objects = (undef)
    @objects = Rose::DB::Object::Manager->get_objects(...);

If you want to avoid this, feel free to change the behavior your wrapper method, or just call it in scalar context (which is more efficient anyway for long lists of objects).

Valid parameters are:

=over 4

=item C<db DB>

A C<Rose::DB>-derived object used to access the database.  If omitted, one will be created by calling the C<init_db()> object method of the C<object_class>.

=item C<object_args HASHREF>

A reference to a hash of name/value pairs to be passed to the constructor of each C<object_class> object fetched, in addition to the values from the database.

=item C<object_class CLASS>

The class name of the C<Rose::DB::Object>-derived objects to be fetched.  This parameter is required; a fatal error will occur if it is omitted.

=item C<share_db BOOL>

If true, C<db> will be passed to each C<Rose::DB::Object>-derived object when it is constructed.  Defaults to true.

=item C<with_object OBJECTS>

Also fetch sub-objects associated with foreign keys in the primary table, where OBJECTS is a reference to an array of foreign key names, as defined by the C<Rose::DB::Object::Metadata> object for C<object_class>.

Another table will be added to the query for each foreign key listed.  The "join" clauses will be added automatically based on the foreign key definitions.  Note that (obviously) each foreign key table has to have a C<Rose::DB::Object>-derived class fronting it.  See the L<synopsis|SYNOPSIS> for a simple example.

=item Any valid Rose::DB::Object::QueryBuilder::build_select() parameter

Any parameter that can be passed to the C<build_select()> function of the C<Rose::DB::Object::QueryBuilder> module can also be passed to this method, which will then pass them on to build_select() to create the SQL query string used to fetch the objects.

=back

=item B<get_objects_count [PARAMS]>

Accepts the same arguments as C<get_objects()>, but just returns the number of rows that would have been fetched, or undef if there was an error.

=item B<get_objects_iterator [PARAMS]>

Accepts the same arguments as C<get_objects()>, but return a C<Rose::DB::Objects::Iterator> object which can be used to fetch the objects one at a time, or undef if there was an error.

=item B<get_objects_sql [PARAMS]>

Accepts the same arguments as C<get_objects()>, but return the SQL query string that would have been used to fetch the objects (in scalar context), or the SQL query string and a reference to an array of bind values (in list context).

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2005 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
