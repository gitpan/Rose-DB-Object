package Rose::DB::Object::Metadata::Column;

use strict;

use Carp();

use Rose::DB::Object::Metadata::Util qw(:all);

use Rose::DB::Object::Metadata::MethodMaker;
our @ISA = qw(Rose::DB::Object::Metadata::MethodMaker);

use Rose::Object::MakeMethods::Generic;
use Rose::DB::Object::MakeMethods::Generic;

our $VERSION = '0.032';

use overload
(
  '""' => sub { shift->name },
   fallback => 1,
);

__PACKAGE__->add_method_maker_argument_names(qw(default type));

Rose::Object::MakeMethods::Generic->make_methods
(
  { preserve_existing => 1 },
  scalar => 
  [
    __PACKAGE__->method_maker_argument_names,
  ],

  boolean => 
  [
    'manager_uses_method',
    'is_primary_key_member',
    'not_null',
  ],
);

*primary_key = \&is_primary_key_member;

*accessor_method_name = \&Rose::DB::Object::Metadata::MethodMaker::method_name;
*mutator_method_name  = \&Rose::DB::Object::Metadata::MethodMaker::method_name;

sub alias { shift->method_name(@_) }

sub type { 'scalar' }

sub should_inline_value { 0 }

sub name
{
  my($self) = shift;

  if(@_)
  {
    $self->name_sql(undef);
    return $self->{'name'} = shift;
  }

  return $self->{'name'};
}

sub name_sql
{
  my($self) = shift;

  return $self->{'name_sql'} = shift  if(@_);

  if(defined $self->{'name_sql'})
  {
    return $self->{'name_sql'};
  }

  if(my $parent = $self->parent)
  {
    return $self->{'name_sql'} = $parent->db->quote_column_name($self->{'name'});
  }
  else
  {
    return $self->{'name'};
  }
}

sub parse_value  { $_[2] }
sub format_value { $_[2] }

sub primary_key_position
{
  my($self) = shift;

  $self->{'primary_key_position'} = shift  if(@_);

  unless($self->is_primary_key_member)
  {
    return $self->{'primary_key_position'} = undef;
  }

  return $self->{'primary_key_position'};
}

# These constants are from the DBI documentation.  Is there somewhere 
# I can load these from?
use constant SQL_NO_NULLS => 0;
use constant SQL_NULLABLE => 1;

sub init_with_dbi_column_info
{
  my($self, $col_info) = @_;

  # We're doing this in Rose::DB::Object::Metadata::Auto now
  #$self->parent->db->refine_dbi_column_info($col_info);

  $self->default($col_info->{'COLUMN_DEF'});

  if($col_info->{'NULLABLE'} == SQL_NO_NULLS)
  {
    $self->not_null(1);
  }
  elsif($col_info->{'NULLABLE'} == SQL_NULLABLE)
  {
    $self->not_null(0);
  }

  return;
}

sub perl_column_defintion_attributes
{
  my($self) = shift;

  my @attrs;

  foreach my $attr ('type', sort keys %$self)
  {
    my $val = $self->can($attr) ? $self->$attr() : next;

    if((!defined $val || ref $val || $attr =~ /^(?:name(?:_sql)?|is_primary_key_member|primary_key_position)$/) ||
       ($attr eq 'method_name' && $self->method_name eq $self->name) ||
       ($attr eq 'not_null' && !$self->not_null))
    {
      next;
    }

    push(@attrs, $attr);
  }

  return @attrs;
}

sub perl_hash_definition
{
  my($self, %args) = @_;

  my $meta = $self->parent;

  my $name_padding = $args{'name_padding'};

  my $indent = defined $args{'indent'} ? $args{'indent'} : 
                 ($meta ? $meta->default_perl_indent : undef);

  my $inline = defined $args{'inline'} ? $args{'inline'} : 1;

  my %hash;

  foreach my $attr ($self->perl_column_defintion_attributes)
  {
    $hash{$attr} = $self->$attr();
  }

  if($name_padding > 0)
  {
    return sprintf('%-*s => ', $name_padding, perl_quote_key($self->name)) .
           perl_hashref(hash      => \%hash, 
                        inline    => $inline, 
                        indent    => $indent, 
                        sort_keys => \&_sort_keys);
  }
  else
  {
    return perl_quote_key($self->name) . ' => ' .
           perl_hashref(hash      => \%hash, 
                        inline    => $inline, 
                        indent    => $indent, 
                        sort_keys => \&_sort_keys);
  }
}

