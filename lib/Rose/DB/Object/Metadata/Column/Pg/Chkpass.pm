package Rose::DB::Object::Metadata::Column::Pg::Chkpass;

use strict;

use Rose::Object::MakeMethods::Generic;
use Rose::DB::Object::MakeMethods::Pg;

use Rose::DB::Object::Metadata::Column;
our @ISA = qw(Rose::DB::Object::Metadata::Column);

our $VERSION = '0.01';

__PACKAGE__->add_method_maker_argument_names('encrypted_suffix', 'cmp_suffix');

Rose::Object::MakeMethods::Generic->make_methods
(
  { preserve_existing => 1 },
  scalar => [ __PACKAGE__->method_maker_argument_names ]
);

sub type { 'chkpass' }

sub method_maker_class { 'Rose::DB::Object::MakeMethods::Pg' }
sub method_maker_type  { 'chkpass' }

1;

__END__

=head1 NAME

Rose::DB::Object::Metadata::Column::Pg::Chkpass - PostgreSQL CHKPASS column metadata.

=head1 SYNOPSIS

  use Rose::DB::Object::Metadata::Column::Pg::Chkpass;

  $col = Rose::DB::Object::Metadata::Column::Pg::Chkpass->new(...);
  $col->make_method(...);
  ...

=head1 DESCRIPTION

Objects of this class store and manipulate metadata for CHKPASS columns in a PostgreSQL database.  Column metadata objects store information about columns (data type, size, etc.) and are responsible for creating object methods that manipulate column values.  See the L<Rose::DB::Object::MakeMethods::Pg> for more information on PostgreSQL's CHKPASS data type.

This class inherits from L<Rose::DB::Object::Metadata::Column>. Inherited methods that are not overridden will not be documented a second time here.  See the L<Rose::DB::Object::Metadata::Column> documentation for more information.

=head1 OBJECT METHODS

=over 4

=item B<cmp_suffix [STRING]>

Get or set the suffix used to form the name of the comparison method.   See the documentation for the C<chkpass> method type in L<Rose::DB::Object::MakeMethods::Pg> for more information.

=item B<encrypted_suffix [STRING]>

Get or set the suffix used to form the name of the accessor method for the encrypted version of the column value.   See the documentation for the C<chkpass> method type in L<Rose::DB::Object::MakeMethods::Pg> for more information.

=item B<method_maker_class>

Returns L<Rose::DB::Object::MakeMethods::Pg>.

=item B<method_maker_type>

Returns C<chkpass>.

=item B<type>

Returns "chkpass".

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2005 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
