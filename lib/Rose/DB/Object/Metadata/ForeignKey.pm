package Rose::DB::Object::Metadata::ForeignKey;

use strict;

use Rose::Object::MakeMethods::Generic;

use Rose::DB::Object::Metadata::Column;
our @ISA = qw(Rose::DB::Object::Metadata::Column);

our $VERSION = '0.01';

__PACKAGE__->add_method_maker_argument_names
(
  qw(share_db class key_columns)
);

Rose::Object::MakeMethods::Generic->make_methods
(
  { preserve_existing => 1 },
  scalar => [ __PACKAGE__->method_maker_argument_names ],

  hash =>
  [
    key_column  => { hash_key  => 'key_columns' },
    key_columns => { interface => 'get_set_all' },
  ],
);

sub method_maker_class { 'Rose::DB::Object::MakeMethods::Generic' }
sub method_maker_type  { 'object_by_key' }

sub type { 'foreign key' }

1;

__END__

=head1 NAME

Rose::DB::Object::Metadata::ForeignKey - Foreign key metadata.

=head1 SYNOPSIS

  use Rose::DB::Object::Metadata::ForeignKey;

  $fk = Rose::DB::Object::Metadata::ForeignKey->new(...);
  $fk->make_method(...);
  ...

=head1 DESCRIPTION

Objects of this class store and manipulate metadata for foreign keys in a database table.  It stores information about which columns in the local table map to which columns in the foreign table, and is responsible for creating an accessor method for the foreign object.

This class represents (and will create an accessor method for) C<the thing referenced by> the foreign key column(s).  You'll still need accessor method(s) for the foreign key column(s) themselves.

Both the local table and the foreign table will need C<Rose::DB::Object>-derived classes fronting them.

Since there is a lot of overlap in responsibilities, this class inherits from C<Rose::DB::Object::Metadata::Column>. Inherited methods that are not overridden will not be documented a second time here.  See the C<Rose::DB::Object::Metadata::Column> documentation for more information.

=head1 OBJECT METHODS

=over 4

=item B<class [CLASS]>

Get or set the class name of the C<Rose::DB::Object>-derived object that encapsulates rows from the table referenced by the foreign key column(s).

=item B<key_column LOCAL [, FOREIGN]>

If passed a local column name LOCAL, return the corresponding column name in the foreign table.  If passed both a local column name LOCAL and a foreign column name FOREIGN, set the local/foreign mapping and return the foreign column name.

=item B<key_columns [HASH|HASHREF]>

Get or set a reference to a hash that maps local column names to foreign column names in the table referenced by the foreign key.

=item B<method_maker_class>

Returns C<Rose::DB::Object::MakeMethods::Generic>.

=item B<method_maker_type>

Returns C<object_by_key>.

=item B<share_db [BOOL]>

Get or set the boolean flag that determines whether the C<db> attribute of the current object is shared with the foreign object to be fetched.  If undefined, it is assumed to be true.

=item B<type>

Returns "foreign key".

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2005 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
