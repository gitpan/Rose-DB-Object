package Rose::DB::Object::Metadata::Column;

use strict;

use Carp();

use Rose::Object;
our @ISA = qw(Rose::Object);

use Rose::Object::MakeMethods::Generic;
use Rose::DB::Object::MakeMethods::Generic;

our $VERSION = '0.01';

use overload
(
  '""' => sub { shift->name },
   fallback => 1,
);

use Rose::Class::MakeMethods::Set
(
  inherited_set => 'method_maker_argument_name'
);

Rose::Object::MakeMethods::Generic->make_methods
(
  { preserve_existing => 1 },
  scalar => 
  [
    'name',
    'method_name',
    __PACKAGE__->method_maker_argument_names,
  ]
);

*accessor_method_name = \&method_name;
*mutator_method_name  = \&method_name;

sub type { 'scalar' }

sub should_inline_value { 0 }

# sub foreign_key
# {
#   my($self) = shift;
#   
#   if(@_)
#   {
#     if(@_ == 1)
#     {
#       if(ref $_[0] eq 'HASH')
#       {
#         return $self->{'foreign_key'}
#       }
#     }
#     else
#     {
#       Carp::croak "Invalid foreign_key arguments: @_";
#     }
#   }
#   
#   return $self->{'foreign_key'};
# }

sub method_maker_arguments
{
  my($self) = shift;

  my %opts = map { $_ => $self->$_() } grep { defined $self->$_() }
    $self->method_maker_argument_names;

  return wantarray ? %opts : \%opts;
}

sub method_maker_class { 'Rose::DB::Object::MakeMethods::Generic' }
sub method_maker_type  { 'scalar' }

sub make_method
{
  my($self, %args) = @_;

  Carp::croak "Missing required 'options' argument"
    unless($args{'options'});

  Carp::croak "Missing required 'target_class' argument"
    unless($args{'options'}{'target_class'});

  $self->method_maker_class->make_methods(
    $args{'options'}, 
    $self->method_maker_type => 
    [
      $self->method_name => scalar $self->method_maker_arguments
    ]);
}

1;

__END__

=head1 NAME

Rose::DB::Object::Metadata::Column - Base class for an object encapsulation of  database column metadata.

=head1 SYNOPSIS

  package MyColumnType;

  use Rose::DB::Object::Metadata::Column;
  our @ISA = qw(Rose::DB::Object::Metadata::Column);
  ...

=head1 DESCRIPTION

This is the base class for objects that store and manipulate database column metadata.  Column metadata objects store information about columns (data type, size, etc.) and are responsible for creating object methods that manipulate column values.

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

Get or set the name of the method used to get the column value.  This is currently an alias for the C<method_name> method.

=item B<make_method PARAMS>

Create an object method used to manipulate column values.  To do this, the C<make_methods()> class method of the C<method_maker_class> is called.  PARAMS are name/value pairs.  Valid PARAMS are:

=over 4

=item C<options HASHREF>

A reference to a hash of options that will be passed as the first argument to the call to the C<make_methods()> class method of the C<method_maker_class>.  This parameter is required, and the HASHREF must include a value for the key C<target_class>, which C<make_methods()> needs in order to determine where to make the method.

=back

The call to C<make_methods()> looks something like this:

    $self->method_maker_class->make_methods(
      $args{'options'}, 
      $self->method_maker_type => 
      [
        $self->method_name => scalar $self->method_maker_arguments
      ]);

where C<$args{'options'}> is the value of the "options" PARAM.

The C<method_maker_class> is expected to be a subclass of (or otherwise conform to the interface of) C<Rose::Object::MakeMethods>.  See the C<Rose::Object::MakeMethods> documentation for more information on the interface, and the C<make_methods()> method in particular.

I know the call above looks confusing, but it is worth studying if you plan to subclass C< Rose::DB::Object::Metadata::Column>.  The various subclasses that are part of the C<Rose::DB::Object> distribution provide some good examples.

More than one method may be created, but there must be at least one get/set accessor method created, and its name must match the return value of C<method_name()>.

=item B<method_maker_arguments>

Returns a hash (in list context) or a reference to a hash (in scalar context) or arguments that will be passed (as a hash ref) to the call to the C<make_methods()> class method of the C<method_maker_class>, as shown in the C<make_method> example above.

The default implementation populates the hash with the defined return values of the object methods named by C<method_maker_argument_names>.  (Method names that return undefined values are not included in the hash.)

=item B<method_maker_class>

Returns the C<Rose::Object::MakeMethods>-derived class used to create the object method that will manipulate the column value.  The default implementation returns C<Rose::DB::Object::MakeMethods::Generic>.

=item B<method_maker_type>

Returns the method type, which is passed to the call to the C<make_methods()> class method of the C<method_maker_class>, as shown in the C<make_method> example above.  The default implementation returns C<scalar>.

=item B<method_name [NAME]>

Get or set the name of the method used to manipulate (get or set) the column value.

=item B<mutator_method_name [NAME]>

Get or set the name of the method used to set the column value.  This is currently an alias for the C<method_name> method.

=item B<name [NAME]>

Get or set the name of the column, not including the table name, username, schema, or any other qualifier.

=item B<should_inline_value DB, VALUE>

Given the C<Rose::DB>-derived object DB and the column value VALUE, return true of the value should be "inlined" (i.e., not bound to a "?" placeholder and passed as an argument to C<DBI>'s C<execute()> method), false otherwise.  The default implementation always returns false.

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

All of the information needed to make this decision is available to the call to C<should_inline_value()>.  It gets passed a C<Rose::DB>-derived object, from which it can determine the database driver, and it gets passed the actual value, which it can check to see if it matches C</^current$/i>.

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
