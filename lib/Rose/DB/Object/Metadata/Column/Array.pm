package Rose::DB::Object::Metadata::Column::Array;

use strict;

use Rose::Object::MakeMethods::Generic;
use Rose::DB::Object::MakeMethods::Generic;

use Rose::DB::Object::Metadata::Column;
our @ISA = qw(Rose::DB::Object::Metadata::Column);

our $VERSION = '0.02';

__PACKAGE__->add_method_maker_argument_names
(
  qw(default dimensions)
);

Rose::Object::MakeMethods::Generic->make_methods
(
  { preserve_existing => 1 },
  scalar => [ __PACKAGE__->method_maker_argument_names ]
);

sub type { 'array' }

sub method_maker_class { 'Rose::DB::Object::MakeMethods::Generic' }
sub method_maker_type  { 'array' }

sub parse_value  { shift; shift->parse_array(@_)  }
sub format_value { shift; shift->format_array(@_) }

1;

__END__

=head1 NAME

Rose::DB::Object::Metadata::Column::Array - Array column metadata.

=head1 SYNOPSIS

  use Rose::DB::Object::Metadata::Column::Array;

  $col = Rose::DB::Object::Metadata::Column::Array->new(...);
  $col->make_method(...);
  ...

=head1 DESCRIPTION

Objects of this class store and manipulate metadata for array columns in a database.  Column metadata objects store information about columns (data type, size, etc.) and are responsible for creating object methods that manipulate column values.

This class inherits from C<Rose::DB::Object::Metadata::Column>. Inherited methods that are not overridden will not be documented a second time here.  See the C<Rose::DB::Object::Metadata::Column> documentation for more information.

=head1 OBJECT METHODS

=over 4

=item B<default [VALUE]>

Get or set the default value of the column.

=item B<dimensions [ARRAYREF]>

Get or set the dimensions of the column as a reference to an array of integer dimensions.

=item B<method_maker_class>

Returns C<Rose::DB::Object::MakeMethods::Generic>.

=item B<method_maker_type>

Returns C<array>.

=item B<parse_value DB, VALUE>

Parse VALUE and return a reference to an array containing the array values.  DB is a C<Rose::DB> object that is  used as part of the parsing process.  Both arguments are required.

=item B<type>

Returns "array".

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2005 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
