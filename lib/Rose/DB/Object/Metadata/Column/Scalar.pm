package Rose::DB::Object::Metadata::Column::Scalar;

use strict;

use Rose::Object::MakeMethods::Generic;

use Rose::DB::Object::Metadata::Column;
our @ISA = qw(Rose::DB::Object::Metadata::Column);

our $VERSION = '0.011';

__PACKAGE__->add_method_maker_argument_names
(
  qw(length check_in with_init init_method)
);

Rose::Object::MakeMethods::Generic->make_methods
(
  { preserve_existing => 1 },
  scalar => [ __PACKAGE__->method_maker_argument_names ]
);

1;

__END__

=head1 NAME

Rose::DB::Object::Metadata::Column::Scalar - Scalar column metadata.

=head1 SYNOPSIS

  use Rose::DB::Object::Metadata::Column::Scalar;

  $col = Rose::DB::Object::Metadata::Column::Scalar->new(...);
  $col->make_method(...);
  ...

=head1 DESCRIPTION

Objects of this class store and manipulate metadata for scalar columns in a database.  Column metadata objects store information about columns (data type, size, etc.) and are responsible for creating object methods that manipulate column values.

This class inherits from L<Rose::DB::Object::Metadata::Column>. Inherited methods that are not overridden will not be documented a second time here.  See the L<Rose::DB::Object::Metadata::Column> documentation for more information.

=head1 OBJECT METHODS

=over 4

=item B<check_in [ARRAYREF]>

Get or set a reference to an array of valid column values.

=item B<init_method [NAME]>

Get or set the name of the "init" method.  See the documentation for the C<scalar> method type in L<Rose::DB::Object::MakeMethods::Generic> for more information.

=item B<length [INT]>

Get or set the length of the column in characters.

=item B<method_maker_class>

Returns L<Rose::DB::Object::MakeMethods::Generic>.

=item B<method_maker_type>

Returns C<scalar>.

=item B<type>

Returns "scalar".

=item B<with_init [BOOL]>

Get or set the flag that determines whether or not the method created by C<make_method()> will include an "init" method as well.  See the documentation for the C<scalar> method type in L<Rose::DB::Object::MakeMethods::Generic> for more information.

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2005 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
