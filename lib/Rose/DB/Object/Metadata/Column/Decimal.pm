package Rose::DB::Object::Metadata::Column::Decimal;

use strict;

use Rose::DB::Object::Metadata::Column::Numeric;
our @ISA = qw(Rose::DB::Object::Metadata::Column::Numeric);

our $VERSION = '0.01';

sub type { 'decimal' }

1;

__END__

=head1 NAME

Rose::DB::Object::Metadata::Column::Decimal - Decimal column metadata.

=head1 SYNOPSIS

  use Rose::DB::Object::Metadata::Column::Decimal;

  $col = Rose::DB::Object::Metadata::Column::Decimal->new(...);
  $col->make_method(...);
  ...

=head1 DESCRIPTION

Objects of this class store and manipulate metadata for decimal columns in a database.  Column metadata objects store information about columns (data type, size, etc.) and are responsible for creating object methods that manipulate column values.

This class inherits from C<Rose::DB::Object::Metadata::Column::Numeric>. Inherited methods that are not overridden will not be documented a second time here.  See the C<Rose::DB::Object::Metadata::Column::Numeric> documentation for more information.

=head1 OBJECT METHODS

=over 4

=item B<method_maker_class>

Returns C<Rose::DB::Object::MakeMethods::Generic>.

=item B<method_maker_type>

Returns C<scalar>.

=item B<type>

Returns "decimal".

=back

=head1 AUTHOR

John C. Siracusa (siracusa@mindspring.com)

=head1 COPYRIGHT

Copyright (c) 2005 by John C. Siracusa.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same terms
as Perl itself.
