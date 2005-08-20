package Rose::DB::Object::Metadata::Relationship::OneToOne;

use strict;

use Carp();

use Rose::DB::Object::Metadata::Relationship;
our @ISA = qw(Rose::DB::Object::Metadata::Relationship);

use Rose::Object::MakeMethods::Generic;
use Rose::DB::Object::MakeMethods::Generic;

our $VERSION = '0.01';

__PACKAGE__->add_method_maker_argument_names
(
  qw(class share_db key_columns)
);

use Rose::Object::MakeMethods::Generic
(
  boolean =>
  [
    '_share_db' => { default => 1 },
  ],

  hash =>
  [
    _key_column  => { hash_key  => 'key_columns' },
    _key_columns => { interface => 'get_set_all' },
  ],
);

Rose::Object::MakeMethods::Generic->make_methods
(
  { preserve_existing => 1 },
  scalar => 
  [
    'foreign_key',
    __PACKAGE__->method_maker_argument_names
  ],
);

sub method_maker_class { 'Rose::DB::Object::MakeMethods::Generic' }
sub method_maker_type  { 'object_by_key' }

sub type { 'one to one' }

sub share_db    { shift->_fk_or_self(share_db => @_)     }
sub key_column  { shift->_fk_or_self(key_column => @_)   }
sub key_columns { shift->_fk_or_self(key_columns => @_)  }

*map_column = \&key_column;
*column_map = \&key_columns;

sub _fk_or_self
{
  my($self, $method) = (shift, shift);

  if(my $fk = $self->foreign_key)
  {
    return $fk->$method(@_);
  }

  $method = "_$method"  if($self->can("_$method"));
  return $self->$method(@_);
}

sub make_method
{
  my($self) = shift;

  if(my $fk = $self->foreign_key)
  {
    return $fk->make_method(@_);
  }

  return $self->SUPER::make_method(@_);
}

sub id
{
  my($self) = shift;

  my $column_map = $self->column_map;

  return $self->class . ' ' . 
    join("\0", map { join("\1", lc $_, lc $column_map->{$_}) } sort keys %$column_map);
}

1;

__END__

=head1 NAME

Rose::DB::Object::Metadata::Relationship::OneToOne - One to one table relationship metadata object.

=head1 SYNOPSIS

  use Rose::DB::Object::Metadata::Relationship::OneToOne;

  $rel = Rose::DB::Object::Metadata::Relationship::OneToOne->new(...);
  $rel->make_method(...);
  ...

=head1 DESCRIPTION

Objects of this class store and manipulate metadata for relationships in which a single row from one table refers to a single row in another table.

This class inherits from L<Rose::DB::Object::Metadata::Relationship>. Inherited methods that are not overridden will not be documented a second time here.  See the L<Rose::DB::Object::Metadata::Relationship> documentation for more information.

=head1 OBJECT METHODS

=over 4

=item B<foreign_key [FK]>

Get or set the L<Rose::DB::Object::Metadata::ForeignKey> object to which this object delegates all responsibility.

One to one relationships encapsulate essentially the same information as foreign keys.  If a foreign key object is stored in this relationship object, then I<all compatible operations are passed through to the foreign key object.>  This includes making object method(s) and adding or modifying the local-to-foreign column map.  In other words, if a L<foreign_key> is set, the relationship object simply acts as a proxy for the foreign key object.

=item B<map_column LOCAL [, FOREIGN]>

If passed a local column name LOCAL, return the corresponding column name in the foreign table.  If passed both a local column name LOCAL and a foreign column name FOREIGN, set the local/foreign mapping and return the foreign column name.

=item B<column_map [HASH | HASHREF]>

Get or set a reference to a hash that maps local column names to foreign column names.

=item B<method_maker_class>

Returns L<Rose::DB::Object::MakeMethods::Generic>.

=item B<method_maker_type>

Returns C<object_by_key>.

=item B<type>

Returns "one to one".

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2005 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
