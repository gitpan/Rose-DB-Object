package Rose::DB::Object::Metadata::Relationship::OneToMany;

use strict;

use Carp();

use Rose::DB::Object::Metadata::Relationship;
our @ISA = qw(Rose::DB::Object::Metadata::Relationship);

use Rose::Object::MakeMethods::Generic;
use Rose::DB::Object::MakeMethods::Generic;

our $VERSION = '0.01';

__PACKAGE__->add_method_maker_argument_names
(
  qw(class share_db key_columns manager_class manager_method manager_args query_args)
);

use Rose::Object::MakeMethods::Generic
(
  boolean =>
  [
    'share_db' => { default => 1 },
  ],

  hash =>
  [
    key_column  => { hash_key  => 'key_columns' },
    key_columns => { interface => 'get_set_all' },
  ],
);

Rose::Object::MakeMethods::Generic->make_methods
(
  { preserve_existing => 1 },
  scalar => 
  [
    __PACKAGE__->method_maker_argument_names
  ],
);

sub method_maker_class { 'Rose::DB::Object::MakeMethods::Generic' }
sub method_maker_type  { 'objects_by_key' }

sub type { 'one to many' }

*map_column = \&key_column;
*column_map = \&key_columns;

1;

__END__

=head1 NAME

Rose::DB::Object::Metadata::Relationship::OneToMany - One to many table relationship metadata object.

=head1 SYNOPSIS

  use Rose::DB::Object::Metadata::Relationship::OneToMany;

  $rel = Rose::DB::Object::Metadata::Relationship::OneToMany->new(...);
  $rel->make_method(...);
  ...

=head1 DESCRIPTION

Objects of this class store and manipulate metadata for relationships in which a single row from one table refers to multiple rows in another table.

This class inherits from L<Rose::DB::Object::Metadata::Relationship>. Inherited methods that are not overridden will not be documented a second time here.  See the L<Rose::DB::Object::Metadata::Relationship> documentation for more information.

=head1 OBJECT METHODS

=over 4

=item B<map_column LOCAL [, FOREIGN]>

If passed a local column name LOCAL, return the corresponding column name in the foreign table.  If passed both a local column name LOCAL and a foreign column name FOREIGN, set the local/foreign mapping and return the foreign column name.

=item B<column_map [HASH | HASHREF]>

Get or set a reference to a hash that maps local column names to foreign column names.

=item B<method_maker_class>

Returns L<Rose::DB::Object::MakeMethods::Generic>.

=item B<method_maker_type>

Returns C<objects_by_key>.

=item B<type>

Returns "one to many".

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2005 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