sub _sort_keys 
{
  if($_[0] eq 'type')
  {
    return -1;
  }
  elsif($_[1] eq 'type')
  {
    return 1;
  }

  return lc $_[0] cmp lc $_[1];
}

sub method_maker_class { 'Rose::DB::Object::MakeMethods::Generic' }
sub method_maker_type  { 'scalar' }

1;

__END__

=head1 NAME

Rose::DB::Object::Metadata::Column - Base class for database column metadata objects.

=head1 SYNOPSIS

  package MyColumnType;

  use Rose::DB::Object::Metadata::Column;
  our @ISA = qw(Rose::DB::Object::Metadata::Column);
  ...

=head1 DESCRIPTION

This is the base class for objects that store and manipulate database column metadata.  Column metadata objects store information about columns (data type, size, etc.) and are responsible for parsing, formatting, and creating object methods that manipulate column values.

C<Rose::DB::Object::Metadata::Column> objects stringify to the value returned by the C<name()> method.  This allows full-blown column objects to be used in place of column name strings in most situations.

=head1 CONSTRUCTOR

=over 4

=item B<new PARAMS>

Constructs a new object based on PARAMS, where PARAMS are
name/value pairs.  Any object method is a valid parameter name.

=back

=head1 OBJECT METHODS

=over 4

=item B<accessor_method_name [NAME]>

Get or set the name of the method used to get the column value.  This is currently an alias for the L<method_name> method.

=item B<default [VALUE]>

Get or set the default value of the column.

=item B<format_value DB, VALUE>

Convert VALUE into a string suitable for the database column of this type.  VALUE is expected to be like the return value of the C<parse_value()> method.  DB is a L<Rose::DB> object that may be used as part of the parsing process.  Both arguments are required.

=item B<is_primary_key_member [BOOL]>

Get or set the boolean flag that indicates whether or not this column is part of the primary key for its table.

=item B<make_method PARAMS>

Create an object method used to manipulate column values.  To do this, the C<make_methods()> class method of the L<method_maker_class> is called.  PARAMS are name/value pairs.  Valid PARAMS are:

=over 4

=item C<options HASHREF>

A reference to a hash of options that will be passed as the first argument to the call to the C<make_methods()> class method of the L<method_maker_class>.  This parameter is required, and the HASHREF must include a value for the key C<target_class>, which C<make_methods()> needs in order to determine where to make the method.

=back

The call to C<make_methods()> looks something like this:

    my $method_name = $self->method_name;

    # Use "name" if "method_name" is undefined
    unless(defined $method_name)
    {
      # ...and set "method_name" so it's defined now
      $method_name = $self->method_name($self->name);
    }

    $self->method_maker_class->make_methods(
      $args{'options'}, 
      $self->method_maker_type => 
      [
        $method_name => scalar $self->method_maker_arguments
      ]);

where C<$args{'options'}> is the value of the "options" PARAM.

The L<method_maker_class> is expected to be a subclass of (or otherwise conform to the interface of) L<Rose::Object::MakeMethods>.  See the L<Rose::Object::MakeMethods> documentation for more information on the interface, and the C<make_methods()> method in particular.

I know the call above looks confusing, but it is worth studying if you plan to subclass L<Rose::DB::Object::Metadata::Column>.  The various subclasses that are part of the L<Rose::DB::Object> distribution provide some good examples.

More than one method may be created, but there must be at least one get/set accessor method created, and its name must match the L<method_name> (or L<name> if L<method_name> is undefined).

=item B<manager_uses_method [BOOL]>

If true, then L<Rose::DB::Object::QueryBuilder> will pass column values through the object method associated with this column when composing SQL queries where C<query_is_sql> is not set.  The default value is false.  See the L<Rose::DB::Object::QueryBuilder> documentation for more information.

