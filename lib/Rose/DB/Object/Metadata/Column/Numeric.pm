package Rose::DB::Object::Metadata::Column::Numeric;

use strict;

use Rose::Object::MakeMethods::Generic;

use Rose::DB::Object::Metadata::Column::Scalar;
our @ISA = qw(Rose::DB::Object::Metadata::Column::Scalar);

our $VERSION = '0.01';

__PACKAGE__->delete_method_maker_argument_names('length');

__PACKAGE__->add_method_maker_argument_names
(
  qw(precision scale)
);

Rose::Object::MakeMethods::Generic->make_methods
(
  { preserve_existing => 1 },
  scalar => [ __PACKAGE__->method_maker_argument_names ]
);

sub type { 'numeric' }

1;

__END__

=head1 NAME

Rose::DB::Object::Metadata::Column::Numeric - Numeric column metadata.

=head1 SYNOPSIS

  use Rose::DB::Object::Metadata::Column::Numeric;

  $col = Rose::DB::Object::Metadata::Column::Numeric->new(...);
  $col->make_method(...);
  ...

=head1 DESCRIPTION

Objects of this class store and manipulate metadata for numeric columns in a database.  Column metadata objects store information about columns (data type, size, etc.) and are responsible for creating object methods that manipulate column values.

This class inherits from C<Rose::DB::Object::Metadata::Column::Scalar>. Inherited methods that are not overridden will not be documented a second time here.  See the C<Rose::DB::Object::Metadata::Column::Scalar> documentation for more information.

=head1 OBJECT METHODS

=over 4

=item B<default [VALUE]>

Get or set the default value of the column.

=item B<method_maker_class>

Returns C<Rose::DB::Object::MakeMethods::Generic>.

=item B<method_maker_type>

Returns C<scalar>.

=item B<precision [INT]>

Get or set the precision of the numeric value.

=item B<scale [INT]>

Get or set the scale of the numeric value.

=item B<type>

Returns "numeric".

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2005 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
