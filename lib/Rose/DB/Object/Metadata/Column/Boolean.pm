package Rose::DB::Object::Metadata::Column::Boolean;

use strict;

use Rose::DB::Object::Metadata::Column::Scalar;
our @ISA = qw(Rose::DB::Object::Metadata::Column::Scalar);

our $VERSION = '0.02';

sub type { 'boolean' }

sub method_maker_type  { 'boolean' }

sub parse_value  { shift; shift->parse_boolean(@_)  }
sub format_value { shift; shift->format_boolean(@_) }

1;

__END__

=head1 NAME

Rose::DB::Object::Metadata::Column::Boolean - Boolean column metadata.

=head1 SYNOPSIS

  use Rose::DB::Object::Metadata::Column::Boolean;

  $col = Rose::DB::Object::Metadata::Column::Boolean->new(...);
  $col->make_method(...);
  ...

=head1 DESCRIPTION

Objects of this class store and manipulate metadata for boolean columns in a database.  Column metadata objects store information about columns (data type, size, etc.) and are responsible for creating object methods that manipulate column values.

This class inherits from C<Rose::DB::Object::Metadata::Column::Scalar>. Inherited methods that are not overridden will not be documented a second time here.  See the C<Rose::DB::Object::Metadata::Column::Scalar> documentation for more information.

=head1 OBJECT METHODS

=over 4

=item B<method_maker_class>

Returns C<Rose::DB::Object::MakeMethods::Generic>.

=item B<method_maker_type>

Returns C<boolean>.

=item B<parse_value DB, VALUE>

Parse VALUE and return true or false according to how the underlying database would view VALUE as the value for a boolean column.  DB is a C<Rose::DB> object that is used as part of the parsing process.  Both arguments are required.

=item B<type>

Returns "boolean".

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2005 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