Note: the method is named "manager_uses_method" instead of, say, "query_builder_uses_method" because L<Rose::DB::Object::QueryBuilder> is rarely used directly.  Instead, it's mostly used indirectly through the L<Rose::DB::Object::Manager> class.

=item B<method_maker_arguments>

Returns a hash (in list context) or a reference to a hash (in scalar context) or arguments that will be passed (as a hash ref) to the call to the C<make_methods()> class method of the L<method_maker_class>, as shown in the L<make_method> example above.

The default implementation populates the hash with the defined return values of the object methods named by L<method_maker_argument_names>.  (Method names that return undefined values are not included in the hash.)

=item B<method_maker_argument_names>

Returns a list of methods to call in order to generate the L<method_maker_arguments> hash.

=item B<method_maker_class>

Returns the name of the L<Rose::Object::MakeMethods>-derived class used to create the object method that will manipulate the column value.  The default implementation returns L<Rose::DB::Object::MakeMethods::Generic>.

=item B<method_maker_type>

Returns the method type, which is passed to the call to the C<make_methods()> class method of the L<method_maker_class>, as shown in the L<make_method> example above.  The default implementation returns C<scalar>.

=item B<method_name [NAME]>

Get or set the name of the method used to manipulate (get or set) the column value.  This may be left undefined if the desired method name is stored in L<name> instead.  Once the method is actually created, the L<method_name> will be set.

=item B<mutator_method_name [NAME]>

Get or set the name of the method used to set the column value.  This is currently an alias for the L<method_name> method.

=item B<method_name [NAME]>

Get or set the name of the object method to be created for this column.  This may be left undefined if the desired method name is stored in L<name> instead.  Once the method is actually created, the L<method_name> will be set.

=item B<name [NAME]>

Get or set the name of the column, not including the table name, username, schema, or any other qualifier.

=item B<not_null [BOOL]>

Get or set a boolean flag that indicated whether or not the column 
value can can be null.

=item B<parse_value DB, VALUE>

Parse and return a convenient Perl representation of VALUE.  What form this value will take is up to the column subclass.  If VALUE is a keyword or otherwise has special meaning to the underlying database, it may be returned unmodified.  DB is a L<Rose::DB> object that may be used as part of the parsing process.  Both arguments are required.

=item B<primary_key_position [INT]>

Get or set the column's ordinal position in the primary key.  Returns undef if the column is not part of the primary key.  Position numbering starts from 1.

=item B<should_inline_value DB, VALUE>

Given the L<Rose::DB>-derived object DB and the column value VALUE, return true of the value should be "inlined" (i.e., not bound to a "?" placeholder and passed as an argument to C<DBI>'s C<execute()> method), false otherwise.  The default implementation always returns false.

This method is necessary because some C<DBI> drivers do not (or cannot) always do the right thing when binding values to placeholders in SQL statements.  For example, consider the following SQL for the Informix database:

    CREATE TABLE test (d DATETIME YEAR TO SECOND);
    INSERT INTO test (d) VALUES (CURRENT);

This is valid Informix SQL and will insert a row with the current date and time into the "test" table. 

Now consider the following attempt to do the same thing using C<DBI> placeholders (assume the table was already created as per the CREATE TABLE statement above):

    $sth = $dbh->prepare('INSERT INTO test (d) VALUES (?)');
    $sth->execute('CURRENT'); # Error!

What you'll end up with is an error like this:

    DBD::Informix::st execute failed: SQL: -1262: Non-numeric 
    character in datetime or interval.

In other words, DBD::Informix has tried to quote the string "CURRENT", which has special meaning to Informix only when it is not quoted. 

In order to make this work, the value "CURRENT" must be "inlined" rather than bound to a placeholder when it is the value of a "DATETIME YEAR TO SECOND" column in an Informix database.

All of the information needed to make this decision is available to the call to C<should_inline_value()>.  It gets passed a L<Rose::DB>-derived object, from which it can determine the database driver, and it gets passed the actual value, which it can check to see if it matches C</^current$/i>.

This is just one example.  Each subclass of C<Rose::DB::Object::Metadata::Column> must determine for itself when a value needs to be inlined.

=item B<type>

Returns the (possibly abstract) data type of the column.  The default implementation returns "scalar".

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2005 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
